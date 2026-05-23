[CmdletBinding()]
param(
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
  [string]$Database = '',
  [string]$BackupDir = '/home/ubuntu/wukongim-phase6-backups/20260520T125818Z',
  [string]$SshKeyPath = '',
  [switch]$Run,
  [switch]$AllowProductionMigration
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
    throw "Remote Phase 6 migration apply failed with exit code $($process.ExitCode)."
  }
}

$remoteRootArg = Quote-Bash -Value $RemoteRoot
$databaseArg = Quote-Bash -Value $Database
$backupDirArg = Quote-Bash -Value $BackupDir

$migrationSql = @'
ALTER TABLE `app_config`
  ADD COLUMN `maintenance_enabled` SMALLINT NOT NULL DEFAULT 0 COMMENT 'maintenance mode enabled' AFTER `can_modify_api_url`,
  ADD COLUMN `maintenance_title` VARCHAR(120) NOT NULL DEFAULT '' COMMENT 'maintenance title' AFTER `maintenance_enabled`,
  ADD COLUMN `maintenance_message` VARCHAR(1000) NOT NULL DEFAULT '' COMMENT 'maintenance message' AFTER `maintenance_title`;

CREATE TABLE IF NOT EXISTS `admin_audit_log` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `operator_uid` VARCHAR(80) NOT NULL DEFAULT '',
  `operator_name` VARCHAR(120) NOT NULL DEFAULT '',
  `action` VARCHAR(80) NOT NULL DEFAULT '',
  `target_type` VARCHAR(80) NOT NULL DEFAULT '',
  `target_id` VARCHAR(160) NOT NULL DEFAULT '',
  `before_json` LONGTEXT NULL,
  `after_json` LONGTEXT NULL,
  `reason` VARCHAR(500) NOT NULL DEFAULT '',
  `ip` VARCHAR(80) NOT NULL DEFAULT '',
  `user_agent` VARCHAR(500) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE INDEX `admin_audit_log_target_idx` ON `admin_audit_log` (`target_type`, `target_id`, `created_at`);
CREATE INDEX `admin_audit_log_operator_idx` ON `admin_audit_log` (`operator_uid`, `created_at`);
CREATE INDEX `admin_audit_log_action_idx` ON `admin_audit_log` (`action`, `created_at`);

INSERT INTO `gorp_migrations` (`id`, `applied_at`)
VALUES ('common-20260520-01.sql', NOW())
ON DUPLICATE KEY UPDATE `applied_at` = `applied_at`;

CREATE TABLE IF NOT EXISTS `user_purge_job` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `job_id` VARCHAR(80) NOT NULL DEFAULT '',
  `uid` VARCHAR(40) NOT NULL DEFAULT '',
  `phone_hash` VARCHAR(128) NOT NULL DEFAULT '',
  `operator_uid` VARCHAR(80) NOT NULL DEFAULT '',
  `status` VARCHAR(40) NOT NULL DEFAULT 'pending',
  `preview_json` LONGTEXT NOT NULL,
  `result_json` LONGTEXT NOT NULL,
  `reason` VARCHAR(1000) NOT NULL DEFAULT '',
  `error` VARCHAR(2000) NOT NULL DEFAULT '',
  `started_at` DATETIME NULL,
  `finished_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='admin user physical purge jobs';

CREATE UNIQUE INDEX `user_purge_job_job_id_uidx` ON `user_purge_job` (`job_id`);
CREATE INDEX `user_purge_job_uid_created_at_idx` ON `user_purge_job` (`uid`, `created_at`);
CREATE INDEX `user_purge_job_operator_created_at_idx` ON `user_purge_job` (`operator_uid`, `created_at`);

CREATE TABLE IF NOT EXISTS `user_purge_verification` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `job_id` VARCHAR(80) NOT NULL DEFAULT '',
  `check_name` VARCHAR(120) NOT NULL DEFAULT '',
  `status` VARCHAR(40) NOT NULL DEFAULT '',
  `detail_json` LONGTEXT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='admin user purge verification rows';

CREATE INDEX `user_purge_verification_job_idx` ON `user_purge_verification` (`job_id`, `created_at`);

INSERT INTO `gorp_migrations` (`id`, `applied_at`)
VALUES ('user-20260520-01.sql', NOW())
ON DUPLICATE KEY UPDATE `applied_at` = `applied_at`;
'@
$migrationSqlArg = Quote-Bash -Value $migrationSql

$applyScript = @"
set -euo pipefail
remote_root=$remoteRootArg
database_name=$databaseArg
backup_dir=$backupDirArg
migration_sql=$migrationSqlArg

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

echo "== phase6 migration preflight =="
echo "database=`$database_name"
echo "backup_dir=`$backup_dir"
test -d "`$backup_dir"
(cd "`$backup_dir" && sha256sum -c im_prod.sql.gz.sha256 && sha256sum -c source.tar.gz.sha256 && sha256sum -c production-compose.tar.gz.sha256)

