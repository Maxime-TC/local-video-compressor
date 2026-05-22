#include "ShellExtension.h"

#include <algorithm>
#include <cwchar>
#include <cwctype>
#include <new>

namespace
{
    constexpr const wchar_t* kSupportedExtensions[] = { L".mp4", L".mov", L".mkv", L".avi", L".webm" };

    HRESULT AllocString(const wchar_t* text, LPWSTR* out)
    {
        if (!out) return E_POINTER;
        *out = nullptr;
        if (!text) return S_OK;

        const size_t chars = wcslen(text) + 1;
        auto* mem = static_cast<wchar_t*>(CoTaskMemAlloc(chars * sizeof(wchar_t)));
        if (!mem) return E_OUTOFMEMORY;
        HRESULT hr = StringCchCopyW(mem, chars, text);
        if (FAILED(hr))
        {
            CoTaskMemFree(mem);
            return hr;
        }
        *out = mem;
        return S_OK;
    }

    std::wstring GetCommandTitle(CommandKind kind)
    {
        switch (kind)
        {
        case CommandKind::Balanced: return L"Balanced";
        case CommandKind::Small: return L"Small";
        case CommandKind::HighQuality: return L"High Quality";
        default: return L"Local Video Compressor";
        }
    }

    std::wstring GetPresetName(CommandKind kind)
    {
        switch (kind)
        {
        case CommandKind::Balanced: return L"Balanced";
        case CommandKind::Small: return L"Small";
        case CommandKind::HighQuality: return L"HighQuality";
        default: return L"Balanced";
        }
    }

    GUID GetCommandGuid(CommandKind kind)
    {
        switch (kind)
        {
        case CommandKind::Balanced: return CMDID_Balanced;
        case CommandKind::Small: return CMDID_Small;
        case CommandKind::HighQuality: return CMDID_HighQuality;
        default: return CMDID_Root;
        }
    }

    bool IsSupportedExtension(const std::wstring& path)
    {
        const size_t dot = path.find_last_of(L'.');
        if (dot == std::wstring::npos) return false;
        std::wstring ext = path.substr(dot);
        std::transform(ext.begin(), ext.end(), ext.begin(), [](wchar_t ch) { return static_cast<wchar_t>(towlower(ch)); });

        for (const auto* supported : kSupportedExtensions)
        {
            if (ext == supported) return true;
        }
        return false;
    }

    HRESULT GetSingleSelectedPath(IShellItemArray* items, std::wstring& path)
    {
        if (!items) return E_INVALIDARG;

        DWORD count = 0;
        HRESULT hr = items->GetCount(&count);
        if (FAILED(hr)) return hr;
        if (count != 1) return HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED);

        IShellItem* item = nullptr;
        hr = items->GetItemAt(0, &item);
        if (FAILED(hr)) return hr;

        PWSTR displayName = nullptr;
        hr = item->GetDisplayName(SIGDN_FILESYSPATH, &displayName);
        item->Release();
        if (FAILED(hr)) return hr;

