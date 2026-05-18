$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed with exit code $LASTEXITCODE"
    }
}

function Enable-WindowsUserProxyForBuild {
    $internetSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $internetSettings = Get-ItemProperty $internetSettingsPath

    if ($internetSettings.ProxyEnable -ne 1 -or [string]::IsNullOrWhiteSpace($internetSettings.ProxyServer)) {
        Write-Host "No Windows user proxy detected for this build."
        return
    }

    $proxyServer = [string]$internetSettings.ProxyServer
    $proxyEndpoint = $proxyServer

    if ($proxyServer.Contains("=")) {
        $entries = @{}
        foreach ($entry in $proxyServer.Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)) {
            $parts = $entry.Split("=", 2)
            if ($parts.Count -eq 2) {
                $entries[$parts[0].Trim().ToLowerInvariant()] = $parts[1].Trim()
            }
        }
        $proxyEndpoint = $entries["https"]
        if ([string]::IsNullOrWhiteSpace($proxyEndpoint)) {
            $proxyEndpoint = $entries["http"]
        }
    }

    if ([string]::IsNullOrWhiteSpace($proxyEndpoint)) {
        Write-Host "Windows user proxy is enabled, but no HTTP/HTTPS endpoint was found."
        return
    }

    if (-not $proxyEndpoint.Contains("://")) {
        $proxyEndpoint = "http://$proxyEndpoint"
    }

    $env:HTTP_PROXY = $proxyEndpoint
    $env:HTTPS_PROXY = $proxyEndpoint
    $env:http_proxy = $proxyEndpoint
    $env:https_proxy = $proxyEndpoint

    if ([string]::IsNullOrWhiteSpace($env:NO_PROXY)) {
        $env:NO_PROXY = "localhost,127.0.0.1"
    }
    if ([string]::IsNullOrWhiteSpace($env:no_proxy)) {
        $env:no_proxy = $env:NO_PROXY
    }

    $env:GIT_CONFIG_COUNT = "2"
    $env:GIT_CONFIG_KEY_0 = "http.proxy"
    $env:GIT_CONFIG_VALUE_0 = $proxyEndpoint
    $env:GIT_CONFIG_KEY_1 = "https.proxy"
    $env:GIT_CONFIG_VALUE_1 = $proxyEndpoint

    Write-Host "Using Windows user proxy for build downloads: $proxyEndpoint"
}

Enable-WindowsUserProxyForBuild

# Flutter/CMake expects this directory during install even when no native
# assets are emitted for Windows.
New-Item -ItemType Directory -Force -Path "build\native_assets\windows" | Out-Null

Invoke-Checked flutter pub get

Invoke-Checked flutter build windows --release
