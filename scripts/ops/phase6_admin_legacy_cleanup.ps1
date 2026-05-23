[CmdletBinding()]
param(
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
  [string]$ReleaseBaseUrl = 'https://infoequity.cn',
  [string]$LegacyContainerName = 'wukongim_prod-admin-nginx-1',
  [int]$ProbeTimeoutSeconds = 10,
  [string]$SshKeyPath = '',
  [switch]$Run,
  [switch]$AllowAdminCutover,
  [switch]$AllowLegacyAdminCleanup
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
    throw "Remote Phase 6 admin legacy cleanup command failed with exit code $($process.ExitCode)."
  }
}

if ($ProbeTimeoutSeconds -lt 1) {
  throw 'ProbeTimeoutSeconds must be at least 1.'
}
$remoteRootArg = Quote-Bash -Value $RemoteRoot
$releaseBaseUrlArg = Quote-Bash -Value $ReleaseBaseUrl
$legacyContainerArg = Quote-Bash -Value $LegacyContainerName

$planScript = @"
set -euo pipefail
remote_root=$remoteRootArg
release_base_url=$releaseBaseUrlArg
legacy_container=$legacyContainerArg
probe_timeout='$ProbeTimeoutSeconds'

release_base_url="`$(printf '%s' "`$release_base_url" | sed 's#/*`$##')"
cd "`$remote_root"
test -f .env

echo '== current admin route =='
docker compose --env-file .env config --services | sort | sed 's/^/compose_service=/'
docker ps --filter "name=`$legacy_container" --format 'legacy_container={{.Names}} image={{.Image}} status={{.Status}} ports={{.Ports}}' || true
if docker inspect "`$legacy_container" >/dev/null 2>&1; then
  docker inspect "`$legacy_container" | python3 -c 'import json,sys
d=json.load(sys.stdin)[0]
print("legacy_name=" + d["Name"])
print("legacy_image=" + d["Config"]["Image"])
print("legacy_created=" + d["Created"])
print("legacy_restart=" + d["HostConfig"]["RestartPolicy"]["Name"])
for m in d.get("Mounts", []):
    print("legacy_mount=" + m.get("Source", "") + "->" + m.get("Destination", ""))'
else
  echo 'legacy_container_missing=1'
fi

echo '== nginx admin references =='
docker exec "`$(docker compose --env-file .env ps -q nginx)" nginx -T 2>/dev/null | grep -n -E 'admin_nginx|/admin/|proxy_pass http://admin_nginx' || true

echo '== candidate admin static assets =='
for path in admin-custom/dist admin-src/dist admin/dist manager/dist; do
  if [ -f "`$path/index.html" ]; then
    printf 'candidate=%s index_bytes=%s mtime=%s\n' "`$path" "`$(wc -c < "`$path/index.html")" "`$(date -r "`$path/index.html" -Is)"
  else
    printf 'candidate_missing=%s\n' "`$path"
  fi
done
curl -fsS --max-time "`$probe_timeout" "`$release_base_url/admin/" >/dev/null
echo 'phase6_admin_legacy_cleanup=plan_only'
"@

$cutoverScript = @"
set -euo pipefail
remote_root=$remoteRootArg
release_base_url=$releaseBaseUrlArg
legacy_container=$legacyContainerArg
probe_timeout='$ProbeTimeoutSeconds'

release_base_url="`$(printf '%s' "`$release_base_url" | sed 's#/*`$##')"
cd "`$remote_root"
test -f .env
test -d admin-custom/dist
test -f admin-custom/dist/index.html
test -f nginx/default.conf.template

timestamp="`$(date +%Y%m%dT%H%M%S%z)"
backup_dir="`$remote_root/backups/phase6-admin-cleanup/`$timestamp"
mkdir -p "`$backup_dir"
cp -p nginx/default.conf.template "`$backup_dir/default.conf.template.before-admin-cutover"
tar -C "`$remote_root" -czf "`$backup_dir/admin-custom-before-cleanup.tar.gz" admin-custom

python3 - "`$remote_root/nginx/default.conf.template" "`$remote_root/nginx/default.conf.template.next" <<'PY'
import re
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
text = source.read_text(encoding='utf-8')
text = re.sub(
    r'upstream admin_nginx \{\n\s*server admin-nginx:80;\n\s*keepalive 16;\n\}\n\n',
    '',
    text,
    count=1,
)
admin_static = r'''
    location = /admin {
        return 308 /admin/;
    }

    location = /admin/logo.png {
        root /usr/share/nginx/html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-cache, must-revalidate" always;
        try_files /admin/logo.png =404;
    }

    location ^~ /admin/admin/static/ {
        rewrite ^/admin/admin/static/(.*)`$ /admin/static/`$1 break;
        root /usr/share/nginx/html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-cache, must-revalidate" always;
        try_files `$uri =404;
    }

    location ^~ /admin/static/ {
        root /usr/share/nginx/html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-cache, must-revalidate" always;
        try_files `$uri =404;
    }

    location ^~ /admin/ {
        root /usr/share/nginx/html;
        index index.html;
        proxy_set_header Accept-Encoding "";
        sub_filter_once off;
        sub_filter_types text/css application/javascript;
        sub_filter 'href="/logo.png"' 'href="/admin/logo.png"';
        sub_filter 'src="/static/' 'src="/admin/static/';
        sub_filter 'href="/static/' 'href="/admin/static/';
        sub_filter '"/static/' '"/admin/static/';
        sub_filter '"static/' '"admin/static/';
        sub_filter 'url(/static/' 'url(/admin/static/';
        sub_filter 'const SY=function(e){return"/"+e}' 'const SY=function(e){return"/admin/"+e}';
        sub_filter 'SY=function(e){return"/"+e}' 'SY=function(e){return e[0]==="/"?e:"/admin/"+e}';
        sub_filter 'history:v4()' 'history:v4("/admin/")';
        sub_filter 'history:y4()' 'history:y4("/admin/")';
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-cache, must-revalidate" always;
        try_files `$uri `$uri/ /admin/index.html;
    }

'''
pattern = re.compile(
    r'    location = /admin \{\n'
    r'        return 308 /admin/;\n'
    r'    \}\n\n'
    r'    location \^~ /admin/admin/static/ \{.*?\n'
    r'    \}\n\n\n'
    r'    location \^~ /admin/ \{.*?\n'
    r'    \}\n\n',
    re.S,
)
text, count = pattern.subn(admin_static, text, count=1)
if count != 1:
    raise SystemExit('admin proxy block was not replaced exactly once')
