#pragma once

#include "Models/AudioContracts.h"

namespace AudioRouter::Windows::Audio {

class ProcessLoopbackCapture {
public:
    bool IsSupported() const;

    // Future implementation:
    // - Activate WASAPI process-loopback capture with AUDIOCLIENT_PROCESS_LOOPBACK_PARAMS.
    // - Keep the captured stream as 32-bit float where possible.
    // - Render to one or more selected endpoints with WASAPI render clients.
    // - Mute or reduce the original session while the route is live.
    Models::AudioRouteStatus StartRoute(Models::AudioSource const& source, Models::AudioOutputDevice const& output);
    void StopRoute(std::wstring const& sourceId);
};

} // namespace AudioRouter::Windows::Audio
