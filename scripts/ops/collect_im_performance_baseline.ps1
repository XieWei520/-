param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
  [string]$OutputDirectory = '',
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
  [switch]$SkipFlutterBuild,
  [switch]$SkipRemote
)

$ErrorActionPreference = 'Continue'

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $OutputDirectory = Join-Path $ProjectRoot "build\performance-baseline\$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Set-Location $ProjectRoot

function Redact-SensitiveText {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text
  )

  if ([string]::IsNullOrEmpty($Text)) {
    return $Text
  }

  $redacted = $Text

  function Redact-SensitiveValueMatch {
    param(
      [Parameter(Mandatory = $true)]$Match
    )

    $fieldName = $Match.Groups['field'].Value.ToLowerInvariant().Replace('-', '_').Replace('_', '')
    $isSafeMetadata = $fieldName -eq 'refreshtoken' -or
      $fieldName -eq 'tokenempty' -or
      $fieldName -eq 'tokenhash' -or
      $fieldName -eq 'tokenlength' -or
      $fieldName -eq 'tokenlen' -or
      $fieldName -eq 'tokensha256' -or
      $fieldName -eq 'tokensha256prefix'
    if ($isSafeMetadata) {
      return $Match.Value
    }

    $isSensitive = $fieldName.Contains('password') -or
      $fieldName.Contains('secret') -or
      $fieldName.Contains('credential') -or
      $fieldName.Contains('token') -or
      $fieldName.Contains('apikey') -or
      $fieldName.Contains('apisecret') -or
      $fieldName.Contains('pwd') -or
      $fieldName.Contains('dsn') -or
      $fieldName.Contains('key')
    if (!$isSensitive) {
      return $Match.Value
    }

    return "$($Match.Groups['prefix'].Value)<redacted>"
  }

  $structuredFieldBoundary = '\s+[A-Za-z_][A-Za-z0-9_-]*\s*[:=]'
  $sensitiveFieldPattern = '(?i)(?<![A-Za-z0-9_-])(?<prefix>"?(?<field>[A-Za-z_][A-Za-z0-9_-]*)"?\s*[:=]\s*)(?<value>"(?:\\.|[^"\\])*"|''(?:\\.|[^''\\])*''|(?:Bearer\s+)?[^\s,}\]]+)'
  $authHeaderRegex = '(?i)(?<![A-Za-z0-9_-])(?<prefix>"?Authorization"?\s*[:=]\s*)(?<value>"(?:\\.|[^"\\])*"|''(?:\\.|[^''\\])*''|[^\r\n]*)'
  $redacted = [regex]::Replace(
    $redacted,
    $authHeaderRegex,
    {
      param($Match)

      $value = $Match.Groups['value'].Value
      if ([string]::IsNullOrWhiteSpace($value)) {
        return $Match.Value
      }

      $trailingText = ''
      $isQuoted = $value.Length -ge 2 -and
        (($value[0] -eq '"' -and $value[$value.Length - 1] -eq '"') -or
         ($value[0] -eq "'" -and $value[$value.Length - 1] -eq "'"))
      if (!$isQuoted) {
        $boundary = [regex]::Match($value, $structuredFieldBoundary)
        if ($boundary.Success) {
          $trailingText = $value.Substring($boundary.Index)
          $value = $value.Substring(0, $boundary.Index)
        }
      }

      if (![string]::IsNullOrEmpty($trailingText)) {
        $trailingText = [regex]::Replace(
          $trailingText,
          $sensitiveFieldPattern,
          { param($TailMatch) Redact-SensitiveValueMatch -Match $TailMatch }
        )
      }

      return "$($Match.Groups['prefix'].Value)<redacted>$trailingText"
    }
  )

  $redacted = [regex]::Replace(
    $redacted,
    $sensitiveFieldPattern,
    { param($Match) Redact-SensitiveValueMatch -Match $Match }
  )

  return $redacted
}

function Write-RedactedContent {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
    [switch]$Append
  )

  $redactedText = Redact-SensitiveText -Text $Text
  if ($Append) {
    $redactedText | Add-Content -Path $Path -Encoding UTF8
    return
  }

  $redactedText | Set-Content -Path $Path -Encoding UTF8
}

