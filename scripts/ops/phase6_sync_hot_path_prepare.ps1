[CmdletBinding()]
param(
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$LocalBackendRoot = '',
  [string]$RemoteSourceRoot = '/opt/wukongim-prod/src',
  [string]$RemoteProductionRoot = '/opt/wukongim-prod/src/deploy/production',
  [string]$RemoteBackupRoot = '/opt/wukongim-prod/backups/phase6-sync-hot-path-source-sync',
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
  'modules/message/api.go',
  'modules/message/api_conversation.go',
  'modules/message/db_conversation_extra.go',
  'modules/message/phase6_message_sync_test.go',
  'modules/message/phase6_conversation_extra_test.go',
  'modules/message/phase6_conversation_sync_test.go'
)

$ExpectedManifestRows = @(
  'd0a5f3bd0a100ce91b46c3c0b7cf9b0a903550721068d59b83e9439061bfbb40  modules/message/api.go',
  '72051603ee604716fdf85bc72ad09f099d4388014ff8250a850c91bd0a093c9d  modules/message/api_conversation.go',
  'e486e958798a5595f8b54e6bed8030e738c424fea084ec3b637fffd17aaf4cec  modules/message/db_conversation_extra.go',
  '90072a98eb13b35897ee2c6a6135fbd06f42cc2e9316e128699fec506dc3c957  modules/message/phase6_message_sync_test.go',
  '9da21ae6e3477c7695274120b69a7142c4219120a6e8ef049d7a6fdbf5c1e8bd  modules/message/phase6_conversation_extra_test.go',
  '5c41e9eaf45fe632fef150bcbf7d278c5349a79e75718388c5b8495132ad5f8a  modules/message/phase6_conversation_sync_test.go'
)
$DefaultPatchPath = 'deploy/production/backend-optimization/patches/0004-phase6-sync-hot-path-optimization.patch'

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

