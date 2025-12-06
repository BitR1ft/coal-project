# Makefile for Mini Stealth Interceptor
# Simplified version for educational purposes

# Configuration
PROJECT = MiniStealthInterceptor
VERSION = 1.0.0

# Directories
SRC_DIR = src
BUILD_DIR = build
OBJ_DIR = $(BUILD_DIR)/obj
BIN_DIR = bin
INC_DIR = include

# MASM32 path
MASM32 = C:/masm32

# Tools
ML = $(MASM32)/bin/ml.exe
LINK = $(MASM32)/bin/link.exe

# Flags
MLFLAGS = /c /coff /Zi /I$(INC_DIR) /I$(MASM32)/include
LDFLAGS = /SUBSYSTEM:CONSOLE /LIBPATH:$(MASM32)/lib
LIBS = kernel32.lib user32.lib

# Source files
CORE_SRC = $(SRC_DIR)/core/hook_engine.asm
HOOK_SRC = $(SRC_DIR)/hooks/messagebox_hook.asm
DEMO_SRC = $(SRC_DIR)/demo/demo_main.asm

# Object files
CORE_OBJ = $(OBJ_DIR)/core/hook_engine.obj
HOOK_OBJ = $(OBJ_DIR)/hooks/messagebox_hook.obj
DEMO_OBJ = $(OBJ_DIR)/demo/demo_main.obj

ALL_OBJ = $(DEMO_OBJ) $(CORE_OBJ) $(HOOK_OBJ)

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
	@echo   Mini Stealth Interceptor
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
