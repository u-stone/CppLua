# build.ps1

$ErrorActionPreference = "Stop"

# 使用更鲁棒的方式获取脚本所在目录
$SCRIPT_DIR = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SCRIPT_DIR)) {
    if ($MyInvocation.MyCommand.Path) {
        $SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
}
if ([string]::IsNullOrWhiteSpace($SCRIPT_DIR)) {
    $SCRIPT_DIR = Get-Location
}

Write-Host "Script directory determined as: $SCRIPT_DIR"

$BUILD_DIR = Join-Path $SCRIPT_DIR "build"

# 保存原始目录，以便最后返回
Push-Location $SCRIPT_DIR

try {
    # 创建构建目录
    if (Test-Path $BUILD_DIR) {
        Remove-Item -Recurse -Force $BUILD_DIR
    }
    New-Item -ItemType Directory -Path $BUILD_DIR
    Set-Location $BUILD_DIR

    # 生成工程 (使用相对路径 .. 指向脚本所在目录)
    Write-Host "Generating project files..."
    cmake .. -G "Visual Studio 17 2022" -A Win32

    # 编译
    Write-Host "Building..."
    cmake --build . --config Release

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
