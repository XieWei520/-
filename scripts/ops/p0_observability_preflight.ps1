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
$remoteCommand = @"
set -euo pipefail
cd $remoteRootArg
test -f docker-compose.yaml
if [ -f docker-compose.observability.yaml ]; then
  docker compose -f docker-compose.yaml -f docker-compose.observability.yaml config >/dev/null
  echo 'remote_observability_compose_config=ok'
else
  echo 'remote_observability_compose_missing=true'
fi
ss -ltnup | grep -E ':(9090|3000)\b' || true
"@

Invoke-RemoteBash -Script $remoteCommand
