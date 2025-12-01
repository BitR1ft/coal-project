# CMakeLists.txt for The Stealth Interceptor
# Note: This project primarily uses MASM, but this CMake file
# is provided for IDE integration and project organization

cmake_minimum_required(VERSION 3.15)

project(StealthInterceptor
    VERSION 1.0.0
    DESCRIPTION "API Hooking Engine using MASM x86 Assembly"
    LANGUAGES ASM_MASM CXX
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
    src/core/trampoline.asm
    src/core/memory_manager.asm
    src/core/register_save.asm
)

set(HOOK_SOURCES
    src/hooks/messagebox_hook.asm
    src/hooks/file_hooks.asm
    src/hooks/network_hooks.asm
    src/hooks/process_hooks.asm
)

set(UTIL_SOURCES
    src/utils/logging.asm
    src/utils/string_utils.asm
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
add_executable(StealthInterceptor
    ${DEMO_SOURCES}
    ${CORE_SOURCES}
    ${HOOK_SOURCES}
    ${UTIL_SOURCES}
)

# Linker settings
set_target_properties(StealthInterceptor PROPERTIES
    LINK_FLAGS "/SUBSYSTEM:CONSOLE"
)

target_link_libraries(StealthInterceptor
    kernel32
    user32
)

# Output directory
set_target_properties(StealthInterceptor PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
)

# Install
install(TARGETS StealthInterceptor
    RUNTIME DESTINATION bin
)

install(DIRECTORY docs/
    DESTINATION docs
)

# Custom targets
add_custom_target(clean-all
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_SOURCE_DIR}/bin
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_SOURCE_DIR}/build
    COMMENT "Cleaning all build artifacts"
)

# Print configuration
message(STATUS "")
message(STATUS "=== The Stealth Interceptor ===")
message(STATUS "Version: ${PROJECT_VERSION}")
message(STATUS "Platform: Windows x86")
message(STATUS "Assembler: MASM")
message(STATUS "")
