#pragma once

#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Windows.ApplicationModel.Activation.h>

#include "App.xaml.g.h"

namespace winrt::AudioRouterWindows::implementation {

struct App : AppT<App> {
    App();
    void OnLaunched(Windows::ApplicationModel::Activation::LaunchActivatedEventArgs const&);

private:
    Microsoft::UI::Xaml::Window m_window{ nullptr };
};

} // namespace winrt::AudioRouterWindows::implementation

namespace winrt::AudioRouterWindows::factory_implementation {

struct App : AppT<App, implementation::App> {
};

} // namespace winrt::AudioRouterWindows::factory_implementation
