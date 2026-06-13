#include "pch.h"
#include "Shell/TrayIconController.h"

namespace AudioRouter::Windows::Shell {

TrayIconController::~TrayIconController() {
    Remove();
}

void TrayIconController::Install(std::wstring const& tooltip, std::function<void()> onActivate) {
    if (m_window != nullptr) {
        return;
    }

    m_onActivate = std::move(onActivate);
    WNDCLASSW windowClass{};
    windowClass.lpfnWndProc = TrayIconController::WindowProc;
    windowClass.hInstance = GetModuleHandleW(nullptr);
    windowClass.lpszClassName = L"AudioRouterTrayWindow";
    RegisterClassW(&windowClass);

    m_window = CreateWindowExW(0, windowClass.lpszClassName, L"AudioRouterTrayWindow", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, windowClass.hInstance, this);
    if (m_window == nullptr) {
        return;
    }

    m_icon = {};
    m_icon.cbSize = sizeof(m_icon);
    m_icon.hWnd = m_window;
    m_icon.uID = 1;
    m_icon.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    m_icon.uCallbackMessage = CallbackMessage;
    m_icon.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    wcsncpy_s(m_icon.szTip, tooltip.c_str(), _TRUNCATE);
    Shell_NotifyIconW(NIM_ADD, &m_icon);
}

void TrayIconController::Remove() {
    if (m_window != nullptr) {
        Shell_NotifyIconW(NIM_DELETE, &m_icon);
        DestroyWindow(m_window);
        m_window = nullptr;
    }
}

LRESULT CALLBACK TrayIconController::WindowProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
    if (message == WM_NCCREATE) {
        auto create = reinterpret_cast<CREATESTRUCTW*>(lParam);
        auto controller = reinterpret_cast<TrayIconController*>(create->lpCreateParams);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(controller));
    }

    auto controller = reinterpret_cast<TrayIconController*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (controller != nullptr) {
        return controller->HandleMessage(message, wParam, lParam);
    }

    return DefWindowProcW(hwnd, message, wParam, lParam);
}

LRESULT TrayIconController::HandleMessage(UINT message, WPARAM wParam, LPARAM lParam) {
    if (message == CallbackMessage && wParam == m_icon.uID) {
        if (lParam == WM_LBUTTONUP || lParam == WM_RBUTTONUP) {
            if (m_onActivate) {
                m_onActivate();
            }
            return 0;
        }
    }

    return DefWindowProcW(m_window, message, wParam, lParam);
}

} // namespace AudioRouter::Windows::Shell
