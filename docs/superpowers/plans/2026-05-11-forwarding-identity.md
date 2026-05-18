# Forwarding Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Feishu forwarding use a dedicated WuKongIM account while each forwarding route can display its own relay name/avatar and forward only the original Feishu content.

**Architecture:** The logged-in WuKongIM account remains the real sender. Each Feishu route stores optional relay display metadata, and the sender injects that metadata into the message payload under `robot` so supported WuKongIM clients render the configured name/avatar. Message text formatting becomes content-only; source group and sender remain internal routing/log context.

**Tech Stack:** Flutter/Dart, WuKongIM Flutter SDK, SharedPreferences route storage, existing Feishu monitor forwarding service and center page.

---

### Task 1: Route Identity Model And Content-Only Formatting

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`
- Test: `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`

- [ ] Write failing tests for route JSON round-trip with `relayDisplayName` and `relayAvatar`.
- [ ] Write failing test that `formatFeishuMonitorEventForForward()` returns only the forwardable message body.
- [ ] Add route fields with backward-compatible defaults and JSON keys `relay_display_name` / `relay_avatar`.
- [ ] Change formatter to return only `_forwardableEventText(event)` or `(空消息)`.
- [ ] Run `flutter test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`.

### Task 2: Inject Robot Identity Into Forwarded Messages

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`
- Modify: `lib/widgets/message_bubble.dart`
- Test: `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`
- Test: `test/modules/chat/message_bubble_experience_test.dart`

- [ ] Write failing tests that routed text forwarding passes route identity to the sender.
- [ ] Write failing tests that `WkImFeishuMonitorTextSender` encodes `robot.provider`, `robot.name`, and `robot.avatar` into text and image payloads.
- [ ] Write failing test that outgoing group robot payloads render robot name/avatar before current user profile.
- [ ] Add a small identity value object and robot-aware text/image content wrappers.
- [ ] Pass route identity through `_sendEventToTarget()` for routed forwarding.
- [ ] Prefer robot identity over current user profile in group message participant resolution.
- [ ] Run targeted Feishu and chat tests.

### Task 3: Configure Per-Route Display Name And Avatar In UI

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Test: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] Write failing widget test that selecting a target group can save relay display name and avatar.
- [ ] After target group selection, show a route identity dialog with default name `飞书转发助手` and optional avatar URL/path.
- [ ] Save these values into the route while preserving existing route enabled state and creation time.
- [ ] Show relay display name in the forwarding rules table.
- [ ] Run `flutter test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`.

### Task 4: Verification And Restart

**Files:**
- No code files beyond Tasks 1-3.

- [ ] Run `flutter test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart test/modules/feishu_monitor/feishu_monitor_center_page_test.dart test/modules/chat/message_bubble_experience_test.dart`.
- [ ] Run `flutter analyze lib/modules/feishu_monitor lib/widgets/message_bubble.dart test/modules/feishu_monitor test/modules/chat/message_bubble_experience_test.dart`.
- [ ] Build Windows release with `flutter build windows --release`.
- [ ] Restart visible `InfoEquity.exe`.
