#pragma once

#include <algorithm>
#include <optional>
#include <string>
#include <vector>

namespace AudioRouter::Windows::Models {

enum class AudioDeviceKind {
    Output,
    Input
};

enum class AudioTransport {
    BuiltIn,
    Bluetooth,
    Usb,
    Hdmi,
    DisplayPort,
    Virtual,
    Unknown
};

enum class AudioRouteMode {
    FollowSystemOutput,
    CustomOutput,
    Unsupported
};

enum class AudioRouteStatus {
    Active,
    Live,
    SavedOnly,
    Simulated,
    RequiresDriver,
    Unsupported,
    DeviceMissing
};

struct AudioSampleRateRange {
    double minimum = 0;
    double maximum = 0;
};

struct AudioOutputDevice {
    std::wstring id;
    std::wstring uid;
    std::wstring name;
    AudioDeviceKind kind = AudioDeviceKind::Output;
    int channelCount = 0;
    AudioTransport transport = AudioTransport::Unknown;
    bool isDefault = false;
    bool isConnected = false;
    bool supportsVolume = false;
    bool supportsMute = false;
    bool supportsBalance = false;
    std::optional<double> volume;
    std::optional<bool> isMuted;
    std::optional<double> balance;
    std::optional<double> sampleRate;
    std::vector<AudioSampleRateRange> sampleRateRanges;
};

struct AudioSource {
    std::wstring id;
    std::wstring appName;
    std::wstring appUserModelId;
    std::wstring executablePath;
    unsigned long processID = 0;
    bool isRunning = false;
    bool isProducingAudio = false;
    std::optional<double> currentLevel;
    double volume = 1.0;
    bool isMuted = false;
    AudioRouteMode routeMode = AudioRouteMode::FollowSystemOutput;
    std::optional<std::wstring> assignedOutputDeviceID;
    bool followsSystemOutput = true;
    std::optional<double> sourceSampleRate;
};

struct AudioRoute {
    std::wstring sourceAppID;
    std::optional<std::wstring> outputDeviceID;
    double volume = 1.0;
    bool isMuted = false;
    AudioRouteMode routeMode = AudioRouteMode::FollowSystemOutput;
    AudioRouteStatus status = AudioRouteStatus::Active;
};

struct OutputGroup {
    std::wstring id;
    std::wstring name;
    std::vector<std::wstring> deviceIDs;
};

struct EQState {
    std::wstring selectedPreset = L"Flat";
    std::vector<double> bands = std::vector<double>(10, 0.0);
    std::vector<double> customBands = std::vector<double>(10, 0.0);
};

struct BackendStatus {
    std::wstring backendName = L"Windows Core Audio";
    bool supportsEndpointVolume = true;
    bool supportsPerSessionVolume = true;
    bool supportsProcessLoopback = false;
    bool supportsTruePerAppRouting = false;
    bool requiresDriverForProductionRouting = true;
};

inline double Clamp01(double value) {
    return std::clamp(value, 0.0, 1.0);
}

inline std::wstring ToDisplayText(AudioRouteStatus status) {
    switch (status) {
    case AudioRouteStatus::Active:
        return L"Working";
    case AudioRouteStatus::Live:
        return L"Live";
    case AudioRouteStatus::SavedOnly:
        return L"Saved Only";
    case AudioRouteStatus::Simulated:
        return L"Simulated";
    case AudioRouteStatus::RequiresDriver:
        return L"Requires Driver";
    case AudioRouteStatus::Unsupported:
        return L"Unsupported";
    case AudioRouteStatus::DeviceMissing:
        return L"Device Missing";
    }
    return L"Unknown";
}

inline std::wstring ToDisplayText(AudioTransport transport) {
    switch (transport) {
    case AudioTransport::BuiltIn:
        return L"Built In";
    case AudioTransport::Bluetooth:
        return L"Bluetooth";
    case AudioTransport::Usb:
        return L"USB";
    case AudioTransport::Hdmi:
        return L"HDMI";
    case AudioTransport::DisplayPort:
        return L"DisplayPort";
    case AudioTransport::Virtual:
        return L"Virtual";
    case AudioTransport::Unknown:
        return L"Unknown";
    }
    return L"Unknown";
}

} // namespace AudioRouter::Windows::Models
