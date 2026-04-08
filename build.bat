@echo off
setlocal

:: Set directories relative to this script
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%~dp0LuaExtensionComparison"
set "BUILD_DIR=%PROJECT_ROOT%\build"

:: Switch to script directory
cd /d "%SCRIPT_DIR%"

:: Clean and create build directory
if exist "%BUILD_DIR%" rd /s /q "%BUILD_DIR%"
mkdir "%BUILD_DIR%"

:: Switch to build directory
cd /d "%BUILD_DIR%"

:: Generate
echo Generating project files in: "%PROJECT_ROOT%"
cmake "%PROJECT_ROOT%" -G "Visual Studio 17 2022" -A Win32

:: Build
echo Building...
cmake --build . --config Release

echo Build complete.
pause
