#include "pch.h"
#include "Audio/ProcessLoopbackCapture.h"

namespace AudioRouter::Windows::Audio {

bool ProcessLoopbackCapture::IsSupported() const {
    OSVERSIONINFOEXW version{};
    version.dwOSVersionInfoSize = sizeof(version);
    using RtlGetVersionFn = LONG(WINAPI*)(OSVERSIONINFOW*);
    auto ntdll = GetModuleHandleW(L"ntdll.dll");
    if (ntdll == nullptr) {
        return false;
    }

    auto rtlGetVersion = reinterpret_cast<RtlGetVersionFn>(GetProcAddress(ntdll, "RtlGetVersion"));
    if (rtlGetVersion == nullptr || rtlGetVersion(reinterpret_cast<OSVERSIONINFOW*>(&version)) != 0) {
        return false;
    }

    // Windows process-loopback capture is available on newer Windows builds. AudioRouter
    // keeps this behind a capability flag because the route renderer still needs endpoint
    // synchronization, duplicate-playback suppression, and latency controls before it can
    // be presented as production-ready routing.
    return version.dwMajorVersion >= 10 && version.dwBuildNumber >= 20348;
}

Models::AudioRouteStatus ProcessLoopbackCapture::StartRoute(Models::AudioSource const&, Models::AudioOutputDevice const&) {
    return IsSupported() ? Models::AudioRouteStatus::RequiresDriver : Models::AudioRouteStatus::Unsupported;
}

void ProcessLoopbackCapture::StopRoute(std::wstring const&) {
}

} // namespace AudioRouter::Windows::Audio
