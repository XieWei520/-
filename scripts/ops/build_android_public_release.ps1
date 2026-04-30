[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [string]$FlutterExecutable = 'flutter',
    [string]$JavaHome = 'D:\Apps\Android\Android Studio\jbr',
    [switch]$BuildAppBundle
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $scriptRoot = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
        $scriptPath = $MyInvocation.MyCommand.Path
        if ([string]::IsNullOrWhiteSpace($scriptPath)) {
            throw 'Unable to resolve project root. Pass -ProjectRoot explicitly.'
        }
        $scriptRoot = Split-Path -Parent $scriptPath
    }
    $ProjectRoot = (Resolve-Path (Join-Path $scriptRoot '..\..')).Path
} else {
    $ProjectRoot = (Resolve-Path $ProjectRoot).Path
}

Set-Location $ProjectRoot

if (Test-Path -LiteralPath $JavaHome) {
    $env:JAVA_HOME = $JavaHome
    $env:Path = "$JavaHome\bin;$env:Path"
}

$targetPlatforms = 'android-arm,android-arm64'

if ($BuildAppBundle) {
    & $FlutterExecutable build appbundle --release --target-platform $targetPlatforms -P wkPublicRelease=true
} else {
    & $FlutterExecutable build apk --release --split-per-abi --target-platform $targetPlatforms -P wkPublicRelease=true
}

if ($LASTEXITCODE -ne 0) {
    throw "Android public release build failed with exit code $LASTEXITCODE."
}
