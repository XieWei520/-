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
    throw "Remote MySQL schema inventory failed with exit code $($process.ExitCode)."
  }
}

$remoteRootArg = Quote-Bash -Value $RemoteRoot
$databaseArg = Quote-Bash -Value $Database

$schemaSQL = @'
SHOW DATABASES;

SELECT @db AS selected_database;

SELECT COUNT(*) AS table_count
FROM information_schema.tables
WHERE TABLE_SCHEMA = @db;

SELECT TABLE_NAME AS purge_related_table
FROM information_schema.tables
WHERE TABLE_SCHEMA = @db
  AND TABLE_NAME IN ('admin_audit_log', 'user_purge_job', 'user_purge_verification', 'app_config', 'gorp_migrations', 'user', 'device', 'friend', 'group', 'group_member', 'message', 'message_extra', 'message_user_extra', 'channel_offset')
ORDER BY TABLE_NAME;

SELECT required.TABLE_NAME AS required_phase6_table,
       CASE WHEN existing.TABLE_NAME IS NULL THEN 'missing' ELSE 'present' END AS status
FROM (
  SELECT 'admin_audit_log' AS TABLE_NAME
  UNION ALL SELECT 'user_purge_job'
  UNION ALL SELECT 'user_purge_verification'
) required
LEFT JOIN information_schema.tables existing
  ON existing.TABLE_SCHEMA = @db AND existing.TABLE_NAME = required.TABLE_NAME
ORDER BY required.TABLE_NAME;

SELECT required.COLUMN_NAME AS required_app_config_column,
       CASE WHEN existing.COLUMN_NAME IS NULL THEN 'missing' ELSE 'present' END AS status
FROM (
  SELECT 'maintenance_enabled' AS COLUMN_NAME
  UNION ALL SELECT 'maintenance_title'
  UNION ALL SELECT 'maintenance_message'
) required
LEFT JOIN information_schema.columns existing
  ON existing.TABLE_SCHEMA = @db
  AND existing.TABLE_NAME = 'app_config'
  AND existing.COLUMN_NAME = required.COLUMN_NAME
ORDER BY required.COLUMN_NAME;

SELECT TABLE_NAME AS migration_metadata_table
FROM information_schema.tables
WHERE TABLE_SCHEMA = @db
  AND TABLE_NAME = 'gorp_migrations';

SELECT COLUMN_NAME AS migration_metadata_column, COLUMN_TYPE, IS_NULLABLE
FROM information_schema.columns
WHERE TABLE_SCHEMA = @db
  AND TABLE_NAME = 'gorp_migrations'
ORDER BY ORDINAL_POSITION;

SELECT required.migration_id AS phase6_migration_record,
       CASE WHEN migration_table.TABLE_NAME IS NULL THEN 'gorp_migrations_missing' ELSE 'table_present_check_rows_below' END AS status
FROM (
  SELECT 'common-20260520-01.sql' AS migration_id
  UNION ALL SELECT 'user-20260520-01.sql'
) required
LEFT JOIN information_schema.tables migration_table
  ON migration_table.TABLE_SCHEMA = @db
  AND migration_table.TABLE_NAME = 'gorp_migrations'
ORDER BY required.migration_id;

SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_ROWS
FROM information_schema.tables
WHERE TABLE_SCHEMA = @db
ORDER BY TABLE_NAME;

SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY
FROM information_schema.columns
WHERE TABLE_SCHEMA = @db
  AND TABLE_NAME IN ('app_config', 'gorp_migrations', 'user', 'device', 'friend', 'group', 'group_member', 'message', 'message_extra', 'message_user_extra', 'channel_offset', 'user_purge_job', 'user_purge_verification', 'admin_audit_log')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT TABLE_NAME, INDEX_NAME, NON_UNIQUE, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS COLUMNS
FROM information_schema.statistics
WHERE TABLE_SCHEMA = @db
  AND TABLE_NAME IN ('user', 'user_purge_job', 'user_purge_verification', 'admin_audit_log')
GROUP BY TABLE_NAME, INDEX_NAME, NON_UNIQUE
ORDER BY TABLE_NAME, INDEX_NAME;

