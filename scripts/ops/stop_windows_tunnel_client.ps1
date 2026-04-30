param(
  [string]$ApiRemote = '172.18.0.9:8090',
  [string]$ImRemote = '172.18.0.6:5100',
  [string]$MinioRemote = '172.18.0.2:9000',
  [int]$ApiLocalPort = 15001,
  [int]$ImLocalPort = 15100,
  [int]$MinioLocalPort = 15002
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$processUtilsPath = Join-Path $PSScriptRoot 'windows_tunnel_client_process_utils.ps1'
. $processUtilsPath

$stoppedProcesses = @(Stop-WindowsTunnelClientProcesses `
  -ApiRemote $ApiRemote `
  -ImRemote $ImRemote `
  -MinioRemote $MinioRemote `
  -ApiLocalPort $ApiLocalPort `
  -ImLocalPort $ImLocalPort `
  -MinioLocalPort $MinioLocalPort)

[pscustomobject]@{
  RepoRoot = $repoRoot
  StoppedCount = $stoppedProcesses.Count
  StoppedPids = @($stoppedProcesses.ProcessId)
  Status = 'Stopped tunnel-backed Windows client processes.'
}
