param(
  [string]$DeviceId = '10ADCF2J20000TJ',
  [string]$PackageId = 'com.im.wukong_im_app',
  [string]$FlutterExe = 'D:\Apps\flutter\bin\flutter.bat',
  [string]$AdbExe = 'D:\Apps\Android\SDK\platform-tools\adb.exe',
  [string]$ApiBaseUrl = 'https://wemx.cc',
  [string]$WsAddr = 'wemx.cc:5100'
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$liveDir = Join-Path $repoRoot 'ops\monitoring\live'
$powershellExe = 'C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe'

New-Item -ItemType Directory -Force -Path $liveDir | Out-Null

$flutterLog = Join-Path $liveDir 'android_client.flutter.run.log'
$flutterErr = Join-Path $liveDir 'android_client.flutter.run.err.log'
$logcatLog = Join-Path $liveDir 'android_client.logcat.log'
$logcatErr = Join-Path $liveDir 'android_client.logcat.err.log'
$pidFile = Join-Path $liveDir 'android_client_monitor_pids.json'

& $AdbExe -s $DeviceId logcat -c | Out-Null
& $AdbExe -s $DeviceId shell am force-stop $PackageId | Out-Null

Set-Content -Path $flutterLog -Value "===== $(Get-Date -Format s) flutter run Android $DeviceId ====="
Set-Content -Path $flutterErr -Value ''
Set-Content -Path $logcatLog -Value "===== $(Get-Date -Format s) adb logcat $DeviceId ====="
Set-Content -Path $logcatErr -Value ''

$logcatProc = Start-Process -FilePath $AdbExe -ArgumentList @(
  '-s', $DeviceId,
  'logcat',
  '-v', 'time'
) -RedirectStandardOutput $logcatLog -RedirectStandardError $logcatErr -PassThru -WindowStyle Hidden

$flutterCommand = @"
Set-Location '$repoRoot'
& '$FlutterExe' run -d '$DeviceId' --dart-define=WK_DEV_BASE_URL=$ApiBaseUrl --dart-define=WK_PROD_BASE_URL=$ApiBaseUrl --dart-define=WK_DEV_WS_ADDR=$WsAddr --dart-define=WK_PROD_WS_ADDR=$WsAddr *> '$flutterLog'
"@

$flutterProc = Start-Process -FilePath $powershellExe -ArgumentList @(
  '-NoLogo',
  '-NoProfile',
  '-ExecutionPolicy', 'Bypass',
  '-Command', $flutterCommand
) -RedirectStandardError $flutterErr -PassThru

$records = @(
  [pscustomobject]@{
    Kind = 'logcat'
    Pid = $logcatProc.Id
    Log = $logcatLog
    ErrorLog = $logcatErr
  }
  [pscustomobject]@{
    Kind = 'flutter'
    Pid = $flutterProc.Id
    Log = $flutterLog
    ErrorLog = $flutterErr
  }
)

$records | ConvertTo-Json -Depth 4 | Set-Content -Path $pidFile -Encoding UTF8

[pscustomobject]@{
  DeviceId = $DeviceId
  PackageId = $PackageId
  FlutterPid = $flutterProc.Id
  LogcatPid = $logcatProc.Id
  FlutterLog = $flutterLog
  FlutterErr = $flutterErr
  LogcatLog = $logcatLog
  LogcatErr = $logcatErr
  ApiBaseUrl = $ApiBaseUrl
  WsAddr = $WsAddr
}
