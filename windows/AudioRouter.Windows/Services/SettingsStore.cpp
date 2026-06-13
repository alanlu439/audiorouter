#include "pch.h"
#include "Services/SettingsStore.h"

#include <fstream>

namespace AudioRouter::Windows::Services {

namespace {

std::wstring EscapeJson(std::wstring const& value) {
    std::wstring escaped;
    escaped.reserve(value.size());
    for (wchar_t character : value) {
        switch (character) {
        case L'\\':
            escaped += L"\\\\";
            break;
        case L'"':
            escaped += L"\\\"";
            break;
        case L'\n':
            escaped += L"\\n";
            break;
        case L'\r':
            escaped += L"\\r";
            break;
        case L'\t':
            escaped += L"\\t";
            break;
        default:
            escaped += character;
            break;
        }
    }
    return escaped;
}

} // namespace

std::filesystem::path SettingsStore::SettingsPath() const {
    wchar_t* localAppData = nullptr;
    size_t length = 0;
    _wdupenv_s(&localAppData, &length, L"LOCALAPPDATA");
    std::filesystem::path base = localAppData != nullptr ? localAppData : L".";
    if (localAppData != nullptr) {
        free(localAppData);
    }

    auto folder = base / L"AudioRouter";
    std::filesystem::create_directories(folder);
    return folder / L"routes.json";
}

void SettingsStore::SaveRoutes(std::vector<Models::AudioRoute> const& routes) const {
    std::wofstream stream(SettingsPath());
    stream << L"{\n  \"schemaVersion\": 1,\n  \"routes\": [\n";
    for (size_t index = 0; index < routes.size(); ++index) {
        auto const& route = routes[index];
        stream << L"    {\n";
        stream << L"      \"sourceAppID\": \"" << EscapeJson(route.sourceAppID) << L"\",\n";
        stream << L"      \"outputDeviceID\": \"" << EscapeJson(route.outputDeviceID.value_or(L"")) << L"\",\n";
        stream << L"      \"volume\": " << route.volume << L",\n";
        stream << L"      \"isMuted\": " << (route.isMuted ? L"true" : L"false") << L"\n";
        stream << L"    }" << (index + 1 == routes.size() ? L"\n" : L",\n");
    }
    stream << L"  ]\n}\n";
}

std::vector<Models::AudioRoute> SettingsStore::LoadRoutes() const {
    // Full JSON parsing is intentionally deferred until the Windows settings UI is wired.
    // The schema is already shared in shared/contracts/audio-router-settings.schema.json.
    return {};
}

} // namespace AudioRouter::Windows::Services
