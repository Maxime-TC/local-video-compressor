#include "ShellExtension.h"

#include <new>
#include <string>
#include <vector>
#include <strsafe.h>
#include <algorithm>
#include <cctype>

HINSTANCE g_hInstance = nullptr;
long g_cDllRef = 0;

namespace
{
    std::wstring GetLocalAppDataPath()
    {
        wchar_t basePath[MAX_PATH] = {};
        DWORD len = GetEnvironmentVariableW(L"LOCALAPPDATA", basePath, ARRAYSIZE(basePath));
        if (len == 0 || len >= ARRAYSIZE(basePath)) return {};
        return std::wstring(basePath);
    }

    bool ReadSmallTextFile(const std::wstring& path, std::string& content)
    {
        HANDLE file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                                  nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (file == INVALID_HANDLE_VALUE) return false;

        LARGE_INTEGER size = {};
        if (!GetFileSizeEx(file, &size) || size.QuadPart < 0 || size.QuadPart > 64 * 1024)
        {
            CloseHandle(file);
            return false;
        }

        content.assign(static_cast<size_t>(size.QuadPart), '\0');
        DWORD bytesRead = 0;
        const BOOL ok = content.empty() || ReadFile(file, content.data(), static_cast<DWORD>(content.size()), &bytesRead, nullptr);
        CloseHandle(file);
        if (!ok) return false;
        content.resize(bytesRead);
        return true;
    }

    bool JsonBoolEnabled(const std::string& json, const char* key)
    {
        std::string compact;
        compact.reserve(json.size());
        for (unsigned char ch : json)
        {
            if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') continue;
            compact.push_back(static_cast<char>(std::tolower(ch)));
        }

        std::string lowerKey(key);
        std::transform(lowerKey.begin(), lowerKey.end(), lowerKey.begin(), [](unsigned char ch) {
            return static_cast<char>(std::tolower(ch));
        });

        const std::string needle = "\"" + lowerKey + "\":true";
        return compact.find(needle) != std::string::npos;
    }

    bool IsTraceEnabled()
    {
        static LONG initialized = 0;
        static bool enabled = false;

        if (InterlockedCompareExchange(&initialized, 1, 0) == 0)
        {
            const std::wstring localAppData = GetLocalAppDataPath();
            if (!localAppData.empty())
            {
                std::string settings;
                const std::wstring settingsPath = localAppData + L"\\LocalVideoCompressor\\settings.json";
                if (ReadSmallTextFile(settingsPath, settings))
                {
                    enabled = JsonBoolEnabled(settings, "debug") ||
                              JsonBoolEnabled(settings, "debugLogging") ||
                              JsonBoolEnabled(settings, "shellExtensionLogging");
                }
            }
        }

        return enabled;
    }

    bool EnsureDirectory(const std::wstring& path)
    {
        if (path.empty()) return false;
        if (CreateDirectoryW(path.c_str(), nullptr)) return true;
        return GetLastError() == ERROR_ALREADY_EXISTS;
    }
}

void TraceLog(const wchar_t* message)
{
    if (!IsTraceEnabled()) return;
    if (!message) return;

    const std::wstring localAppData = GetLocalAppDataPath();
    if (localAppData.empty()) return;

    const std::wstring appDataDir = localAppData + L"\\LocalVideoCompressor";
    const std::wstring logsDir = appDataDir + L"\\logs";
    if (!EnsureDirectory(appDataDir) || !EnsureDirectory(logsDir)) return;
    const std::wstring path = logsDir + L"\\shell-extension.log";

    SYSTEMTIME st = {};
    GetLocalTime(&st);
    wchar_t line[1024] = {};
    StringCchPrintfW(line, ARRAYSIZE(line), L"%04u-%02u-%02u %02u:%02u:%02u.%03u pid=%lu %s\r\n",
                     st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond, st.wMilliseconds,
                     GetCurrentProcessId(), message);
    OutputDebugStringW(line);

    int bytes = WideCharToMultiByte(CP_UTF8, 0, line, -1, nullptr, 0, nullptr, nullptr);
    if (bytes <= 1) return;
    std::vector<char> buffer(static_cast<size_t>(bytes));
    WideCharToMultiByte(CP_UTF8, 0, line, -1, buffer.data(), bytes, nullptr, nullptr);

    HANDLE file = CreateFileW(path.c_str(), FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                              nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return;
    DWORD written = 0;
    WriteFile(file, buffer.data(), static_cast<DWORD>(bytes - 1), &written, nullptr);
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
