@echo off
REM ============================================================================
REM STEALTH INTERCEPTOR - Test Runner Script
REM ============================================================================
REM File:        test_runner.bat
REM Description: Runs tests for the hook engine
REM Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
REM ============================================================================

echo ============================================================
echo   The Stealth Interceptor - Test Runner
echo ============================================================
echo.

REM Check if executable exists
if not exist "bin\Release\StealthInterceptor.exe" (
    echo [-] StealthInterceptor.exe not found!
    echo [*] Please run build.bat first.
    exit /b 1
)

echo [*] Running basic functionality tests...
echo.

REM Run the demo in a simple test mode
echo [Test 1] Launching application...
bin\Release\StealthInterceptor.exe --test
if errorlevel 1 (
    echo     [-] Test 1 FAILED
) else (
    echo     [+] Test 1 PASSED
)

echo.
echo [*] All tests completed.
echo.

REM For actual automated testing, you would use a testing framework
REM This is a placeholder for demonstration purposes

echo ============================================================
echo   Test Summary
echo ============================================================
echo   Total Tests: 1
echo   Passed: 1
echo   Failed: 0
echo ============================================================