        path.assign(displayName);
        CoTaskMemFree(displayName);
        return S_OK;
    }

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

    std::wstring GetInstalledAppRoot()
    {
        PWSTR localAppData = nullptr;
        HRESULT hr = SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_DEFAULT, nullptr, &localAppData);
        if (FAILED(hr)) return {};

        std::wstring root(localAppData);
        CoTaskMemFree(localAppData);
        root += L"\\Programs\\LocalVideoCompressor";
        return root;
    }

    bool FileExists(const std::wstring& path)
    {
        const DWORD attrs = GetFileAttributesW(path.c_str());
        return attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY);
    }

    std::wstring BuildIconPath()
    {
        std::wstring root = GetInstalledAppRoot();
        if (root.empty()) return {};
        return root + L"\\assets\\local-video-compressor.ico";
    }

    HRESULT LaunchCompressor(const std::wstring& selectedPath, CommandKind kind)
    {
        const std::wstring root = GetInstalledAppRoot();
        if (root.empty()) return E_FAIL;

        const std::wstring script = root + L"\\scripts\\Compress-Video.ps1";
        if (!FileExists(script)) return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);

        std::wstring commandLine = L"powershell.exe -NoProfile -ExecutionPolicy Bypass -File ";
        commandLine += QuoteCommandLineArg(script);
        commandLine += L" -Path ";
        commandLine += QuoteCommandLineArg(selectedPath);
        commandLine += L" -Preset ";
        commandLine += QuoteCommandLineArg(GetPresetName(kind));
        commandLine += L" -PauseOnExit";

        STARTUPINFOW si{};
        si.cb = sizeof(si);
        PROCESS_INFORMATION pi{};

        // CreateProcessW may modify the command-line buffer.
        std::vector<wchar_t> buffer(commandLine.begin(), commandLine.end());
        buffer.push_back(L'\0');

        if (!CreateProcessW(nullptr, buffer.data(), nullptr, nullptr, FALSE, CREATE_NEW_CONSOLE, nullptr, nullptr, &si, &pi))
        {
            return HRESULT_FROM_WIN32(GetLastError());
        }

        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
        return S_OK;
    }

    const CommandKind kSubCommands[] = { CommandKind::Balanced, CommandKind::Small, CommandKind::HighQuality };
}

ExplorerCommand::ExplorerCommand(CommandKind kind) noexcept : _refCount(1), _kind(kind)
{
    DllAddRef();
}

ExplorerCommand::~ExplorerCommand()
{
    DllRelease();
}

IFACEMETHODIMP ExplorerCommand::QueryInterface(REFIID riid, void** ppv)
{
    if (!ppv) return E_POINTER;
    *ppv = nullptr;

    if (riid == IID_IUnknown || riid == IID_IExplorerCommand)
    {
        *ppv = static_cast<IExplorerCommand*>(this);
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}

IFACEMETHODIMP_(ULONG) ExplorerCommand::AddRef()
{
    return static_cast<ULONG>(InterlockedIncrement(&_refCount));
}

IFACEMETHODIMP_(ULONG) ExplorerCommand::Release()
{
    const ULONG count = static_cast<ULONG>(InterlockedDecrement(&_refCount));
    if (count == 0) delete this;
    return count;
}

IFACEMETHODIMP ExplorerCommand::GetTitle(IShellItemArray*, LPWSTR* ppszName)
{
    const std::wstring title = GetCommandTitle(_kind);
    return AllocString(title.c_str(), ppszName);
}

IFACEMETHODIMP ExplorerCommand::GetIcon(IShellItemArray*, LPWSTR* ppszIcon)
{
    const std::wstring icon = BuildIconPath();
    if (icon.empty() || !FileExists(icon)) return AllocString(L"", ppszIcon);
    return AllocString(icon.c_str(), ppszIcon);
}

IFACEMETHODIMP ExplorerCommand::GetToolTip(IShellItemArray*, LPWSTR* ppszInfoTip)
{
    if (!ppszInfoTip) return E_POINTER;
    *ppszInfoTip = nullptr;
    return E_NOTIMPL;
}

IFACEMETHODIMP ExplorerCommand::GetCanonicalName(GUID* pguidCommandName)
{
    if (!pguidCommandName) return E_POINTER;
    *pguidCommandName = GetCommandGuid(_kind);
    return S_OK;
}

IFACEMETHODIMP ExplorerCommand::GetState(IShellItemArray* psiItemArray, BOOL, EXPCMDSTATE* pCmdState)
{
    if (!pCmdState) return E_POINTER;
    *pCmdState = ECS_DISABLED;

    std::wstring path;
    HRESULT hr = GetSingleSelectedPath(psiItemArray, path);
    if (FAILED(hr)) return S_OK;

    *pCmdState = IsSupportedExtension(path) ? ECS_ENABLED : ECS_HIDDEN;
    return S_OK;
}

IFACEMETHODIMP ExplorerCommand::Invoke(IShellItemArray* psiItemArray, IBindCtx*)
{
    if (_kind == CommandKind::Root) return S_FALSE;

    std::wstring path;
    HRESULT hr = GetSingleSelectedPath(psiItemArray, path);
    if (FAILED(hr)) return hr;
    if (!IsSupportedExtension(path)) return HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED);

    return LaunchCompressor(path, _kind);
}

