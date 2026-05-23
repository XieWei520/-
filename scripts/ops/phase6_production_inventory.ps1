[CmdletBinding()]
param(
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
  [string]$RemoteSourceRoot = '/opt/wukongim-prod/src',
  [string]$SshKeyPath = '',
  [switch]$Run
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Quote-Bash {
  param([Parameter(Mandatory = $true)][string]$Value)

  $single = [string][char]39
  $double = [string][char]34
  $replacement = $single + $double + $single + $double + $single
  return $single + $Value.Replace($single, $replacement) + $single
}

function Validate-RemoteHostToken {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value -notmatch '^[A-Za-z0-9_.@:%+-]+$' -or $Value.StartsWith('-')) {
    throw "RemoteHost must be a single safe ssh host token: $Value"
  }
}

function Get-SshOptions {
  $options = @('-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new')
  if (-not [string]::IsNullOrWhiteSpace($SshKeyPath)) {
    $resolvedKey = (Resolve-Path -LiteralPath $SshKeyPath).Path
    $options += @('-i', $resolvedKey)
  }
  return $options
}

function Quote-ProcessArgument {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value -match '[\s"]') {
    return '"' + ($Value.Replace('\', '\\').Replace('"', '\"')) + '"'
  }
  return $Value
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
    throw "Remote inventory failed with exit code $($process.ExitCode)."
  }
}

$remoteRootArg = Quote-Bash -Value $RemoteRoot
$remoteSourceRootArg = Quote-Bash -Value $RemoteSourceRoot

$inventoryScript = @"
set -euo pipefail
remote_root=$remoteRootArg
remote_source_root=$remoteSourceRootArg

echo '== host =='
hostname
date -Is
uname -a

echo '== runtime versions =='
command -v docker >/dev/null 2>&1 && docker --version || true
docker compose version 2>/dev/null || true
command -v go >/dev/null 2>&1 && go version || true
command -v node >/dev/null 2>&1 && node --version || true
command -v pnpm >/dev/null 2>&1 && pnpm --version || true

echo '== candidate paths =='
for path in "`$remote_root" "`$remote_source_root" /opt/wukongim-prod /opt; do
  if [ -e "`$path" ]; then
    ls -ld "`$path"
  else
    printf 'missing %s\n' "`$path"
  fi
done
compose_candidates="`$(find /opt -maxdepth 4 \( -name 'docker-compose.yml' -o -name 'docker-compose.yaml' -o -name '.env' \) -print 2>/dev/null || true)"
printf '%s\n' "`$compose_candidates" | sort | sed -n '1,120p'

echo '== source status =='
if [ -d "`$remote_source_root/.git" ]; then
  git -C "`$remote_source_root" status --short --branch
  git -C "`$remote_source_root" rev-parse --short HEAD
else
  echo 'source git repository not found'
fi

echo '== compose status =='
if [ -d "`$remote_root" ]; then
  cd "`$remote_root"
  if [ -f .env ]; then
    grep -E '^(BUILD_|PUBLIC_DOMAIN=|TSDD_BASE_URL=|APP_URL=)' .env || true
  else
    echo '.env not found'
  fi
  docker compose --env-file .env ps 2>/dev/null || docker compose ps 2>/dev/null || true
  docker compose --env-file .env config --services 2>/dev/null || docker compose config --services 2>/dev/null || true
else
  echo 'remote compose root missing'
fi

echo '== service units =='
systemctl list-units --type=service --all 2>/dev/null | grep -Ei 'wukong|tsdd|docker|nginx|mysql|redis|minio|livekit|coturn' || true

echo '== host capacity =='
df -h
free -h || true
"@

if (-not $Run) {
  Write-Host 'Dry run only. Add -Run to execute read-only SSH inventory.'
  Write-Host "RemoteHost: $RemoteHost"
  Write-Host "RemoteRoot: $RemoteRoot"
  Write-Host "RemoteSourceRoot: $RemoteSourceRoot"
  Write-Host ''
  Write-Host 'Commands that would run remotely:'
  $inventoryScript
  exit 0
}

Invoke-RemoteBash -Script $inventoryScript
