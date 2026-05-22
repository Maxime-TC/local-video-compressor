#include "ShellExtension.h"

#include <new>

ClassFactory::ClassFactory() noexcept : _refCount(1)
{
    DllAddRef();
}

ClassFactory::~ClassFactory()
{
    DllRelease();
}

IFACEMETHODIMP ClassFactory::QueryInterface(REFIID riid, void** ppv)
{
    if (!ppv) return E_POINTER;
    *ppv = nullptr;

    if (riid == IID_IUnknown || riid == IID_IClassFactory)
    {
        *ppv = static_cast<IClassFactory*>(this);
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}

IFACEMETHODIMP_(ULONG) ClassFactory::AddRef()
{
    return static_cast<ULONG>(InterlockedIncrement(&_refCount));
}

IFACEMETHODIMP_(ULONG) ClassFactory::Release()
{
    const ULONG count = static_cast<ULONG>(InterlockedDecrement(&_refCount));
    if (count == 0) delete this;
    return count;
}

IFACEMETHODIMP ClassFactory::CreateInstance(IUnknown* pUnkOuter, REFIID riid, void** ppv)
{
    if (!ppv) return E_POINTER;
    *ppv = nullptr;

    if (pUnkOuter) return CLASS_E_NOAGGREGATION;

    auto* command = new (std::nothrow) ExplorerCommand(CommandKind::Root);
    if (!command) return E_OUTOFMEMORY;

    HRESULT hr = command->QueryInterface(riid, ppv);
    command->Release();
    return hr;
}

IFACEMETHODIMP ClassFactory::LockServer(BOOL fLock)
{
    if (fLock) DllAddRef();
    else DllRelease();
    return S_OK;
}
