param(
  [string]$SshTarget = 'ubuntu@42.194.218.158',
  [string]$ApiRemote = '172.18.0.9:8090',
  [string]$ImRemote = '172.18.0.6:5100',
  [string]$MinioRemote = '172.18.0.2:9000',
  [int]$ApiLocalPort = 15001,
  [int]$ImLocalPort = 15100,
  [int]$MinioLocalPort = 15002,
  [string]$ApiContainer = 'wukongim_prod-tsdd-api-1',
  [string]$ImContainer = 'wukongim_prod-wukongim-1',
  [string]$MinioContainer = 'wukongim_prod-minio-1',
  [switch]$ResolveRemoteTargets = $true,
  [switch]$StopFirst = $true
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$liveDir = Join-Path $repoRoot 'ops\monitoring\live'
$sshExe = 'C:\Windows\System32\OpenSSH\ssh.exe'
$powershellExe = 'C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe'
$processUtilsPath = Join-Path $PSScriptRoot 'windows_tunnel_client_process_utils.ps1'

New-Item -ItemType Directory -Force -Path $liveDir | Out-Null
. $processUtilsPath

function Get-RemoteContainerIp {
  param([Parameter(Mandatory = $true)][string]$ContainerName)

  $remoteCommand = "docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $ContainerName"
  $output = @(& $sshExe -o BatchMode=yes -o ConnectTimeout=10 $SshTarget $remoteCommand 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect remote container '$ContainerName': $($output -join "`n")"
  }

  $ip = @(
    $output |
      ForEach-Object { "$_".Trim() } |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  ) | Select-Object -First 1

  return $ip
}

if ($StopFirst) {
  Stop-WindowsTunnelClientProcesses `
    -ApiRemote $ApiRemote `
    -ImRemote $ImRemote `
    -MinioRemote $MinioRemote `
    -ApiLocalPort $ApiLocalPort `
    -ImLocalPort $ImLocalPort `
    -MinioLocalPort $MinioLocalPort | Out-Null
  Start-Sleep -Seconds 2
}

if ($ResolveRemoteTargets) {
  $containerIpResolver = { param($ContainerName) Get-RemoteContainerIp -ContainerName $ContainerName }

  if (-not $PSBoundParameters.ContainsKey('ApiRemote')) {
    $ApiRemote = Resolve-WindowsTunnelRemoteTarget `
      -DefaultRemote $ApiRemote `
      -ContainerName $ApiContainer `
      -ContainerPort 8090 `
      -ContainerIpResolver $containerIpResolver
  }

  if (-not $PSBoundParameters.ContainsKey('ImRemote')) {
    $ImRemote = Resolve-WindowsTunnelRemoteTarget `
      -DefaultRemote $ImRemote `
      -ContainerName $ImContainer `
      -ContainerPort 5100 `
      -ContainerIpResolver $containerIpResolver
  }

  if (-not $PSBoundParameters.ContainsKey('MinioRemote')) {
    $MinioRemote = Resolve-WindowsTunnelRemoteTarget `
      -DefaultRemote $MinioRemote `
      -ContainerName $MinioContainer `
      -ContainerPort 9000 `
      -ContainerIpResolver $containerIpResolver
  }
}

$tunnelOut = Join-Path $liveDir 'ssh_tunnel_api_im_minio.out.log'
$tunnelErr = Join-Path $liveDir 'ssh_tunnel_api_im_minio.err.log'
$clientLog = Join-Path $liveDir 'windows_client.tunnel.run.log'

$sshProc = Start-Process -FilePath $sshExe -ArgumentList @(
  '-o', 'ExitOnForwardFailure=yes',
  '-o', 'ServerAliveInterval=30',
  '-o', 'ServerAliveCountMax=3',
  '-L', "${ApiLocalPort}:$ApiRemote",
  '-L', "${ImLocalPort}:$ImRemote",
  '-L', "${MinioLocalPort}:$MinioRemote",
  '-N',
  $SshTarget
) -RedirectStandardOutput $tunnelOut -RedirectStandardError $tunnelErr -PassThru -WindowStyle Hidden

Start-Sleep -Seconds 3

$expectedLocalPorts = @($ApiLocalPort, $ImLocalPort, $MinioLocalPort)
$listenPorts = Get-NetTCPConnection -State Listen -LocalPort $expectedLocalPorts -ErrorAction SilentlyContinue
$listeningLocalPorts = @($listenPorts | Select-Object -ExpandProperty LocalPort -Unique)
$missingLocalPorts = @($expectedLocalPorts | Where-Object { $listeningLocalPorts -notcontains $_ })
if ($missingLocalPorts.Count -gt 0) {
  throw "Tunnel ports were not all established. Missing: $($missingLocalPorts -join ', '); expected: $($expectedLocalPorts -join ', ')."
}

$flutterCommand = "Set-Location '$repoRoot'; flutter run -d windows --dart-define=WK_DEV_BASE_URL=http://127.0.0.1:$ApiLocalPort --dart-define=WK_PROD_BASE_URL=http://127.0.0.1:$ApiLocalPort --dart-define=WK_DEV_WS_ADDR=127.0.0.1:$ImLocalPort --dart-define=WK_PROD_WS_ADDR=127.0.0.1:$ImLocalPort *> '$clientLog'"
$flutterProc = Start-Process -FilePath $powershellExe -ArgumentList @(
  '-NoLogo',
  '-NoProfile',
  '-ExecutionPolicy', 'Bypass',
  '-Command', $flutterCommand
) -PassThru

Start-Sleep -Seconds 3

[pscustomobject]@{
  RepoRoot = $repoRoot
  TunnelPid = $sshProc.Id
  FlutterPid = $flutterProc.Id
  TunnelStdout = $tunnelOut
  TunnelStderr = $tunnelErr
  ClientLog = $clientLog
  ApiBaseUrl = "http://127.0.0.1:$ApiLocalPort"
  ImAddr = "127.0.0.1:$ImLocalPort"
  MinioBaseUrl = "http://127.0.0.1:$MinioLocalPort"
  ApiRemote = $ApiRemote
  ImRemote = $ImRemote
  MinioRemote = $MinioRemote
}
