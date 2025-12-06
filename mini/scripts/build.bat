@echo off
REM Build script for Mini Stealth Interceptor
echo ========================================
echo   Building Mini Stealth Interceptor
echo ========================================
echo.

REM Check for MASM32
if not exist "C:\masm32" (
    echo ERROR: MASM32 not found at C:\masm32
    echo Please install MASM32 or update the path
    exit /b 1
)

REM Create directories
if not exist build mkdir build
if not exist build\obj mkdir build\obj
if not exist build\obj\core mkdir build\obj\core
if not exist build\obj\hooks mkdir build\obj\hooks
if not exist build\obj\demo mkdir build\obj\demo
if not exist bin mkdir bin

echo [1/4] Compiling hook engine...
C:\masm32\bin\ml.exe /c /coff /Zi /Iinclude /IC:\masm32\include /Fobuild\obj\core\hook_engine.obj src\core\hook_engine.asm
if errorlevel 1 goto error

echo [2/4] Compiling messagebox hook...
C:\masm32\bin\ml.exe /c /coff /Zi /Iinclude /IC:\masm32\include /Fobuild\obj\hooks\messagebox_hook.obj src\hooks\messagebox_hook.asm
if errorlevel 1 goto error

echo [3/4] Compiling demo...
C:\masm32\bin\ml.exe /c /coff /Zi /Iinclude /IC:\masm32\include /Fobuild\obj\demo\demo_main.obj src\demo\demo_main.asm
if errorlevel 1 goto error

echo [4/4] Linking...
C:\masm32\bin\link.exe /SUBSYSTEM:CONSOLE /LIBPATH:C:\masm32\lib /OUT:bin\MiniStealthInterceptor.exe build\obj\demo\demo_main.obj build\obj\core\hook_engine.obj build\obj\hooks\messagebox_hook.obj kernel32.lib user32.lib
if errorlevel 1 goto error

echo.
echo ========================================
echo   Build Successful!
echo   Output: bin\MiniStealthInterceptor.exe
echo ========================================
goto end

:error
echo.
echo ========================================
echo   Build Failed!
echo ========================================
exit /b 1

:end
