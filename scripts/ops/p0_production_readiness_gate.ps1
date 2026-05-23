param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
  [string]$OutputDirectory = '',
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
  [switch]$Run
)

$ErrorActionPreference = 'Continue'
$FailedGates = New-Object System.Collections.Generic.List[string]

if (-not $Run) {
  'Dry run only. Add -Run to execute read-only P0 production readiness gate.'
  exit 0
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $OutputDirectory = Join-Path $ProjectRoot "build\p0-production-readiness\$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Set-Location $ProjectRoot

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

function Invoke-RemoteReadOnlyBash {
  param([Parameter(Mandatory = $true)][string]$Script)

  Validate-RemoteHostToken -Value $RemoteHost
  $Script = (($Script -replace "`r`n", "`n") -replace "`r", "`n").TrimEnd() + "`n"

  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = 'ssh'
  $startInfo.Arguments = "-o BatchMode=yes -o StrictHostKeyChecking=accept-new -- $RemoteHost bash -s"
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardInput = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo
  [void]$process.Start()
  $process.StandardInput.Write($Script)
  $process.StandardInput.Close()
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()

  if (-not [string]::IsNullOrEmpty($stdout)) {
    $stdout -split "`r?`n" | Where-Object { $_ -ne '' } | ForEach-Object { $_ }
  }
  if (-not [string]::IsNullOrEmpty($stderr)) {
    $stderr -split "`r?`n" | Where-Object { $_ -ne '' } | ForEach-Object { $_ }
  }
  $global:LASTEXITCODE = $process.ExitCode
}

function Invoke-ReadOnlyGate {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )

  $target = Join-Path $OutputDirectory "$Name.txt"
  "## $Name" | Set-Content -Path $target -Encoding UTF8
  "## started: $(Get-Date -Format o)" | Add-Content -Path $target -Encoding UTF8

  $exitCode = 0
  $global:LASTEXITCODE = 0
  try {
    & $Command 2>&1 | ForEach-Object {
      $text = $_.ToString()
      $text
      Add-Content -Path $target -Value $text -Encoding UTF8
    }
    if ($global:LASTEXITCODE -ne 0) {
      $exitCode = $global:LASTEXITCODE
    }
  } catch {
    $exitCode = 1
    $errorText = "## error: $($_.Exception.Message)"
    $errorText
    Add-Content -Path $target -Value $errorText -Encoding UTF8
  }

  "## exit: $exitCode" | Add-Content -Path $target -Encoding UTF8
  "## finished: $(Get-Date -Format o)" | Add-Content -Path $target -Encoding UTF8

  if ($exitCode -ne 0) {
    $FailedGates.Add($Name) | Out-Null
  }
}

Invoke-ReadOnlyGate -Name 'local_git_status' -Command {
  git status --short --branch
  $dirty = git status --porcelain
  if (-not [string]::IsNullOrWhiteSpace(($dirty -join "`n"))) {
    'local_worktree_dirty=true'
    $global:LASTEXITCODE = 1
  }
}

Invoke-ReadOnlyGate -Name 'local_secret_scan' -Command {
  $scanner = Join-Path $ProjectRoot 'scripts/ops/secret_log_scan.py'
  git diff --cached | python $scanner --source staged-diff
  if ($LASTEXITCODE -eq 2) {
    throw "scripts/ops/secret_log_scan.py failed to read input"
  }
}

$remoteRootArg = Quote-Bash -Value $RemoteRoot

Invoke-ReadOnlyGate -Name 'remote_container_health' -Command {
  $remoteCommand = @"
set -euo pipefail
cd $remoteRootArg
docker compose ps
"@
  Invoke-RemoteReadOnlyBash -Script $remoteCommand
}

Invoke-ReadOnlyGate -Name 'remote_public_port_audit' -Command {
  $remoteCommand = @"
set -euo pipefail
ss -ltnup | sed -n '1,160p'
if ss -ltnup | grep -E ':(3306|6379|9000|9001|5001|5100|5200)\b' | grep -v '127.0.0.1'; then
  echo 'unexpected_public_service_port=true'
  exit 1
fi
"@
  Invoke-RemoteReadOnlyBash -Script $remoteCommand
}