function Invoke-Capture {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )

  $target = Join-Path $OutputDirectory "$Name.txt"
  Write-RedactedContent -Path $target -Text "## $Name"
  Write-RedactedContent -Path $target -Text "## started: $(Get-Date -Format o)" -Append
  try {
    $commandOutput = & $Command 2>&1 | Out-String
    Write-RedactedContent -Path $target -Text $commandOutput -Append
    Write-RedactedContent -Path $target -Text "## exit: $LASTEXITCODE" -Append
  } catch {
    Write-RedactedContent -Path $target -Text "## error: $($_.Exception.Message)" -Append
  }
  Write-RedactedContent -Path $target -Text "## finished: $(Get-Date -Format o)" -Append
}

function Quote-Bash {
  param([Parameter(Mandatory = $true)][string]$Value)

  $single = [string][char]39
  $double = [string][char]34
  $replacement = $single + $double + $single + $double + $single
  return $single + $Value.Replace($single, $replacement) + $single
}

function Write-DirectorySize {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $target = Join-Path $OutputDirectory "$Name.txt"
  if (!(Test-Path $Path)) {
    Write-RedactedContent -Path $target -Text "$Path does not exist"
    return
  }

  $directorySizeOutput = Get-ChildItem -Path $Path -Recurse -File |
    Sort-Object Length -Descending |
    Select-Object -First 80 FullName, Length |
    Format-Table -AutoSize |
    Out-String

  Write-RedactedContent -Path $target -Text $directorySizeOutput
}

Invoke-Capture -Name 'local_git_status' -Command { git status --short --branch }
Invoke-Capture -Name 'flutter_version' -Command { flutter --version }
Invoke-Capture -Name 'flutter_analyze' -Command { flutter analyze }
Invoke-Capture -Name 'flutter_test_smoke' -Command {
  flutter test `
    test/web_dependency_wasm_policy_test.dart `
    test/platform_geolocator_boundary_test.dart `
    test/web_entrypoint_cache_cleanup_test.dart `
    test/web_pwa_service_worker_test.dart `
    test/app/navigation/app_router_test.dart `
    test/app/navigation/app_push_route_bridge_test.dart `
    test/wukong_push/push_service_notification_tap_test.dart `
    test/wukong_push/foreground_notification_plan_test.dart `
    test/wukong_push/push_payload_test.dart `
    test/wukong_push/browser_notification_service_test.dart `
    test/wukong_push/device_badge_service_test.dart `
    test/wukong_push/browser_notification_click_bridge_test.dart `
    test/realtime/session/session_runtime_test.dart `
    test/realtime/telemetry/realtime_rollout_telemetry_test.dart `
    test/app/bootstrap/app_startup_test.dart `
    test/core/cache/media_cache_manager_test.dart `
    test/core/utils/platform_utils_test.dart `
    test/core/utils/qr_export_file_naming_test.dart `
    test/widgets/local_media_image_provider_test.dart `
    test/wukong_base/utils/download_manager_naming_test.dart `
    test/wukong_base/utils/wk_file_utils_test.dart `
    test/wukong_scan/scan_webview_page_test.dart `
    test/wukong_scan/scan_qr_code_image_io_test.dart `
    test/wukong_scan/scan_qr_code_image_stub_test.dart `
    test/modules/chat/chat_viewport_controller_test.dart `
    test/modules/chat/chat_scroll_pagination_test.dart `
    test/modules/chat/chat_desktop_drop_target_test.dart `
    test/modules/chat/chat_media_action_service_test.dart `
    test/modules/chat/chat_image_bytes_loader_io_test.dart `
    test/modules/chat/chat_file_opening_test.dart `
    test/service/api/file_api_test.dart `
    test/service/im/im_service_test.dart `
    test/service/im/local_attachment_file_io_test.dart `
    test/modules/settings/cache_clean_service_test.dart `
    test/modules/settings/backup_restore_message_service_test.dart `
    test/modules/video_call/livekit_call_media_engine_test.dart `
    test/modules/video_call/call_session_service_test.dart `
    test/modules/video_call/call_bootstrap_api_test.dart `
    test/modules/video_call/call_realtime_client_test.dart `
    test/modules/conversation/conversation_metadata_resolver_test.dart `
    test/modules/conversation/conversation_list_item_loader_test.dart `
    test/data/providers/conversation_provider_test.dart `
    test/scripts/ops/flutter_web_release_prune_test.dart `
    test/scripts/ops/flutter_web_release_deploy_test.dart `
    test/scripts/ops/nginx_edge_optimizations_test.dart `
    test/scripts/ops/collect_im_performance_baseline_test.dart
}

