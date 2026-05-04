[CmdletBinding()]
param(
    [string]$BuildWebDir = '',
    [switch]$DryRun,
    [switch]$KeepBundledChineseFont
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($BuildWebDir)) {
    $scriptRoot = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
        $scriptPath = $MyInvocation.MyCommand.Path
        if ([string]::IsNullOrWhiteSpace($scriptPath)) {
            throw 'Unable to resolve build web directory. Pass -BuildWebDir explicitly.'
        }
        $scriptRoot = Split-Path -Parent $scriptPath
    }
    $BuildWebDir = Join-Path $scriptRoot '..\..\build\web'
}

$BuildWebDir = (Resolve-Path -LiteralPath $BuildWebDir).Path
$canvasKitDir = Join-Path $BuildWebDir 'canvaskit'
$bootstrapPath = Join-Path $BuildWebDir 'flutter_bootstrap.js'

if (-not (Test-Path -LiteralPath $bootstrapPath -PathType Leaf)) {
    throw 'Required Flutter Web release artifact is missing: flutter_bootstrap.js'
}

$bootstrap = Get-Content -Raw -LiteralPath $bootstrapPath
$hasCanvasKitBuild = $bootstrap.Contains('"renderer":"canvaskit"')
$hasSkwasmBuild = $bootstrap.Contains('"renderer":"skwasm"') -or $bootstrap.Contains('"compileTarget":"dart2wasm"')

if (-not $hasCanvasKitBuild -and -not $hasSkwasmBuild) {
    throw 'This pruner only supports Flutter Web release builds using CanvasKit and/or Skwasm renderers.'
}

function Get-ReleaseRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return $Path.Substring($BuildWebDir.Length).TrimStart('\', '/')
}

function Remove-ReleaseFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return 0
    }

    $item = Get-Item -LiteralPath $Path
    $relative = Get-ReleaseRelativePath -Path $item.FullName
    if ($DryRun) {
        Write-Host "[dry-run] remove $relative ($Description)"
        return $item.Length
    }

    Remove-Item -LiteralPath $item.FullName -Force
    Write-Host "removed $relative ($Description)"
    return $item.Length
}

$requiredRelativeFiles = @(
    'flutter_bootstrap.js'
)

if ($hasCanvasKitBuild) {
    $requiredRelativeFiles += @(
        'main.dart.js',
        'canvaskit/canvaskit.js',
        'canvaskit/canvaskit.wasm',
        'canvaskit/chromium/canvaskit.js',
        'canvaskit/chromium/canvaskit.wasm'
    )
}

if ($hasSkwasmBuild) {
    $requiredRelativeFiles += @(
        'main.dart.wasm',
        'main.dart.mjs',
        'canvaskit/skwasm.js',
        'canvaskit/skwasm.wasm',
        'canvaskit/skwasm_heavy.js',
        'canvaskit/skwasm_heavy.wasm',
        'canvaskit/wimp.js',
        'canvaskit/wimp.wasm'
    )
}

$requiredRelativeFiles = @(
    $requiredRelativeFiles | Sort-Object -Unique
)

$unusedRendererPatterns = @(
    'skwasm*',
    'wimp*'
)

$patterns = @(
    '*.js.symbols'
)

if (-not $hasSkwasmBuild) {
    $patterns += $unusedRendererPatterns
}

foreach ($relativePath in $requiredRelativeFiles) {
    $path = Join-Path $BuildWebDir $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required Flutter Web release artifact is missing: $relativePath"
    }
}

if (-not (Test-Path -LiteralPath $canvasKitDir -PathType Container)) {
    throw "CanvasKit directory is missing: $canvasKitDir"
}

$requiredFullPaths = @{}
foreach ($relativePath in $requiredRelativeFiles) {
    $requiredFullPaths[(Join-Path $BuildWebDir $relativePath)] = $true
}

$candidatesByPath = @{}
foreach ($pattern in $patterns) {
    Get-ChildItem -LiteralPath $canvasKitDir -Recurse -File -Filter $pattern |
        ForEach-Object {
            if (-not $requiredFullPaths.ContainsKey($_.FullName)) {
                $candidatesByPath[$_.FullName] = $_
            }
        }
}

