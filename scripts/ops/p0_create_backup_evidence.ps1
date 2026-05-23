param(
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
  [string]$BackupRoot = '/opt/wukongim-prod/backups',
  [string]$SysctlBackupRoot = '/var/backups/wukongim-sysctl',
  [string]$SshKeyPath = '',
  [switch]$Run,
  [switch]$AllowProductionWrites
)

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

  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = 'ssh'
  $startInfo.Arguments = (($sshArgs | ForEach-Object { Quote-ProcessArgument -Value $_ }) -join ' ')
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardInput = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true

  $process = New-Object System.Diagnostics.Process
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
    throw "Remote P0 backup evidence failed with exit code $($process.ExitCode)."
  }
}

$remoteRootArg = Quote-Bash -Value $RemoteRoot
$backupRootArg = Quote-Bash -Value $BackupRoot
$sysctlBackupRootArg = Quote-Bash -Value $SysctlBackupRoot

$backupScript = @"
set -euo pipefail
remote_root=$remoteRootArg
backup_root=$backupRootArg
sysctl_backup_root=$sysctlBackupRootArg

cd "`$remote_root"
umask 077
stamp="`$(date -u +%Y%m%dT%H%M%SZ)"
target_dir="`$backup_root/p0-readiness-`$stamp"
manifest="`$target_dir/backup_manifest.txt"

read_env_value() {
  local key="`$1"
  awk -v wanted_key="`$key" '
    /^[[:space:]]*#/ || `$0 !~ /=/ { next }
    {
      raw_key=`$0
      sub(/=.*/, "", raw_key)
      gsub(/^[[:space:]]+|[[:space:]]+`$/, "", raw_key)
      if (raw_key != wanted_key) { next }
      raw_value=`$0
      sub(/^[^=]*=/, "", raw_value)
      gsub(/^[[:space:]]+|[[:space:]]+`$/, "", raw_value)
      if ((substr(raw_value, 1, 1) == "\"" && substr(raw_value, length(raw_value), 1) == "\"") ||
          (substr(raw_value, 1, 1) == "'"'"'" && substr(raw_value, length(raw_value), 1) == "'"'"'")) {
        raw_value=substr(raw_value, 2, length(raw_value)-2)
      }
      print raw_value
      exit
    }
  ' .env
}

MYSQL_DATABASE="`$(read_env_value MYSQL_DATABASE)"
redis_auth="`$(read_env_value REDIS_PASSWORD)"
test -n "`$MYSQL_DATABASE"
test -n "`$redis_auth"
case "`$MYSQL_DATABASE" in
  *[!A-Za-z0-9_]*)
    echo "invalid_mysql_database=true"
    exit 1
    ;;
esac

if [ ! -d "`$backup_root" ]; then
  mkdir -p "`$backup_root" 2>/dev/null || sudo -n install -d -m 755 "`$backup_root"
fi
sudo -n install -d -m 700 -o "`$(id -u)" -g "`$(id -g)" "`$target_dir" "`$sysctl_backup_root"
chmod 700 "`$target_dir" "`$sysctl_backup_root"

{
  echo "backup_kind=p0-readiness"
  echo "created_at_utc=`$stamp"
  echo "target_dir=`$target_dir"
  echo "remote_root=`$remote_root"
  echo "mysql_database=`$MYSQL_DATABASE"
  echo "host=`$(hostname)"
  echo "kernel=`$(uname -sr)"
  echo "docker_compose_services_begin"
  docker compose --env-file .env ps --services | sort
  echo "docker_compose_services_end"
} > "`$manifest"

echo "mysql_backup_start=true"
docker compose --env-file .env exec -T mysql sh -lc \
  'exec mysqldump --single-transaction --quick --routines --events --triggers --set-gtid-purged=OFF -uroot -p"`$MYSQL_ROOT_PASSWORD" "`$1"' \
  sh "`$MYSQL_DATABASE" \
  </dev/null \
  | gzip -c > "`$target_dir/mysql-`$MYSQL_DATABASE.sql.gz"
