@echo off
REM Simple test script for Mini Stealth Interceptor
echo ========================================
echo   Testing Mini Stealth Interceptor
echo ========================================
echo.

if not exist bin\MiniStealthInterceptor.exe (
    echo ERROR: MiniStealthInterceptor.exe not found
    echo Please build the project first
    exit /b 1
)

echo Running tests...
echo Note: This is a manual test - follow the on-screen prompts
echo.

bin\MiniStealthInterceptor.exe
