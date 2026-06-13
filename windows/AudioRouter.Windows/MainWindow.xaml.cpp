#include "pch.h"
#include "MainWindow.xaml.h"

#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace winrt;
using namespace Microsoft::UI::Xaml;
using namespace Microsoft::UI::Xaml::Controls;
using namespace Microsoft::UI::Xaml::Input;
using namespace Microsoft::UI::Xaml::Media;
using namespace AudioRouter::Windows::Models;

namespace {

winrt::Microsoft::UI::Xaml::Media::SolidColorBrush Brush(uint8_t r, uint8_t g, uint8_t b, uint8_t a = 255) {
    return SolidColorBrush(winrt::Windows::UI::Color{ a, r, g, b });
}

winrt::hstring H(std::wstring const& value) {
    return winrt::hstring(value);
}

} // namespace

namespace winrt::AudioRouterWindows::implementation {

MainWindow::MainWindow() {
    InitializeComponent();
    InstallKeyboardShortcuts();
    m_tray.Install(L"AudioRouter", [this] {
        DispatcherQueue().TryEnqueue([this] {
            Activate();
        });
    });
    Refresh();
}

MainWindow::~MainWindow() {
    m_tray.Remove();
}

void MainWindow::RefreshButton_Click(IInspectable const&, RoutedEventArgs const&) {
    Refresh();
}

void MainWindow::SoundSettingsButton_Click(IInspectable const&, RoutedEventArgs const&) {
    m_backend.OpenSoundSettings();
}

void MainWindow::Refresh() {
    try {
        auto status = m_backend.Status();
        StatusText().Text(H(status.backendName + L" ready"));
        CapabilityText().Text(status.supportsProcessLoopback
            ? L"Process-loopback capture is available on this Windows build. Production per-app routing remains gated behind the routing renderer and driver capability."
            : L"Endpoint/session controls are live. Process-loopback routing is unavailable on this Windows build.");

        auto sources = m_backend.ListAudioSources();
        auto outputs = m_backend.ListOutputDevices();
        SourceCountText().Text(winrt::to_hstring(sources.size()) + L" sessions");
        OutputCountText().Text(winrt::to_hstring(outputs.size()) + L" devices");

        SourceList().Children().Clear();
        for (auto const& source : sources) {
            BuildSourceCard(source);
        }

        OutputList().Children().Clear();
        for (auto const& output : outputs) {
            BuildOutputCard(output);
        }
    } catch (std::exception const& error) {
        StatusText().Text(L"Windows Core Audio error");
        CapabilityText().Text(winrt::to_hstring(error.what()));
    }
}

void MainWindow::InstallKeyboardShortcuts() {
    auto install = [this](Windows::System::VirtualKey key, double delta) {
        KeyboardAccelerator accelerator;
        accelerator.Key(key);
        accelerator.Modifiers(Windows::System::VirtualKeyModifiers::Control);
        accelerator.Invoked([this, delta](KeyboardAccelerator const&, KeyboardAcceleratorInvokedEventArgs const& args) {
            if (m_selectedSourceId.has_value()) {
                auto sources = m_backend.ListAudioSources();
                auto found = std::find_if(sources.begin(), sources.end(), [&](AudioSource const& source) {
                    return source.id == m_selectedSourceId.value();
                });
                if (found != sources.end()) {
                    m_backend.SetSourceVolume(found->id, std::clamp(found->volume + delta, 0.0, 1.0));
                    Refresh();
                }
            }
            args.Handled(true);
        });
        Content().as<UIElement>().KeyboardAccelerators().Append(accelerator);
    };

    install(Windows::System::VirtualKey::OemPlus, 0.01);
    install(Windows::System::VirtualKey::Add, 0.01);
    install(Windows::System::VirtualKey::OemMinus, -0.01);
    install(Windows::System::VirtualKey::Subtract, -0.01);
}

void MainWindow::BuildSourceCard(AudioSource const& source) {
    auto border = CardBorder();
    border.BorderBrush(source.id == m_selectedSourceId.value_or(L"") ? Brush(230, 179, 90) : Brush(41, 48, 53));

    Grid grid;
    grid.ColumnSpacing(12);
    grid.ColumnDefinitions().Append(ColumnDefinition());
    grid.ColumnDefinitions().Append(ColumnDefinition());
    grid.ColumnDefinitions().Append(ColumnDefinition());
    grid.ColumnDefinitions().GetAt(0).Width(GridLengthHelper::FromPixels(220));
    grid.ColumnDefinitions().GetAt(1).Width(GridLengthHelper::FromValueAndType(1, GridUnitType::Star));
    grid.ColumnDefinitions().GetAt(2).Width(GridLengthHelper::FromPixels(180));

    StackPanel title;
    title.Spacing(3);
    TextBlock name;
    name.Text(H(source.appName));
    name.Foreground(Brush(245, 245, 243));
    name.FontSize(16);
    name.FontWeight(Windows::UI::Text::FontWeights::SemiBold());
    TextBlock meta;
    meta.Text((source.isProducingAudio ? L"Playing" : L"Ready") + std::wstring(L" · ") + (source.sourceSampleRate ? std::to_wstring(static_cast<int>(source.sourceSampleRate.value())) + L" Hz" : L"sample rate pending"));
    meta.Foreground(source.isProducingAudio ? Brush(105, 226, 139) : Brush(160, 160, 160));
    title.Children().Append(name);
    title.Children().Append(meta);
    grid.Children().Append(title);

    Slider slider;
    slider.Minimum(0);
    slider.Maximum(1);
    slider.StepFrequency(0.01);
    slider.Value(source.volume);
    slider.HorizontalAlignment(HorizontalAlignment::Stretch);
    slider.ValueChanged([this, sourceId = source.id](IInspectable const& sender, muxcp::RangeBaseValueChangedEventArgs const& args) {
        auto slider = sender.as<Slider>();
        if (std::abs(args.NewValue() - args.OldValue()) >= 0.009) {
            m_backend.SetSourceVolume(sourceId, slider.Value());
        }
    });
    Grid::SetColumn(slider, 1);
    grid.Children().Append(slider);

    StackPanel controls;
    controls.Orientation(Orientation::Horizontal);
    controls.Spacing(8);
    controls.HorizontalAlignment(HorizontalAlignment::Right);

    Button select = SmallButton(source.id == m_selectedSourceId.value_or(L"") ? L"Selected" : L"Select");
    select.Click([this, sourceId = source.id](IInspectable const&, RoutedEventArgs const&) {
        m_selectedSourceId = sourceId;
        Refresh();
    });
    controls.Children().Append(select);

    Button mute = SmallButton(source.isMuted ? L"Unmute" : L"Mute");
    mute.Click([this, sourceId = source.id, muted = source.isMuted](IInspectable const&, RoutedEventArgs const&) {
        m_backend.SetSourceMute(sourceId, !muted);
        Refresh();
    });
    controls.Children().Append(mute);

    TextBlock percent;
    percent.Text(PercentText(source.volume));
    percent.Foreground(Brush(230, 179, 90));
    percent.FontWeight(Windows::UI::Text::FontWeights::SemiBold());
    percent.VerticalAlignment(VerticalAlignment::Center);
    controls.Children().Append(percent);

    Grid::SetColumn(controls, 2);
    grid.Children().Append(controls);

    border.Child(grid);
    SourceList().Children().Append(border);
}

void MainWindow::BuildOutputCard(AudioOutputDevice const& output) {
    auto border = CardBorder();
    border.BorderBrush(output.isDefault ? Brush(143, 233, 222) : Brush(41, 48, 53));

    Grid grid;
    grid.ColumnSpacing(12);
    grid.ColumnDefinitions().Append(ColumnDefinition());
    grid.ColumnDefinitions().Append(ColumnDefinition());
    grid.ColumnDefinitions().Append(ColumnDefinition());
    grid.ColumnDefinitions().GetAt(0).Width(GridLengthHelper::FromValueAndType(1, GridUnitType::Star));
    grid.ColumnDefinitions().GetAt(1).Width(GridLengthHelper::FromPixels(170));
    grid.ColumnDefinitions().GetAt(2).Width(GridLengthHelper::FromPixels(110));

    StackPanel title;
    title.Spacing(3);
    TextBlock name;
    name.Text(H(output.name));
    name.Foreground(Brush(245, 245, 243));
    name.FontSize(16);
    name.FontWeight(Windows::UI::Text::FontWeights::SemiBold());
    TextBlock meta;
    meta.Text(ToDisplayText(output.transport) + L" · " + std::to_wstring(output.channelCount) + L" ch" + (output.isDefault ? L" · Default" : L""));
    meta.Foreground(output.isConnected ? Brush(160, 160, 160) : Brush(230, 179, 90));
    title.Children().Append(name);
    title.Children().Append(meta);
    grid.Children().Append(title);

    Slider slider;
    slider.Minimum(0);
    slider.Maximum(1);
    slider.StepFrequency(0.01);
    slider.IsEnabled(output.supportsVolume && output.volume.has_value());
    slider.Value(output.volume.value_or(0));
    slider.ValueChanged([this, deviceId = output.id](IInspectable const& sender, muxcp::RangeBaseValueChangedEventArgs const& args) {
        auto slider = sender.as<Slider>();
        if (std::abs(args.NewValue() - args.OldValue()) >= 0.009) {
            m_backend.SetOutputVolume(deviceId, slider.Value());
        }
    });
    Grid::SetColumn(slider, 1);
    grid.Children().Append(slider);

    StackPanel right;
    right.Orientation(Orientation::Horizontal);
    right.Spacing(8);
    right.HorizontalAlignment(HorizontalAlignment::Right);
    TextBlock percent;
    percent.Text(output.volume ? PercentText(output.volume.value()) : L"N/A");
    percent.Foreground(Brush(143, 233, 222));
    percent.FontWeight(Windows::UI::Text::FontWeights::SemiBold());
    percent.VerticalAlignment(VerticalAlignment::Center);
    right.Children().Append(percent);

    Button mute = SmallButton(output.isMuted.value_or(false) ? L"On" : L"Mute");
    mute.IsEnabled(output.supportsMute);
    mute.Click([this, deviceId = output.id, muted = output.isMuted.value_or(false)](IInspectable const&, RoutedEventArgs const&) {
        m_backend.SetOutputMute(deviceId, !muted);
        Refresh();
    });
    right.Children().Append(mute);

    Grid::SetColumn(right, 2);
    grid.Children().Append(right);

    border.Child(grid);
    OutputList().Children().Append(border);
}

Button MainWindow::SmallButton(winrt::hstring const& text) {
    Button button;
    button.Content(box_value(text));
    button.Padding(ThicknessHelper::FromLengths(12, 6, 12, 6));
    return button;
}

Microsoft::UI::Xaml::Controls::Border MainWindow::CardBorder() const {
    Border border;
    border.CornerRadius(CornerRadiusHelper::FromUniformRadius(12));
    border.Background(Brush(18, 22, 25));
    border.BorderBrush(Brush(41, 48, 53));
    border.BorderThickness(ThicknessHelper::FromUniformLength(1));
    border.Padding(ThicknessHelper::FromUniformLength(14));
    return border;
}

winrt::hstring MainWindow::PercentText(double value) const {
    auto percent = static_cast<int>(std::round(value * 100));
    return winrt::to_hstring(percent) + L"%";
}

} // namespace winrt::AudioRouterWindows::implementation
