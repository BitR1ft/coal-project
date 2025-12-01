@echo off
REM ============================================================================
REM STEALTH INTERCEPTOR - Setup Script
REM ============================================================================
REM File:        setup.bat
REM Description: Sets up the development environment
REM Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
REM ============================================================================

echo ============================================================
echo   The Stealth Interceptor - Setup Script
echo   Version 1.0.0
echo ============================================================
echo.

echo [*] Checking prerequisites...
echo.

REM Check for Administrator privileges
net session >nul 2>&1
if errorlevel 1 (
    echo [!] WARNING: Not running as Administrator
    echo [!] Some setup steps may fail without admin privileges
    echo.
)

REM Check for Visual Studio
echo [*] Checking for Visual Studio...
set VS_FOUND=0

if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC" (
    echo     [+] Visual Studio 2022 Community found
    set VS_FOUND=1
)
if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC" (
    echo     [+] Visual Studio 2022 Professional found
    set VS_FOUND=1
)
if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC" (
    echo     [+] Visual Studio 2022 Enterprise found
    set VS_FOUND=1
)
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC" (
    echo     [+] Visual Studio 2019 Community found
    set VS_FOUND=1
)

if %VS_FOUND%==0 (
    echo     [-] Visual Studio not found!
    echo.
    echo     Please install Visual Studio with the following:
    echo     - Desktop development with C++ workload
    echo     - Windows 10 SDK
    echo.
    echo     Download from: https://visualstudio.microsoft.com/
    echo.
)

REM Check for MASM32
echo [*] Checking for MASM32...
if exist "C:\masm32\bin\ml.exe" (
    echo     [+] MASM32 found at C:\masm32
    set MASM32=C:\masm32
) else (
    echo     [-] MASM32 not found!
    echo.
    echo     Please install MASM32 to C:\masm32
    echo     Download from: http://www.masm32.com/
    echo.
    
    REM Offer to download MASM32
    echo     Would you like to open the MASM32 download page?
    choice /M "Open download page"
    if errorlevel 2 goto :skip_masm_download
    start http://www.masm32.com/download.htm
    :skip_masm_download
)

REM Check for x64dbg (optional)
echo [*] Checking for x64dbg (optional debugger)...
if exist "C:\x64dbg\x32\x32dbg.exe" (
    echo     [+] x64dbg found
) else if exist "%USERPROFILE%\Desktop\x64dbg\x32\x32dbg.exe" (
    echo     [+] x64dbg found on Desktop
) else (
    echo     [!] x64dbg not found (optional but recommended)
    echo     Download from: https://x64dbg.com/
)

echo.
echo [*] Creating project directory structure...

REM Create directories if they don't exist
if not exist "build" mkdir build
if not exist "build\obj" mkdir build\obj
if not exist "bin" mkdir bin
if not exist "bin\Release" mkdir bin\Release
if not exist "bin\Debug" mkdir bin\Debug
if not exist "docs\images" mkdir docs\images

echo     [+] Directory structure created
echo.

REM Set environment variables
echo [*] Setting up environment variables...

setx STEALTH_HOME "%CD%" >nul 2>&1
if errorlevel 0 (
    echo     [+] STEALTH_HOME set to %CD%
) else (
    echo     [!] Could not set STEALTH_HOME environment variable
)

echo.
echo ============================================================
echo   SETUP COMPLETE
echo ============================================================
echo.
echo   Next steps:
echo   1. Open Developer Command Prompt for VS 2022
echo   2. Navigate to this directory
echo   3. Run: scripts\build.bat
echo.
echo   To run the demo after building:
echo   bin\Release\StealthInterceptor.exe
echo.
echo   For debugging:
echo   - Use Visual Studio or x64dbg
echo   - Enable OutputDebugString viewing with DebugView
echo.
echo ============================================================

pause
