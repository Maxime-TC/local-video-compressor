#include "ShellExtension.h"

#include <new>
#include <string>
#include <vector>
#include <strsafe.h>

HINSTANCE g_hInstance = nullptr;
long g_cDllRef = 0;

void TraceLog(const wchar_t* message)
{
    if (!message) return;

    wchar_t basePath[MAX_PATH] = {};
    DWORD len = GetEnvironmentVariableW(L"LOCALAPPDATA", basePath, ARRAYSIZE(basePath));
    std::wstring path;
    if (len > 0 && len < ARRAYSIZE(basePath))
    {
        path.assign(basePath);
        path += L"\\Temp\\lvc-shell-ext.log";
    }
    else
    {
        len = GetTempPathW(ARRAYSIZE(basePath), basePath);
        if (len == 0 || len >= ARRAYSIZE(basePath)) return;
        path.assign(basePath);
        path += L"lvc-shell-ext.log";
    }

    SYSTEMTIME st = {};
    GetLocalTime(&st);
    wchar_t line[1024] = {};
    StringCchPrintfW(line, ARRAYSIZE(line), L"%04u-%02u-%02u %02u:%02u:%02u.%03u pid=%lu %s\r\n",
                     st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond, st.wMilliseconds,
                     GetCurrentProcessId(), message);
    OutputDebugStringW(line);

    int bytes = WideCharToMultiByte(CP_UTF8, 0, line, -1, nullptr, 0, nullptr, nullptr);
    if (bytes <= 1) return;
    std::vector<char> buffer(static_cast<size_t>(bytes - 1));
    WideCharToMultiByte(CP_UTF8, 0, line, -1, buffer.data(), bytes, nullptr, nullptr);

    HANDLE file = CreateFileW(path.c_str(), FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                              nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return;
    DWORD written = 0;
    WriteFile(file, buffer.data(), static_cast<DWORD>(buffer.size()), &written, nullptr);
    CloseHandle(file);
}

void DllAddRef()
{
    InterlockedIncrement(&g_cDllRef);
}

void DllRelease()
{
    InterlockedDecrement(&g_cDllRef);
}

BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH)
    {
        g_hInstance = hModule;
        DisableThreadLibraryCalls(hModule);
        TraceLog(L"DllMain PROCESS_ATTACH");
    }
    return TRUE;
}

STDAPI DllCanUnloadNow()
{
    TraceLog(L"DllCanUnloadNow");
    return g_cDllRef == 0 ? S_OK : S_FALSE;
}

STDAPI DllGetClassObject(REFCLSID rclsid, REFIID riid, void** ppv)
{
    TraceLog(L"DllGetClassObject");
    if (!ppv) return E_POINTER;
    *ppv = nullptr;

    if (rclsid != CLSID_LocalVideoCompressorCommand)
    {
        return CLASS_E_CLASSNOTAVAILABLE;
    }

    auto* factory = new (std::nothrow) ClassFactory();
    if (!factory) return E_OUTOFMEMORY;

    HRESULT hr = factory->QueryInterface(riid, ppv);
    factory->Release();
    return hr;
}
