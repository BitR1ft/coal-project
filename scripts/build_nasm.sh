#!/bin/bash
#===============================================================================
# STEALTH INTERCEPTOR - NASM Build Script (Linux/MinGW)
#===============================================================================
# Description: Builds the project using NASM and MinGW cross-compiler
# Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
#===============================================================================

echo "========================================"
echo "  The Stealth Interceptor"
echo "  NASM Build System"
echo "========================================"
echo ""

# Check for NASM
if ! command -v nasm &> /dev/null; then
    echo "ERROR: NASM not found. Please install NASM."
    echo "  sudo apt-get install nasm"
    exit 1
fi

# Check for MinGW
if ! command -v i686-w64-mingw32-ld &> /dev/null; then
    echo "ERROR: MinGW not found. Please install MinGW."
    echo "  sudo apt-get install mingw-w64 gcc-mingw-w64-i686"
    exit 1
fi

echo "[+] Build tools verified"
echo ""

# Determine which project to build
if [ "$1" == "mini" ] || [ "$1" == "" ]; then
    echo "[*] Building Mini Stealth Interceptor..."
    cd mini
    make -f Makefile_nasm all
    if [ $? -eq 0 ]; then
        echo ""
        echo "========================================"
        echo "  BUILD SUCCESSFUL!"
        echo "========================================"
        echo "  Output: mini/bin/MiniStealthInterceptor.exe"
        echo ""
        echo "To run on Linux (requires Wine):"
        echo "  wine mini/bin/MiniStealthInterceptor.exe"
        echo ""
        echo "To run on Windows:"
        echo "  Copy to Windows and run directly"
        echo "========================================"
    else
        echo ""
        echo "========================================"
        echo "  BUILD FAILED!"
        echo "========================================"
        exit 1
    fi
elif [ "$1" == "full" ]; then
    echo "[*] Building Full Stealth Interceptor..."
    echo ""
    echo "Full project NASM conversion in progress."
    echo "The mini project is currently available and working."
    echo ""
    echo "To build the mini project:"
    echo "  ./build_nasm.sh mini"
else
    echo "Usage: $0 [mini|full]"
    echo ""
    echo "  mini - Build mini version (default, fully working)"
    echo "  full - Build full version (in progress)"
    exit 1
fi
