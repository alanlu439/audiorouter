#include "pch.h"
#include "Audio/WindowsAudioDeviceService.h"

#include "Audio/ComHelpers.h"

using namespace AudioRouter::Windows::Models;

namespace AudioRouter::Windows::Audio {

WindowsAudioDeviceService::WindowsAudioDeviceService() {
    ThrowIfFailed(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL, IID_PPV_ARGS(m_enumerator.put())), L"Create MMDevice enumerator");
}

std::vector<AudioOutputDevice> WindowsAudioDeviceService::ListOutputDevices() const {
    return ListEndpoints(eRender);
}

std::vector<AudioOutputDevice> WindowsAudioDeviceService::ListInputDevices() const {
    return ListEndpoints(eCapture);
}

std::optional<std::wstring> WindowsAudioDeviceService::DefaultOutputDeviceId() const {
    return DefaultDeviceId(eRender);
}

std::optional<std::wstring> WindowsAudioDeviceService::DefaultInputDeviceId() const {
    return DefaultDeviceId(eCapture);
}

bool WindowsAudioDeviceService::SetEndpointVolume(std::wstring const& endpointId, double volume) const {
    try {
        auto device = DeviceFromId(endpointId);
        ComPtr<IAudioEndpointVolume> endpointVolume;
        HRESULT result = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr, endpointVolume.put_void());
        if (FAILED(result)) {
            return false;
        }
        return SUCCEEDED(endpointVolume->SetMasterVolumeLevelScalar(static_cast<float>(Clamp01(volume)), nullptr));
    } catch (...) {
        return false;
    }
}

bool WindowsAudioDeviceService::SetEndpointMute(std::wstring const& endpointId, bool muted) const {
    try {
        auto device = DeviceFromId(endpointId);
        ComPtr<IAudioEndpointVolume> endpointVolume;
        HRESULT result = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr, endpointVolume.put_void());
        if (FAILED(result)) {
            return false;
        }
        return SUCCEEDED(endpointVolume->SetMute(muted ? TRUE : FALSE, nullptr));
    } catch (...) {
        return false;
    }
}

void WindowsAudioDeviceService::OpenSoundSettings() const {
    ShellExecuteW(nullptr, L"open", L"ms-settings:sound", nullptr, nullptr, SW_SHOWNORMAL);
}

std::vector<AudioOutputDevice> WindowsAudioDeviceService::ListEndpoints(EDataFlow flow) const {
    std::vector<AudioOutputDevice> devices;
    auto defaultId = DefaultDeviceId(flow);

    ComPtr<IMMDeviceCollection> collection;
    ThrowIfFailed(m_enumerator->EnumAudioEndpoints(flow, DEVICE_STATE_ACTIVE | DEVICE_STATE_UNPLUGGED | DEVICE_STATE_DISABLED, collection.put()), L"Enumerate audio endpoints");

    UINT count = 0;
    ThrowIfFailed(collection->GetCount(&count), L"Read endpoint count");
    devices.reserve(count);

    for (UINT index = 0; index < count; ++index) {
        ComPtr<IMMDevice> device;
        if (SUCCEEDED(collection->Item(index, device.put()))) {
            devices.push_back(ReadEndpoint(device.get(), flow, defaultId));
        }
    }

    return devices;
}

std::optional<std::wstring> WindowsAudioDeviceService::DefaultDeviceId(EDataFlow flow) const {
    ComPtr<IMMDevice> device;
    if (FAILED(m_enumerator->GetDefaultAudioEndpoint(flow, eConsole, device.put()))) {
        return std::nullopt;
    }
    LPWSTR rawId = nullptr;
    if (FAILED(device->GetId(&rawId))) {
        return std::nullopt;
    }
    return CoTaskMemStringToWString(rawId);
}

