param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
  [string]$OutputDirectory = '',
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
  [string]$RemoteSourceRoot = '/opt/wukongim-prod/src',
  [switch]$SkipRemote
)

$ErrorActionPreference = 'Continue'
$FailedGates = New-Object System.Collections.Generic.List[string]

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $OutputDirectory = Join-Path $ProjectRoot "build\phase5-preflight\$stamp"
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

function Invoke-Gate {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )

  $target = Join-Path $OutputDirectory "$Name.txt"
  "## $Name" | Set-Content -Path $target -Encoding UTF8
  "## started: $(Get-Date -Format o)" | Add-Content -Path $target -Encoding UTF8

  $exitCode = 0
  $global:LASTEXITCODE = 0
  $script:gateNativeExitCode = 0
  $script:gateSucceeded = $true
  $gateCaught = $false
  try {
    & {
      $previousDefaultParameterValues = $PSDefaultParameterValues.Clone()
      $PSDefaultParameterValues['*:ErrorAction'] = 'Stop'
      try {
        & $Command
        $commandSucceeded = $?
        $commandNativeExitCode = $global:LASTEXITCODE
        $script:gateSucceeded = $commandSucceeded
        $script:gateNativeExitCode = $commandNativeExitCode
      } finally {
        $PSDefaultParameterValues.Clear()
        foreach ($key in $previousDefaultParameterValues.Keys) {
          $PSDefaultParameterValues[$key] = $previousDefaultParameterValues[$key]
        }
      }
    } 2>&1 | ForEach-Object {
      $text = $_.ToString()
      $text
      Add-Content -Path $target -Value $text -Encoding UTF8
    }
  } catch {
    $gateCaught = $true
    $errorText = "## error: $($_.Exception.Message)"
    $errorText
    Add-Content -Path $target -Value $errorText -Encoding UTF8
    $exitCode = 1
  }

  if (-not $gateCaught) {
    if ($script:gateNativeExitCode -ne 0) {
      $exitCode = $script:gateNativeExitCode
    } elseif (-not $script:gateSucceeded) {
      $exitCode = 1
    }
  }

  "## exit: $exitCode" | Add-Content -Path $target -Encoding UTF8
  "## finished: $(Get-Date -Format o)" | Add-Content -Path $target -Encoding UTF8

  if ($exitCode -ne 0) {
    $FailedGates.Add($Name) | Out-Null
  }
}

Invoke-Gate -Name 'local_git_status' -Command { git status --short --branch }

Invoke-Gate -Name 'flutter_analyze' -Command { flutter analyze }

Invoke-Gate -Name 'flutter_phase5_tests' -Command {
  flutter test `
    test/scripts/ops/phase5_governance_preflight_test.dart `
    test/scripts/ops/collect_im_performance_baseline_test.dart
  if ($LASTEXITCODE -ne 0) {
    throw "phase5 governance/baseline tests failed with exit code $LASTEXITCODE"
  }

  flutter test `
    test/modules/chat/chat_page_scene_flow_test.dart `
    --plain-name "send button uses compact motion states for composer feedback"
}

if (-not $SkipRemote) {
  Invoke-Gate -Name 'remote_docker_compose_config' -Command {
    $remoteRootArg = Quote-Bash -Value $RemoteRoot
    $remoteCommand = "cd $remoteRootArg && docker compose config >/tmp/wukongim-phase5-compose.yml && test -s /tmp/wukongim-phase5-compose.yml"
    ssh $RemoteHost "bash -lc $(Quote-Bash -Value $remoteCommand)"
  }

  Invoke-Gate -Name 'remote_nginx_syntax' -Command {
    ssh $RemoteHost "docker exec wukongim-prod-nginx nginx -t"
  }

  Invoke-Gate -Name 'remote_smoke_test' -Command {
    $remoteRootArg = Quote-Bash -Value $RemoteRoot
    $remoteCommand = "cd $remoteRootArg && python3 scripts/smoke_test.py --base-url http://127.0.0.1 --timeout 10"
    ssh $RemoteHost "bash -lc $(Quote-Bash -Value $remoteCommand)"
  }

  Invoke-Gate -Name 'remote_public_web_smoke' -Command {
    $remoteRootArg = Quote-Bash -Value $RemoteRoot
    $remoteCommand = @"
set -euo pipefail
cd $remoteRootArg
public_domain=`$(grep -E '^PUBLIC_DOMAIN=' .env | head -n1 | cut -d= -f2- | tr -d '"')
test -n "`$public_domain"
curl -k -fsSI "https://`$public_domain/index.html" | sed -n '1,16p'
curl -k -fsSI "https://`$public_domain/flutter_bootstrap.js" | sed -n '1,16p'
curl -k -fsSI "https://`$public_domain/wk_pwa_service_worker.js" | sed -n '1,16p'
curl -k -fsSI "https://`$public_domain/manifest.json" | sed -n '1,16p'
"@
    ssh $RemoteHost "bash -lc $(Quote-Bash -Value $remoteCommand)"
  }

  Invoke-Gate -Name 'remote_websocket_handshake' -Command {
    $remoteRootArg = Quote-Bash -Value $RemoteRoot
    $remoteCommand = @"
set -euo pipefail
cd $remoteRootArg
public_domain=`$(grep -E '^PUBLIC_DOMAIN=' .env | head -n1 | cut -d= -f2- | tr -d '"')
test -n "`$public_domain"
response_file=`$(mktemp)
curl_status=0
curl -k --http1.1 --max-time 8 -i \
  -H 'Connection: Upgrade' \
  -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  -H 'Sec-WebSocket-Version: 13' \
  "https://`$public_domain/ws" > "`$response_file" 2>&1 || curl_status=`$?
sed -n '1,24p' "`$response_file"
grep -q '101 Switching Protocols' "`$response_file"
rm -f "`$response_file"
if [ "`$curl_status" -ne 0 ] && [ "`$curl_status" -ne 52 ]; then
  exit "`$curl_status"
fi
"@
    ssh $RemoteHost "bash -lc $(Quote-Bash -Value $remoteCommand)"
  }

  Invoke-Gate -Name 'server_sql_gate' -Command {
    powershell -NoProfile -ExecutionPolicy Bypass `
      -File (Join-Path $ProjectRoot 'scripts/ops/phase5_server_sql_gate.ps1') `
      -ProjectRoot $ProjectRoot `
      -OutputDirectory $OutputDirectory `
      -RemoteHost $RemoteHost `
      -RemoteSourceRoot $RemoteSourceRoot
  }
} else {
  Invoke-Gate -Name 'remote_gates_skipped' -Command { 'Remote gates skipped by -SkipRemote.' }
}

$summaryPath = Join-Path $OutputDirectory 'failed-gates.txt'
if ($FailedGates.Count -gt 0) {
  $FailedGates | Set-Content -Path $summaryPath -Encoding UTF8
  "Phase 5 preflight failed. Evidence: $OutputDirectory"
  "failed-gates: $($FailedGates -join ', ')"
  exit 1
}

'PASS' | Set-Content -Path $summaryPath -Encoding UTF8
"Phase 5 preflight passed. Evidence: $OutputDirectory"
exit 0
