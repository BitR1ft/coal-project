@echo off
REM ============================================================================
REM STEALTH INTERCEPTOR - Clean Script
REM ============================================================================
REM File:        clean.bat
REM Description: Cleans build artifacts
REM Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
REM ============================================================================

echo ============================================================
echo   The Stealth Interceptor - Clean Script
echo ============================================================
echo.

echo [*] Cleaning build artifacts...

REM Remove object files
if exist "build\obj" (
    del /Q build\obj\*.obj 2>nul
    echo     [+] Object files removed
)

REM Remove executables
if exist "bin\Release" (
    del /Q bin\Release\*.exe 2>nul
    del /Q bin\Release\*.pdb 2>nul
    del /Q bin\Release\*.ilk 2>nul
    echo     [+] Release binaries removed
)

if exist "bin\Debug" (
    del /Q bin\Debug\*.exe 2>nul
    del /Q bin\Debug\*.pdb 2>nul
    del /Q bin\Debug\*.ilk 2>nul
    echo     [+] Debug binaries removed
)

REM Remove log files
del /Q *.log 2>nul
del /Q stealth_interceptor.log 2>nul
echo     [+] Log files removed

echo.
echo [+] Clean complete!
echo.
