[CmdletBinding()]
param(
    [string]$WebImDir = 'web_im'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$resolvedWebImDir = (Resolve-Path -LiteralPath (Join-Path $root $WebImDir)).Path

Write-Host "[STEP] Installing Web IM dependencies"
pnpm --dir $resolvedWebImDir install --frozen-lockfile
if ($LASTEXITCODE -ne 0) {
    throw "pnpm install failed for Web IM."
}

Write-Host "[STEP] Building Web IM release"
pnpm --dir $resolvedWebImDir build
if ($LASTEXITCODE -ne 0) {
    throw "pnpm build failed for Web IM."
}

$dist = Join-Path $resolvedWebImDir 'dist'
foreach ($required in @('index.html', 'manifest.webmanifest', 'sw.js', 'offline.html')) {
    $path = Join-Path $dist $required
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing required Web IM release artifact: $path"
    }
}

Write-Host "WEB_IM_RELEASE_DIR=$dist"
