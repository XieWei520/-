# Spec: Web PWA Background Notification Reliability

## Objective
Improve Web message notification reliability for desktop browsers, Android Web/PWA, and iOS Home Screen PWA without adding Getui, JPush, FCM, or vendor push channels.

Success means:
- Normal Web Push messages are not dropped after only 60 seconds of Apple/browser delivery delay.
- Realtime call-style notifications still expire quickly.
- Web/PWA clients report whether their page is visible or backgrounded so the backend can send Web Push when a page is backgrounded but the IM server still considers it online.
- iOS Home Screen PWA refreshes its push subscription, IM session, and conversation list when Safari restores a frozen page.
- Production logs show whether Web Push was skipped, sent, accepted by the push endpoint, failed, or removed as stale without logging full push endpoint secrets.
- The nginx `/ws` location does not request-rate-limit normal WebSocket reconnect bursts.
- Existing foreground in-page alerts remain unchanged.

## Tech Stack
- Flutter/Dart Web frontend.
- Go backend under `.codex-backend-work/src`.
- Redis-backed Web Push subscription storage.
- Standards-based Web Push via VAPID and Service Worker.

## Commands
- Flutter analysis: `flutter analyze`
- Flutter web notification tests: `flutter test test\wukong_push\web_notification_integration_policy_test.dart`
- Backend user tests: `go test ./modules/user -run TestWebPush -count=1`
- Backend webhook tests: `go test ./modules/webhook -run TestWebPush -count=1`

## Project Structure
- `lib/wukong_push/notification/web_notification_manager_web.dart`: Web permission, subscription, foreground notification, and page lifecycle handling.
- `lib/modules/home/home_pwa_resume_coordinator.dart`: Platform export for browser resume recovery.
- `lib/modules/home/home_pwa_resume_coordinator_web.dart`: Web-only listeners for PWA resume, focus, online, and Service Worker messages.
- `lib/modules/home/home_pwa_resume_coordinator_stub.dart`: No-op implementation for non-Web platforms.
- `lib/service/api/web_push_api.dart`: Web Push API client.
- `lib/core/config/api_config.dart`: API paths.
- `.codex-backend-work/src/modules/user/api.go`: Web Push subscription and client state endpoints.
- `.codex-backend-work/src/modules/webhook/push_webpush.go`: Web Push delivery and TTL policy.
- `.codex-backend-work/src/modules/webhook/api.go`: IM webhook dispatch path.
- `deploy/production/nginx/default.conf.template`: production edge config for WebSocket proxying.
- `scripts/ops/apply_nginx_edge_optimizations.sh`: remote nginx edge config applicator.
- `web/wk_pwa_service_worker.js`: background push notification display.

## Code Style
Keep policy logic in small pure helpers that can be tested directly:

```go
func webPushTTLSeconds(msg msgOfflineNotify) int {
	if isRealtimeWebPushMessage(msg) {
		return webPushRealtimeTTLSeconds
	}
	if msg.Expire > 0 && int(msg.Expire) < webPushDefaultTTLSeconds {
		return int(msg.Expire)
	}
	return webPushDefaultTTLSeconds
}
```

## Testing Strategy
- Go unit tests cover TTL policy and subscription client state merging.
- Go unit tests cover safe Web Push endpoint diagnostics.
- Dart source-policy tests cover frontend state reporting wiring and API path exposure.
- Dart source-policy tests cover nginx `/ws` remaining proxied without request-rate limiting.
- Existing Service Worker tests continue to verify `showNotification`, click routing, and non-silent notifications.
- Dart source-policy tests cover the iOS PWA resume coordinator wiring and Service Worker `pushsubscriptionchange` notification path.

## Boundaries
- Always: preserve user notification/mute settings, avoid secrets in source, avoid Web JS audio for true background notification, keep offline Web Push behavior.
- Ask first: database schema changes, third-party push vendors, changing auth middleware, forcing web clients offline.
- Never: commit VAPID private keys, bypass browser/OS notification settings, remove existing tests to make a build pass.

## Success Criteria
- `go test ./modules/webhook -run TestWebPush -count=1` passes.
- `go test ./modules/user -run TestWebPush -count=1` passes.
- `flutter test test\wukong_push\web_notification_integration_policy_test.dart` passes.
- The backend can distinguish normal message TTL from realtime/call TTL.
- The frontend updates backend Web Push client state on `visibilitychange` and `pagehide`.
- The Home shell runs a throttled resume recovery on `visibilitychange`, `pageshow`, `focus`, `online`, and Service Worker `message` events.
- Resume recovery refreshes Web Push registration state, calls IM initialization/reconnect path, and reloads conversations from the server.
- Production `tsdd-api` logs include `Web Push send result` with uid, endpoint host, endpoint hash, status code, stale flag, visibility, permission, standalone, last seen age, TTL, and error.
- Production nginx no longer returns `/ws` 503 due to `ws_limit`.

## Open Questions
- Real iOS delivery still needs physical device verification because Apple controls background delivery, Focus mode, permission state, and process eviction.