function Quote-CmdArgument {
  param([Parameter(Mandatory = $true)][string]$Value)

  $escaped = $Value.
    Replace('^', '^^').
    Replace('&', '^&').
    Replace('<', '^<').
    Replace('>', '^>').
    Replace('|', '^|').
    Replace('"', '\"')
  return '"' + $escaped + '"'
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
  $platformPatchPath = $DefaultPatchPath -replace '/', [System.IO.Path]::DirectorySeparatorChar
  return (Resolve-Path -LiteralPath (Join-Path $repoRoot $platformPatchPath)).Path
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
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  $remoteScriptFile = Join-Path ([System.IO.Path]::GetTempPath()) "phase6-sync-hot-path-remote-bash-$([guid]::NewGuid().ToString('N')).sh"
  $cmdFile = Join-Path ([System.IO.Path]::GetTempPath()) "phase6-sync-hot-path-remote-bash-$([guid]::NewGuid().ToString('N')).cmd"

  try {
    [System.IO.File]::WriteAllText($remoteScriptFile, $normalizedScript, $utf8NoBom)
    $sshCommand = (Quote-CmdArgument -Value 'ssh') + ' ' + (($sshArgs | ForEach-Object { Quote-CmdArgument -Value $_ }) -join ' ') + ' < ' + (Quote-CmdArgument -Value $remoteScriptFile)
    [System.IO.File]::WriteAllText($cmdFile, "@echo off`r`n$sshCommand`r`nexit /b %ERRORLEVEL%`r`n", [System.Text.Encoding]::ASCII)

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = if ($env:ComSpec) { $env:ComSpec } else { 'cmd.exe' }
    $startInfo.Arguments = '/d /c ' + (Quote-CmdArgument -Value $cmdFile) + ' 2>&1'
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $false

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()
  } finally {
    if (Test-Path -LiteralPath $remoteScriptFile) {
      Remove-Item -LiteralPath $remoteScriptFile -Force
    }
    if (Test-Path -LiteralPath $cmdFile) {
      Remove-Item -LiteralPath $cmdFile -Force
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($stdout)) {
    $stdout.TrimEnd() -split "`r?`n" | ForEach-Object { $_ }
  }
  if ($process.ExitCode -ne 0) {
    throw "Remote Phase 6 sync hot path prepare command failed with exit code $($process.ExitCode)."
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

function Assert-ReviewedManifest {
  param([Parameter(Mandatory = $true)]$ManifestRows)

  $actual = @($ManifestRows)
  $expected = @($ExpectedManifestRows)
  if ($actual.Count -ne $expected.Count) {
    throw 'LocalBackendRoot files do not match reviewed Phase 6 manifest.'
  }
  for ($i = 0; $i -lt $expected.Count; $i++) {
    if ($actual[$i] -ne $expected[$i]) {
      throw 'LocalBackendRoot files do not match reviewed Phase 6 manifest.'
    }
  }
}

function Assert-RemoteProductionRootMatchesSourceRoot {
  $expectedProductionRoot = $RemoteSourceRoot.TrimEnd('/') + '/deploy/production'
  if ($RemoteProductionRoot.TrimEnd('/') -ne $expectedProductionRoot) {
    throw "RemoteProductionRoot must equal RemoteSourceRoot/deploy/production: expected $expectedProductionRoot"
  }
}

function Assert-RemoteBackupRootOutsideSourceRoot {
  $sourcePrefix = $RemoteSourceRoot.TrimEnd('/') + '/'
  $backupRoot = $RemoteBackupRoot.TrimEnd('/')
  if ($backupRoot -eq $RemoteSourceRoot.TrimEnd('/') -or $backupRoot.StartsWith($sourcePrefix)) {
    throw 'RemoteBackupRoot must be outside RemoteSourceRoot so backups cannot enter the Docker build context.'
  }
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
      Write-Host 'phase6_sync_hot_path_local_patch=applied'
      return
    }

    & git apply --reverse --check --whitespace=nowarn $patchFile
    if ($LASTEXITCODE -eq 0) {
      throw 'Phase 6 sync hot path patch appears to be already applied to LocalBackendRoot.'
    }
    throw 'Phase 6 sync hot path patch cannot be applied cleanly to LocalBackendRoot.'
  } finally {
    Pop-Location
  }
}

function Invoke-LocalTests {
  param([Parameter(Mandatory = $true)][string]$BackendRoot)

  Push-Location -LiteralPath $BackendRoot
  try {
    Write-Host "Running: go test -count=1 ./modules/message -run 'TestPhase4|TestPhase5|TestPhase6|TestSyncSensitiveWords|TestProhibit|TestBuildUserLastOffsets|TestClearSyncConversationCache'"
    & go test -count=1 ./modules/message -run 'TestPhase4|TestPhase5|TestPhase6|TestSyncSensitiveWords|TestProhibit|TestBuildUserLastOffsets|TestClearSyncConversationCache'
    if ($LASTEXITCODE -ne 0) {
      throw 'backend message focused tests failed.'
    }
  } finally {
    Pop-Location
  }
}

function Invoke-SqlMigrationLint {
  $repoRoot = Resolve-RepoRoot
  $lintScript = Join-Path $repoRoot 'scripts\ops\phase6_sql_migration_lint.ps1'
  if (-not (Test-Path -LiteralPath $lintScript -PathType Leaf)) {
    throw "Missing Phase 6 SQL migration lint gate: $lintScript"
  }

  Write-Host "Running: scripts/ops/phase6_sql_migration_lint.ps1 -BackendRoot $backendRoot"
  & powershell -NoProfile -ExecutionPolicy Bypass -File $lintScript -BackendRoot $backendRoot
  if ($LASTEXITCODE -ne 0) {
    throw 'Phase 6 SQL migration lint gate failed.'
  }
}

Validate-RemoteHostToken -Value $RemoteHost
Validate-RemoteAbsolutePath -Name 'RemoteSourceRoot' -Value $RemoteSourceRoot
Validate-RemoteAbsolutePath -Name 'RemoteProductionRoot' -Value $RemoteProductionRoot
Validate-RemoteAbsolutePath -Name 'RemoteBackupRoot' -Value $RemoteBackupRoot
Assert-RemoteProductionRootMatchesSourceRoot
Assert-RemoteBackupRootOutsideSourceRoot

$backendRoot = Resolve-BackendRoot
Invoke-SqlMigrationLint

if ($ApplyLocalPatch) {
  Invoke-GitApplyPatch -BackendRoot $backendRoot
}

if ($RunTests) {
  Invoke-LocalTests -BackendRoot $backendRoot
}

$manifestRows = New-Manifest -BackendRoot $backendRoot
Assert-ReviewedManifest -ManifestRows $manifestRows
$remoteSourceArg = Quote-Bash -Value $RemoteSourceRoot
$remoteProductionArg = Quote-Bash -Value $RemoteProductionRoot
$remoteBackupArg = Quote-Bash -Value $RemoteBackupRoot
$manifestText = ($manifestRows -join "`n")
$manifestArg = Quote-Bash -Value $manifestText

if (-not $Run) {
  Write-Host 'Dry run only. Use -Run -AllowProductionSync -BuildImage -AllowProductionBuild for one-shot sync+build.'
  Write-Host 'Build-only mode is intentionally unsupported; build context integrity is verified during sync+build.'
  Write-Host 'Before production switch, capture baseline with scripts/ops/phase6_prometheus_gate_report.ps1 -Run.'
  Write-Host 'After production switch, run scripts/ops/phase6_prometheus_gate_report.ps1 -Run for immediate and 30-minute gates.'
  Write-Host "RemoteHost: $RemoteHost"
  Write-Host "LocalBackendRoot: $backendRoot"
  Write-Host "RemoteSourceRoot: $RemoteSourceRoot"
  Write-Host "RemoteProductionRoot: $RemoteProductionRoot"
  Write-Host "RemoteBackupRoot: $RemoteBackupRoot"
  Write-Host 'phase6_sync_hot_path_sync_backup_dir=<created only when -Run -AllowProductionSync is used>'
  Write-Host 'Reviewed manifest: verified'
  Write-Host 'phase6_sync_hot_path_reviewed_manifest=verified'
  Write-Host ''
  Write-Host 'Files to sync:'
  $ReleaseFiles | ForEach-Object { Write-Host "  $_" }
  Write-Host ''
  Write-Host 'Manifest:'
  $manifestRows | ForEach-Object { Write-Host $_ }
  exit 0
}

if ($BuildImage -and -not $AllowProductionBuild) {
  throw 'Refusing to build production backend image without -AllowProductionBuild.'
}
if (-not $AllowProductionSync) {
  throw 'Refusing to sync production backend source without -AllowProductionSync.'
}
if (-not $BuildImage) {
  throw 'Refusing to run production Phase 6 prepare without -BuildImage.'
}

$remoteTempDir = "/tmp/phase6-sync-hot-path-sync-$([guid]::NewGuid().ToString('N'))"
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

  $manifestFile = Join-Path ([System.IO.Path]::GetTempPath()) "phase6-sync-hot-path-manifest-$([guid]::NewGuid().ToString('N')).txt"
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
remote_backup_root=$remoteBackupArg
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
case "`$remote_backup_root" in
  /*) ;;
  *) echo "unsafe remote backup path: `$remote_backup_root" >&2; exit 1 ;;
esac
case "`$remote_source" in
  /|*'/../'*|*/..|../*) echo "unsafe remote source path: `$remote_source" >&2; exit 1 ;;
esac
case "`$remote_production" in
  /|*'/../'*|*/..|../*) echo "unsafe remote production path: `$remote_production" >&2; exit 1 ;;
esac
case "`$remote_backup_root" in
  /|*'/../'*|*/..|../*) echo "unsafe remote backup path: `$remote_backup_root" >&2; exit 1 ;;
esac
case "`$remote_backup_root" in
  "`$remote_source"|"`$remote_source"/*)
    echo "remote backup root must be outside source tree: `$remote_backup_root" >&2
    exit 1
    ;;
esac
canonical_source="`$(realpath -m "`$remote_source")"
canonical_backup_root="`$(realpath -m "`$remote_backup_root")"
case "`$canonical_backup_root" in
  "`$canonical_source"|"`$canonical_source"/*)
    echo "remote backup root must be outside canonical source tree: `$canonical_backup_root" >&2
    exit 1
    ;;
esac

function should_include_build_context_path() {
  case "`$1" in
    .git|.git/*|*/.git|*/.git/*|\
    .env|.env.*|*/.env|*/.env.*|\
    *.pem|*.key|*.db|*.sqlite|*.sqlite3|*.log|*.gz|*.zip|*.tar|*.tgz|*.p12|*.pfx|*.jks|\
    *.pyc|*/__pycache__/*|__pycache__/*|\
    .dart_tool|.dart_tool/*|*/.dart_tool/*|\
    build|build/*|*/build/*|dist|dist/*|*/dist/*|node_modules|node_modules/*|*/node_modules/*)
      return 1
      ;;
  esac
  return 0
}

copy_build_context_file_list() {
  find go.mod go.sum main.go assets configs internal modules pkg serverlib -type f -print | while IFS= read -r path; do
    if should_include_build_context_path "`$path"; then
      printf '%s\n' "`$path"
    fi
  done
}

hash_build_context_file_list() {
  while IFS= read -r path; do
    [ -n "`$path" ] || continue
    if [ ! -r "`$path" ]; then
      echo "unreadable build context path: `$path" >&2
      exit 1
    fi
    sha256sum "`$path"
  done
}

cd "`$remote_source"
test -f main.go
test -d modules/message
test -d serverlib
build_context_before="`$remote_tmp/.build-context.before"
build_context_after="`$remote_tmp/.build-context.after"
release_paths_file="`$remote_tmp/.release_paths"
printf '%s\n' "`$manifest_text" | awk '{print `$2}' > "`$release_paths_file"
copy_build_context_file_list | hash_build_context_file_list | sort > "`$build_context_before"
test -f "`$remote_tmp/.manifest"
tr -d '\r' < "`$remote_tmp/.manifest" > "`$remote_tmp/.manifest.lf"
mv "`$remote_tmp/.manifest.lf" "`$remote_tmp/.manifest"
if ! diff -u <(printf '%s\n' "`$manifest_text") "`$remote_tmp/.manifest"; then
  echo 'phase6_sync_hot_path_sync=manifest_mismatch' >&2
  exit 1
fi

timestamp="`$(date +%Y%m%dT%H%M%S%z)"
backup_dir="`$remote_backup_root/`$timestamp"
sudo mkdir -p "`$backup_dir"
sudo chown "`$(id -u):`$(id -g)" "`$backup_dir"
absent_manifest="`$backup_dir/.phase6_sync_hot_path_absent_files"
: > "`$absent_manifest"

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
  else
    printf '%s\n' "`$relative_path" >> "`$absent_manifest"
  fi
  mkdir -p "`$(dirname "`$relative_path")"
  install -m 0644 "`$staged_path" "`$relative_path"
  installed_hash="`$(sha256sum "`$relative_path" | awk '{print `$1}')"
  if [ "`$installed_hash" != "`$expected_hash" ]; then
    echo "installed hash mismatch for `$relative_path" >&2
    exit 1
  fi
done < "`$remote_tmp/.manifest"

copy_build_context_file_list | hash_build_context_file_list | sort > "`$build_context_after"
awk '{hash=`$1; `$1=""; sub(/^  */, "", `$0); print `$0 "\t" hash}' "`$build_context_before" | sort > "`$remote_tmp/.build-context.before.tsv"
awk '{hash=`$1; `$1=""; sub(/^  */, "", `$0); print `$0 "\t" hash}' "`$build_context_after" | sort > "`$remote_tmp/.build-context.after.tsv"
if ! awk -F '\t' 'NR==FNR {allowed[`$1]=1; next} {
  path=`$1
  sub(/^\.\//, "", path)
  before[path]=`$2
  seen[path]=1
}
END {
  for (path in before) {
    if (!(path in allowed)) {
      print "phase6_sync_hot_path_build_context_unreviewed_change=" path > "/dev/stderr"
      exit 1
    }
  }
}' "`$release_paths_file" <(comm -3 "`$remote_tmp/.build-context.before.tsv" "`$remote_tmp/.build-context.after.tsv" | sed 's/^\t//'); then
  echo 'phase6_sync_hot_path_build_context=unreviewed_change' >&2
  exit 1
