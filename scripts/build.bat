@echo off
REM ============================================================================
REM STEALTH INTERCEPTOR - Build Script
REM ============================================================================
REM File:        build.bat
REM Description: Compiles and links all project files
REM Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
REM ============================================================================

echo ============================================================
echo   The Stealth Interceptor - Build System
echo   Version 1.0.0
echo ============================================================
echo.

REM Check for Visual Studio environment
if not defined VSINSTALLDIR (
    echo [!] Visual Studio environment not detected.
    echo [!] Please run this script from a Developer Command Prompt
    echo [!] or run vcvarsall.bat first.
    echo.
    echo Attempting to find Visual Studio...
    
    REM Try to find and run vcvarsall
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" (
        call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x86
    ) else if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvarsall.bat" (
        call "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvarsall.bat" x86
    ) else if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" (
        call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" x86
    ) else (
        echo [-] Could not find Visual Studio installation.
        echo [-] Please install Visual Studio with C++ desktop development workload.
        exit /b 1
    )
)

REM Check for MASM32
if not defined MASM32 (
    if exist "C:\masm32" (
        set MASM32=C:\masm32
    ) else (
        echo [-] MASM32 not found. Please install MASM32 to C:\masm32
        exit /b 1
    )
)

echo [+] Build environment configured
echo.

REM Create build directories
echo [*] Creating build directories...
if not exist "build" mkdir build
if not exist "build\obj" mkdir build\obj
if not exist "bin" mkdir bin
if not exist "bin\Release" mkdir bin\Release
if not exist "bin\Debug" mkdir bin\Debug

REM Set paths
set SRC_DIR=src
set BUILD_DIR=build
set OBJ_DIR=build\obj
set BIN_DIR=bin\Release
set INC_DIR=include

REM Assembler options
set ML_OPTS=/c /coff /Zi /I%INC_DIR% /I%MASM32%\include

REM Linker options
set LINK_OPTS=/SUBSYSTEM:CONSOLE /LIBPATH:%MASM32%\lib kernel32.lib user32.lib

echo [*] Compiling source files...
echo.

REM Compile core files
echo     Compiling hook_engine.asm...
ml %ML_OPTS% /Fo%OBJ_DIR%\hook_engine.obj %SRC_DIR%\core\hook_engine.asm
if errorlevel 1 goto :error

echo     Compiling trampoline.asm...
ml %ML_OPTS% /Fo%OBJ_DIR%\trampoline.obj %SRC_DIR%\core\trampoline.asm
if errorlevel 1 goto :error

echo     Compiling memory_manager.asm...
ml %ML_OPTS% /Fo%OBJ_DIR%\memory_manager.obj %SRC_DIR%\core\memory_manager.asm
if errorlevel 1 goto :error

echo     Compiling register_save.asm...
ml %ML_OPTS% /Fo%OBJ_DIR%\register_save.obj %SRC_DIR%\core\register_save.asm
if errorlevel 1 goto :error

REM Compile hook files
echo     Compiling messagebox_hook.asm...
ml %ML_OPTS% /Fo%OBJ_DIR%\messagebox_hook.obj %SRC_DIR%\hooks\messagebox_hook.asm
if errorlevel 1 goto :error

echo     Compiling file_hooks.asm...
ml %ML_OPTS% /Fo%OBJ_DIR%\file_hooks.obj %SRC_DIR%\hooks\file_hooks.asm
if errorlevel 1 goto :error

echo     Compiling network_hooks.asm...
ml %ML_OPTS% /Fo%OBJ_DIR%\network_hooks.obj %SRC_DIR%\hooks\network_hooks.asm
if errorlevel 1 goto :error

echo     Compiling process_hooks.asm...
ml %ML_OPTS% /Fo%OBJ_DIR%\process_hooks.obj %SRC_DIR%\hooks\process_hooks.asm
if errorlevel 1 goto :error

REM Compile utility files
echo     Compiling logging.asm...
ml %ML_OPTS% /Fo%OBJ_DIR%\logging.obj %SRC_DIR%\utils\logging.asm
if errorlevel 1 goto :error

echo     Compiling string_utils.asm...
ml %ML_OPTS% /Fo%OBJ_DIR%\string_utils.obj %SRC_DIR%\utils\string_utils.asm
if errorlevel 1 goto :error

REM Compile demo
echo     Compiling demo_main.asm...
ml %ML_OPTS% /Fo%OBJ_DIR%\demo_main.obj %SRC_DIR%\demo\demo_main.asm
if errorlevel 1 goto :error

echo.
echo [*] Linking...

REM Link all object files
link %LINK_OPTS% /OUT:%BIN_DIR%\StealthInterceptor.exe ^
    %OBJ_DIR%\demo_main.obj ^
    %OBJ_DIR%\hook_engine.obj ^
    %OBJ_DIR%\trampoline.obj ^
    %OBJ_DIR%\memory_manager.obj ^
    %OBJ_DIR%\register_save.obj ^
    %OBJ_DIR%\messagebox_hook.obj ^
    %OBJ_DIR%\file_hooks.obj ^
    %OBJ_DIR%\network_hooks.obj ^
    %OBJ_DIR%\process_hooks.obj ^
    %OBJ_DIR%\logging.obj ^
    %OBJ_DIR%\string_utils.obj

if errorlevel 1 goto :error

echo.
echo ============================================================
echo   BUILD SUCCESSFUL!
echo ============================================================
echo   Output: %BIN_DIR%\StealthInterceptor.exe
echo ============================================================
echo.
goto :end

:error
echo.
echo ============================================================
echo   BUILD FAILED!
echo ============================================================
echo   Please check the error messages above.
echo ============================================================
echo.
exit /b 1

:end
echo Build completed successfully.
