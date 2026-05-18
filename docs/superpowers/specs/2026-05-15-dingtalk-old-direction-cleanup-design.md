# Spec: DingTalk Main App Monitor Cleanup

## Objective
Remove DingTalk real-time monitoring and auto-forwarding from the WuKong IM main Flutter app. The standalone Windows-native PoC project stays in the repository, and DingTalk group robot/webhook configuration stays available because it is separate from passive monitoring and forwarding.

## Tech Stack
- Existing Flutter/Dart app repository
- PowerShell for local verification
- Git worktree may already be dirty; cleanup must not revert unrelated user changes

## Commands
- Inspect main-app references: `Get-ChildItem -Path lib,test -Recurse -File -ErrorAction SilentlyContinue | Select-String -Pattern 'dingtalk_monitor|DingTalkMonitor|management-center-dingtalk'`
- Targeted tests: `flutter test test/modules/vip/vip_management_page_test.dart test/modules/user/user_page_parity_test.dart test/modules/local_monitor/local_monitor_auto_forward_coordinator_test.dart`
- Targeted analyze: `flutter analyze lib/app/app.dart lib/modules/vip/vip_management_page.dart test/modules/vip/vip_management_page_test.dart test/modules/user/user_page_parity_test.dart`

## Project Structure
- `lib/modules/dingtalk_monitor/` -> Flutter-side DingTalk monitor and auto-forward feature to remove
- `test/modules/dingtalk_monitor/` -> DingTalk monitor tests to remove
- `lib/app/app.dart` -> remove DingTalk runtime startup hook
- `lib/modules/vip/vip_management_page.dart` -> remove DingTalk monitor center card
- `tools/dingtalk_windows_host/` -> standalone PoC project to keep
- `lib/wukong_uikit/group/group_dingtalk_bot_page.dart` and related group robot models/APIs -> keep

## Code Style
```dart
expect(find.byKey(const ValueKey('management-center-feishu')), findsOneWidget);
expect(find.byKey(const ValueKey('management-center-dingtalk')), findsNothing);
expect(find.byKey(const ValueKey('management-center-xiaoe')), findsOneWidget);
```

Prefer surgical removals over broad refactors. Remove only DingTalk old-direction hooks and keep neighboring user edits intact.

## Testing Strategy
- Update management/user tests to assert the DingTalk monitor entry is absent.
- Delete tests whose only subject is the removed DingTalk monitor module.
- Run targeted tests that cover app startup runner composition, VIP management page, and user entry flow.
- Do a final text search for `dingtalk_monitor`, `DingTalkMonitor`, and `management-center-dingtalk` in `lib/` and `test/`.

## Boundaries
- Always: preserve unrelated user changes; keep Feishu monitor code untouched; keep the standalone Windows-native PoC; keep DingTalk group robot/webhook configuration
- Ask first: removing any shared local-monitor abstraction, changing Feishu behavior, deleting `tools/dingtalk_windows_host`, or removing DingTalk group robot APIs/pages
- Never: revert unrelated dirty files, delete active Feishu infrastructure, or claim desktop DingTalk monitoring is still supported in the main app

## Success Criteria
- `lib/modules/dingtalk_monitor/` is removed
- `test/modules/dingtalk_monitor/` is removed
- app startup no longer imports or starts a DingTalk monitor runtime
- management UI no longer exposes a DingTalk monitor entry
- DingTalk group robot/webhook features still compile untouched
- standalone PoC under `tools/dingtalk_windows_host/` remains present
- targeted tests pass
- no remaining main-app `dingtalk_monitor`, `DingTalkMonitor`, or `management-center-dingtalk` references remain in `lib/` and `test/`

## Open Questions
- None for this cleanup. Future DingTalk work, if any, must be handled as a standalone PoC or official API integration, not a main-app real-time monitor.