run_mysql_scalar() {
  local query="`$1"
  printf '%s\n' "`$query" | docker compose --env-file .env exec -T mysql sh -lc 'mysql -uroot -p"`$MYSQL_ROOT_PASSWORD" --batch --skip-column-names'
}

gorp_migrations_present="`$(run_mysql_scalar "select count(*) from information_schema.tables where table_schema = '`$database_name' and table_name = 'gorp_migrations';" | tr -d '[:space:]')"
required_tables_present="`$(run_mysql_scalar "select count(*) from information_schema.tables where table_schema = '`$database_name' and table_name in ('admin_audit_log', 'user_purge_job', 'user_purge_verification');" | tr -d '[:space:]')"
maintenance_columns_present="`$(run_mysql_scalar "select count(*) from information_schema.columns where table_schema = '`$database_name' and table_name = 'app_config' and column_name in ('maintenance_enabled', 'maintenance_title', 'maintenance_message');" | tr -d '[:space:]')"
required_indexes_present="`$(run_mysql_scalar "select count(*) from (select required.table_name, required.index_name, required.columns from (select 'admin_audit_log' table_name, 'admin_audit_log_target_idx' index_name, 'target_type,target_id,created_at' columns union all select 'admin_audit_log', 'admin_audit_log_operator_idx', 'operator_uid,created_at' union all select 'admin_audit_log', 'admin_audit_log_action_idx', 'action,created_at' union all select 'user_purge_job', 'user_purge_job_job_id_uidx', 'job_id' union all select 'user_purge_job', 'user_purge_job_uid_created_at_idx', 'uid,created_at' union all select 'user_purge_job', 'user_purge_job_operator_created_at_idx', 'operator_uid,created_at' union all select 'user_purge_verification', 'user_purge_verification_job_idx', 'job_id,created_at') required join (select table_name, index_name, group_concat(column_name order by seq_in_index) columns from information_schema.statistics where table_schema = '`$database_name' group by table_name, index_name) existing on existing.table_name = required.table_name and existing.index_name = required.index_name and existing.columns = required.columns) matched;" | tr -d '[:space:]')"
phase6_records_present="`$(run_mysql_scalar "select count(*) from `$database_name.gorp_migrations where id in ('common-20260520-01.sql', 'user-20260520-01.sql');" | tr -d '[:space:]')"

echo "gorp_migrations_present=`$gorp_migrations_present"
echo "required_tables_present=`$required_tables_present/3"
echo "maintenance_columns_present=`$maintenance_columns_present/3"
echo "required_indexes_present=`$required_indexes_present/7"
echo "phase6_records_present=`$phase6_records_present/2"

if [ "`$gorp_migrations_present" != '1' ] || [ "`$required_tables_present" != '0' ] || [ "`$maintenance_columns_present" != '0' ] || [ "`$required_indexes_present" != '0' ] || [ "`$phase6_records_present" != '0' ]; then
  echo 'phase6_migration_readiness=inconsistent_phase6_schema'
  exit 1
fi
echo 'phase6_migration_readiness=ready_for_phase6_migration'

sql_file="`$(mktemp)"
trap 'rm -f "`$sql_file"' EXIT
printf '%s\n' "`$migration_sql" > "`$sql_file"

echo "== applying phase6 migrations =="
docker compose --env-file .env exec -T mysql sh -lc 'mysql -uroot -p"`$MYSQL_ROOT_PASSWORD" "`$1"' sh "`$database_name" < "`$sql_file"
echo 'phase6_apply_migrations=applied'
"@

if ($applyScript -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') {
  throw 'Generated remote migration script contains unexpected control characters.'
}

if (-not $Run) {
  Write-Host 'Dry run only. Add -Run and -AllowProductionMigration to apply production migrations.'
  Write-Host "RemoteHost: $RemoteHost"
  Write-Host "RemoteRoot: $RemoteRoot"
  Write-Host "Database: $Database"
  Write-Host "BackupDir: $BackupDir"
  Write-Host ''
  Write-Host 'Commands that would run remotely:'
  $applyScript
  exit 0
}

if (-not $AllowProductionMigration) {
  throw 'Refusing to apply production migrations without -AllowProductionMigration. Re-run with -Run -AllowProductionMigration after explicit approval.'
}

Invoke-RemoteBash -Script $applyScript
