# run_all.ps1
$ErrorActionPreference = "Stop"

Write-Host "=== 1. Clean and Build ===" -ForegroundColor Cyan
if (Test-Path "LuaExtensionComparison/build") { Remove-Item -Recurse -Force "LuaExtensionComparison/build" }
if (Test-Path "LuaExtensionComparison/deploy") { Remove-Item -Recurse -Force "LuaExtensionComparison/deploy" }
.\build.ps1

Write-Host "`n=== 2. Configure Environment ===" -ForegroundColor Cyan
$deployPath = Join-Path $PSScriptRoot "LuaExtensionComparison\deploy"
$modulesPath = Join-Path $deployPath "modules"
$scriptsPath = Join-Path $deployPath "scripts"

# Set environment variables to ensure modules (.dll) and dependencies (core.dll) can be found
$env:LUA_CPATH = "$modulesPath\?.dll;;"
$env:PATH = "$modulesPath;" + $env:PATH

Write-Host "Deployment directory: $deployPath"

Write-Host "`n=== 3. Execute Tests ===" -ForegroundColor Cyan
$testScripts = @(
    "test_raw.lua",
    "test_luabridge.lua",
    "test_sol2.lua"
)

foreach ($script in $testScripts) {
    $scriptPath = Join-Path $scriptsPath $script
    Write-Host "`nRunning test: $script" -ForegroundColor Yellow
    lua $scriptPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Test failed: $script" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n=== All tests completed successfully! ===" -ForegroundColor Green
