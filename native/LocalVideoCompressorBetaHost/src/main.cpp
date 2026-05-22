#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <windows.h>
#include <shellapi.h>
#include <shlobj_core.h>
#include <strsafe.h>

#include <algorithm>
#include <cctype>
#include <ctime>
#include <string>
#include <vector>

namespace
{
    constexpr const wchar_t* kAppName = L"Local Video Compressor";
    constexpr const wchar_t* kAppVersion = L"0.5.9-beta";

    struct Settings
    {
        bool debug = false;
        bool writeLog = false;
        bool showConsole = false;
        bool pauseOnExit = false;
        bool showSuccessMessage = false;
        bool showErrorMessage = true;
    };

    std::wstring QuoteCommandLineArg(const std::wstring& arg)
    {
        std::wstring quoted;
        quoted.reserve(arg.size() + 2);
        quoted.push_back(L'"');

        size_t backslashes = 0;
        for (wchar_t ch : arg)
        {
            if (ch == L'\\')
            {
                ++backslashes;
            }
            else if (ch == L'"')
            {
                quoted.append(backslashes * 2 + 1, L'\\');
                quoted.push_back(ch);
                backslashes = 0;
            }
            else
            {
                quoted.append(backslashes, L'\\');
                backslashes = 0;
                quoted.push_back(ch);
            }
        }

        quoted.append(backslashes * 2, L'\\');
        quoted.push_back(L'"');
        return quoted;
    }

    std::wstring GetDirectoryName(const std::wstring& path)
    {
        const size_t slash = path.find_last_of(L"\\/");
        if (slash == std::wstring::npos) return {};
        return path.substr(0, slash);
    }

    std::wstring GetExeDirectory()
    {
        wchar_t exePath[MAX_PATH] = {};
        const DWORD len = GetModuleFileNameW(nullptr, exePath, ARRAYSIZE(exePath));
        if (len == 0 || len >= ARRAYSIZE(exePath)) return {};
        return GetDirectoryName(exePath);
    }

    std::wstring GetLocalAppDataPath()
    {
        PWSTR localAppData = nullptr;
        HRESULT hr = SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_DEFAULT, nullptr, &localAppData);
        if (FAILED(hr)) return {};