if (!$SkipFlutterBuild) {
  Invoke-Capture -Name 'flutter_build_web' -Command { flutter build web --release }
  Invoke-Capture -Name 'flutter_build_web_wasm' -Command { flutter build web --wasm --release }
  Invoke-Capture -Name 'flutter_web_prune_dry_run' -Command {
    powershell -NoProfile -ExecutionPolicy Bypass `
      -File (Join-Path $ProjectRoot 'scripts/ops/prune_flutter_web_release.ps1') `
      -BuildWebDir (Join-Path $ProjectRoot 'build/web') `
      -DryRun
  }
  Write-DirectorySize -Name 'artifact_build_web_largest_files' -Path (Join-Path $ProjectRoot 'build/web')
  Write-DirectorySize -Name 'artifact_android_apk_largest_files' -Path (Join-Path $ProjectRoot 'build/app/outputs/flutter-apk')
  Write-DirectorySize -Name 'artifact_windows_largest_files' -Path (Join-Path $ProjectRoot 'build/windows')
}

if (!$SkipRemote) {
  Invoke-Capture -Name 'remote_host_runtime' -Command {
    ssh $RemoteHost "date -Is; uptime; free -h; df -h; ss -s"
  }
  Invoke-Capture -Name 'remote_docker_status' -Command {
    ssh $RemoteHost "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'; docker stats --no-stream"
  }
  Invoke-Capture -Name 'remote_nginx_config' -Command {
    ssh $RemoteHost "docker exec wukongim-prod-nginx nginx -T 2>&1 | sed -n '1,260p'"
  }
  Invoke-Capture -Name 'remote_public_web_smoke' -Command {
    $remoteRootArg = Quote-Bash -Value $RemoteRoot
    $remoteCommand = @"
set -e
cd $remoteRootArg
public_domain=`$(grep -E '^PUBLIC_DOMAIN=' .env | head -n1 | cut -d= -f2- | tr -d '"')
test -n "`$public_domain"
curl -k -fsSI "https://`$public_domain/index.html" | sed -n '1,16p'
curl -k -fsSI "https://`$public_domain/flutter_bootstrap.js" | sed -n '1,16p'
curl -k -fsSI "https://`$public_domain/wk_pwa_service_worker.js" | sed -n '1,16p'
curl -k -fsSI "https://`$public_domain/manifest.json" | sed -n '1,16p'
"@
    ssh $RemoteHost "bash -lc $(Quote-Bash -Value $remoteCommand)"
  }
  Invoke-Capture -Name 'remote_websocket_handshake' -Command {
    $remoteRootArg = Quote-Bash -Value $RemoteRoot
    $remoteCommand = @"
set -e
cd $remoteRootArg
public_domain=`$(grep -E '^PUBLIC_DOMAIN=' .env | head -n1 | cut -d= -f2- | tr -d '"')
test -n "`$public_domain"
response_file=`$(mktemp)
curl_status=0
curl -k --http1.1 --max-time 8 -i \
  -H 'Connection: Upgrade' \
  -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  -H 'Sec-WebSocket-Version: 13' \
  "https://`$public_domain/ws" > "`$response_file" 2>&1 || curl_status=`$?
sed -n '1,24p' "`$response_file"
grep -q '101 Switching Protocols' "`$response_file"
rm -f "`$response_file"
if [ "`$curl_status" -ne 0 ] && [ "`$curl_status" -ne 52 ]; then
  exit "`$curl_status"
fi
"@
    ssh $RemoteHost "bash -lc $(Quote-Bash -Value $remoteCommand)"
  }
  Invoke-Capture -Name 'remote_wukongim_health_varz' -Command {
    ssh $RemoteHost "curl -fsS http://127.0.0.1:5001/health; echo; curl -fsS http://127.0.0.1:5001/varz"
  }
  Invoke-Capture -Name 'remote_recent_nginx_log' -Command {
    ssh $RemoteHost "docker logs --since 30m --tail 300 wukongim-prod-nginx 2>&1"
  }
  Invoke-Capture -Name 'remote_recent_api_log' -Command {
    ssh $RemoteHost "docker logs --since 30m --tail 300 wukongim-prod-tsdd-api 2>&1"
  }
}

"Baseline written to $OutputDirectory"