AudioOutputDevice WindowsAudioDeviceService::ReadEndpoint(IMMDevice* device, EDataFlow flow, std::optional<std::wstring> const& defaultId) const {
    LPWSTR rawId = nullptr;
    ThrowIfFailed(device->GetId(&rawId), L"Read endpoint id");
    std::wstring id = CoTaskMemStringToWString(rawId);

    DWORD state = 0;
    ThrowIfFailed(device->GetState(&state), L"Read endpoint state");

    std::wstring name = L"Audio Device";
    ComPtr<IPropertyStore> properties;
    if (SUCCEEDED(device->OpenPropertyStore(STGM_READ, properties.put()))) {
        PropVariantScope friendlyName;
        if (SUCCEEDED(properties->GetValue(PKEY_Device_FriendlyName, &friendlyName.value))) {
            auto text = PropVariantToWString(friendlyName.value);
            if (!text.empty()) {
                name = text;
            }
        }
    }

    AudioOutputDevice info;
    info.id = id;
    info.uid = id;
    info.name = name;
    info.kind = flow == eRender ? AudioDeviceKind::Output : AudioDeviceKind::Input;
    info.isDefault = defaultId.has_value() && defaultId.value() == id;
    info.isConnected = state == DEVICE_STATE_ACTIVE;
    info.transport = TransportFromEndpoint(device, name);

    ComPtr<IAudioClient> audioClient;
    if (SUCCEEDED(device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr, audioClient.put_void()))) {
        WAVEFORMATEX* mixFormat = nullptr;
        if (SUCCEEDED(audioClient->GetMixFormat(&mixFormat)) && mixFormat != nullptr) {
            info.channelCount = mixFormat->nChannels;
            info.sampleRate = static_cast<double>(mixFormat->nSamplesPerSec);
            CoTaskMemFree(mixFormat);
        }
    }

    ComPtr<IAudioEndpointVolume> endpointVolume;
    if (SUCCEEDED(device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr, endpointVolume.put_void()))) {
        float volume = 0;
        if (SUCCEEDED(endpointVolume->GetMasterVolumeLevelScalar(&volume))) {
            info.volume = static_cast<double>(volume);
            info.supportsVolume = true;
        }

        BOOL muted = FALSE;
        if (SUCCEEDED(endpointVolume->GetMute(&muted))) {
            info.isMuted = muted == TRUE;
            info.supportsMute = true;
        }

        UINT channelCount = 0;
        if (SUCCEEDED(endpointVolume->GetChannelCount(&channelCount)) && channelCount >= 2) {
            float left = 0;
            float right = 0;
            if (SUCCEEDED(endpointVolume->GetChannelVolumeLevelScalar(0, &left)) &&
                SUCCEEDED(endpointVolume->GetChannelVolumeLevelScalar(1, &right))) {
                double total = std::max(0.001f, left + right);
                info.balance = std::clamp((static_cast<double>(right - left) / total), -1.0, 1.0);
                info.supportsBalance = true;
            }
        }
    }

    return info;
}

ComPtr<IMMDevice> WindowsAudioDeviceService::DeviceFromId(std::wstring const& endpointId) const {
    ComPtr<IMMDevice> device;
    ThrowIfFailed(m_enumerator->GetDevice(endpointId.c_str(), device.put()), L"Open endpoint");
    return device;
}

AudioTransport WindowsAudioDeviceService::TransportFromEndpoint(IMMDevice* device, std::wstring const& name) {
    std::wstring lowerName = name;
    std::transform(lowerName.begin(), lowerName.end(), lowerName.begin(), [](wchar_t value) {
        return static_cast<wchar_t>(towlower(value));
    });

    if (lowerName.find(L"bluetooth") != std::wstring::npos || lowerName.find(L"airpods") != std::wstring::npos) {
        return AudioTransport::Bluetooth;
    }
    if (lowerName.find(L"usb") != std::wstring::npos) {
        return AudioTransport::Usb;
    }
    if (lowerName.find(L"hdmi") != std::wstring::npos) {
        return AudioTransport::Hdmi;
    }
    if (lowerName.find(L"displayport") != std::wstring::npos) {
        return AudioTransport::DisplayPort;
    }

    ComPtr<IPropertyStore> properties;
    if (SUCCEEDED(device->OpenPropertyStore(STGM_READ, properties.put()))) {
        PropVariantScope formFactor;
        if (SUCCEEDED(properties->GetValue(PKEY_AudioEndpoint_FormFactor, &formFactor.value)) && formFactor.value.vt == VT_UI4) {
            switch (formFactor.value.ulVal) {
            case Speakers:
            case Headphones:
                return AudioTransport::BuiltIn;
            case SPDIF:
            case DigitalAudioDisplayDevice:
            default:
                break;
            }
        }
    }

    return AudioTransport::Unknown;
}

} // namespace AudioRouter::Windows::Audio