fi
echo 'phase6_sync_hot_path_build_context=verified'

echo 'phase6_sync_hot_path_sync=applied'
echo "phase6_sync_hot_path_sync_backup_dir=`$backup_dir"
echo "phase6_sync_hot_path_absent_files_manifest=`$absent_manifest"
echo 'phase6_sync_hot_path_reviewed_manifest=verified'

if [ "`$build_image" = '1' ]; then
  build_context_root="`$remote_tmp/build-context"
  rm -rf "`$build_context_root"
  mkdir -p "`$build_context_root"
  copy_build_context_file_list | while IFS= read -r relative_path; do
    mkdir -p "`$build_context_root/`$(dirname "`$relative_path")"
    install -m 0644 "`$relative_path" "`$build_context_root/`$relative_path"
  done
  cat > "`$build_context_root/Dockerfile.tsdd" <<'PHASE6_DOCKERFILE'
FROM golang:1.20 AS build

ENV GOPROXY=https://goproxy.cn,direct
ENV GO111MODULE=on
ARG BUILD_VERSION=prod-local
ARG BUILD_COMMIT=workspace
ARG BUILD_COMMIT_DATE=2026-04-05
ARG BUILD_TREE_STATE=dirty

WORKDIR /src

COPY go.mod go.sum ./
COPY serverlib ./serverlib
RUN go mod download

