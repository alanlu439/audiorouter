#include "pch.h"
#include "App.xaml.h"
#include "MainWindow.xaml.h"

using namespace winrt;
using namespace Microsoft::UI::Xaml;

namespace winrt::AudioRouterWindows::implementation {

App::App() {
    InitializeComponent();
}

void App::OnLaunched(Windows::ApplicationModel::Activation::LaunchActivatedEventArgs const&) {
    m_window = make<MainWindow>();
    m_window.Activate();
}

} // namespace winrt::AudioRouterWindows::implementation