Invoke-ReadOnlyGate -Name 'remote_nginx_syntax' -Command {
  $remoteCommand = @"
set -euo pipefail
cd $remoteRootArg
docker compose exec -T nginx nginx -t
"@
  Invoke-RemoteReadOnlyBash -Script $remoteCommand
}

Invoke-ReadOnlyGate -Name 'remote_smoke_ping' -Command {
  $remoteCommand = @"
set -euo pipefail
cd $remoteRootArg
public_domain=`$(grep -E '^PUBLIC_DOMAIN=' .env | head -n1 | cut -d= -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
test -n "`$public_domain"
curl -k -fsS --max-time 10 "https://`$public_domain/v1/ping"
"@
  Invoke-RemoteReadOnlyBash -Script $remoteCommand
}

Invoke-ReadOnlyGate -Name 'remote_websocket_handshake' -Command {
  $remoteCommand = @"
set -euo pipefail
cd $remoteRootArg
public_domain=`$(grep -E '^PUBLIC_DOMAIN=' .env | head -n1 | cut -d= -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
test -n "`$public_domain"
response=`$(curl -k --http1.1 --max-time 8 -i \
  -H 'Connection: Upgrade' \
  -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  -H 'Sec-WebSocket-Version: 13' \
  "https://`$public_domain/ws" 2>&1 || true)
printf '%s\n' "`$response" | sed -n '1,24p'
printf '%s\n' "`$response" | grep -q '101 Switching Protocols'
"@
  Invoke-RemoteReadOnlyBash -Script $remoteCommand
}

Invoke-ReadOnlyGate -Name 'remote_backup_artifact_audit' -Command {
  $remoteCommand = @"
set -euo pipefail
missing=0
for path in /opt/wukongim-prod/backups /var/backups/wukongim-sysctl; do
  if [ -d "`$path" ]; then
    echo "backup_path=`$path"
    recent_count=`$(find "`$path" -maxdepth 2 -type f -mtime -14 | wc -l)
    echo "backup_recent_file_count=`$recent_count"
    find "`$path" -maxdepth 2 -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' | sort | tail -20
    if [ "`$recent_count" -eq 0 ]; then
      echo "backup_recent_artifacts_missing=`$path"
      missing=1
    fi
  else
    echo "backup_path_missing=`$path"
    missing=1
  fi
done
if [ "`$missing" -ne 0 ]; then
  echo 'backup_artifacts_missing=true'
  exit 1
fi
"@
  Invoke-RemoteReadOnlyBash -Script $remoteCommand
}

Invoke-ReadOnlyGate -Name 'remote_observability_inventory' -Command {
  $remoteCommand = @"
set -euo pipefail
echo 'observability_port_probe=9090,3000'
ss -ltnup | grep -E ':(9090|3000)\b' || true
cd $remoteRootArg
observability_services=`$(docker compose ps | grep -Ei 'prometheus|grafana|node-exporter|cadvisor' || true)
printf '%s\n' "`$observability_services"
printf '%s\n' "`$observability_services" | grep -qi 'prometheus' || missing_prometheus=1
printf '%s\n' "`$observability_services" | grep -qi 'grafana' || missing_grafana=1
if [ "`${missing_prometheus:-0}" -ne 0 ] || [ "`${missing_grafana:-0}" -ne 0 ]; then
  echo 'observability_stack_missing=true'
  exit 1
fi
"@
  Invoke-RemoteReadOnlyBash -Script $remoteCommand
}

$summaryPath = Join-Path $OutputDirectory 'failed-gates.txt'
if ($FailedGates.Count -gt 0) {
  $FailedGates | Set-Content -Path $summaryPath -Encoding UTF8
  "p0_readiness=fail"
  "failed-gates: $($FailedGates -join ', ')"
  "Evidence: $OutputDirectory"
  exit 1
}

'PASS' | Set-Content -Path $summaryPath -Encoding UTF8
"p0_readiness=pass"
"Evidence: $OutputDirectory"
exit 0