SELECT required.TABLE_NAME AS required_phase6_table,
       required.INDEX_NAME AS required_phase6_index,
       required.COLUMNS AS required_columns,
       CASE WHEN existing.INDEX_NAME IS NULL THEN 'missing' ELSE 'present' END AS status
FROM (
  SELECT 'admin_audit_log' AS TABLE_NAME, 'admin_audit_log_target_idx' AS INDEX_NAME, 'target_type,target_id,created_at' AS COLUMNS
  UNION ALL SELECT 'admin_audit_log', 'admin_audit_log_operator_idx', 'operator_uid,created_at'
  UNION ALL SELECT 'admin_audit_log', 'admin_audit_log_action_idx', 'action,created_at'
  UNION ALL SELECT 'user_purge_job', 'user_purge_job_job_id_uidx', 'job_id'
  UNION ALL SELECT 'user_purge_job', 'user_purge_job_uid_created_at_idx', 'uid,created_at'
  UNION ALL SELECT 'user_purge_job', 'user_purge_job_operator_created_at_idx', 'operator_uid,created_at'
  UNION ALL SELECT 'user_purge_verification', 'user_purge_verification_job_idx', 'job_id,created_at'
) required
LEFT JOIN (
  SELECT TABLE_NAME, INDEX_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS COLUMNS
  FROM information_schema.statistics
  WHERE TABLE_SCHEMA = @db
  GROUP BY TABLE_NAME, INDEX_NAME
) existing
  ON existing.TABLE_NAME = required.TABLE_NAME
  AND existing.INDEX_NAME = required.INDEX_NAME
  AND existing.COLUMNS = required.COLUMNS
ORDER BY required.TABLE_NAME, required.INDEX_NAME;

SELECT TABLE_NAME, COUNT(*) AS PARTITION_COUNT
FROM information_schema.partitions
WHERE TABLE_SCHEMA = @db
  AND TABLE_NAME IN ('message', 'message_user_extra', 'channel_offset')
  AND PARTITION_NAME IS NOT NULL
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;
'@

$inventoryScript = @"
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

echo "== mysql schema inventory =="
echo "database=`$database_name"

sql_file="`$(mktemp)"
trap 'rm -f "`$sql_file"' EXIT
cat > "`$sql_file" <<'SQL'
$schemaSQL
SQL

docker compose --env-file .env exec -T mysql sh -lc 'mysql -uroot -p"`$MYSQL_ROOT_PASSWORD" --table --init-command="SET @db := \"`$1\";"' sh "`$database_name" < "`$sql_file"

if docker compose --env-file .env exec -T mysql sh -lc 'mysql -uroot -p"`$MYSQL_ROOT_PASSWORD" --batch --skip-column-names --execute="SELECT COUNT(*) FROM information_schema.tables WHERE TABLE_SCHEMA = \"`$1\" AND TABLE_NAME = \"gorp_migrations\";"' sh "`$database_name" | grep -q '^1$'; then
  echo "== phase6 migration records =="
  docker compose --env-file .env exec -T mysql sh -lc 'mysql -uroot -p"`$MYSQL_ROOT_PASSWORD" --table "`$1" --execute="SELECT required.id AS phase6_migration_record, CASE WHEN gm.id IS NULL THEN \"missing\" ELSE \"present\" END AS phase6_migration_record_status, gm.applied_at FROM (SELECT \"common-20260520-01.sql\" AS id UNION ALL SELECT \"user-20260520-01.sql\") required LEFT JOIN gorp_migrations gm ON gm.id = required.id ORDER BY required.id;"' sh "`$database_name"
else
  echo "== phase6 migration records =="
  echo "gorp_migrations table missing"
fi
"@

if (-not $Run) {
  Write-Host 'Dry run only. Add -Run to execute read-only MySQL schema inventory.'
  Write-Host "RemoteHost: $RemoteHost"
  Write-Host "RemoteRoot: $RemoteRoot"
  Write-Host "Database: $Database"
  Write-Host ''
  Write-Host 'SQL that would run remotely:'
  $schemaSQL
  Write-Host ''
  Write-Host 'Remote wrapper that would run:'
  $inventoryScript
  exit 0
}

Invoke-RemoteBash -Script $inventoryScript
