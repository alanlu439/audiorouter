#pragma once

namespace AudioRouter::Windows::Shell {

class TrayIconController {
public:
    TrayIconController() = default;
    ~TrayIconController();

    void Install(std::wstring const& tooltip, std::function<void()> onActivate);
    void Remove();

private:
    static constexpr UINT CallbackMessage = WM_APP + 0x4155;
    HWND m_window = nullptr;
    NOTIFYICONDATAW m_icon{};
    std::function<void()> m_onActivate;

    static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam);
    LRESULT HandleMessage(UINT message, WPARAM wParam, LPARAM lParam);
};

} // namespace AudioRouter::Windows::Shell
