#include "pch.h"
#include "Audio/WindowsAudioSessionService.h"

#include "Audio/ComHelpers.h"

using namespace AudioRouter::Windows::Models;

namespace AudioRouter::Windows::Audio {

WindowsAudioSessionService::WindowsAudioSessionService() {
    ThrowIfFailed(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL, IID_PPV_ARGS(m_enumerator.put())), L"Create MMDevice enumerator");
}

std::vector<AudioSource> WindowsAudioSessionService::ListAudioSources() const {
    std::vector<AudioSource> sources;
    auto manager = DefaultSessionManager();
    ComPtr<IAudioSessionEnumerator> enumerator;
    ThrowIfFailed(manager->GetSessionEnumerator(enumerator.put()), L"Get audio session enumerator");

    int count = 0;
    ThrowIfFailed(enumerator->GetCount(&count), L"Read audio session count");
    sources.reserve(static_cast<size_t>(count));

    for (int index = 0; index < count; ++index) {
        ComPtr<IAudioSessionControl> control;
        if (SUCCEEDED(enumerator->GetSession(index, control.put()))) {
            sources.push_back(ReadSession(control.get()));
        }
    }

    return sources;
}

bool WindowsAudioSessionService::SetSessionVolume(std::wstring const& sourceId, double volume) const {
    auto manager = DefaultSessionManager();
    ComPtr<IAudioSessionEnumerator> enumerator;
    if (FAILED(manager->GetSessionEnumerator(enumerator.put()))) {
        return false;
    }

    int count = 0;
    if (FAILED(enumerator->GetCount(&count))) {
        return false;
    }

    for (int index = 0; index < count; ++index) {
        ComPtr<IAudioSessionControl> control;
        if (FAILED(enumerator->GetSession(index, control.put()))) {
            continue;
        }

        auto source = ReadSession(control.get());
        if (source.id != sourceId) {
            continue;
        }

        ComPtr<ISimpleAudioVolume> volumeControl;
        if (SUCCEEDED(control->QueryInterface(__uuidof(ISimpleAudioVolume), volumeControl.put_void()))) {
            return SUCCEEDED(volumeControl->SetMasterVolume(static_cast<float>(Clamp01(volume)), nullptr));
        }
    }

    return false;
}

bool WindowsAudioSessionService::SetSessionMute(std::wstring const& sourceId, bool muted) const {
    auto manager = DefaultSessionManager();
    ComPtr<IAudioSessionEnumerator> enumerator;
    if (FAILED(manager->GetSessionEnumerator(enumerator.put()))) {
        return false;
    }

    int count = 0;
    if (FAILED(enumerator->GetCount(&count))) {
        return false;
    }

    for (int index = 0; index < count; ++index) {
        ComPtr<IAudioSessionControl> control;
        if (FAILED(enumerator->GetSession(index, control.put()))) {
            continue;
        }

        auto source = ReadSession(control.get());
        if (source.id != sourceId) {
            continue;
        }

        ComPtr<ISimpleAudioVolume> volumeControl;
        if (SUCCEEDED(control->QueryInterface(__uuidof(ISimpleAudioVolume), volumeControl.put_void()))) {
            return SUCCEEDED(volumeControl->SetMute(muted ? TRUE : FALSE, nullptr));
        }
    }

    return false;
}

ComPtr<IAudioSessionManager2> WindowsAudioSessionService::DefaultSessionManager() const {
    ComPtr<IMMDevice> device;
    ThrowIfFailed(m_enumerator->GetDefaultAudioEndpoint(eRender, eConsole, device.put()), L"Get default render endpoint");

    ComPtr<IAudioSessionManager2> manager;
    ThrowIfFailed(device->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL, nullptr, manager.put_void()), L"Activate audio session manager");
    return manager;
}

AudioSource WindowsAudioSessionService::ReadSession(IAudioSessionControl* control) {
    AudioSource source;

    ComPtr<IAudioSessionControl2> control2;
    if (SUCCEEDED(control->QueryInterface(__uuidof(IAudioSessionControl2), control2.put_void()))) {
        DWORD pid = 0;
        if (SUCCEEDED(control2->GetProcessId(&pid))) {
            source.processID = pid;
            source.id = SourceIdForProcess(pid);
            source.executablePath = ProcessPath(pid);
            source.appName = ProcessName(pid);
        }

        LPWSTR sessionId = nullptr;
        if (SUCCEEDED(control2->GetSessionIdentifier(&sessionId))) {
            source.appUserModelId = CoTaskMemStringToWString(sessionId);
        }
    }

    if (source.id.empty()) {
        source.id = L"session:unknown";
    }
    if (source.appName.empty()) {
        LPWSTR displayName = nullptr;
        if (SUCCEEDED(control->GetDisplayName(&displayName))) {
            source.appName = CoTaskMemStringToWString(displayName);
        }
    }
    if (source.appName.empty()) {
        source.appName = L"System Audio";
    }

    AudioSessionState state = AudioSessionStateInactive;
    if (SUCCEEDED(control->GetState(&state))) {
        source.isRunning = state != AudioSessionStateExpired;
        source.isProducingAudio = state == AudioSessionStateActive;
    }

    ComPtr<ISimpleAudioVolume> volumeControl;
    if (SUCCEEDED(control->QueryInterface(__uuidof(ISimpleAudioVolume), volumeControl.put_void()))) {
        float volume = 1;
        if (SUCCEEDED(volumeControl->GetMasterVolume(&volume))) {
            source.volume = volume;
        }
        BOOL muted = FALSE;
        if (SUCCEEDED(volumeControl->GetMute(&muted))) {
            source.isMuted = muted == TRUE;
        }
    }

    ComPtr<IAudioMeterInformation> meter;
    if (SUCCEEDED(control->QueryInterface(__uuidof(IAudioMeterInformation), meter.put_void()))) {
        float peak = 0;
        if (SUCCEEDED(meter->GetPeakValue(&peak))) {
            source.currentLevel = std::clamp(static_cast<double>(peak), 0.0, 1.0);
        }
    }

    return source;
}

std::wstring WindowsAudioSessionService::SourceIdForProcess(unsigned long processId) {
    return L"process:" + std::to_wstring(processId);
}

std::wstring WindowsAudioSessionService::ProcessName(unsigned long processId) {
    auto path = ProcessPath(processId);
    if (path.empty()) {
        return processId == 0 ? L"System Audio" : L"Process " + std::to_wstring(processId);
    }

    std::filesystem::path file(path);
    auto stem = file.stem().wstring();
    return stem.empty() ? file.filename().wstring() : stem;
}

std::wstring WindowsAudioSessionService::ProcessPath(unsigned long processId) {
    if (processId == 0) {
        return {};
    }

    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, processId);
    if (process == nullptr) {
        return {};
    }

    std::wstring path(MAX_PATH, L'\0');
    DWORD size = static_cast<DWORD>(path.size());
    if (!QueryFullProcessImageNameW(process, 0, path.data(), &size)) {
        CloseHandle(process);
        return {};
    }

    CloseHandle(process);
    path.resize(size);
    return path;
}

} // namespace AudioRouter::Windows::Audio
