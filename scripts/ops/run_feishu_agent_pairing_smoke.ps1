param(
  [int]$Port = 8787
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$serverDir = Join-Path $repoRoot 'tools\monitor_mock_server'
$agentDir = Join-Path $repoRoot 'tools\feishu_monitor_agent'
$storeDir = Join-Path $env:TEMP ('feishu-agent-smoke-' + [Guid]::NewGuid().ToString('N'))
$dartExeCommand = Get-Command dart.exe -ErrorAction SilentlyContinue
if ($dartExeCommand) {
  $dartExe = $dartExeCommand.Source
} else {
  $dartBat = Get-Command dart -ErrorAction Stop
  $dartExe = (Resolve-Path (Join-Path (Split-Path $dartBat.Source -Parent) 'cache\dart-sdk\bin\dart.exe')).Path
}
if (-not $dartExe -or -not (Test-Path -LiteralPath $dartExe)) {
  throw "Cannot locate dart.exe. Resolved path: $dartExe"
}

Write-Host "Starting mock server on port $Port"
$existingPort = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($existingPort) {
  throw "Port $Port is already in use by process $($existingPort.OwningProcess). Rerun with -Port <free-port>."
}

$server = Start-Process -FilePath $dartExe -ArgumentList @('run', 'bin/monitor_mock_server.dart', '--port', "$Port") -WorkingDirectory $serverDir -PassThru -WindowStyle Hidden
for ($i = 0; $i -lt 30; $i++) {
  if ($server.HasExited) {
    throw "Mock server exited early with code $($server.ExitCode)."
  }
  $listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  if ($listening) {
    break
  }
  Start-Sleep -Milliseconds 500
}
if (-not (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)) {
  throw "Mock server did not start listening on port $Port within 15 seconds."
}

try {
  $codeResponse = Invoke-RestMethod -TimeoutSec 10 -Method Post -Uri "http://127.0.0.1:$Port/v1/monitor/agent-pairing-codes" -ContentType 'application/json' -Body (@{ device_name = 'Windows Agent'; platform = 'windows' } | ConvertTo-Json)
  $code = $codeResponse.data.pairing_code
  Write-Host "Pairing code: $code"

  Push-Location $agentDir
  try {
    & $dartExe run bin/feishu_monitor_agent.dart pair --server "http://127.0.0.1:$Port" --code $code --store-dir $storeDir
    & $dartExe run bin/feishu_monitor_agent.dart run --once --store-dir $storeDir
  } finally {
    Pop-Location
  }

  $agents = Invoke-RestMethod -TimeoutSec 10 -Method Get -Uri "http://127.0.0.1:$Port/v1/monitor/agents?platform=feishu"
  $agentList = @($agents.data)
  if ($agentList.Count -lt 1 -or $agentList[0].status -ne 'online') {
    throw 'Expected one online Agent from mock server.'
  }
  Write-Host "Smoke passed: Agent is online."
} finally {
  $listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  foreach ($listener in @($listeners)) {
    if ($listener.OwningProcess) {
      Stop-Process -Id $listener.OwningProcess -Force -ErrorAction SilentlyContinue
    }
  }
  if ($server -and -not $server.HasExited) {
    Stop-Process -Id $server.Id -Force
  }
  if (Test-Path -LiteralPath $storeDir) {
    Remove-Item -LiteralPath $storeDir -Recurse -Force
  }
}
