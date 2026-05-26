[CmdletBinding()]
param(
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$LocalBackendRoot = '',
  [string]$RemoteSourceRoot = '/opt/wukongim-prod/src',
  [string]$RemoteProductionRoot = '/opt/wukongim-prod/src/deploy/production',
  [string]$PatchPath = '',
  [string]$SshKeyPath = '',
  [switch]$Run,
  [switch]$AllowProductionSync,
  [switch]$BuildImage,
  [switch]$AllowProductionBuild,
  [switch]$RunTests,
  [switch]$ApplyLocalPatch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ReleaseFiles = @(
  'modules/user/api.go',
  'modules/user/api_im_route_test.go',
  'modules/message/api_conversation.go',
  'modules/message/api_conversation_syncack_test.go',
  'modules/file/service_minio.go',
  'modules/file/service_minio_test.go',
  'serverlib/pkg/metrics/metrics.go',
  'serverlib/pkg/metrics/metrics_test.go'
)

function Quote-Bash {
  param([AllowEmptyString()][Parameter(Mandatory = $true)][string]$Value)

  $single = [string][char]39
  $double = [string][char]34
  $replacement = $single + $double + $single + $double + $single
  return $single + $Value.Replace($single, $replacement) + $single
}

function Quote-ProcessArgument {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value -match '[\s"]') {
    return '"' + ($Value.Replace('\', '\\').Replace('"', '\"')) + '"'
  }
  return $Value
}

function Validate-RemoteHostToken {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value -notmatch '^[A-Za-z0-9_.@:%+-]+$' -or $Value.StartsWith('-')) {
    throw "RemoteHost must be a single safe ssh host token: $Value"
  }
}

function Validate-RemoteAbsolutePath {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Value
  )

  if ($Value -notmatch '^/[A-Za-z0-9._/+-]+$' -or $Value -eq '/' -or $Value -match '(^|/)\.\.(/|$)') {
    throw "$Name must be a safe absolute remote path: $Value"
  }
}

function Assert-SafeRelativePath {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value.StartsWith('/') -or $Value.Contains('..') -or $Value.Contains('\') -or [string]::IsNullOrWhiteSpace($Value)) {
    throw "Unsafe release file path: $Value"
  }
}

function Resolve-RepoRoot {
  return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
}

function Resolve-BackendRoot {
  if (-not [string]::IsNullOrWhiteSpace($LocalBackendRoot)) {
    return (Resolve-Path -LiteralPath $LocalBackendRoot).Path
  }
  $repoRoot = Resolve-RepoRoot
  return (Resolve-Path -LiteralPath (Join-Path $repoRoot '.codex-backend-work\src')).Path
}

function Resolve-PatchFile {
  if (-not [string]::IsNullOrWhiteSpace($PatchPath)) {
    return (Resolve-Path -LiteralPath $PatchPath).Path
  }
  $repoRoot = Resolve-RepoRoot
  return (Resolve-Path -LiteralPath (Join-Path $repoRoot 'deploy\production\backend-optimization\patches\0001-phase3-backend-low-risk-optimization.patch')).Path
}

function Get-SshOptions {
  $options = @('-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new')
  if (-not [string]::IsNullOrWhiteSpace($SshKeyPath)) {
    $resolvedKey = (Resolve-Path -LiteralPath $SshKeyPath).Path
    $options += @('-i', $resolvedKey)
  }
  return $options
}

function Invoke-RemoteBash {
  param([Parameter(Mandatory = $true)][string]$Script)

  Validate-RemoteHostToken -Value $RemoteHost
  $normalizedScript = (($Script -replace "`r`n", "`n") -replace "`r", "`n").TrimEnd() + "`n"
  $sshArgs = @((Get-SshOptions) + @('--', $RemoteHost, 'bash', '-s'))

  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = 'ssh'
  $startInfo.Arguments = (($sshArgs | ForEach-Object { Quote-ProcessArgument -Value $_ }) -join ' ')
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardInput = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  [void]$process.Start()
  $process.StandardInput.Write($normalizedScript)
  $process.StandardInput.Close()
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()

  if (-not [string]::IsNullOrWhiteSpace($stdout)) {
    $stdout.TrimEnd() -split "`r?`n" | ForEach-Object { $_ }
  }
  if (-not [string]::IsNullOrWhiteSpace($stderr)) {
    $stderr.TrimEnd() -split "`r?`n" | ForEach-Object { $_ }
  }
  if ($process.ExitCode -ne 0) {
    throw "Remote Phase 3 backend optimization prepare command failed with exit code $($process.ExitCode)."
  }
}

function Copy-ToRemote {
  param(
    [Parameter(Mandatory = $true)][string]$LocalPath,
    [Parameter(Mandatory = $true)][string]$RemotePath
  )

  Validate-RemoteHostToken -Value $RemoteHost
  $scpArgs = @((Get-SshOptions) + @('--', $LocalPath, "$RemoteHost`:$RemotePath"))
  & scp @scpArgs
  if ($LASTEXITCODE -ne 0) {
    throw "scp failed while copying '$LocalPath' to '$RemotePath'."
  }
}

