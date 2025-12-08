@echo off
REM ============================================================================
REM STEALTH INTERCEPTOR - NASM Build Script (Windows)
REM ============================================================================
REM Description: Builds the project using NASM on Windows
REM Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
REM ============================================================================

echo ========================================
echo   The Stealth Interceptor
echo   NASM Build System
echo ========================================
echo.

REM Check for NASM
where nasm >nul 2>nul
if errorlevel 1 (
    echo ERROR: NASM not found. Please install NASM.
    echo Download from: https://www.nasm.us/
    exit /b 1
)

echo [+] NASM found
echo.

REM Determine which project to build
if "%1"=="full" goto BUILD_FULL
if "%1"=="mini" goto BUILD_MINI
if "%1"=="" goto BUILD_MINI

echo Usage: %0 [mini^|full]
echo.
echo   mini - Build mini version (default, fully working)
echo   full - Build full version (in progress)
exit /b 1

:BUILD_MINI
echo [*] Building Mini Stealth Interceptor...
echo.
cd mini
call :BUILD_MINI_INTERNAL
if errorlevel 1 goto ERROR
cd ..
goto SUCCESS

:BUILD_MINI_INTERNAL
if not exist build mkdir build
if not exist build\obj mkdir build\obj
if not exist bin mkdir bin

echo [1/4] Assembling hook engine...
nasm -f win32 -o build\obj\hook_engine_nasm.obj src\core\hook_engine_nasm.asm
if errorlevel 1 exit /b 1

echo [2/4] Assembling messagebox hook...
nasm -f win32 -o build\obj\messagebox_hook_nasm.obj src\hooks\messagebox_hook_nasm.asm
if errorlevel 1 exit /b 1

echo [3/4] Assembling demo...
nasm -f win32 -o build\obj\demo_main_nasm.obj src\demo\demo_main_nasm.asm
if errorlevel 1 exit /b 1

echo [4/4] Linking...
REM Try GoLink first (simpler), fallback to LINK.exe if available
where golink >nul 2>nul
if not errorlevel 1 (
    golink /console /entry _main build\obj\demo_main_nasm.obj build\obj\hook_engine_nasm.obj build\obj\messagebox_hook_nasm.obj kernel32.dll user32.dll /fo bin\MiniStealthInterceptor.exe
) else (
    where link >nul 2>nul
    if not errorlevel 1 (
        link /SUBSYSTEM:CONSOLE /ENTRY:_main /OUT:bin\MiniStealthInterceptor.exe build\obj\demo_main_nasm.obj build\obj\hook_engine_nasm.obj build\obj\messagebox_hook_nasm.obj kernel32.lib user32.lib
    ) else (
        echo ERROR: No linker found. Install Visual Studio or GoLink.
        exit /b 1
    )
)
if errorlevel 1 exit /b 1
echo.
echo Build complete!
exit /b 0

:BUILD_FULL
echo [*] Building Full Stealth Interceptor...
echo.
echo Full project NASM conversion in progress.
echo The mini project is currently available and working.
echo.
echo To build the mini project:
echo   %0 mini
exit /b 0

:SUCCESS
echo.
echo ========================================
echo   BUILD SUCCESSFUL!
echo ========================================
echo   Output: mini\bin\MiniStealthInterceptor.exe
echo.
echo To run:
echo   mini\bin\MiniStealthInterceptor.exe
echo ========================================
exit /b 0

:ERROR
echo.
echo ========================================
echo   BUILD FAILED!
echo ========================================
exit /b 1
