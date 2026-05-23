[CmdletBinding()]
param(
    [string]$Server = 'ubuntu@42.194.218.158',
    [string]$BuildWebDir = 'build\web',
    [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
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

$resolvedBuildDir = (Resolve-Path -LiteralPath $BuildWebDir).Path
foreach ($required in @('index.html', 'flutter_bootstrap.js', 'manifest.json')) {
    $requiredPath = Join-Path -Path $resolvedBuildDir -ChildPath $required
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Missing required web release file: $requiredPath"
    }
}

$pruneScript = Join-Path -Path $PSScriptRoot -ChildPath 'prune_flutter_web_release.ps1'
if (-not (Test-Path -LiteralPath $pruneScript -PathType Leaf)) {
    throw "Missing Flutter Web release pruner: $pruneScript"
}

Write-Host "[STEP] Pruning Flutter Web release artifacts"
& powershell -NoProfile -ExecutionPolicy Bypass -File $pruneScript -BuildWebDir $resolvedBuildDir
if ($LASTEXITCODE -ne 0) {
    throw "Flutter Web release pruning failed for '$resolvedBuildDir'."
}

$timestamp = Get-Date -Format 'yyyyMMddHHmmss'
$archive = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "wukong-flutter-web-$timestamp.tar.gz"
$localRemoteScript = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "wukong-flutter-web-deploy-$timestamp.sh"
$remoteArchive = "/tmp/wukong-flutter-web-$timestamp.tar.gz"
$remoteScript = "/tmp/wukong-flutter-web-deploy-$timestamp.sh"

try {
    Write-Host "[STEP] Packing Flutter Web release"
    & tar -C $resolvedBuildDir -czf $archive .
    if ($LASTEXITCODE -ne 0) {
        throw "tar failed while packing '$resolvedBuildDir'."
    }

    Write-Host "[STEP] Uploading Flutter Web release"
    Copy-ToRemote -LocalPath $archive -RemotePath $remoteArchive

    $remoteTemplate = @'
set -euo pipefail
REMOTE_ROOT=__REMOTE_ROOT__
ARCHIVE=__ARCHIVE__
TIMESTAMP=__TIMESTAMP__
RELEASE_DIR="${REMOTE_ROOT}/nginx/html"
TMP_DIR="${REMOTE_ROOT}/nginx/html.__deploy_tmp_${TIMESTAMP}"
BACKUP_DIR="${REMOTE_ROOT}/backup/web-release-${TIMESTAMP}"
COMPOSE_PATH="${REMOTE_ROOT}/docker-compose.yaml"

cd "${REMOTE_ROOT}"
mkdir -p "${BACKUP_DIR}"
cp "${COMPOSE_PATH}" "${BACKUP_DIR}/docker-compose.yaml"
if [[ -d "${RELEASE_DIR}" ]]; then
  cp -a "${RELEASE_DIR}" "${BACKUP_DIR}/html"
else
  touch "${BACKUP_DIR}/html.absent"
fi

restore_from_backup() {
  cp "${BACKUP_DIR}/docker-compose.yaml" "${COMPOSE_PATH}"
  rm -rf "${RELEASE_DIR}" "${TMP_DIR}"
  if [[ -d "${BACKUP_DIR}/html" ]]; then
    cp -a "${BACKUP_DIR}/html" "${RELEASE_DIR}"
  fi
}

rollback_needed=1
trap 'if [[ "${rollback_needed}" -eq 1 ]]; then echo "Deploy failed; restoring previous web release." >&2; restore_from_backup; docker compose --env-file .env up -d --no-deps --force-recreate nginx || true; fi' ERR

rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"
tar -xzf "${ARCHIVE}" -C "${TMP_DIR}"
test -f "${TMP_DIR}/index.html"
test -f "${TMP_DIR}/flutter_bootstrap.js"
test -f "${TMP_DIR}/manifest.json"
test -f "${TMP_DIR}/wk_pwa_service_worker.js"
test -f "${TMP_DIR}/offline.html"

python3 - "${COMPOSE_PATH}" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
compose = path.read_text(encoding="utf-8")
mount = "      - ./nginx/html:/usr/share/nginx/html:ro"
anchor = "      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro"
if mount not in compose:
    if anchor not in compose:
        raise SystemExit("nginx.conf mount not found in docker-compose.yaml")
    compose = compose.replace(anchor, f"{mount}\n{anchor}")
    path.write_text(compose, encoding="utf-8")
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

public_domain="$(grep -E '^PUBLIC_DOMAIN=' .env | head -n1 | cut -d= -f2- | tr -d '\"')"
if [[ -n "${public_domain}" ]]; then
  curl -k -fsSI "https://${public_domain}/index.html" | sed -n '1,12p'
  curl -k -fsSI "https://${public_domain}/wk_pwa_service_worker.js" | sed -n '1,12p'
fi

rm -f "${ARCHIVE}" "$0" || true
rollback_needed=0
echo "ROLLBACK_HINT=ssh __SERVER__ 'cd ${REMOTE_ROOT} && cp ${BACKUP_DIR}/docker-compose.yaml docker-compose.yaml && rm -rf nginx/html && if [ -d ${BACKUP_DIR}/html ]; then cp -a ${BACKUP_DIR}/html nginx/html; fi && docker compose --env-file .env up -d --no-deps --force-recreate nginx'"
echo "Flutter Web release deployed. Backup: ${BACKUP_DIR}"
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

    Write-Host "[STEP] Installing Flutter Web release on remote nginx"
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