function New-Manifest {
  param([Parameter(Mandatory = $true)][string]$BackendRoot)

  $rows = New-Object System.Collections.Generic.List[string]
  foreach ($relative in $ReleaseFiles) {
    Assert-SafeRelativePath -Value $relative
    $localPath = Join-Path $BackendRoot ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $localPath -PathType Leaf)) {
      throw "Missing local release file: $localPath"
    }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $localPath).Hash.ToLowerInvariant()
    $rows.Add("$hash  $relative")
  }
  return $rows
}

function Invoke-GitApplyPatch {
  param([Parameter(Mandatory = $true)][string]$BackendRoot)

  $patchFile = Resolve-PatchFile
  Write-Host "Applying local patch: $patchFile"
  Push-Location -LiteralPath $BackendRoot
  try {
    & git apply --check --whitespace=nowarn $patchFile
    if ($LASTEXITCODE -eq 0) {
      & git apply --whitespace=nowarn $patchFile
      if ($LASTEXITCODE -ne 0) {
        throw "git apply failed for $patchFile"
      }
      Write-Host 'phase3_backend_optimization_local_patch=applied'
      return
    }

    & git apply --reverse --check --whitespace=nowarn $patchFile
    if ($LASTEXITCODE -eq 0) {
      throw 'Phase 3 backend optimization patch appears to be already applied to LocalBackendRoot.'
    }
    throw 'Phase 3 backend optimization patch cannot be applied cleanly to LocalBackendRoot.'
  } finally {
    Pop-Location
  }
}

function Invoke-LocalTests {
  param([Parameter(Mandatory = $true)][string]$BackendRoot)

  Push-Location -LiteralPath (Join-Path $backendRoot 'serverlib')
  try {
    Write-Host 'Running: go test -count=1 ./pkg/metrics -run TestStorageOperationMetricsDoNotLeakObjectPaths'
    & go test -count=1 ./pkg/metrics -run TestStorageOperationMetricsDoNotLeakObjectPaths
    if ($LASTEXITCODE -ne 0) {
      throw 'serverlib metrics tests failed.'
    }
  } finally {
    Pop-Location
  }

  Push-Location -LiteralPath $BackendRoot
  try {
    Write-Host 'Running backend module tests: go test -count=1 ./modules/user ./modules/message ./modules/file'
    & go test -count=1 ./modules/user ./modules/message ./modules/file
    if ($LASTEXITCODE -ne 0) {
      throw 'backend module compile tests failed.'
    }
  } finally {
    Pop-Location
  }
}

Validate-RemoteHostToken -Value $RemoteHost
Validate-RemoteAbsolutePath -Name 'RemoteSourceRoot' -Value $RemoteSourceRoot
Validate-RemoteAbsolutePath -Name 'RemoteProductionRoot' -Value $RemoteProductionRoot

$backendRoot = Resolve-BackendRoot

if ($ApplyLocalPatch) {
  Invoke-GitApplyPatch -BackendRoot $backendRoot
}

if ($RunTests) {
  Invoke-LocalTests -BackendRoot $backendRoot
}

$manifestRows = New-Manifest -BackendRoot $backendRoot
$remoteSourceArg = Quote-Bash -Value $RemoteSourceRoot
$remoteProductionArg = Quote-Bash -Value $RemoteProductionRoot
$manifestText = ($manifestRows -join "`n")
$manifestArg = Quote-Bash -Value $manifestText

if (-not $Run) {
  Write-Host 'Dry run only. Add -Run -AllowProductionSync to sync Phase 3 backend optimization source files.'
  Write-Host 'Add -BuildImage -AllowProductionBuild to build the tsdd-api image after sync without restarting services.'
  Write-Host "RemoteHost: $RemoteHost"
  Write-Host "LocalBackendRoot: $backendRoot"
  Write-Host "RemoteSourceRoot: $RemoteSourceRoot"
  Write-Host "RemoteProductionRoot: $RemoteProductionRoot"
  Write-Host 'phase3_backend_optimization_sync_backup_dir=<created only when -Run -AllowProductionSync is used>'
  Write-Host ''
  Write-Host 'Files to sync:'
  $ReleaseFiles | ForEach-Object { Write-Host "  $_" }
  Write-Host ''
  Write-Host 'Manifest:'
  $manifestRows | ForEach-Object { Write-Host $_ }
  exit 0
}

if (-not $AllowProductionSync) {
  throw 'Refusing to sync production backend source without -AllowProductionSync.'
}
if ($BuildImage -and -not $AllowProductionBuild) {
  throw 'Refusing to build production backend image without -AllowProductionBuild.'
}

$remoteTempDir = "/tmp/phase3-backend-optimization-sync-$([guid]::NewGuid().ToString('N'))"
$remoteTempArg = Quote-Bash -Value $remoteTempDir
$initScript = @"
set -euo pipefail
remote_tmp=$remoteTempArg
rm -rf "`$remote_tmp"
mkdir -p "`$remote_tmp"
"@
Invoke-RemoteBash -Script $initScript

