# CMakeLists.txt for Mini Stealth Interceptor
# Simplified version demonstrating API hooking concepts

cmake_minimum_required(VERSION 3.15)

project(MiniStealthInterceptor
    VERSION 1.0.0
    DESCRIPTION "Mini API Hooking Engine using MASM x86 Assembly"
    LANGUAGES ASM_MASM
)

# Windows only
if(NOT WIN32)
    message(FATAL_ERROR "This project only supports Windows")
endif()

# x86 only
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(WARNING "This is a 32-bit project. Consider using -A Win32 with cmake.")
endif()

# MASM settings
enable_language(ASM_MASM)
set(CMAKE_ASM_MASM_FLAGS "/c /coff /Zi")

# Source files
set(CORE_SOURCES
    src/core/hook_engine.asm
)

set(HOOK_SOURCES
    src/hooks/messagebox_hook.asm
)

set(DEMO_SOURCES
    src/demo/demo_main.asm
)

# Include directories
include_directories(
    ${CMAKE_SOURCE_DIR}/include
    $ENV{MASM32}/include
)

# Link directories
link_directories(
    $ENV{MASM32}/lib
)

# Main executable
add_executable(MiniStealthInterceptor
    ${DEMO_SOURCES}
    ${CORE_SOURCES}
    ${HOOK_SOURCES}
)

# Linker settings
set_target_properties(MiniStealthInterceptor PROPERTIES
    LINK_FLAGS "/SUBSYSTEM:CONSOLE"
)

target_link_libraries(MiniStealthInterceptor
    kernel32
    user32
)

# Output directory
set_target_properties(MiniStealthInterceptor PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
)

# Install
install(TARGETS MiniStealthInterceptor
    RUNTIME DESTINATION bin
)

install(DIRECTORY docs/
    DESTINATION docs
)

# Print configuration
message(STATUS "")
message(STATUS "=== Mini Stealth Interceptor ===")
message(STATUS "Version: ${PROJECT_VERSION}")
message(STATUS "Platform: Windows x86")
message(STATUS "Assembler: MASM")
message(STATUS "")