COPY . .

RUN mkdir -p /out && CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w -X main.Version=`${BUILD_VERSION} -X main.Commit=`${BUILD_COMMIT} -X main.CommitDate=`${BUILD_COMMIT_DATE} -X main.TreeState=`${BUILD_TREE_STATE}" \
    -o /out/app ./main.go

FROM debian:bookworm-slim

ENV TZ=Asia/Shanghai

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates tzdata wget && \
    ln -snf /usr/share/zoneinfo/`$TZ /etc/localtime && \
    echo `$TZ >/etc/timezone && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home

COPY --from=build /out/app /home/app
COPY --from=build /src/assets /home/assets
COPY --from=build /src/configs /home/configs

ENTRYPOINT ["/home/app"]
PHASE6_DOCKERFILE
  cat > "`$build_context_root/.dockerignore" <<'PHASE6_DOCKERIGNORE'
.git
**/.git

.env
.env.*
**/.env
**/.env.*
!.env.example
!**/.env.example

deploy/production/.env
deploy/production/.env.bak*
deploy/production/rendered/
deploy/production/logs/
deploy/production/data/
deploy/production/backup/
deploy/production/backups/
deploy/production/certs/
deploy/production/keys/

**/__pycache__/
**/*.pyc

build/
**/build/
dist/
**/dist/
node_modules/
**/node_modules/
.dart_tool/

