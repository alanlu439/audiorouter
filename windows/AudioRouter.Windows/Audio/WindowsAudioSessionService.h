#pragma once

#include "Audio/ComHelpers.h"
#include "Models/AudioContracts.h"

namespace AudioRouter::Windows::Audio {

class WindowsAudioSessionService {
public:
    WindowsAudioSessionService();

    std::vector<Models::AudioSource> ListAudioSources() const;
    bool SetSessionVolume(std::wstring const& sourceId, double volume) const;
    bool SetSessionMute(std::wstring const& sourceId, bool muted) const;

private:
    ComPtr<IMMDeviceEnumerator> m_enumerator;

    ComPtr<IAudioSessionManager2> DefaultSessionManager() const;
    static Models::AudioSource ReadSession(IAudioSessionControl* control);
    static std::wstring SourceIdForProcess(unsigned long processId);
    static std::wstring ProcessName(unsigned long processId);
    static std::wstring ProcessPath(unsigned long processId);
};

} // namespace AudioRouter::Windows::Audio
