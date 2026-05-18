# Spec: Chat 30 Day Cloud Retention

Date: 2026-05-13

## Objective

Keep normal chat text and chat media on the cloud for 30 days, then allow automatic cleanup. Feishu monitor forwarding keeps its stricter 6 hour retention.

Success criteria:

- Normal chat sends use a 30 day WuKongIM message expiration by default.
- Explicit message expirations still win, including Feishu monitor 6 hour forwarding.
- Normal chat image/file/video/voice objects under MinIO `chat/1/` and `chat/2/` are removed after 30 days.
- Feishu monitor media remains isolated under `chat/feishu-monitor/` and keeps the existing 6 hour cleanup.
- The cleanup script never deletes avatars, group icons, common assets, moments, backups, or the whole `chat` bucket.

## Tech Stack

- Flutter/Dart chat client.
- WuKongIM Flutter SDK `WKSendOptions.expire`.
- MinIO `mc rm --older-than`.
- Linux cron on `ubuntu@42.194.218.158`.

## Commands

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test\modules\chat\chat_scene_gateway_test.dart test\modules\chat\chat_scene_providers_test.dart test\modules\search\chat_search_image_forward_page_test.dart test\modules\feishu_monitor\feishu_monitor_forwarding_service_test.dart -r compact
flutter analyze lib\modules\chat\chat_scene_gateway.dart lib\modules\chat\chat_scene_providers.dart lib\modules\search\presentation\chat_search_image_forward_page.dart lib\service\im\screenshot_notification_service.dart test\modules\chat\chat_scene_gateway_test.dart test\modules\chat\chat_scene_providers_test.dart test\modules\search\chat_search_image_forward_page_test.dart test\modules\feishu_monitor\feishu_monitor_forwarding_service_test.dart
```

```bash
ssh ubuntu@42.194.218.158 "/opt/wukongim-prod/scripts/cleanup_chat_minio_30d.sh --dry-run"
ssh ubuntu@42.194.218.158 "crontab -l | grep cleanup_chat_minio_30d.sh"
```

## Project Structure

```text
lib/modules/chat/chat_scene_gateway.dart
  Shared normal chat sending path and default message expiration.

lib/modules/chat/chat_scene_providers.dart
  Passes the 30 day send option into the real SDK sender and web direct-send path.

lib/modules/search/presentation/chat_search_image_forward_page.dart
  Search image forwarding path; must use the same 30 day expiration.

lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart
  Feishu-specific override using 6 hour expiration and isolated media prefix.

deploy/production/scripts/cleanup_chat_minio_30d.sh
  Server-side MinIO cleanup for ordinary chat media prefixes only.
```

## Code Style

```dart
final effectiveExpireSeconds =
    expireSeconds ?? defaultChatMessageRetentionSeconds;
final options = WKSendOptions()..expire = effectiveExpireSeconds;
```

Keep retention constants named and tested. Use explicit prefix allowlists for destructive object storage cleanup.

## Testing Strategy

- Unit tests prove default normal chat sends pass 30 day `expire`.
- Unit tests prove explicit expirations are preserved.
- Existing Feishu forwarding tests prove 6 hour expiration still wins.
- Server cleanup script is verified with `--dry-run` before being scheduled.

## Boundaries

- Always: clean only MinIO `chat/1/` and `chat/2/` for normal chat media.
- Always: keep Feishu monitor `chat/feishu-monitor/` on the 6 hour cleanup path.
- Ask first: direct deletion of WuKongIM internal database/log files.
- Never: delete the whole `chat` bucket or non-chat buckets such as `avatar`, `group`, `common`, `moment`, `message-backup`.

## Open Questions

- WuKongIM stores message body data in its own data directory. There is no confirmed safe table-level delete path in MySQL for normal messages, so normal text retention is implemented through message expiration at send time instead of direct data-file deletion.