$candidates = @($candidatesByPath.Values | Sort-Object FullName)
$bytes = 0
foreach ($candidate in $candidates) {
    $bytes += $candidate.Length
}

$bundledChineseFontBytes = 0
$bundledChineseFontFamily = 'WKNotoSansSC'
$bundledChineseFontManifestAsset = 'assets/reference_ui/fonts/noto_sans_sc_vf.ttf'
$bundledChineseFontBuildPath = Join-Path $BuildWebDir 'assets\assets\reference_ui\fonts\noto_sans_sc_vf.ttf'
$fontManifestPath = Join-Path $BuildWebDir 'assets\FontManifest.json'

if (-not $KeepBundledChineseFont) {
    $mainJsPath = Join-Path $BuildWebDir 'main.dart.js'
    $entrypointText = ''
    if (Test-Path -LiteralPath $mainJsPath -PathType Leaf) {
        $entrypointText += Get-Content -Raw -LiteralPath $mainJsPath
    }
    $mainMjsPath = Join-Path $BuildWebDir 'main.dart.mjs'
    if (Test-Path -LiteralPath $mainMjsPath -PathType Leaf) {
        $entrypointText += Get-Content -Raw -LiteralPath $mainMjsPath
    }
    if ($entrypointText.Contains($bundledChineseFontFamily) -or $entrypointText.Contains($bundledChineseFontManifestAsset)) {
        throw "Web entrypoints still reference $bundledChineseFontFamily. Rebuild after switching Web typography to system Chinese fonts, or pass -KeepBundledChineseFont."
    }

    if (-not (Test-Path -LiteralPath $fontManifestPath -PathType Leaf)) {
        throw "FontManifest.json is missing: $fontManifestPath"
    }

    if (Test-Path -LiteralPath $bundledChineseFontBuildPath -PathType Leaf) {
        $bundledChineseFontBytes = (Get-Item -LiteralPath $bundledChineseFontBuildPath).Length
    }
}

$totalBytes = $bytes + $bundledChineseFontBytes
$mb = [Math]::Round($totalBytes / 1MB, 2)
Write-Host "Flutter Web prune target: $BuildWebDir"
Write-Host "Matched $($candidates.Count) unused CanvasKit artifacts; reclaimable size: $([Math]::Round($bytes / 1MB, 2)) MB"
if ($KeepBundledChineseFont) {
    Write-Host "Keeping bundled Chinese fallback font because -KeepBundledChineseFont was provided."
}
else {
    Write-Host "Bundled Chinese fallback font reclaimable size: $([Math]::Round($bundledChineseFontBytes / 1MB, 2)) MB"
}
Write-Host "Total reclaimable size: $mb MB"

foreach ($candidate in $candidates) {
    $relative = Get-ReleaseRelativePath -Path $candidate.FullName
    if ($DryRun) {
        Write-Host "[dry-run] remove $relative"
        continue
    }
    Remove-Item -LiteralPath $candidate.FullName -Force
    Write-Host "removed $relative"
}

if (-not $KeepBundledChineseFont) {
    $fontManifestJson = Get-Content -Raw -LiteralPath $fontManifestPath
    $fontManifestRaw = $fontManifestJson | ConvertFrom-Json
    $fontManifest = @(
        foreach ($entry in $fontManifestRaw) {
            $entry
        }
    )
    $filteredFontManifest = @(
        foreach ($entry in $fontManifest) {
            if ($entry.family -ne $bundledChineseFontFamily) {
                $entry
            }
        }
    )

    if ($filteredFontManifest.Count -lt $fontManifest.Count) {
        if ($DryRun) {
            Write-Host "[dry-run] remove $bundledChineseFontFamily from assets\FontManifest.json"
        }
        else {
            $json = ConvertTo-Json -InputObject @($filteredFontManifest) -Depth 8 -Compress
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($fontManifestPath, $json, $utf8NoBom)
            Write-Host "removed $bundledChineseFontFamily from assets\FontManifest.json"
        }
    }

    [void](Remove-ReleaseFile -Path $bundledChineseFontBuildPath -Description 'bundled Chinese fallback font')
}