if 'proxy_pass http://admin_nginx' in text or 'upstream admin_nginx' in text:
    raise SystemExit('admin_nginx references remain after rewrite')
target.write_text(text, encoding='utf-8')
PY

mkdir -p nginx/html/admin
tar -C admin-custom/dist -cf - . | tar -C nginx/html/admin -xf -
mv nginx/default.conf.template.next nginx/default.conf.template
docker compose --env-file .env up -d --no-deps --force-recreate nginx
nginx_container_id="`$(docker compose --env-file .env ps -q nginx)"
docker exec "`$nginx_container_id" nginx -t
docker exec "`$nginx_container_id" nginx -s reload
curl -fsS --max-time "`$probe_timeout" "`$release_base_url/admin/" >/dev/null
curl -fsS --max-time "`$probe_timeout" "`$release_base_url/v1/ping" >/dev/null
if docker exec "`$nginx_container_id" nginx -T 2>/dev/null | grep -q 'admin_nginx'; then
  echo 'admin_nginx_reference_still_present=1' >&2
  exit 1
fi
echo "phase6_admin_cutover_backup_dir=`$backup_dir"
echo 'phase6_admin_legacy_cleanup=cutover_completed'
"@

$cleanupScript = @"
set -euo pipefail
remote_root=$remoteRootArg
release_base_url=$releaseBaseUrlArg
legacy_container=$legacyContainerArg
probe_timeout='$ProbeTimeoutSeconds'

release_base_url="`$(printf '%s' "`$release_base_url" | sed 's#/*`$##')"
cd "`$remote_root"
nginx_container_id="`$(docker compose --env-file .env ps -q nginx)"
if docker exec "`$nginx_container_id" nginx -T 2>/dev/null | grep -q 'admin_nginx'; then
  echo 'refusing_cleanup_admin_nginx_still_in_nginx_config=1' >&2
  exit 1
fi
curl -fsS --max-time "`$probe_timeout" "`$release_base_url/admin/" >/dev/null
curl -fsS --max-time "`$probe_timeout" "`$release_base_url/v1/ping" >/dev/null

timestamp="`$(date +%Y%m%dT%H%M%S%z)"
archive_dir="`$remote_root/backups/phase6-admin-cleanup/legacy-archive-`$timestamp"
mkdir -p "`$archive_dir"
if docker inspect "`$legacy_container" >/dev/null 2>&1; then
  docker inspect "`$legacy_container" > "`$archive_dir/legacy-container.inspect.json"
  docker stop "`$legacy_container"
  docker rm "`$legacy_container"
fi
for path in admin admin-src admin-custom manager; do
  if [ -e "`$path" ]; then
    tar -C "`$remote_root" -czf "`$archive_dir/`$path.tar.gz" "`$path"
    mv "`$path" "`$archive_dir/`$path.removed"
  fi
done
echo "phase6_admin_legacy_archive_dir=`$archive_dir"
echo 'phase6_admin_legacy_cleanup=cleanup_completed'
"@

if (-not $Run) {
  Write-Host 'Dry run only. Add -Run to inspect legacy admin cleanup plan.'
  Write-Host 'Add -Run -AllowAdminCutover to cut /admin/ over from legacy admin-nginx to main nginx static assets.'
  Write-Host 'Add -Run -AllowAdminCutover -AllowLegacyAdminCleanup to stop/remove the legacy admin-nginx container and archive old admin directories.'
  Write-Host "RemoteHost: $RemoteHost"
  Write-Host "RemoteRoot: $RemoteRoot"
  Write-Host "ReleaseBaseUrl: $ReleaseBaseUrl"
  Write-Host "LegacyContainerName: $LegacyContainerName"
  Write-Host 'Legacy static path: admin-custom/dist'
  Write-Host ''
  Write-Host 'Read-only plan script:'
  $planScript
  exit 0
}

if (-not $AllowAdminCutover -and -not $AllowLegacyAdminCleanup) {
  Invoke-RemoteBash -Script $planScript
  exit 0
}

if ($AllowAdminCutover) {
  Invoke-RemoteBash -Script $cutoverScript
}

if ($AllowLegacyAdminCleanup) {
  Invoke-RemoteBash -Script $cleanupScript
} else {
  Write-Host 'Legacy admin cleanup skipped. Add -AllowLegacyAdminCleanup after verifying /admin/ works through main nginx.'
}
