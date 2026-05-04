param(
    [string]$PluginMetadataPath = (Join-Path $PSScriptRoot "..\\.flutter-plugins-dependencies")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$mirrorUrls = @(
    "https://maven.aliyun.com/repository/google",
    "https://maven.aliyun.com/repository/central",
    "https://maven.aliyun.com/repository/gradle-plugin"
)

function Get-BraceDelta {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    return ([regex]::Matches($Line, "\{")).Count - ([regex]::Matches($Line, "\}")).Count
}

function Add-MirrorRepositories {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GradleFile
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in Get-Content -LiteralPath $GradleFile) {
        [void]$lines.Add($line)
    }

    $changed = $false
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -notmatch "^(\s*)repositories\s*\{") {
            continue
        }

        $blockIndent = $matches[1]
        $entryIndent = $blockIndent + "    "
        $depth = Get-BraceDelta -Line $lines[$index]
        $probeIndex = $index + 1
        $hasAliyunMirror = $false

        while ($probeIndex -lt $lines.Count -and $depth -gt 0) {
            if ($lines[$probeIndex] -match "maven\.aliyun\.com/repository/google") {
                $hasAliyunMirror = $true
            }

            $depth += Get-BraceDelta -Line $lines[$probeIndex]
            $probeIndex++
        }

        if ($hasAliyunMirror) {
            continue
        }

        $mirrorLines = [System.Collections.Generic.List[string]]::new()
        foreach ($url in $mirrorUrls) {
            [void]$mirrorLines.Add($entryIndent + "maven { url = uri(`"$url`") }")
        }

        $lines.InsertRange($index + 1, $mirrorLines)
        $changed = $true
        $index += $mirrorLines.Count
    }

    if ($changed) {
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllLines($GradleFile, $lines, $utf8NoBom)
    }

    return $changed
}

function Normalize-CompileSdk {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GradleFile
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in Get-Content -LiteralPath $GradleFile) {
        [void]$lines.Add($line)
    }

    $changed = $false
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match "^(\s*)(compileSdk|compileSdkVersion)(\s*=?\s*)35(\s*)$") {
            $indent = $matches[1]
            $keyword = $matches[2]
            $separator = $matches[3]
            $trailing = $matches[4]
            $lines[$index] = $indent + $keyword + $separator + "flutter.compileSdkVersion" + $trailing
            $changed = $true
        }
    }

    if ($changed) {
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllLines($GradleFile, $lines, $utf8NoBom)
    }

    return $changed
}

function Remove-LegacyFlutterRegistrar {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PluginRoot
    )

    $pluginFile = Join-Path $PluginRoot "android\\src\\main\\java\\com\\cloudwebrtc\\webrtc\\FlutterWebRTCPlugin.java"
    if (-not (Test-Path -LiteralPath $pluginFile)) {
        return $false
    }

    $content = Get-Content -Raw -LiteralPath $pluginFile
    if ($content -notmatch "PluginRegistry\.Registrar") {
        return $false
    }

    $updated = [regex]::Replace(
        $content,
        "(?m)^\s*import io\.flutter\.plugin\.common\.PluginRegistry\.Registrar;\r?\n",
        ""
    )
    $updated = [regex]::Replace(
        $updated,
        "(?ms)\s*/\*\*\s*\r?\n\s*\* Plugin registration\.\s*\r?\n\s*\*/\s*public static void registerWith\(Registrar registrar\)\s*\{.*?^\s*\}\r?\n\r?\n\s*@Override",
        "`r`n    @Override"
    )

    if ($updated -eq $content) {
        return $false
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($pluginFile, $updated, $utf8NoBom)
    return $true
}

function Patch-FilePickerLegacyRegistrar {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PluginRoot
    )

    $pluginFile = Join-Path $PluginRoot "android\\src\\main\\java\\com\\mr\\flutter\\plugin\\filepicker\\FilePickerPlugin.java"
    if (-not (Test-Path -LiteralPath $pluginFile)) {
        return $false
    }

    $content = Get-Content -Raw -LiteralPath $pluginFile
    if ($content -notmatch "PluginRegistry\.Registrar") {
        return $false
    }

    $updated = $content -replace "`r`n", "`n"
    $updated = [regex]::Replace(
        $updated,
        "(?m)^\s*import io\.flutter\.plugin\.common\.PluginRegistry;\n",
        ""
    )
    $updated = [regex]::Replace(
        $updated,
        "(?ms)\n\s*/\*\*\s*\n\s*\* Plugin registration\.\s*\n\s*\*/\s*public static void registerWith\(final io\.flutter\.plugin\.common\.PluginRegistry\.Registrar registrar\)\s*\{.*?^\s*\}\n\n\s*@SuppressWarnings\(""unchecked""\)",
        "`n    @SuppressWarnings(""unchecked"")"
    )
    $updated = $updated.Replace(
        "            final Activity activity,`n            final PluginRegistry.Registrar registrar,`n            final ActivityPluginBinding activityBinding) {",
        "            final Activity activity,`n            final ActivityPluginBinding activityBinding) {"
    )
    $updated = $updated.Replace(
        "        if (registrar != null) {`n            // V1 embedding setup for activity listeners.`n            application.registerActivityLifecycleCallbacks(this.observer);`n            registrar.addActivityResultListener(this.delegate);`n            registrar.addRequestPermissionsResultListener(this.delegate);`n        } else {`n            // V2 embedding setup for activity listeners.`n            activityBinding.addActivityResultListener(this.delegate);`n            activityBinding.addRequestPermissionsResultListener(this.delegate);`n            this.lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(activityBinding);`n            this.lifecycle.addObserver(this.observer);`n        }",
        "        application.registerActivityLifecycleCallbacks(this.observer);`n        activityBinding.addActivityResultListener(this.delegate);`n        activityBinding.addRequestPermissionsResultListener(this.delegate);`n        this.lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(activityBinding);`n        this.lifecycle.addObserver(this.observer);"
    )
    $updated = $updated.Replace(
        "                this.activityBinding.getActivity(),`n                null,`n                this.activityBinding);",
        "                this.activityBinding.getActivity(),`n                this.activityBinding);"
    )
    $updated = $updated.Replace(
        "    private static int compressionQuality;`n    @SuppressWarnings(""unchecked"")",
        "    private static int compressionQuality;`n`n    @SuppressWarnings(""unchecked"")"
    )
    $updated = $updated -replace "`n", "`r`n"

    if ($updated -eq $content) {
        return $false
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($pluginFile, $updated, $utf8NoBom)
    return $true
}

if (-not (Test-Path -LiteralPath $PluginMetadataPath)) {
    throw "Plugin metadata file not found: $PluginMetadataPath"
}

$pluginMetadata = Get-Content -Raw -LiteralPath $PluginMetadataPath | ConvertFrom-Json
$androidPlugins = @($pluginMetadata.plugins.android)

$gradleFiles = $androidPlugins |
    Where-Object { $_.native_build } |
    ForEach-Object {
        $pluginRoot = $_.path
        $candidates = @(
            (Join-Path $pluginRoot "android\\build.gradle"),
            (Join-Path $pluginRoot "android\\build.gradle.kts")
        )

        foreach ($candidate in $candidates) {
            if (Test-Path -LiteralPath $candidate) {
                $candidate
            }
        }
    } |
    Sort-Object -Unique

if ($gradleFiles.Count -eq 0) {
    throw "No Android plugin Gradle files were found from $PluginMetadataPath"
}

$patchedFiles = [System.Collections.Generic.List[string]]::new()
$normalizedCompileSdkFiles = [System.Collections.Generic.List[string]]::new()
$legacyEmbeddingPatchedFiles = [System.Collections.Generic.List[string]]::new()
$filePickerPatchedFiles = [System.Collections.Generic.List[string]]::new()
foreach ($gradleFile in $gradleFiles) {
    if (Add-MirrorRepositories -GradleFile $gradleFile) {
        [void]$patchedFiles.Add($gradleFile)
    }

    if (Normalize-CompileSdk -GradleFile $gradleFile) {
        [void]$normalizedCompileSdkFiles.Add($gradleFile)
    }
}

foreach ($pluginRoot in ($androidPlugins | Select-Object -ExpandProperty path -Unique)) {
    if (Remove-LegacyFlutterRegistrar -PluginRoot $pluginRoot) {
        [void]$legacyEmbeddingPatchedFiles.Add((Join-Path $pluginRoot "android\\src\\main\\java\\com\\cloudwebrtc\\webrtc\\FlutterWebRTCPlugin.java"))
    }

    if (Patch-FilePickerLegacyRegistrar -PluginRoot $pluginRoot) {
        [void]$filePickerPatchedFiles.Add((Join-Path $pluginRoot "android\\src\\main\\java\\com\\mr\\flutter\\plugin\\filepicker\\FilePickerPlugin.java"))
    }
}

Write-Host ("Scanned {0} Android plugin Gradle files." -f $gradleFiles.Count)
if ($patchedFiles.Count -eq 0 -and $normalizedCompileSdkFiles.Count -eq 0 -and $legacyEmbeddingPatchedFiles.Count -eq 0 -and $filePickerPatchedFiles.Count -eq 0) {
    Write-Host "No plugin Gradle files needed mirror, compileSdk, or legacy embedding updates."
    exit 0
}

if ($patchedFiles.Count -gt 0) {
    Write-Host ("Patched mirrors in {0} plugin Gradle files:" -f $patchedFiles.Count)
    foreach ($patchedFile in $patchedFiles) {
        Write-Host (" - {0}" -f $patchedFile)
    }
}

if ($normalizedCompileSdkFiles.Count -gt 0) {
    Write-Host ("Normalized compileSdk in {0} plugin Gradle files:" -f $normalizedCompileSdkFiles.Count)
    foreach ($normalizedFile in $normalizedCompileSdkFiles) {
        Write-Host (" - {0}" -f $normalizedFile)
    }
}

if ($legacyEmbeddingPatchedFiles.Count -gt 0) {
    Write-Host ("Removed legacy Registrar entrypoints in {0} plugin files:" -f $legacyEmbeddingPatchedFiles.Count)
    foreach ($legacyFile in $legacyEmbeddingPatchedFiles) {
        Write-Host (" - {0}" -f $legacyFile)
    }
}

if ($filePickerPatchedFiles.Count -gt 0) {
    Write-Host ("Patched file_picker legacy embedding in {0} plugin files:" -f $filePickerPatchedFiles.Count)
    foreach ($filePickerFile in $filePickerPatchedFiles) {
        Write-Host (" - {0}" -f $filePickerFile)
    }
}
