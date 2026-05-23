param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
  [string]$SshKeyPath = '',
  [switch]$Run
)

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

  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = 'ssh'
  $startInfo.Arguments = (($sshArgs | ForEach-Object { Quote-ProcessArgument -Value $_ }) -join ' ')
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardInput = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true

  $process = New-Object System.Diagnostics.Process
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
    throw "Remote observability preflight failed with exit code $($process.ExitCode)."
  }
}

$composePath = Join-Path $ProjectRoot 'deploy/production/docker-compose.yaml'
$observabilityComposePath = Join-Path $ProjectRoot 'deploy/production/docker-compose.observability.yaml'
$prometheusPath = Join-Path $ProjectRoot 'deploy/production/monitoring/prometheus.yml'

if (-not (Test-Path -LiteralPath $composePath)) {
  throw "Missing base compose file: $composePath"
}
if (-not (Test-Path -LiteralPath $observabilityComposePath)) {
  throw "Missing observability compose file: $observabilityComposePath"
}
if (-not (Test-Path -LiteralPath $prometheusPath)) {
  throw "Missing prometheus config file: $prometheusPath"
}

$observabilityCompose = Get-Content -LiteralPath $observabilityComposePath -Raw
if ($observabilityCompose -match '0\.0\.0\.0:(9090|3000)') {
  throw 'Prometheus and Grafana must not bind public interfaces.'
}
if ($observabilityCompose -notmatch '127\.0\.0\.1:9090:9090' -or $observabilityCompose -notmatch '127\.0\.0\.1:3000:3000') {
  throw 'Prometheus and Grafana must bind to loopback ports only.'
}

$localProduction = Join-Path $ProjectRoot 'deploy/production'
Push-Location $localProduction
try {
  $dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
  if ($null -ne $dockerCommand) {
    docker compose -f docker-compose.yaml -f docker-compose.observability.yaml config | Out-Host
  } else {
    'local_docker_cli_missing=true'
    'local_compose_config_skipped=true'
  }
} finally {
  Pop-Location
}

if (-not $Run) {
  'Dry run only. Add -Run to check remote production files and current listening ports.'
  "RemoteHost: $RemoteHost"
  "RemoteRoot: $RemoteRoot"
  exit 0
}

$remoteRootArg = Quote-Bash -Value $RemoteRoot
$remoteCommandTemplate = @'
set -euo pipefail
cd __REMOTE_ROOT__
test -f docker-compose.yaml
if [ -f docker-compose.observability.yaml ]; then
  docker compose -f docker-compose.yaml -f docker-compose.observability.yaml config >/dev/null
  echo 'remote_observability_compose_config=ok'
else
  echo 'remote_observability_compose_missing=true'
fi
permission_failed=0
permission_checked=0
check_data_dir_permissions() {
  path="$1"
  target_uid="$2"
  target_gid="$3"
  label="$4"

  if [ ! -d "$path" ]; then
    echo "remote_observability_data_permissions_missing=$label:$path"
    return 0
  fi

  permission_checked=1
  set -- $(stat -c '%u %g %a' "$path")
  owner_uid="$1"
  owner_gid="$2"
  mode_octal="$3"

  mode_int=$((8#$mode_octal))
  can_write=0
  if [ "$owner_uid" -eq "$target_uid" ]; then
    if [ $((mode_int & 0200)) -ne 0 ] && [ $((mode_int & 0100)) -ne 0 ]; then
      can_write=1
    fi
  elif [ "$owner_gid" -eq "$target_gid" ]; then
    if [ $((mode_int & 0020)) -ne 0 ] && [ $((mode_int & 0010)) -ne 0 ]; then
      can_write=1
    fi
  else
    if [ $((mode_int & 0002)) -ne 0 ] && [ $((mode_int & 0001)) -ne 0 ]; then
      can_write=1
    fi
  fi

  if [ "$can_write" -eq 1 ]; then
    echo "remote_observability_data_permissions=$label:ok"
    return 0
  fi

  echo "remote_observability_data_permissions=$label:fail path=$path owner=${owner_uid}:${owner_gid} mode=$mode_octal target=${target_uid}:${target_gid}"
  permission_failed=1
  return 1
}
if ! check_data_dir_permissions data/prometheus 65534 65534 prometheus; then
  :
fi
if ! check_data_dir_permissions data/grafana 472 0 grafana; then
  :
fi
if [ "$permission_failed" -ne 0 ]; then
  exit 1
fi
if [ "$permission_checked" -eq 0 ]; then
  echo 'remote_observability_data_permissions_skipped=true'
fi
echo 'remote_observability_data_permissions=ok'
ss -ltnup | grep -E ':(9090|3000)\b' || true
'@
$remoteCommand = $remoteCommandTemplate.Replace('__REMOTE_ROOT__', $remoteRootArg)

Invoke-RemoteBash -Script $remoteCommand
