[CmdletBinding()]
param(
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
  [string]$RemoteSourceRoot = '/opt/wukongim-prod/src',
  [string]$RemoteBackupRoot = '/home/ubuntu/wukongim-phase6-backups',
  [string]$Database = '',
  [string]$SshKeyPath = '',
  [switch]$Run,
  [switch]$AllowProductionWrites
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Quote-Bash {
  param([AllowEmptyString()][Parameter(Mandatory = $true)][string]$Value)

  $single = [string][char]39
  $double = [string][char]34
  $replacement = $single + $double + $single + $double + $single
  return $single + $Value.Replace($single, $replacement) + $single
}

function Quote-ProcessArgument {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value -match '[\s"]') {
    return '"' + ($Value.Replace('\', '\\').Replace('"', '\"')) + '"'
  }
  return $Value
}

function Validate-RemoteHostToken {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value -notmatch '^[A-Za-z0-9_.@:%+-]+$' -or $Value.StartsWith('-')) {
    throw "RemoteHost must be a single safe ssh host token: $Value"
  }
}

function Get-SshOptions {
  $options = @('-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new')
  if (-not [string]::IsNullOrWhiteSpace($SshKeyPath)) {
    $resolvedKey = (Resolve-Path -LiteralPath $SshKeyPath).Path
    $options += @('-i', $resolvedKey)
  }
  return $options
}

function Invoke-RemoteBash {
  param([Parameter(Mandatory = $true)][string]$Script)

  Validate-RemoteHostToken -Value $RemoteHost
  $normalizedScript = (($Script -replace "`r`n", "`n") -replace "`r", "`n").TrimEnd() + "`n"
  $sshArgs = @((Get-SshOptions) + @('--', $RemoteHost, 'bash', '-s'))

  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = 'ssh'
  $startInfo.Arguments = (($sshArgs | ForEach-Object { Quote-ProcessArgument -Value $_ }) -join ' ')
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardInput = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  [void]$process.Start()
  $process.StandardInput.Write($normalizedScript)
  $process.StandardInput.Close()
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()

  if (-not [string]::IsNullOrWhiteSpace($stdout)) {
    $stdout.TrimEnd() -split "`r?`n" | ForEach-Object { $_ }
  }
  if (-not [string]::IsNullOrWhiteSpace($stderr)) {
    $stderr.TrimEnd() -split "`r?`n" | ForEach-Object { $_ }
  }
  if ($process.ExitCode -ne 0) {
    throw "Remote Phase 6 backup failed with exit code $($process.ExitCode)."
  }
}

$remoteRootArg = Quote-Bash -Value $RemoteRoot
$remoteSourceRootArg = Quote-Bash -Value $RemoteSourceRoot
$remoteBackupRootArg = Quote-Bash -Value $RemoteBackupRoot
$databaseArg = Quote-Bash -Value $Database

$backupScript = @"
set -euo pipefail
remote_root=$remoteRootArg
remote_source_root=$remoteSourceRootArg
backup_root=$remoteBackupRootArg
database_name=$databaseArg

cd "`$remote_root"
umask 077
if [ -z "`$database_name" ]; then
  database_name="`$(grep -E '^MYSQL_DATABASE=' .env 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '"' || true)"
fi
if [ -z "`$database_name" ]; then
  database_name='tsdd'
fi
case "`$database_name" in
  *[!A-Za-z0-9_]*)
    echo "invalid database name: `$database_name" >&2
    exit 1
    ;;
esac

stamp="`$(date -u +%Y%m%dT%H%M%SZ)"
target_dir="`$backup_root/`$stamp"

echo "== phase6 backup target =="
echo "database=`$database_name"
echo "target_dir=`$target_dir"

mkdir -p "`$target_dir"
chmod 700 "`$backup_root" "`$target_dir"

echo "== database dump =="
docker compose --env-file .env exec -T mysql sh -lc 'mysqldump -uroot -p"`$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --events --databases "`$1"' sh "`$database_name" < /dev/null | gzip -c > "`$target_dir/`$database_name.sql.gz"
echo "database_dump_done=`$target_dir/`$database_name.sql.gz"
sha256sum "`$target_dir/`$database_name.sql.gz" | tee "`$target_dir/`$database_name.sql.gz.sha256"

echo "== source archive =="
tar --exclude='.git' --exclude='logs' --exclude='data' --exclude='tmp' --exclude='*.log' --exclude='src/deploy/production/rendered/coturn-certs' -czf "`$target_dir/source.tar.gz" -C "`$(dirname "`$remote_source_root")" "`$(basename "`$remote_source_root")"
echo "source_archive_done=`$target_dir/source.tar.gz"
sha256sum "`$target_dir/source.tar.gz" | tee "`$target_dir/source.tar.gz.sha256"

echo "== compose archive =="
tar --exclude='production/rendered/coturn-certs' --exclude='production/data' --exclude='production/logs' -czf "`$target_dir/production-compose.tar.gz" -C "`$(dirname "`$remote_root")" "`$(basename "`$remote_root")"
echo "compose_archive_done=`$target_dir/production-compose.tar.gz"
sha256sum "`$target_dir/production-compose.tar.gz" | tee "`$target_dir/production-compose.tar.gz.sha256"

echo "== backup files =="
find "`$target_dir" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort
"@

if (-not $Run) {
  Write-Host 'Dry run only. Add -Run and -AllowProductionWrites to create production backup files.'
  Write-Host "RemoteHost: $RemoteHost"
  Write-Host "RemoteRoot: $RemoteRoot"
  Write-Host "RemoteSourceRoot: $RemoteSourceRoot"
  Write-Host "RemoteBackupRoot: $RemoteBackupRoot"
  Write-Host "Database: $Database"
  Write-Host ''
  Write-Host 'Commands that would run remotely:'
  $backupScript
  exit 0
}

if (-not $AllowProductionWrites) {
  throw 'Refusing to write production backups without -AllowProductionWrites. Re-run with -Run -AllowProductionWrites after explicit approval.'
}

Invoke-RemoteBash -Script $backupScript
