[CmdletBinding()]
param(
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
  [string]$Database = '',
  [string]$SshKeyPath = '',
  [switch]$Run
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
    throw "Remote Phase 6 migration readiness gate failed with exit code $($process.ExitCode)."
  }
}

$remoteRootArg = Quote-Bash -Value $RemoteRoot
$databaseArg = Quote-Bash -Value $Database

$readinessScript = @"
set -euo pipefail
remote_root=$remoteRootArg
database_name=$databaseArg

cd "`$remote_root"
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

run_mysql_scalar() {
  local query="`$1"
  printf '%s\n' "`$query" | docker compose --env-file .env exec -T mysql sh -lc 'mysql -uroot -p"`$MYSQL_ROOT_PASSWORD" --batch --skip-column-names'
}

gorp_migrations_present="`$(run_mysql_scalar "select count(*) from information_schema.tables where table_schema = '`$database_name' and table_name = 'gorp_migrations';" | tr -d '[:space:]')"
if [ "`$gorp_migrations_present" != '1' ]; then
  echo 'phase6_migration_readiness=blocked_missing_gorp_migrations'
  echo "database=`$database_name"
  echo 'gorp_migrations_present=0'
  exit 1
fi

required_tables_present="`$(run_mysql_scalar "select count(*) from information_schema.tables where table_schema = '`$database_name' and table_name in ('admin_audit_log', 'user_purge_job', 'user_purge_verification');" | tr -d '[:space:]')"
maintenance_columns_present="`$(run_mysql_scalar "select count(*) from information_schema.columns where table_schema = '`$database_name' and table_name = 'app_config' and column_name in ('maintenance_enabled', 'maintenance_title', 'maintenance_message');" | tr -d '[:space:]')"
required_indexes_present="`$(run_mysql_scalar "select count(*) from (select required.table_name, required.index_name, required.columns from (select 'admin_audit_log' table_name, 'admin_audit_log_target_idx' index_name, 'target_type,target_id,created_at' columns union all select 'admin_audit_log', 'admin_audit_log_operator_idx', 'operator_uid,created_at' union all select 'admin_audit_log', 'admin_audit_log_action_idx', 'action,created_at' union all select 'user_purge_job', 'user_purge_job_job_id_uidx', 'job_id' union all select 'user_purge_job', 'user_purge_job_uid_created_at_idx', 'uid,created_at' union all select 'user_purge_job', 'user_purge_job_operator_created_at_idx', 'operator_uid,created_at' union all select 'user_purge_verification', 'user_purge_verification_job_idx', 'job_id,created_at') required join (select table_name, index_name, group_concat(column_name order by seq_in_index) columns from information_schema.statistics where table_schema = '`$database_name' group by table_name, index_name) existing on existing.table_name = required.table_name and existing.index_name = required.index_name and existing.columns = required.columns) matched;" | tr -d '[:space:]')"
phase6_records_present="`$(run_mysql_scalar "select count(*) from `$database_name.gorp_migrations where id in ('common-20260520-01.sql', 'user-20260520-01.sql');" | tr -d '[:space:]')"

echo "database=`$database_name"
echo 'gorp_migrations_present=1'
echo "required_tables_present=`$required_tables_present/3"
echo "maintenance_columns_present=`$maintenance_columns_present/3"
echo "required_indexes_present=`$required_indexes_present/7"
echo "phase6_records_present=`$phase6_records_present/2"

if [ "`$required_tables_present" = '0' ] && [ "`$maintenance_columns_present" = '0' ] && [ "`$required_indexes_present" = '0' ] && [ "`$phase6_records_present" = '0' ]; then
  echo 'phase6_migration_readiness=ready_for_phase6_migration'
  exit 0
fi

if [ "`$required_tables_present" = '3' ] && [ "`$maintenance_columns_present" = '3' ] && [ "`$required_indexes_present" = '7' ] && [ "`$phase6_records_present" = '2' ]; then
  echo 'phase6_migration_readiness=already_migrated'
  exit 0
fi

echo 'phase6_migration_readiness=inconsistent_phase6_schema'
exit 1
"@

if (-not $Run) {
  Write-Host 'Dry run only. Add -Run to execute read-only Phase 6 migration readiness gate.'
  Write-Host "RemoteHost: $RemoteHost"
  Write-Host "RemoteRoot: $RemoteRoot"
  Write-Host "Database: $Database"
  Write-Host ''
  Write-Host 'Commands that would run remotely:'
  $readinessScript
  exit 0
}

Invoke-RemoteBash -Script $readinessScript
