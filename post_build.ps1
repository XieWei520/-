# Post-build script to copy sqlite3.dll to output directories
# This script should be run after flutter build windows

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# Prefer the checked-in runtime DLL. Recent sqlite3 packages do not always
# include a Windows DLL in the pub cache.
$sqlite3DllPath = $null
$repoSqlite3DllPath = Join-Path $root "sqlite3.dll"
if (Test-Path $repoSqlite3DllPath) {
    $sqlite3DllPath = $repoSqlite3DllPath
}

if (-not $sqlite3DllPath -and $env:LOCALAPPDATA) {
    $pubCachePath = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted"
    if (Test-Path $pubCachePath) {
        $sqlite3DllPath = Get-ChildItem -Path $pubCachePath -Recurse -Filter "sqlite3.dll" -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
    }
}

if (-not $sqlite3DllPath) {
    $existingOutputDll = Get-ChildItem -Path "build\windows\x64\runner" -Recurse -Filter "sqlite3.dll" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($existingOutputDll) {
        Write-Host "sqlite3.dll already exists in build output: $existingOutputDll"
        exit 0
    }

    Write-Error "Could not find sqlite3.dll in the repository, pub cache, or build output"
}

Write-Host "Found sqlite3.dll at: $sqlite3DllPath"

# Copy to Debug and Release directories
$buildDir = "build\windows\x64\runner"
$debugDir = Join-Path $buildDir "Debug"
$releaseDir = Join-Path $buildDir "Release"

if (Test-Path $debugDir) {
    try {
        Copy-Item $sqlite3DllPath -Destination $debugDir -Force
        Write-Host "Copied sqlite3.dll to Debug directory"
    }
    catch {
        Write-Host "Skipping Debug sqlite3.dll copy because the file is in use: $($_.Exception.Message)"
    }
}

if (Test-Path $releaseDir) {
    try {
        Copy-Item $sqlite3DllPath -Destination $releaseDir -Force
        Write-Host "Copied sqlite3.dll to Release directory"
    }
    catch {
        Write-Host "Skipping Release sqlite3.dll copy because the file is in use: $($_.Exception.Message)"
    }
}

Write-Host "sqlite3.dll deployment completed successfully!"

function Copy-MonitorShellBundle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$SourceDir,
        [Parameter(Mandatory = $true)]
        [string]$DestinationDir
    )

    if (-not (Test-Path $SourceDir)) {
        Write-Host "Skipping $Name monitor shell copy; source not found: $SourceDir"
        return
    }

    if (Test-Path $DestinationDir) {
        Remove-Item -LiteralPath $DestinationDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null
    Copy-Item -Path (Join-Path $SourceDir "*") -Destination $DestinationDir -Recurse -Force
    Write-Host "Copied $Name monitor shell to: $DestinationDir"
}

$mengxiaShellReleaseDir = Join-Path $root "tools\mengxia_monitor_shell_app\build\windows\x64\runner\Release"

if (Test-Path $releaseDir) {
    Copy-MonitorShellBundle `
        -Name "MX信息监控" `
        -SourceDir $mengxiaShellReleaseDir `
        -DestinationDir (Join-Path $releaseDir "monitor_shells\mengxia")
}