IFACEMETHODIMP ExplorerCommand::GetFlags(EXPCMDFLAGS* pFlags)
{
    if (!pFlags) return E_POINTER;
    *pFlags = (_kind == CommandKind::Root) ? ECF_HASSUBCOMMANDS : ECF_DEFAULT;
    return S_OK;
}

IFACEMETHODIMP ExplorerCommand::EnumSubCommands(IEnumExplorerCommand** ppEnum)
{
    if (!ppEnum) return E_POINTER;
    *ppEnum = nullptr;

    if (_kind != CommandKind::Root) return E_NOTIMPL;

    auto* enumerator = new (std::nothrow) ExplorerCommandEnum();
    if (!enumerator) return E_OUTOFMEMORY;
    *ppEnum = enumerator;
    return S_OK;
}

ExplorerCommandEnum::ExplorerCommandEnum() : _refCount(1), _index(0)
{
    DllAddRef();
}

ExplorerCommandEnum::~ExplorerCommandEnum()
{
    DllRelease();
}

IFACEMETHODIMP ExplorerCommandEnum::QueryInterface(REFIID riid, void** ppv)
{
    if (!ppv) return E_POINTER;
    *ppv = nullptr;

    if (riid == IID_IUnknown || riid == IID_IEnumExplorerCommand)
    {
        *ppv = static_cast<IEnumExplorerCommand*>(this);
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}

IFACEMETHODIMP_(ULONG) ExplorerCommandEnum::AddRef()
{
    return static_cast<ULONG>(InterlockedIncrement(&_refCount));
}

IFACEMETHODIMP_(ULONG) ExplorerCommandEnum::Release()
{
    const ULONG count = static_cast<ULONG>(InterlockedDecrement(&_refCount));
    if (count == 0) delete this;
    return count;
}

IFACEMETHODIMP ExplorerCommandEnum::Next(ULONG celt, IExplorerCommand** pUICommand, ULONG* pceltFetched)
{
    if (!pUICommand) return E_POINTER;
    if (celt != 1 && !pceltFetched) return E_POINTER;

    ULONG fetched = 0;
    while (fetched < celt && _index < ARRAYSIZE(kSubCommands))
    {
        auto* command = new (std::nothrow) ExplorerCommand(kSubCommands[_index]);
        if (!command) break;
        pUICommand[fetched] = command;
        ++fetched;
        ++_index;
    }

    if (pceltFetched) *pceltFetched = fetched;
    return fetched == celt ? S_OK : S_FALSE;
}

IFACEMETHODIMP ExplorerCommandEnum::Skip(ULONG celt)
{
    _index += celt;
    if (_index > ARRAYSIZE(kSubCommands)) _index = ARRAYSIZE(kSubCommands);
    return _index < ARRAYSIZE(kSubCommands) ? S_OK : S_FALSE;
}

IFACEMETHODIMP ExplorerCommandEnum::Reset()
{
    _index = 0;
    return S_OK;
}

IFACEMETHODIMP ExplorerCommandEnum::Clone(IEnumExplorerCommand** ppenum)
{
    if (!ppenum) return E_POINTER;
    *ppenum = nullptr;

    auto* clone = new (std::nothrow) ExplorerCommandEnum();
    if (!clone) return E_OUTOFMEMORY;
    clone->_index = _index;
    *ppenum = clone;
    return S_OK;
}
