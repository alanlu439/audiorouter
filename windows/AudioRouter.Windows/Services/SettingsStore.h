#pragma once

#include "Models/AudioContracts.h"

namespace AudioRouter::Windows::Services {

class SettingsStore {
public:
    std::filesystem::path SettingsPath() const;
    void SaveRoutes(std::vector<Models::AudioRoute> const& routes) const;
    std::vector<Models::AudioRoute> LoadRoutes() const;
};

} // namespace AudioRouter::Windows::Services
