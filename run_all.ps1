# run_all.ps1
$ErrorActionPreference = "Stop"

Write-Host "=== 1. 清理与编译 ===" -ForegroundColor Cyan
if (Test-Path "LuaExtensionComparison/build") { Remove-Item -Recurse -Force "LuaExtensionComparison/build" }
if (Test-Path "LuaExtensionComparison/deploy") { Remove-Item -Recurse -Force "LuaExtensionComparison/deploy" }
.\build.ps1

Write-Host "`n=== 2. 配置环境 ===" -ForegroundColor Cyan
$deployPath = Join-Path $PSScriptRoot "LuaExtensionComparison\deploy"
$modulesPath = Join-Path $deployPath "modules"
$scriptsPath = Join-Path $deployPath "scripts"

# 设置环境变量，确保能找到模块 (.dll) 及其依赖 (core.dll)
$env:LUA_CPATH = "$modulesPath\?.dll;;"
$env:PATH = "$modulesPath;" + $env:PATH

Write-Host "部署目录: $deployPath"

Write-Host "`n=== 3. 执行测试 ===" -ForegroundColor Cyan
$testScripts = @(
    "test_raw.lua",
    "test_luabridge.lua",
    "test_sol2.lua"
)

foreach ($script in $testScripts) {
    $scriptPath = Join-Path $scriptsPath $script
    Write-Host "`n运行测试: $script" -ForegroundColor Yellow
    lua $scriptPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "测试失败: $script" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n=== 所有测试顺利完成！ ===" -ForegroundColor Green
