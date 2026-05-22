#include "ShellExtension.h"

#include <new>

HINSTANCE g_hInstance = nullptr;
long g_cDllRef = 0;

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
    return g_cDllRef == 0 ? S_OK : S_FALSE;
}

STDAPI DllGetClassObject(REFCLSID rclsid, REFIID riid, void** ppv)
{
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
