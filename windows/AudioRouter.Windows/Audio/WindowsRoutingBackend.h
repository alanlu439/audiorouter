#pragma once

#include "Audio/ProcessLoopbackCapture.h"
#include "Audio/WindowsAudioDeviceService.h"
#include "Audio/WindowsAudioSessionService.h"
#include "Models/AudioContracts.h"

namespace AudioRouter::Windows::Audio {

class WindowsRoutingBackend {
public:
    WindowsRoutingBackend();

    Models::BackendStatus Status() const;
    std::vector<Models::AudioOutputDevice> ListOutputDevices() const;
    std::vector<Models::AudioOutputDevice> ListInputDevices() const;
    std::vector<Models::AudioSource> ListAudioSources() const;

    bool SetOutputVolume(std::wstring const& deviceId, double volume) const;
    bool SetOutputMute(std::wstring const& deviceId, bool muted) const;
    bool SetSourceVolume(std::wstring const& sourceId, double volume) const;
    bool SetSourceMute(std::wstring const& sourceId, bool muted) const;

    Models::AudioRoute AssignRoute(Models::AudioSource const& source, std::optional<std::wstring> const& outputDeviceId);
    void OpenSoundSettings() const;

private:
    WindowsAudioDeviceService m_devices;
    WindowsAudioSessionService m_sessions;
    ProcessLoopbackCapture m_processLoopback;
};

} // namespace AudioRouter::Windows::Audio
