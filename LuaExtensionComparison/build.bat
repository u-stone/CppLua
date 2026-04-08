@echo off
setlocal

:: Switch to script directory
cd /d "%~dp0"

:: Define build directory
set "BUILD_DIR=%~dp0build"

:: Clean and create build directory
if exist "%BUILD_DIR%" rd /s /q "%BUILD_DIR%"
mkdir "%BUILD_DIR%"

:: Switch to build directory
cd /d "%BUILD_DIR%"

:: Generate
echo Generating project files...
cmake .. -G "Visual Studio 17 2022" -A Win32

:: Build
echo Building...
cmake --build . --config Release

echo Build complete.
pause
