[CmdletBinding()]
param(
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
[string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
  [string]$ReleaseBaseUrl = 'https://infoequity.cn',
  [int]$HealthTimeoutSeconds = 180,
  [int]$ProbeTimeoutSeconds = 10,
  [string]$SshKeyPath = '',
  [switch]$Run,
  [switch]$AllowProductionServiceSwitch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
  $remoteScriptFile = Join-Path ([System.IO.Path]::GetTempPath()) "phase6-remote-bash-$([guid]::NewGuid().ToString('N')).sh"
  $cmdFile = Join-Path ([System.IO.Path]::GetTempPath()) "phase6-remote-bash-$([guid]::NewGuid().ToString('N')).cmd"

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
    throw "Remote Phase 6 backend service switch failed with exit code $($process.ExitCode)."
  }
}

if ($HealthTimeoutSeconds -lt 30) {
  throw 'HealthTimeoutSeconds must be at least 30.'
}
if ($ProbeTimeoutSeconds -lt 1) {
  throw 'ProbeTimeoutSeconds must be at least 1.'
}
$remoteRootArg = Quote-Bash -Value $RemoteRoot
$releaseBaseUrlArg = Quote-Bash -Value $ReleaseBaseUrl

$switchScriptTemplate = @'
set -euo pipefail
remote_root=__REMOTE_ROOT__
release_base_url=__RELEASE_BASE_URL__
health_timeout=__HEALTH_TIMEOUT__
probe_timeout=__PROBE_TIMEOUT__

release_base_url="${release_base_url%/}"

wait_for_health() {
  local service="$1"
  local timeout="${2:-$health_timeout}"
  local elapsed=0
  local container_id=""
  local health_status=""

  container_id="$(docker compose --env-file .env ps -q "$service")"
  if [ -z "$container_id" ]; then
    echo "service_has_no_container=$service" >&2
    return 1
  fi

  while [ "$elapsed" -lt "$timeout" ]; do
    health_status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id")"
    if [ "$health_status" = 'healthy' ] || [ "$health_status" = 'none' ]; then
      echo "service_health=$service:$health_status"
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done

  echo "service_health_timeout=$service:$health_status" >&2
  docker compose --env-file .env ps
  return 1
}

cd "$remote_root"
test -f .env

echo '== switch backend services =='
docker compose --env-file .env up -d --no-deps --force-recreate tsdd-api callgateway
wait_for_health tsdd-api "$health_timeout"
wait_for_health callgateway "$health_timeout"

echo '== restart nginx upstream cache =='
nginx_container_id="$(docker compose --env-file .env ps -q nginx)"
if [ -z "$nginx_container_id" ]; then
  echo 'nginx_container_missing=1' >&2
  exit 1
fi
docker exec "$nginx_container_id" nginx -t
post_nginx_restart_since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
docker compose --env-file .env restart nginx

echo '== post-switch smoke =='
external_ping="$(curl -fsS --max-time "$probe_timeout" "$release_base_url/v1/ping")"
echo "external_ping=$external_ping"
recent_502_count="$(docker compose --env-file .env logs --since="$post_nginx_restart_since" nginx 2>&1 | grep -c ' 502 ' || true)"
echo "nginx_recent_502_count=$recent_502_count"
if [ "$recent_502_count" != '0' ]; then
  echo 'phase6_backend_service_switch=blocked_recent_nginx_502' >&2
  exit 1
fi

echo '== final status =='
docker compose --env-file .env ps tsdd-api callgateway nginx
for service in tsdd-api callgateway; do
  container_id="$(docker compose --env-file .env ps -q "$service")"
  image_id="$(docker inspect -f '{{.Image}}' "$container_id")"
  echo "service_image=$service:$image_id"
done
echo 'phase6_backend_service_switch=completed'
'@

$switchScript = $switchScriptTemplate.
  Replace('__REMOTE_ROOT__', $remoteRootArg).
  Replace('__RELEASE_BASE_URL__', $releaseBaseUrlArg).
  Replace('__HEALTH_TIMEOUT__', [string]$HealthTimeoutSeconds).
  Replace('__PROBE_TIMEOUT__', [string]$ProbeTimeoutSeconds)

if (-not $Run) {
  Write-Host 'Dry run only. Add -Run -AllowProductionServiceSwitch to switch production backend services and restart nginx.'
  Write-Host "RemoteHost: $RemoteHost"
  Write-Host "RemoteRoot: $RemoteRoot"
  Write-Host "ReleaseBaseUrl: $ReleaseBaseUrl"
  Write-Host "Services: tsdd-api callgateway"
  Write-Host ''
  Write-Host 'Commands that would run remotely:'
  $switchScript
  exit 0
}

if (-not $AllowProductionServiceSwitch) {
  throw 'Refusing to switch production backend services without -AllowProductionServiceSwitch.'
}

Invoke-RemoteBash -Script $switchScript
