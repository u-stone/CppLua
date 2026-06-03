# build.ps1

$ErrorActionPreference = "Stop"

# Get script directory (root)
$SCRIPT_DIR = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SCRIPT_DIR)) {
    if ($MyInvocation.MyCommand.Path) {
        $SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
}
if ([string]::IsNullOrWhiteSpace($SCRIPT_DIR)) {
    $SCRIPT_DIR = Get-Location
}

# Point to project directory
$PROJECT_ROOT = Join-Path $SCRIPT_DIR "CppLua"
$BUILD_DIR = Join-Path $PROJECT_ROOT "build"

Write-Host "Script directory: $SCRIPT_DIR"
Write-Host "Project root: $PROJECT_ROOT"

# Save original directory to return later
Push-Location $SCRIPT_DIR

try {
    # Create build directory
    if (Test-Path $BUILD_DIR) {
        Remove-Item -Recurse -Force $BUILD_DIR
    }
    New-Item -ItemType Directory -Path $BUILD_DIR
    Set-Location $BUILD_DIR

    # Generate project
    Write-Host "Generating project files..."
    cmake $PROJECT_ROOT -G "Visual Studio 17 2022" -A Win32

    # Compile and install
    Write-Host "Building and Installing..."
    cmake --build . --config Release --target install

    Write-Host "Build complete."
}
catch {
    Write-Host "Build failed: $_" -ForegroundColor Red
}
finally {
    # Return to original position regardless of success or failure
    Pop-Location
    # Wait for user input, simulate pause
    # Read-Host "Press any key to continue..."
}

