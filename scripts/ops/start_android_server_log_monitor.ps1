param(
  [string]$SshTarget = 'ubuntu@42.194.218.158',
  [string[]]$Containers = @(
    'wukongim_prod-tsdd-api-1',
    'wukongim_prod-wukongim-1',
    'wukongim_prod-nginx-1',
    'wukongim_prod-callgateway-1'
  )
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$liveDir = Join-Path $repoRoot 'ops\monitoring\live'
$sshExe = 'C:\Windows\System32\OpenSSH\ssh.exe'

New-Item -ItemType Directory -Force -Path $liveDir | Out-Null

$records = @()
foreach ($container in $Containers) {
  $safeName = $container -replace '[^a-zA-Z0-9_-]', '_'
  $stdout = Join-Path $liveDir "android_server_$safeName.log"
  $stderr = Join-Path $liveDir "android_server_$safeName.err.log"
  $wrapper = Join-Path $liveDir "android_server_$safeName.monitor.ps1"

  Set-Content -Path $stdout -Value "===== $(Get-Date -Format s) docker logs -f $container =====" -Encoding UTF8
  Set-Content -Path $stderr -Value '' -Encoding UTF8

  $wrapperContent = @"
`$ErrorActionPreference = 'Continue'
`$sshExe = '$sshExe'
`$sshTarget = '$SshTarget'
`$container = '$container'
`$stdout = '$stdout'
`$stderr = '$stderr'

try {
  "[`$(Get-Date -Format s)] monitor started: `$container" | Out-File -FilePath `$stdout -Append -Encoding utf8
  `$remoteCommand = "docker logs -f --tail 120 `$container"
  & `$sshExe -o BatchMode=yes -o ServerAliveInterval=30 `$sshTarget `$remoteCommand 2>&1 |
    ForEach-Object { "[{0}] {1}" -f (Get-Date -Format 's'), `$_ } |
    Out-File -FilePath `$stdout -Append -Encoding utf8
} catch {
  "[`$(Get-Date -Format s)] MONITOR_ERROR: `$(`$_.Exception.Message)" | Out-File -FilePath `$stderr -Append -Encoding utf8
}
"@
  Set-Content -Path $wrapper -Value $wrapperContent -Encoding UTF8

  $process = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $wrapper
  ) -PassThru -WindowStyle Hidden

  $records += [pscustomobject]@{
    Container = $container
    Pid = $process.Id
    Stdout = $stdout
    Stderr = $stderr
    Wrapper = $wrapper
  }
}

$pidFile = Join-Path $liveDir 'android_server_monitor_pids.json'
$records | ConvertTo-Json -Depth 4 | Set-Content -Path $pidFile -Encoding UTF8

$records