        std::wstring result(localAppData);
        CoTaskMemFree(localAppData);
        return result;
    }

    bool EnsureDirectory(const std::wstring& path)
    {
        if (path.empty()) return false;
        if (CreateDirectoryW(path.c_str(), nullptr)) return true;
        return GetLastError() == ERROR_ALREADY_EXISTS;
    }

    bool FileExists(const std::wstring& path)
    {
        const DWORD attrs = GetFileAttributesW(path.c_str());
        return attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY);
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

    std::string CompactLowerJson(const std::string& json)
    {
        std::string compact;
        compact.reserve(json.size());
        for (unsigned char ch : json)
        {
            if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') continue;
            compact.push_back(static_cast<char>(std::tolower(ch)));
        }
        return compact;
    }

    bool JsonBoolValue(const std::string& compactLowerJson, const char* key, bool defaultValue)
    {
        std::string lowerKey(key);
        std::transform(lowerKey.begin(), lowerKey.end(), lowerKey.begin(), [](unsigned char ch) {
            return static_cast<char>(std::tolower(ch));
        });

        const std::string prefix = "\"" + lowerKey + "\":";
        const size_t pos = compactLowerJson.find(prefix);
        if (pos == std::string::npos) return defaultValue;

        const size_t valuePos = pos + prefix.size();
        if (compactLowerJson.compare(valuePos, 4, "true") == 0) return true;
        if (compactLowerJson.compare(valuePos, 5, "false") == 0) return false;
        return defaultValue;
    }

    std::wstring GetSettingsPath()
    {
        const std::wstring localAppData = GetLocalAppDataPath();
        if (localAppData.empty()) return {};
        return localAppData + L"\\LocalVideoCompressor\\settings.json";
    }

    std::wstring GetInstalledBackendRoot()
    {
        const std::wstring localAppData = GetLocalAppDataPath();
        if (localAppData.empty()) return {};
        return localAppData + L"\\Programs\\LocalVideoCompressor";
    }

    std::wstring ResolveCompressorScript(const std::wstring& packageDir)
    {
        const std::wstring backendRoot = GetInstalledBackendRoot();
        if (!backendRoot.empty())
        {
            const std::wstring installedScript = backendRoot + L"\\scripts\\Compress-Video.ps1";
            if (FileExists(installedScript)) return installedScript;
        }

        // Fallback for development/loose-package runs. Normal MSIX installs use the LocalAppData backend
        // because WindowsApps package files are intentionally not a friendly runtime dependency for child tools.
        const std::wstring packagedScript = packageDir + L"\\scripts\\Compress-Video.ps1";
        if (FileExists(packagedScript)) return packagedScript;
        return {};
    }

    Settings LoadSettings()
    {
        Settings settings;
        const std::wstring settingsPath = GetSettingsPath();
        std::string json;
        if (settingsPath.empty() || !ReadSmallTextFile(settingsPath, json)) return settings;

        const std::string compact = CompactLowerJson(json);
        settings.debug = JsonBoolValue(compact, "debug", settings.debug);
        settings.writeLog = JsonBoolValue(compact, "writeLog", settings.writeLog) ||
                            JsonBoolValue(compact, "debugLogging", settings.debug) ||
                            settings.debug;
        settings.showConsole = JsonBoolValue(compact, "showConsole", settings.showConsole);
        settings.pauseOnExit = JsonBoolValue(compact, "pauseOnExit", settings.pauseOnExit);
        settings.showSuccessMessage = JsonBoolValue(compact, "showSuccessMessage", settings.showSuccessMessage);
        settings.showErrorMessage = JsonBoolValue(compact, "showErrorMessage", settings.showErrorMessage);
        return settings;
    }

    std::wstring GetLogsDirectory()
    {
        const std::wstring localAppData = GetLocalAppDataPath();
        if (localAppData.empty()) return {};
        const std::wstring appDataDir = localAppData + L"\\LocalVideoCompressor";
        const std::wstring logsDir = appDataDir + L"\\logs";
        if (!EnsureDirectory(appDataDir) || !EnsureDirectory(logsDir)) return {};
        return logsDir;
    }

    std::wstring MakeCompressionLogPath()
    {
        const std::wstring logsDir = GetLogsDirectory();
        if (logsDir.empty()) return {};

        SYSTEMTIME st = {};
        GetLocalTime(&st);
        wchar_t fileName[128] = {};
        StringCchPrintfW(fileName, ARRAYSIZE(fileName), L"compress-%04u%02u%02u-%02u%02u%02u-%lu.log",
                         st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond, GetCurrentProcessId());
        return logsDir + L"\\" + fileName;
    }

    HANDLE OpenInheritableFile(const std::wstring& path, DWORD access, DWORD creationDisposition)
    {
        SECURITY_ATTRIBUTES sa{};
        sa.nLength = sizeof(sa);
        sa.bInheritHandle = TRUE;
        return CreateFileW(path.c_str(), access, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                           &sa, creationDisposition, FILE_ATTRIBUTE_NORMAL, nullptr);
    }

    HANDLE OpenInheritableNul(DWORD access)
    {
        SECURITY_ATTRIBUTES sa{};
        sa.nLength = sizeof(sa);
        sa.bInheritHandle = TRUE;
        return CreateFileW(L"NUL", access, FILE_SHARE_READ | FILE_SHARE_WRITE, &sa, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    }

    void WriteUtf8(HANDLE file, const std::wstring& text)
    {
        if (file == INVALID_HANDLE_VALUE || file == nullptr || text.empty()) return;
        int bytes = WideCharToMultiByte(CP_UTF8, 0, text.c_str(), -1, nullptr, 0, nullptr, nullptr);
        if (bytes <= 1) return;
        std::vector<char> buffer(static_cast<size_t>(bytes));
        WideCharToMultiByte(CP_UTF8, 0, text.c_str(), -1, buffer.data(), bytes, nullptr, nullptr);
        DWORD written = 0;
        WriteFile(file, buffer.data(), static_cast<DWORD>(bytes - 1), &written, nullptr);
    }

    std::wstring GetPowerShellPath()
    {
        wchar_t systemDir[MAX_PATH] = {};
        const UINT len = GetSystemDirectoryW(systemDir, ARRAYSIZE(systemDir));
        if (len == 0 || len >= ARRAYSIZE(systemDir)) return L"powershell.exe";
        return std::wstring(systemDir) + L"\\WindowsPowerShell\\v1.0\\powershell.exe";
    }

    bool IsSupportedPreset(const std::wstring& preset)
    {
        return preset == L"Balanced" || preset == L"Small" || preset == L"HighQuality";
    }

    void ShowInfoMessage()
    {
        const std::wstring settingsPath = GetSettingsPath();
        std::wstring message = L"Local Video Compressor is installed.\n\n"
                               L"Use File Explorer's context menu on a supported video file.\n\n"
                               L"Default mode runs quietly without command windows.\n"
                               L"For debugging, create or edit:\n";
        message += settingsPath.empty() ? L"%LOCALAPPDATA%\\LocalVideoCompressor\\settings.json" : settingsPath;
        message += L"\n\nExample:\n{\n  \"debug\": true,\n  \"writeLog\": true,\n  \"showConsole\": false\n}";
        MessageBoxW(nullptr, message.c_str(), kAppName, MB_OK | MB_ICONINFORMATION);
    }

    int LaunchCompression(const std::wstring& inputPath, const std::wstring& preset)
    {
        if (inputPath.empty() || !FileExists(inputPath))
        {
            MessageBoxW(nullptr, L"Selected video file does not exist anymore.", kAppName, MB_OK | MB_ICONERROR);
            return 2;
        }
        if (!IsSupportedPreset(preset))
        {
            MessageBoxW(nullptr, L"Unsupported compression preset.", kAppName, MB_OK | MB_ICONERROR);
            return 2;
        }

        const Settings settings = LoadSettings();
        const std::wstring exeDir = GetExeDirectory();
        const std::wstring scriptPath = ResolveCompressorScript(exeDir);
        if (exeDir.empty() || scriptPath.empty())
        {
            MessageBoxW(nullptr,
                        L"Compressor backend is missing. Re-run the Local Video Compressor installer so the backend is available in LocalAppData.",
                        kAppName, MB_OK | MB_ICONERROR);
            return 3;
        }

        const std::wstring powershell = GetPowerShellPath();
        std::wstring commandLine = QuoteCommandLineArg(powershell);
        commandLine += L" -NoProfile";
        if (!settings.showConsole) commandLine += L" -NonInteractive";
        commandLine += L" -ExecutionPolicy Bypass -File ";
        commandLine += QuoteCommandLineArg(scriptPath);
        commandLine += L" -Path ";
        commandLine += QuoteCommandLineArg(inputPath);
        commandLine += L" -Preset ";
        commandLine += QuoteCommandLineArg(preset);
        if (settings.showConsole && settings.pauseOnExit) commandLine += L" -PauseOnExit";

        std::wstring logPath;
        HANDLE outputHandle = INVALID_HANDLE_VALUE;
        HANDLE inputHandle = INVALID_HANDLE_VALUE;
        DWORD creationFlags = 0;
        BOOL inheritHandles = FALSE;

        STARTUPINFOW si{};
        si.cb = sizeof(si);
        PROCESS_INFORMATION pi{};

        if (settings.showConsole)
        {
            creationFlags = CREATE_NEW_CONSOLE;
            si.dwFlags = STARTF_USESHOWWINDOW;
            si.wShowWindow = SW_SHOWNORMAL;
        }
        else
        {
            creationFlags = CREATE_NO_WINDOW;
            si.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
            si.wShowWindow = SW_HIDE;
            inputHandle = OpenInheritableNul(GENERIC_READ);

            if (settings.writeLog)
            {
                logPath = MakeCompressionLogPath();
                if (!logPath.empty()) outputHandle = OpenInheritableFile(logPath, GENERIC_WRITE, CREATE_ALWAYS);
                if (outputHandle == INVALID_HANDLE_VALUE) logPath.clear();
            }
            if (outputHandle == INVALID_HANDLE_VALUE)
            {
                outputHandle = OpenInheritableNul(GENERIC_WRITE);
            }

            si.hStdInput = inputHandle == INVALID_HANDLE_VALUE ? nullptr : inputHandle;
            si.hStdOutput = outputHandle == INVALID_HANDLE_VALUE ? nullptr : outputHandle;
            si.hStdError = outputHandle == INVALID_HANDLE_VALUE ? nullptr : outputHandle;
            inheritHandles = TRUE;
        }

        if (settings.writeLog && outputHandle != INVALID_HANDLE_VALUE && outputHandle != nullptr)
        {
            WriteUtf8(outputHandle, std::wstring(L"Local Video Compressor ") + kAppVersion + L"\r\n");
            WriteUtf8(outputHandle, std::wstring(L"Input: ") + inputPath + L"\r\n");
            WriteUtf8(outputHandle, std::wstring(L"Preset: ") + preset + L"\r\n");
            WriteUtf8(outputHandle, std::wstring(L"Script: ") + scriptPath + L"\r\n\r\n");
        }

        std::vector<wchar_t> buffer(commandLine.begin(), commandLine.end());
        buffer.push_back(L'\0');

        const BOOL started = CreateProcessW(powershell.c_str(), buffer.data(), nullptr, nullptr, inheritHandles,
                                            creationFlags, nullptr, exeDir.c_str(), &si, &pi);
        if (inputHandle != INVALID_HANDLE_VALUE) CloseHandle(inputHandle);
        if (outputHandle != INVALID_HANDLE_VALUE) CloseHandle(outputHandle);

        if (!started)
        {
            wchar_t message[1024] = {};
            StringCchPrintfW(message, ARRAYSIZE(message), L"Could not start the compressor. Windows error: %lu", GetLastError());
            MessageBoxW(nullptr, message, kAppName, MB_OK | MB_ICONERROR);
            return 4;
        }

        WaitForSingleObject(pi.hProcess, INFINITE);
        DWORD exitCode = 0;
        GetExitCodeProcess(pi.hProcess, &exitCode);
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);

        if (exitCode != 0 && settings.showErrorMessage)
        {
            std::wstring message = L"Compression failed.";
            if (!logPath.empty()) message += std::wstring(L"\n\nDebug log:\n") + logPath;
            MessageBoxW(nullptr, message.c_str(), kAppName, MB_OK | MB_ICONERROR);
        }
        else if (exitCode == 0 && settings.showSuccessMessage)
        {
            MessageBoxW(nullptr, L"Compression finished.", kAppName, MB_OK | MB_ICONINFORMATION);
        }

        return static_cast<int>(exitCode);
    }
}

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int)
{
    int argc = 0;
    LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (!argv)
    {
        MessageBoxW(nullptr, L"Could not parse command line.", kAppName, MB_OK | MB_ICONERROR);
        return 1;
    }

    bool compress = false;
    std::wstring inputPath;
    std::wstring preset = L"Balanced";

    for (int i = 1; i < argc; ++i)
    {
        const std::wstring arg = argv[i];
        if (arg == L"--compress")
        {
            compress = true;
        }
        else if (arg == L"--path" && i + 1 < argc)
        {
            inputPath = argv[++i];
        }
        else if (arg == L"--preset" && i + 1 < argc)
        {
            preset = argv[++i];
        }
    }

    LocalFree(argv);

    if (!compress)
    {
        ShowInfoMessage();
        return 0;
    }

    return LaunchCompression(inputPath, preset);
}