try {
  foreach ($relative in $ReleaseFiles) {
    $localPath = Join-Path $backendRoot ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    $remotePath = "$remoteTempDir/$relative"
    $remoteDir = Split-Path -Path $remotePath -Parent
    Invoke-RemoteBash -Script ("set -euo pipefail`nmkdir -p " + (Quote-Bash -Value ($remoteDir -replace '\\', '/')))
    Copy-ToRemote -LocalPath $localPath -RemotePath $remotePath
  }

  $manifestFile = Join-Path ([System.IO.Path]::GetTempPath()) "phase3-backend-optimization-manifest-$([guid]::NewGuid().ToString('N')).txt"
  try {
    $manifestContent = (($manifestRows -join "`n") + "`n")
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($manifestFile, $manifestContent, $utf8NoBom)
    Copy-ToRemote -LocalPath $manifestFile -RemotePath "$remoteTempDir/.manifest"
  } finally {
    if (Test-Path -LiteralPath $manifestFile) {
      Remove-Item -LiteralPath $manifestFile -Force
    }
  }

  $buildFlag = if ($BuildImage) { '1' } else { '0' }
  $applyScript = @"
set -euo pipefail
remote_source=$remoteSourceArg
remote_production=$remoteProductionArg
remote_tmp=$remoteTempArg
manifest_text=$manifestArg
build_image='$buildFlag'

case "`$remote_source" in
  /*) ;;
  *) echo "unsafe remote source path: `$remote_source" >&2; exit 1 ;;
esac
case "`$remote_production" in
  /*) ;;
  *) echo "unsafe remote production path: `$remote_production" >&2; exit 1 ;;
esac
case "`$remote_source" in
  /|*'/../'*|*/..|../*) echo "unsafe remote source path: `$remote_source" >&2; exit 1 ;;
esac
case "`$remote_production" in
  /|*'/../'*|*/..|../*) echo "unsafe remote production path: `$remote_production" >&2; exit 1 ;;
esac

cd "`$remote_source"
test -f main.go
test -d modules/message
test -d modules/file
test -d serverlib
test -f "`$remote_tmp/.manifest"
tr -d '\r' < "`$remote_tmp/.manifest" > "`$remote_tmp/.manifest.lf"
mv "`$remote_tmp/.manifest.lf" "`$remote_tmp/.manifest"
if ! diff -u <(printf '%s\n' "`$manifest_text") "`$remote_tmp/.manifest"; then
  echo 'phase3_backend_optimization_sync=manifest_mismatch' >&2
  exit 1
fi

timestamp="`$(date +%Y%m%dT%H%M%S%z)"
backup_dir="`$remote_production/backups/phase3-backend-optimization-source-sync/`$timestamp"
mkdir -p "`$backup_dir"

while IFS= read -r row; do
  [ -n "`$row" ] || continue
  expected_hash="`$(printf '%s\n' "`$row" | awk '{print `$1}')"
  relative_path="`$(printf '%s\n' "`$row" | cut -d' ' -f3-)"
  case "`$relative_path" in
    /*|*..*|*'\'*|'')
      echo "unsafe release file path: `$relative_path" >&2
      exit 1
      ;;
  esac
  staged_path="`$remote_tmp/`$relative_path"
  test -f "`$staged_path"
  staged_hash="`$(sha256sum "`$staged_path" | awk '{print `$1}')"
  if [ "`$staged_hash" != "`$expected_hash" ]; then
    echo "staged hash mismatch for `$relative_path" >&2
    exit 1
  fi
  if [ -f "`$relative_path" ]; then
    mkdir -p "`$backup_dir/`$(dirname "`$relative_path")"
    cp -p "`$relative_path" "`$backup_dir/`$relative_path"
  fi
  mkdir -p "`$(dirname "`$relative_path")"
  install -m 0644 "`$staged_path" "`$relative_path"
  installed_hash="`$(sha256sum "`$relative_path" | awk '{print `$1}')"
  if [ "`$installed_hash" != "`$expected_hash" ]; then
    echo "installed hash mismatch for `$relative_path" >&2
    exit 1
  fi
done < "`$remote_tmp/.manifest"

echo 'phase3_backend_optimization_sync=applied'
echo "phase3_backend_optimization_sync_backup_dir=`$backup_dir"

if [ "`$build_image" = '1' ]; then
  cd "`$remote_production"
  docker compose --env-file .env build tsdd-api
  echo 'phase3_backend_optimization_build=completed'
  docker compose --env-file .env ps tsdd-api
else
  echo 'phase3_backend_optimization_build=skipped'
fi
"@
  Invoke-RemoteBash -Script $applyScript
}
finally {
  Invoke-RemoteBash -Script ("set -euo pipefail`nrm -rf " + $remoteTempArg) | Out-Null
}
