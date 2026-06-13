#pragma once

#include "pch.h"

namespace AudioRouter::Windows::Audio {

inline void ThrowIfFailed(HRESULT result, std::wstring_view operation) {
    if (FAILED(result)) {
        throw std::runtime_error(winrt::to_string(std::wstring(operation) + L" failed with HRESULT 0x" + std::to_wstring(static_cast<unsigned long>(result))));
    }
}

template <typename T>
using ComPtr = winrt::com_ptr<T>;

struct PropVariantScope {
    PROPVARIANT value{};

    PropVariantScope() {
        PropVariantInit(&value);
    }

    ~PropVariantScope() {
        PropVariantClear(&value);
    }

    PropVariantScope(PropVariantScope const&) = delete;
    PropVariantScope& operator=(PropVariantScope const&) = delete;
};

inline std::wstring CoTaskMemStringToWString(LPWSTR value) {
    if (value == nullptr) {
        return {};
    }
    std::wstring result(value);
    CoTaskMemFree(value);
    return result;
}

inline std::wstring PropVariantToWString(PROPVARIANT const& value) {
    if (value.vt == VT_LPWSTR && value.pwszVal != nullptr) {
        return value.pwszVal;
    }
    if (value.vt == VT_BSTR && value.bstrVal != nullptr) {
        return value.bstrVal;
    }
    return {};
}

} // namespace AudioRouter::Windows::Audio
