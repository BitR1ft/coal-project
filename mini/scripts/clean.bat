@echo off
REM Clean script for Mini Stealth Interceptor
echo Cleaning build artifacts...

if exist build rmdir /s /q build
if exist bin rmdir /s /q bin

echo Clean complete.
