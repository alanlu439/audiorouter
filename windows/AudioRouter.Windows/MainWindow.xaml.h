#pragma once

#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Controls.Primitives.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>

#include "Audio/WindowsRoutingBackend.h"
#include "MainWindow.xaml.g.h"
#include "Shell/TrayIconController.h"

namespace muxcp = winrt::Microsoft::UI::Xaml::Controls::Primitives;
namespace muxc = winrt::Microsoft::UI::Xaml::Controls;

namespace winrt::AudioRouterWindows::implementation {

struct MainWindow : MainWindowT<MainWindow> {
    MainWindow();
    ~MainWindow();

    void RefreshButton_Click(winrt::Windows::Foundation::IInspectable const&, Microsoft::UI::Xaml::RoutedEventArgs const&);
    void SoundSettingsButton_Click(winrt::Windows::Foundation::IInspectable const&, Microsoft::UI::Xaml::RoutedEventArgs const&);

private:
    AudioRouter::Windows::Audio::WindowsRoutingBackend m_backend;
    AudioRouter::Windows::Shell::TrayIconController m_tray;
    std::optional<std::wstring> m_selectedSourceId;

    void Refresh();
    void InstallKeyboardShortcuts();
    void BuildSourceCard(AudioRouter::Windows::Models::AudioSource const& source);
    void BuildOutputCard(AudioRouter::Windows::Models::AudioOutputDevice const& output);
    muxc::Button SmallButton(winrt::hstring const& text);
    Microsoft::UI::Xaml::Controls::Border CardBorder() const;
    winrt::hstring PercentText(double value) const;
};

} // namespace winrt::AudioRouterWindows::implementation

namespace winrt::AudioRouterWindows::factory_implementation {

struct MainWindow : MainWindowT<MainWindow, implementation::MainWindow> {
};

} // namespace winrt::AudioRouterWindows::factory_implementation
