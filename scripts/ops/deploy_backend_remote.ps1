[CmdletBinding()]
param(
    [string]$Server = 'ubuntu@42.194.218.158',
    [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
    [string]$BuildVersion = ('prod-' + (Get-Date -Format 'yyyyMMdd-HHmmss')),
    [string]$BuildCommit = ('manual-' + (Get-Date -Format 'yyyyMMdd-HHmmss')),
    [string]$BuildCommitDate = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$BuildTreeState = 'manual-sync',
    [string]$SshKeyPath = ''
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
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [switch]$CaptureOutput
    )

    $sshArgs = @((Get-SshOptions) + @($Server, $Command))
    if ($CaptureOutput) {
        $output = & ssh @sshArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Remote command failed: $Command`n$($output -join [Environment]::NewLine)"
        }
        return $output
    }

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

$localRemoteScript = Join-Path -Path $PSScriptRoot -ChildPath 'remote_redeploy.sh'
if (-not (Test-Path -LiteralPath $localRemoteScript)) {
    throw "Missing local helper script: $localRemoteScript"
}

$remoteTempScript = "/tmp/wukongim-remote-redeploy-$([guid]::NewGuid().ToString('N')).sh"
$remoteLiteral = Quote-Bash -Value $RemoteRoot

Write-Host "[STEP] Checking current production status"
Invoke-Ssh -Command "cd $remoteLiteral && docker compose --env-file .env ps"

Write-Host "[STEP] Capturing current BUILD_* markers"
$currentBuild = Invoke-Ssh -Command "cd $remoteLiteral && grep '^BUILD_' .env || true" -CaptureOutput
$currentBuild | ForEach-Object { Write-Host $_ }

try {
    Write-Host "[STEP] Uploading remote helper"
    Copy-ToRemote -LocalPath $localRemoteScript -RemotePath $remoteTempScript
    Invoke-Ssh -Command "chmod +x $(Quote-Bash -Value $remoteTempScript)"

    Write-Host "[STEP] Running remote redeploy"
    $remoteCommand = @(
        "export BUILD_VERSION=$(Quote-Bash -Value $BuildVersion)",
        "export BUILD_COMMIT=$(Quote-Bash -Value $BuildCommit)",
        "export BUILD_COMMIT_DATE=$(Quote-Bash -Value $BuildCommitDate)",
        "export BUILD_TREE_STATE=$(Quote-Bash -Value $BuildTreeState)",
        "bash $(Quote-Bash -Value $remoteTempScript) $remoteLiteral"
    ) -join '; '
    Invoke-Ssh -Command $remoteCommand
}
finally {
    Invoke-Ssh -Command "rm -f $(Quote-Bash -Value $remoteTempScript)" | Out-Null
}
