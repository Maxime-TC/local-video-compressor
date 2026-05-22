#pragma once

#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <windows.h>
#include <shobjidl_core.h>
#include <shlobj_core.h>
#include <knownfolders.h>
#include <strsafe.h>

#include <string>
#include <vector>

// CLSID registered in the package manifest. Keep in sync with packaging/AppxManifest.xml.
// {8AC3CC15-339A-4202-9E1E-56F80717AC92}
inline constexpr CLSID CLSID_LocalVideoCompressorCommand =
{ 0x8ac3cc15, 0x339a, 0x4202, { 0x9e, 0x1e, 0x56, 0xf8, 0x07, 0x17, 0xac, 0x92 } };

// Canonical command IDs returned by IExplorerCommand::GetCanonicalName.
// {54BFFEED-3EBC-4BE3-BB64-CD05B8B399CF}
inline constexpr GUID CMDID_Root =
{ 0x54bffeed, 0x3ebc, 0x4be3, { 0xbb, 0x64, 0xcd, 0x05, 0xb8, 0xb3, 0x99, 0xcf } };
// {316A2480-A541-4AA1-97A0-DBC5B4CC20B3}
inline constexpr GUID CMDID_Balanced =
{ 0x316a2480, 0xa541, 0x4aa1, { 0x97, 0xa0, 0xdb, 0xc5, 0xb4, 0xcc, 0x20, 0xb3 } };
// {14E9A056-329C-40C2-B868-77BBF085CD8D}
inline constexpr GUID CMDID_Small =
{ 0x14e9a056, 0x329c, 0x40c2, { 0xb8, 0x68, 0x77, 0xbb, 0xf0, 0x85, 0xcd, 0x8d } };
// {8F57FA9E-2A9F-4F7D-99F1-3EA5BC27BDA8}
inline constexpr GUID CMDID_HighQuality =
{ 0x8f57fa9e, 0x2a9f, 0x4f7d, { 0x99, 0xf1, 0x3e, 0xa5, 0xbc, 0x27, 0xbd, 0xa8 } };

enum class CommandKind
{
    Root,
    Balanced,
    Small,
    HighQuality,
};

extern HINSTANCE g_hInstance;
extern long g_cDllRef;

void DllAddRef();
void DllRelease();

class ExplorerCommand final : public IExplorerCommand
{
public:
    explicit ExplorerCommand(CommandKind kind) noexcept;
    ExplorerCommand(const ExplorerCommand&) = delete;
    ExplorerCommand& operator=(const ExplorerCommand&) = delete;

    // IUnknown
    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override;
    IFACEMETHODIMP_(ULONG) AddRef() override;
    IFACEMETHODIMP_(ULONG) Release() override;

    // IExplorerCommand
    IFACEMETHODIMP GetTitle(IShellItemArray* psiItemArray, LPWSTR* ppszName) override;
    IFACEMETHODIMP GetIcon(IShellItemArray* psiItemArray, LPWSTR* ppszIcon) override;
    IFACEMETHODIMP GetToolTip(IShellItemArray* psiItemArray, LPWSTR* ppszInfoTip) override;
    IFACEMETHODIMP GetCanonicalName(GUID* pguidCommandName) override;
    IFACEMETHODIMP GetState(IShellItemArray* psiItemArray, BOOL fOkToBeSlow, EXPCMDSTATE* pCmdState) override;
    IFACEMETHODIMP Invoke(IShellItemArray* psiItemArray, IBindCtx* pbc) override;
    IFACEMETHODIMP GetFlags(EXPCMDFLAGS* pFlags) override;
    IFACEMETHODIMP EnumSubCommands(IEnumExplorerCommand** ppEnum) override;

private:
    ~ExplorerCommand();

    long _refCount;
    CommandKind _kind;
};

class ExplorerCommandEnum final : public IEnumExplorerCommand
{
public:
    ExplorerCommandEnum();
    ExplorerCommandEnum(const ExplorerCommandEnum&) = delete;
    ExplorerCommandEnum& operator=(const ExplorerCommandEnum&) = delete;

    // IUnknown
    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override;
    IFACEMETHODIMP_(ULONG) AddRef() override;
    IFACEMETHODIMP_(ULONG) Release() override;

    // IEnumExplorerCommand
    IFACEMETHODIMP Next(ULONG celt, IExplorerCommand** pUICommand, ULONG* pceltFetched) override;
    IFACEMETHODIMP Skip(ULONG celt) override;
    IFACEMETHODIMP Reset() override;
    IFACEMETHODIMP Clone(IEnumExplorerCommand** ppenum) override;

private:
    ~ExplorerCommandEnum();

    long _refCount;
    ULONG _index;
};

class ClassFactory final : public IClassFactory
{
public:
    ClassFactory() noexcept;
    ClassFactory(const ClassFactory&) = delete;
    ClassFactory& operator=(const ClassFactory&) = delete;

    // IUnknown
    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override;
    IFACEMETHODIMP_(ULONG) AddRef() override;
    IFACEMETHODIMP_(ULONG) Release() override;

    // IClassFactory
    IFACEMETHODIMP CreateInstance(IUnknown* pUnkOuter, REFIID riid, void** ppv) override;
    IFACEMETHODIMP LockServer(BOOL fLock) override;

private:
    ~ClassFactory();

    long _refCount;
};