test -s "`$target_dir/mysql-`$MYSQL_DATABASE.sql.gz"
sha256sum "`$target_dir/mysql-`$MYSQL_DATABASE.sql.gz" > "`$target_dir/mysql-`$MYSQL_DATABASE.sql.gz.sha256"
echo "mysql_backup_done=`$target_dir/mysql-`$MYSQL_DATABASE.sql.gz"

echo "redis_backup_start=true"
printf '%s\n' "`$redis_auth" | docker compose --env-file .env exec -T redis sh -lc \
  'IFS= read -r redis_auth; test -n "`$redis_auth"; REDISCLI_AUTH="`$redis_auth" exec redis-cli --rdb -' \
  > "`$target_dir/redis.rdb"
test -s "`$target_dir/redis.rdb"
sha256sum "`$target_dir/redis.rdb" > "`$target_dir/redis.rdb.sha256"
echo "redis_backup_done=`$target_dir/redis.rdb"

echo "runtime_config_archive_start=true"
tar \
  --exclude='./data' \
  --exclude='./logs' \
  --exclude='./nginx/html' \
  --exclude='./certbot' \
  --exclude='./rendered/coturn-certs' \
  -czf "`$target_dir/production-runtime-config.tar.gz" .
test -s "`$target_dir/production-runtime-config.tar.gz"
sha256sum "`$target_dir/production-runtime-config.tar.gz" > "`$target_dir/production-runtime-config.tar.gz.sha256"
echo "runtime_config_archive_done=`$target_dir/production-runtime-config.tar.gz"

echo "wukongim_data_archive_start=true"
tar -czf "`$target_dir/wukongim-data.tar.gz" -C "`$remote_root/data" wukongim
test -s "`$target_dir/wukongim-data.tar.gz"
sha256sum "`$target_dir/wukongim-data.tar.gz" > "`$target_dir/wukongim-data.tar.gz.sha256"
echo "wukongim_data_archive_done=`$target_dir/wukongim-data.tar.gz"

{
  echo "created_at_utc=`$stamp"
  sysctl -n net.core.somaxconn 2>/dev/null | sed 's/^/net.core.somaxconn=/'
  sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null | sed 's/^/net.ipv4.tcp_max_syn_backlog=/'
  sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null | sed 's/^/net.netfilter.nf_conntrack_max=/'
  ulimit -n | sed 's/^/nofile=/'
} > "`$sysctl_backup_root/p0-readiness-`$stamp.txt"
sha256sum "`$sysctl_backup_root/p0-readiness-`$stamp.txt" > "`$sysctl_backup_root/p0-readiness-`$stamp.txt.sha256"
echo "sysctl_backup_done=`$sysctl_backup_root/p0-readiness-`$stamp.txt"

find "`$target_dir" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort >> "`$manifest"
sha256sum "`$manifest" > "`$manifest.sha256"
chmod 600 "`$target_dir"/* "`$sysctl_backup_root/p0-readiness-`$stamp.txt" "`$sysctl_backup_root/p0-readiness-`$stamp.txt.sha256"

echo "backup_manifest.txt=`$manifest"
find "`$target_dir" -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' | sort
"@

if (-not $Run) {
  'Dry run only. Add -Run and -AllowProductionWrites to create production backup evidence.'
  "RemoteHost: $RemoteHost"
  "RemoteRoot: $RemoteRoot"
  "BackupRoot: $BackupRoot"
  "SysctlBackupRoot: $SysctlBackupRoot"
  ''
  'Commands that would run remotely:'
  $backupScript
  exit 0
}

if (-not $AllowProductionWrites) {
  throw 'Refusing to write production backups without -AllowProductionWrites. Re-run with -Run -AllowProductionWrites after explicit approval.'
}

Invoke-RemoteBash -Script $backupScript
