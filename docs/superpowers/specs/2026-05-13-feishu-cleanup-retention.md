# Spec: Feishu Forwarding Cleanup Retention

Date: 2026-05-13

## Objective

Limit storage growth caused by Feishu forwarding.

Success criteria:

- Feishu-forwarded WuKongIM text and image messages are sent with a 6 hour message expiration value.
- Normal chat sends and manual forwards keep the existing non-expiring default.
- Local shell capture records for message candidates and normalized recent events are pruned after 24 hours.
- Pruning happens automatically during normal shell store load/save/update operations.
- Shell network capture diagnostics (`network.jsonl`) and cached network images are pruned after 24 hours.
- Main-app temporary Feishu forwarded image cache files are pruned after 24 hours.
- New Feishu-forwarded image uploads use the isolated `chat/feishu-monitor/` MinIO prefix.
- Production MinIO removes only `chat/feishu-monitor/` objects older than 6 hours every hour.

## Tech Stack

- Flutter/Dart desktop client.
- WuKongIM Flutter SDK `WKSendOptions.expire`.
- Dart local Feishu monitor shell snapshot store.

## Commands

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test\modules\chat\chat_scene_gateway_test.dart test\modules\feishu_monitor\feishu_monitor_forwarding_service_test.dart -r compact
flutter analyze lib\modules\chat\chat_scene_gateway.dart lib\modules\feishu_monitor\feishu_monitor_forwarding_service.dart test\modules\chat\chat_scene_gateway_test.dart test\modules\feishu_monitor\feishu_monitor_forwarding_service_test.dart
```

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell
dart test
dart analyze lib test
```

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
flutter test test\feishu_network_capture_runtime_test.dart test\feishu_network_capture_store_test.dart -r compact
flutter analyze lib\main.dart lib\src\feishu_network_capture_retention.dart test\feishu_network_capture_runtime_test.dart
```

```bash
ssh ubuntu@42.194.218.158 "/opt/wukongim-prod/scripts/cleanup_feishu_monitor_minio.sh --dry-run"
ssh ubuntu@42.194.218.158 "crontab -l | grep cleanup_feishu_monitor_minio.sh"
```

## Project Structure

```text
lib/modules/chat/chat_scene_gateway.dart
  Shared send path and SDK send options.

lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart
  Feishu-specific text/image forwarding, isolated upload prefix, local temp image cache cleanup.

lib/service/api/file_api.dart
  Chat media upload API and explicit object-path upload helper.

tools/feishu_monitor_shell/lib/src/shell_models.dart
  Snapshot model and retention pruning.

tools/feishu_monitor_shell/lib/src/shell_store.dart
  Automatic pruning on load/save/update.

tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_retention.dart
  Shell runtime diagnostics and network image cache pruning.

deploy/production/scripts/cleanup_feishu_monitor_minio.sh
  Server-side MinIO cleanup for `chat/feishu-monitor/` only.
```

## Code Style

```dart
await gateway.sendMessageContent(
  content,
  channelId: route.targetGroupId,
  channelType: WKChannelType.group,
  expireSeconds: feishuMonitorForwardedMessageExpireSeconds,
);
```

Keep retention constants named and tested. Preserve existing defaults unless the Feishu monitor path explicitly opts in.

```dart
final uploadPath = feishuMonitorForwardedImageUploadPath(
  channelId: channelId,
  channelType: channelType,
  filePath: filePath,
  now: DateTime.now().toUtc(),
);
```

Cloud object cleanup must target the dedicated Feishu monitor prefix instead of the whole chat bucket.

## Testing Strategy

- Unit tests prove SDK send options receive the requested expiration.
- Feishu forwarding tests prove text and image paths pass 21600 seconds.
- Shell store tests prove records older than 24 hours are removed and retained records persist.
- Runtime retention tests prove stale JSONL diagnostics and network image files are removed while invalid/unknown timestamps are kept.
- Forwarding tests prove forwarded image upload paths use `/feishu-monitor/...` and current local files are not deleted during preparation.

## Boundaries

- Always: keep normal chat sends non-expiring by default.
- Always: keep invalid or missing timestamps rather than deleting them accidentally.
- Always: clean cloud objects only under `chat/feishu-monitor/`.
- Ask first: deleting historical media that was uploaded before the isolated prefix existed.
- Never: delete the entire `chat` bucket or arbitrary local files referenced by captured image paths.

## Open Questions

- Historical Feishu-forwarded images uploaded before this change may live under normal chat object paths. They are not automatically deleted by the new prefix cleanup to avoid deleting normal user chat media.
