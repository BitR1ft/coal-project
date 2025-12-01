# Makefile for The Stealth Interceptor
# For use with GNU Make on Windows (e.g., through MinGW or WSL)

# Configuration
PROJECT = StealthInterceptor
VERSION = 1.0.0

# Directories
SRC_DIR = src
BUILD_DIR = build
OBJ_DIR = $(BUILD_DIR)/obj
BIN_DIR = bin/Release
INC_DIR = include
DOCS_DIR = docs

# MASM32 path (adjust if needed)
MASM32 = C:/masm32

# Tools
ML = $(MASM32)/bin/ml.exe
LINK = $(MASM32)/bin/link.exe

# Assembler flags
MLFLAGS = /c /coff /Zi /I$(INC_DIR) /I$(MASM32)/include

# Linker flags
LDFLAGS = /SUBSYSTEM:CONSOLE /LIBPATH:$(MASM32)/lib

# Libraries
LIBS = kernel32.lib user32.lib

# Source files
CORE_SRC = \
	$(SRC_DIR)/core/hook_engine.asm \
	$(SRC_DIR)/core/trampoline.asm \
	$(SRC_DIR)/core/memory_manager.asm \
	$(SRC_DIR)/core/register_save.asm

HOOK_SRC = \
	$(SRC_DIR)/hooks/messagebox_hook.asm \
	$(SRC_DIR)/hooks/file_hooks.asm \
	$(SRC_DIR)/hooks/network_hooks.asm \
	$(SRC_DIR)/hooks/process_hooks.asm

UTIL_SRC = \
	$(SRC_DIR)/utils/logging.asm \
	$(SRC_DIR)/utils/string_utils.asm

DEMO_SRC = \
	$(SRC_DIR)/demo/demo_main.asm

# Object files
CORE_OBJ = $(patsubst $(SRC_DIR)/%.asm,$(OBJ_DIR)/%.obj,$(CORE_SRC))
HOOK_OBJ = $(patsubst $(SRC_DIR)/%.asm,$(OBJ_DIR)/%.obj,$(HOOK_SRC))
UTIL_OBJ = $(patsubst $(SRC_DIR)/%.asm,$(OBJ_DIR)/%.obj,$(UTIL_SRC))
DEMO_OBJ = $(patsubst $(SRC_DIR)/%.asm,$(OBJ_DIR)/%.obj,$(DEMO_SRC))

ALL_OBJ = $(DEMO_OBJ) $(CORE_OBJ) $(HOOK_OBJ) $(UTIL_OBJ)

# Output
TARGET = $(BIN_DIR)/$(PROJECT).exe

# Default target
.PHONY: all
all: banner directories $(TARGET)
	@echo Build complete!
	@echo Output: $(TARGET)

# Banner
.PHONY: banner
banner:
	@echo ========================================
	@echo   The Stealth Interceptor
	@echo   Version $(VERSION)
	@echo ========================================
	@echo.

# Create directories
.PHONY: directories
directories:
	@if not exist "$(BUILD_DIR)" mkdir "$(BUILD_DIR)"
	@if not exist "$(OBJ_DIR)" mkdir "$(OBJ_DIR)"
	@if not exist "$(OBJ_DIR)/core" mkdir "$(OBJ_DIR)/core"
	@if not exist "$(OBJ_DIR)/hooks" mkdir "$(OBJ_DIR)/hooks"
	@if not exist "$(OBJ_DIR)/utils" mkdir "$(OBJ_DIR)/utils"
	@if not exist "$(OBJ_DIR)/demo" mkdir "$(OBJ_DIR)/demo"
	@if not exist "$(BIN_DIR)" mkdir "$(BIN_DIR)"

# Linking
$(TARGET): $(ALL_OBJ)
	@echo Linking...
	$(LINK) $(LDFLAGS) /OUT:$@ $^ $(LIBS)

# Compile rules
$(OBJ_DIR)/%.obj: $(SRC_DIR)/%.asm
	@echo Compiling $<...
	$(ML) $(MLFLAGS) /Fo$@ $<

# Clean
.PHONY: clean
clean:
	@echo Cleaning...
	@if exist "$(BUILD_DIR)" rmdir /s /q "$(BUILD_DIR)"
	@if exist "$(BIN_DIR)" rmdir /s /q "$(BIN_DIR)"
	@echo Clean complete.

# Rebuild
.PHONY: rebuild
rebuild: clean all

# Run
.PHONY: run
run: all
	$(TARGET)

# Help
.PHONY: help
help:
	@echo Available targets:
	@echo   all     - Build the project (default)
	@echo   clean   - Remove build artifacts
	@echo   rebuild - Clean and build
	@echo   run     - Build and run
	@echo   help    - Show this help

# Dependencies
$(OBJ_DIR)/demo/demo_main.obj: $(SRC_DIR)/demo/demo_main.asm $(INC_DIR)/stealth_interceptor.inc
$(OBJ_DIR)/core/hook_engine.obj: $(SRC_DIR)/core/hook_engine.asm
$(OBJ_DIR)/core/trampoline.obj: $(SRC_DIR)/core/trampoline.asm
$(OBJ_DIR)/core/memory_manager.obj: $(SRC_DIR)/core/memory_manager.asm
$(OBJ_DIR)/core/register_save.obj: $(SRC_DIR)/core/register_save.asm
$(OBJ_DIR)/hooks/messagebox_hook.obj: $(SRC_DIR)/hooks/messagebox_hook.asm
$(OBJ_DIR)/hooks/file_hooks.obj: $(SRC_DIR)/hooks/file_hooks.asm
$(OBJ_DIR)/hooks/network_hooks.obj: $(SRC_DIR)/hooks/network_hooks.asm
$(OBJ_DIR)/hooks/process_hooks.obj: $(SRC_DIR)/hooks/process_hooks.asm
$(OBJ_DIR)/utils/logging.obj: $(SRC_DIR)/utils/logging.asm
$(OBJ_DIR)/utils/string_utils.obj: $(SRC_DIR)/utils/string_utils.asm
