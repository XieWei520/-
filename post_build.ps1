# Post-build script to copy sqlite3.dll to output directories
# This script should be run after flutter build windows

$ErrorActionPreference = "Stop"

# Find sqlite3.dll from pub cache
$sqlite3DllPath = Get-ChildItem -Path "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.flutter-io.cn\sqlite3-*\lib\src\ffi\sqlite3.dll" | Select-Object -First 1 -ExpandProperty FullName

if (-not $sqlite3DllPath) {
    Write-Error "Could not find sqlite3.dll in pub cache"
    exit 1
}

Write-Host "Found sqlite3.dll at: $sqlite3DllPath"

# Copy to Debug and Release directories
$buildDir = "build\windows\x64\runner"
$debugDir = Join-Path $buildDir "Debug"
$releaseDir = Join-Path $buildDir "Release"

if (Test-Path $debugDir) {
    Copy-Item $sqlite3DllPath -Destination $debugDir -Force
    Write-Host "Copied sqlite3.dll to Debug directory"
}

if (Test-Path $releaseDir) {
    Copy-Item $sqlite3DllPath -Destination $releaseDir -Force
    Write-Host "Copied sqlite3.dll to Release directory"
}

Write-Host "sqlite3.dll deployment completed successfully!"
