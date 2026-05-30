[CmdletBinding()]
param(
    [string]$Server = 'ubuntu@42.194.218.158',
    [string]$WebImDir = 'web_im',
    [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
    [string]$ApiBaseUrl = 'https://infoequity.cn',
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

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Operation,
        [Parameter(Mandatory = $true)][string]$Description,
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 2
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            & $Operation
            return
        } catch {
            if ($attempt -ge $MaxAttempts) {
                throw
            }
            Write-Warning "$Description failed on attempt $attempt/$MaxAttempts. Retrying in $DelaySeconds second(s). $($_.Exception.Message)"
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Invoke-Ssh {
    param([Parameter(Mandatory = $true)][string]$Command)
    Invoke-WithRetry -Description "ssh command" -Operation {
        $sshArgs = @((Get-SshOptions) + @($Server, $Command))
        & ssh @sshArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Remote command failed: $Command"
        }
    }
}

function Copy-ToRemote {
    param(
        [Parameter(Mandatory = $true)][string]$LocalPath,
        [Parameter(Mandatory = $true)][string]$RemotePath
    )

    Invoke-WithRetry -Description "scp upload" -Operation {
        $scpArgs = @((Get-SshOptions) + @($LocalPath, "$Server`:$RemotePath"))
        & scp @scpArgs
        if ($LASTEXITCODE -ne 0) {
            throw "scp failed while copying '$LocalPath' to '$RemotePath'."
        }
    }
}

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$resolvedWebImDir = (Resolve-Path -LiteralPath (Join-Path $root $WebImDir)).Path
$buildScript = Join-Path -Path $PSScriptRoot -ChildPath 'build_web_im_release.ps1'
if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
    throw "Missing Web IM release builder: $buildScript"
}

$previousMode = $env:VITE_WK_WEB_IM_MODE
$previousApiBaseUrl = $env:VITE_WK_API_BASE_URL
try {
    Write-Host "[STEP] Building Web IM live release"
    $env:VITE_WK_WEB_IM_MODE = 'live'
    $env:VITE_WK_API_BASE_URL = $ApiBaseUrl
    & powershell -NoProfile -ExecutionPolicy Bypass -File $buildScript -WebImDir $WebImDir
    if ($LASTEXITCODE -ne 0) {
        throw "Web IM release build failed for '$resolvedWebImDir'."
    }
}
finally {
    $env:VITE_WK_WEB_IM_MODE = $previousMode
    $env:VITE_WK_API_BASE_URL = $previousApiBaseUrl
}

$dist = Join-Path -Path $resolvedWebImDir -ChildPath 'dist'
foreach ($required in @('index.html', 'manifest.webmanifest', 'sw.js', 'offline.html')) {
    $requiredPath = Join-Path -Path $dist -ChildPath $required
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Missing required Web IM release file: $requiredPath"
    }
}

$timestamp = Get-Date -Format 'yyyyMMddHHmmss'
$archive = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "wukong-web-im-$timestamp.tar.gz"
$localRemoteScript = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "wukong-web-im-deploy-$timestamp.sh"
$remoteArchive = "/tmp/wukong-web-im-$timestamp.tar.gz"
$remoteScript = "/tmp/wukong-web-im-deploy-$timestamp.sh"

