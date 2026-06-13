#include "pch.h"
#include "Audio/WindowsRoutingBackend.h"

using namespace AudioRouter::Windows::Models;

namespace AudioRouter::Windows::Audio {

WindowsRoutingBackend::WindowsRoutingBackend() = default;

BackendStatus WindowsRoutingBackend::Status() const {
    BackendStatus status;
    status.supportsProcessLoopback = m_processLoopback.IsSupported();
    status.supportsTruePerAppRouting = false;
    status.requiresDriverForProductionRouting = true;
    return status;
}

std::vector<AudioOutputDevice> WindowsRoutingBackend::ListOutputDevices() const {
    return m_devices.ListOutputDevices();
}

std::vector<AudioOutputDevice> WindowsRoutingBackend::ListInputDevices() const {
    return m_devices.ListInputDevices();
}

std::vector<AudioSource> WindowsRoutingBackend::ListAudioSources() const {
    return m_sessions.ListAudioSources();
}

bool WindowsRoutingBackend::SetOutputVolume(std::wstring const& deviceId, double volume) const {
    return m_devices.SetEndpointVolume(deviceId, volume);
}

bool WindowsRoutingBackend::SetOutputMute(std::wstring const& deviceId, bool muted) const {
    return m_devices.SetEndpointMute(deviceId, muted);
}

bool WindowsRoutingBackend::SetSourceVolume(std::wstring const& sourceId, double volume) const {
    return m_sessions.SetSessionVolume(sourceId, volume);
}

bool WindowsRoutingBackend::SetSourceMute(std::wstring const& sourceId, bool muted) const {
    return m_sessions.SetSessionMute(sourceId, muted);
}

AudioRoute WindowsRoutingBackend::AssignRoute(AudioSource const& source, std::optional<std::wstring> const& outputDeviceId) {
    AudioRoute route;
    route.sourceAppID = source.id;
    route.outputDeviceID = outputDeviceId;
    route.volume = source.volume;
    route.isMuted = source.isMuted;

    if (!outputDeviceId.has_value()) {
        route.routeMode = AudioRouteMode::FollowSystemOutput;
        route.status = AudioRouteStatus::Active;
        return route;
    }

    auto outputs = ListOutputDevices();
    auto output = std::find_if(outputs.begin(), outputs.end(), [&](AudioOutputDevice const& candidate) {
        return candidate.id == outputDeviceId.value() || candidate.uid == outputDeviceId.value();
    });

    if (output == outputs.end() || !output->isConnected) {
        route.routeMode = AudioRouteMode::CustomOutput;
        route.status = AudioRouteStatus::DeviceMissing;
        return route;
    }

    route.routeMode = AudioRouteMode::CustomOutput;
    route.status = m_processLoopback.StartRoute(source, *output);
    return route;
}

void WindowsRoutingBackend::OpenSoundSettings() const {
    m_devices.OpenSoundSettings();
}

} // namespace AudioRouter::Windows::Audio
