#pragma once

#include "Audio/ComHelpers.h"
#include "Models/AudioContracts.h"

namespace AudioRouter::Windows::Audio {

class WindowsAudioDeviceService {
public:
    WindowsAudioDeviceService();

    std::vector<Models::AudioOutputDevice> ListOutputDevices() const;
    std::vector<Models::AudioOutputDevice> ListInputDevices() const;
    std::optional<std::wstring> DefaultOutputDeviceId() const;
    std::optional<std::wstring> DefaultInputDeviceId() const;

    bool SetEndpointVolume(std::wstring const& endpointId, double volume) const;
    bool SetEndpointMute(std::wstring const& endpointId, bool muted) const;
    void OpenSoundSettings() const;

private:
    ComPtr<IMMDeviceEnumerator> m_enumerator;

    std::vector<Models::AudioOutputDevice> ListEndpoints(EDataFlow flow) const;
    std::optional<std::wstring> DefaultDeviceId(EDataFlow flow) const;
    Models::AudioOutputDevice ReadEndpoint(IMMDevice* device, EDataFlow flow, std::optional<std::wstring> const& defaultId) const;
    ComPtr<IMMDevice> DeviceFromId(std::wstring const& endpointId) const;
    static Models::AudioTransport TransportFromEndpoint(IMMDevice* device, std::wstring const& name);
};

} // namespace AudioRouter::Windows::Audio
