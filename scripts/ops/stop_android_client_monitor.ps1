param(
  [string]$DeviceId = '10ADCF2J20000TJ',
  [string]$PackageId = 'com.im.wukong_im_app',
  [string]$AdbExe = 'D:\Apps\Android\SDK\platform-tools\adb.exe',
  [switch]$ForceStopApp = $false
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$pidFile = Join-Path $repoRoot 'ops\monitoring\live\android_client_monitor_pids.json'

$stopped = @()
if (Test-Path $pidFile) {
  $rawRecords = Get-Content -Path $pidFile -Raw | ConvertFrom-Json
  $records = @()
  foreach ($record in @($rawRecords)) {
    if ($record -is [array]) {
      $records += $record
    } else {
      $records += @($record)
    }
  }

  foreach ($record in $records) {
    $pid = [int]$record.Pid
    $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
    if ($null -ne $process) {
      Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
      $stopped += $pid
    }
  }
}

if ($ForceStopApp) {
  & $AdbExe -s $DeviceId shell am force-stop $PackageId | Out-Null
}

[pscustomobject]@{
  StoppedCount = $stopped.Count
  StoppedPids = $stopped
  ForceStoppedApp = [bool]$ForceStopApp
  Status = 'Stopped Android client monitors.'
}
