[CmdletBinding()]
param(
    [string]$Server = 'ubuntu@42.194.218.158',
    [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
    [string]$SshKeyPath = '',
    [string]$RollbackBackupDir = '',
    [switch]$Apply,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Quote-Bash {
    param([Parameter(Mandatory = $true)][string]$Value)
    $single = [string][char]39
    $double = [string][char]34
    $replacement = $single + $double + $single + $double + $single
    return $single + $Value.Replace($single, $replacement) + $single
}

function Get-SshOptions {
    $options = @('-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new')
    if (-not [string]::IsNullOrWhiteSpace($SshKeyPath)) {
        $resolvedKey = (Resolve-Path -LiteralPath $SshKeyPath).Path
        $options += @('-i', $resolvedKey)
    }
    return $options
}

function Invoke-Ssh {
    param([Parameter(Mandatory = $true)][string]$Command)
    $sshArgs = @((Get-SshOptions) + @($Server, $Command))
    & ssh @sshArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Remote command failed: $Command"
    }
}

function Copy-ToRemote {
    param(
        [Parameter(Mandatory = $true)][string]$LocalPath,
        [Parameter(Mandatory = $true)][string]$RemotePath
    )

    $scpArgs = @((Get-SshOptions) + @($LocalPath, "$Server`:$RemotePath"))
    & scp @scpArgs
    if ($LASTEXITCODE -ne 0) {
        throw "scp failed while copying '$LocalPath' to '$RemotePath'."
    }
}

$localScript = Join-Path -Path $PSScriptRoot -ChildPath 'apply_nginx_edge_optimizations.sh'
if (-not (Test-Path -LiteralPath $localScript)) {
    throw "Missing local helper script: $localScript"
}

$remoteTempScript = "/tmp/wukongim-nginx-edge-$([guid]::NewGuid().ToString('N')).sh"
$remoteRootLiteral = Quote-Bash -Value $RemoteRoot
$remoteArgs = '--dry-run'
if ($Apply) {
    $remoteArgs = '--apply'
}
if ($DryRun) {
    $remoteArgs = '--dry-run'
}
if (-not [string]::IsNullOrWhiteSpace($RollbackBackupDir)) {
    $remoteArgs = '--rollback ' + (Quote-Bash -Value $RollbackBackupDir)
}

try {
    Write-Host "[STEP] Uploading nginx edge optimizer"
    Copy-ToRemote -LocalPath $localScript -RemotePath $remoteTempScript
    Invoke-Ssh -Command "chmod +x $(Quote-Bash -Value $remoteTempScript)"

    Write-Host "[STEP] Running nginx edge optimizer ($remoteArgs)"
    Invoke-Ssh -Command "bash $(Quote-Bash -Value $remoteTempScript) $remoteRootLiteral $remoteArgs"
}
finally {
    Invoke-Ssh -Command "rm -f $(Quote-Bash -Value $remoteTempScript)" | Out-Null
}