**/*.pem
**/*.key
**/*.db
**/*.sqlite
**/*.sqlite3
**/*.log
**/*.gz
**/*.zip
**/*.tar
**/*.tgz
**/*.p12
**/*.pfx
**/*.jks
PHASE6_DOCKERIGNORE
  cat > "`$remote_tmp/docker-compose.phase6-sync-hot-path-build.yaml" <<'PHASE6_COMPOSE'
services:
  tsdd-api:
    build:
      context: __BUILD_CONTEXT_ROOT__
      dockerfile: Dockerfile.tsdd
      args:
        BUILD_VERSION: "`${BUILD_VERSION}"
        BUILD_COMMIT: "`${BUILD_COMMIT}"
        BUILD_COMMIT_DATE: "`${BUILD_COMMIT_DATE}"
        BUILD_TREE_STATE: "`${BUILD_TREE_STATE}"
    image: wukongim/tsdd-api:production-local
PHASE6_COMPOSE
  sed -i "s|__BUILD_CONTEXT_ROOT__|`$build_context_root|g" "`$remote_tmp/docker-compose.phase6-sync-hot-path-build.yaml"
  echo "phase6_sync_hot_path_build_context_root=`$build_context_root"
  cd "`$remote_production"
  image_timestamp="`$(date -u +%Y%m%dT%H%M%SZ)"
  previous_image_tag="wukongim/tsdd-api:phase6-sync-hot-path-pre-`$image_timestamp"
  if docker image inspect wukongim/tsdd-api:production-local >/dev/null 2>&1; then
    docker tag wukongim/tsdd-api:production-local "`$previous_image_tag"
    echo "phase6_sync_hot_path_previous_image_tag=`$previous_image_tag"
  else
    echo 'previous production image is missing: wukongim/tsdd-api:production-local' >&2
    exit 1
  fi
  docker compose --env-file .env -f "`$remote_tmp/docker-compose.phase6-sync-hot-path-build.yaml" build tsdd-api
  echo 'phase6_sync_hot_path_build=completed'
  docker compose --env-file .env ps tsdd-api
else
  echo 'phase6_sync_hot_path_build=skipped'
fi
"@
  Invoke-RemoteBash -Script $applyScript
}
finally {
  Invoke-RemoteBash -Script ("set -euo pipefail`nrm -rf " + $remoteTempArg) | Out-Null
}


