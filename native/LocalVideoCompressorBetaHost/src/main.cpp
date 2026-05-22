#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <windows.h>

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int)
{
    MessageBoxW(
        nullptr,
        L"Local Video Compressor Beta is installed. Use File Explorer's context menu on a supported video file.",
        L"Local Video Compressor Beta",
        MB_OK | MB_ICONINFORMATION);
    return 0;
}
