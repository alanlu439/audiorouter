#include "pch.h"
#include "Audio/WindowsRoutingBackend.h"

#include <iostream>

int wmain() {
    HRESULT initResult = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (FAILED(initResult)) {
        std::wcerr << L"COM initialization failed: 0x" << std::hex << initResult << L"\n";
        return 1;
    }

    int exitCode = 0;
    try {
        AudioRouter::Windows::Audio::WindowsRoutingBackend backend;
        auto status = backend.Status();
        auto outputs = backend.ListOutputDevices();
        auto inputs = backend.ListInputDevices();
        auto sources = backend.ListAudioSources();

        std::wcout << L"Backend: " << status.backendName << L"\n";
        std::wcout << L"Outputs: " << outputs.size() << L"\n";
        std::wcout << L"Inputs: " << inputs.size() << L"\n";
        std::wcout << L"Sessions: " << sources.size() << L"\n";
        std::wcout << L"Process loopback supported: " << (status.supportsProcessLoopback ? L"yes" : L"no") << L"\n";
    } catch (std::exception const& error) {
        std::wcerr << L"Backend smoke failed: " << winrt::to_hstring(error.what()).c_str() << L"\n";
        exitCode = 1;
    }

    CoUninitialize();
    return exitCode;
}
