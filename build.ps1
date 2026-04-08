# build.ps1

$ErrorActionPreference = "Stop"

# 获取脚本所在目录 (根目录)
$SCRIPT_DIR = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SCRIPT_DIR)) {
    if ($MyInvocation.MyCommand.Path) {
        $SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
}
if ([string]::IsNullOrWhiteSpace($SCRIPT_DIR)) {
    $SCRIPT_DIR = Get-Location
}

# 指向项目目录
$PROJECT_ROOT = Join-Path $SCRIPT_DIR "LuaExtensionComparison"
$BUILD_DIR = Join-Path $PROJECT_ROOT "build"

Write-Host "Script directory: $SCRIPT_DIR"
Write-Host "Project root: $PROJECT_ROOT"

# 保存原始目录，以便最后返回
Push-Location $SCRIPT_DIR

try {
    # 创建构建目录
    if (Test-Path $BUILD_DIR) {
        Remove-Item -Recurse -Force $BUILD_DIR
    }
    New-Item -ItemType Directory -Path $BUILD_DIR
    Set-Location $BUILD_DIR

    # 生成工程
    Write-Host "Generating project files..."
    cmake $PROJECT_ROOT -G "Visual Studio 17 2022" -A Win32

    # 编译并安装
    Write-Host "Building and Installing..."
    cmake --build . --config Release --target install

    Write-Host "Build complete."
}
catch {
    Write-Host "Build failed: $_" -ForegroundColor Red
}
finally {
    # 无论成功与否，回到原来的位置
    Pop-Location
    # 等待用户输入，模拟 pause
    Read-Host "Press any key to continue..."
}
