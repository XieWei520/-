$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$pidFile = Join-Path $repoRoot 'ops\monitoring\live\android_server_monitor_pids.json'

if (-not (Test-Path $pidFile)) {
  [pscustomobject]@{
    StoppedCount = 0
    Status = 'No android server monitor pid file found.'
  }
  return
}

$rawRecords = Get-Content -Path $pidFile -Raw | ConvertFrom-Json
$pids = New-Object System.Collections.Generic.List[int]
foreach ($record in @($rawRecords)) {
  foreach ($pidValue in @($record.Pid)) {
    if ($null -ne $pidValue -and "$pidValue" -match '^\d+$') {
      $pids.Add([int]$pidValue)
    }
  }
}

$stopped = @()

function Stop-ProcessTree {
  param([Parameter(Mandatory = $true)][int]$ProcessId)

  $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue
  foreach ($child in $children) {
    Stop-ProcessTree -ProcessId ([int]$child.ProcessId)
  }

  $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
  if ($null -ne $process) {
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    return $true
  }
  return $false
}

foreach ($monitorPid in $pids) {
  if (Stop-ProcessTree -ProcessId $monitorPid) {
    $stopped += $monitorPid
  }
}

[pscustomobject]@{
  StoppedCount = $stopped.Count
  StoppedPids = $stopped
  Status = 'Stopped Android server log monitors.'
}