try {
    Write-Host "[STEP] Packing Web IM release"
    & tar -C $dist -czf $archive .
    if ($LASTEXITCODE -ne 0) {
        throw "tar failed while packing '$dist'."
    }

    Write-Host "[STEP] Uploading Web IM release"
    Copy-ToRemote -LocalPath $archive -RemotePath $remoteArchive

    $remoteTemplate = @'
set -euo pipefail
REMOTE_ROOT=__REMOTE_ROOT__
ARCHIVE=__ARCHIVE__
TIMESTAMP=__TIMESTAMP__
RELEASE_DIR="${REMOTE_ROOT}/nginx/html/im"
TMP_DIR="${REMOTE_ROOT}/nginx/html.__web_im_tmp_${TIMESTAMP}"
BACKUP_DIR="${REMOTE_ROOT}/backup/web-im-release-${TIMESTAMP}"
COMPOSE_PATH="${REMOTE_ROOT}/docker-compose.yaml"
NGINX_TEMPLATE="${REMOTE_ROOT}/nginx/default.conf.template"

cd "${REMOTE_ROOT}"
mkdir -p "${BACKUP_DIR}" "${REMOTE_ROOT}/nginx/html"
cp "${COMPOSE_PATH}" "${BACKUP_DIR}/docker-compose.yaml"
cp "${NGINX_TEMPLATE}" "${BACKUP_DIR}/default.conf.template"
if [[ -d "${RELEASE_DIR}" ]]; then
  cp -a "${RELEASE_DIR}" "${BACKUP_DIR}/im"
else
  touch "${BACKUP_DIR}/im.absent"
fi

restore_from_backup() {
  cp "${BACKUP_DIR}/docker-compose.yaml" "${COMPOSE_PATH}"
  cp "${BACKUP_DIR}/default.conf.template" "${NGINX_TEMPLATE}"
  rm -rf "${RELEASE_DIR}" "${TMP_DIR}"
  if [[ -d "${BACKUP_DIR}/im" ]]; then
    cp -a "${BACKUP_DIR}/im" "${RELEASE_DIR}"
  fi
}

rollback_needed=1
trap 'if [[ "${rollback_needed}" -eq 1 ]]; then echo "Deploy failed; restoring previous Web IM release." >&2; restore_from_backup; docker compose --env-file .env up -d --no-deps --force-recreate nginx || true; fi' ERR

rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"
tar -xzf "${ARCHIVE}" -C "${TMP_DIR}"
test -f "${TMP_DIR}/index.html"
test -f "${TMP_DIR}/manifest.webmanifest"
test -f "${TMP_DIR}/sw.js"
test -f "${TMP_DIR}/offline.html"

python3 - "${NGINX_TEMPLATE}" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
template = path.read_text(encoding="utf-8")
begin = "    # BEGIN WEB_IM_GRAY_RELEASE"
end = "    # END WEB_IM_GRAY_RELEASE"
block = """    # BEGIN WEB_IM_GRAY_RELEASE
    location = /im {
        return 308 /im/;
    }

    location = /im/ {
        root /usr/share/nginx/html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0" always;
        try_files /im/index.html =404;
    }

    location = /im/index.html {
        root /usr/share/nginx/html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0" always;
        try_files /im/index.html =404;
    }

    location = /im/sw.js {
        root /usr/share/nginx/html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0" always;
        try_files /im/sw.js =404;
    }

    location = /im/manifest.webmanifest {
        root /usr/share/nginx/html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-cache, must-revalidate" always;
        try_files /im/manifest.webmanifest =404;
    }

    location = /im/offline.html {
        root /usr/share/nginx/html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0" always;
        try_files /im/offline.html =404;
    }

    location ^~ /im/assets/ {
        root /usr/share/nginx/html;
        access_log off;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "public, max-age=31536000, immutable" always;
        try_files $uri =404;
    }

    location ^~ /im/icons/ {
        root /usr/share/nginx/html;
        access_log off;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "public, max-age=86400" always;
        try_files $uri =404;
    }

    location ^~ /im/ {
        root /usr/share/nginx/html;
        index index.html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-cache, must-revalidate" always;
        try_files $uri $uri/ /im/index.html;
    }
    # END WEB_IM_GRAY_RELEASE
"""

if begin in template:
    start = template.index(begin)
    stop = template.index(end, start) + len(end)
    if stop < len(template) and template[stop:stop + 1] == "\n":
        stop += 1
    template = template[:start] + block + template[stop:]
else:
    anchor = "    location = /index.html {"
    index = template.find(anchor)
    if index < 0:
        raise SystemExit("Could not find Flutter root index location in nginx template")
    template = template[:index] + block + "\n" + template[index:]

path.write_text(template, encoding="utf-8")
PY

rm -rf "${RELEASE_DIR}.previous"
if [[ -d "${RELEASE_DIR}" ]]; then
  mv "${RELEASE_DIR}" "${RELEASE_DIR}.previous"
fi
mv "${TMP_DIR}" "${RELEASE_DIR}"
rm -rf "${RELEASE_DIR}.previous"

docker compose --env-file .env config -q
docker compose --env-file .env up -d --no-deps --force-recreate nginx
container_id="$(docker compose --env-file .env ps -q nginx)"
docker exec "${container_id}" nginx -t

public_domain="$(grep -E '^PUBLIC_DOMAIN=' .env | head -n1 | cut -d= -f2- | tr -d '"')"
if [[ -n "${public_domain}" ]]; then
  curl -k -fsSI "https://${public_domain}/im/" | sed -n '1,12p'
  curl -k -fsSI "https://${public_domain}/im/sw.js" | sed -n '1,12p'
  curl -k -fsSI "https://${public_domain}/im/manifest.webmanifest" | sed -n '1,12p'
  echo "WEB_IM_CANARY_URL=https://${public_domain}/im/"
fi

rm -f "${ARCHIVE}" "$0" || true
rollback_needed=0
echo "ROLLBACK_HINT=ssh __SERVER__ 'cd ${REMOTE_ROOT} && cp ${BACKUP_DIR}/docker-compose.yaml docker-compose.yaml && cp ${BACKUP_DIR}/default.conf.template nginx/default.conf.template && rm -rf nginx/html/im && if [ -d ${BACKUP_DIR}/im ]; then cp -a ${BACKUP_DIR}/im nginx/html/im; fi && docker compose --env-file .env up -d --no-deps --force-recreate nginx'"
echo "Web IM canary release deployed. Backup: ${BACKUP_DIR}"
'@

    $remoteCommand = $remoteTemplate.
        Replace('__REMOTE_ROOT__', (Quote-Bash -Value $RemoteRoot)).
        Replace('__ARCHIVE__', (Quote-Bash -Value $remoteArchive)).
        Replace('__TIMESTAMP__', (Quote-Bash -Value $timestamp)).
        Replace('__SERVER__', $Server)
    $remoteCommand = $remoteCommand -replace "`r`n", "`n"
    $remoteCommand = $remoteCommand -replace "`r", "`n"

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($localRemoteScript, $remoteCommand, $utf8NoBom)
    Copy-ToRemote -LocalPath $localRemoteScript -RemotePath $remoteScript

    Write-Host "[STEP] Installing Web IM canary release on remote nginx"
    Invoke-Ssh -Command "bash $(Quote-Bash -Value $remoteScript)"
}
finally {
    if (Test-Path -LiteralPath $archive) {
        Remove-Item -LiteralPath $archive -Force
    }
    if (Test-Path -LiteralPath $localRemoteScript) {
        Remove-Item -LiteralPath $localRemoteScript -Force
    }
}
