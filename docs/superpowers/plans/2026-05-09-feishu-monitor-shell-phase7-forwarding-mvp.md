# Feishu Monitor Shell Phase 7 Forwarding MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first end-to-end forwarding slice: WuKongIM reads normalized Feishu `recent_events` from the local shell and sends new text events to one configured WuKongIM group.

**Architecture:** Keep cloud route management, multi-rule matching, durable retry queues, and media forwarding out of this slice. The WuKongIM desktop monitor center owns a local forwarding service, a persisted single target group id, a manual "forward recent events" action, and an optional polling toggle. The forwarding service formats `FeishuMonitorMessageEvent` into `WKTextContent` and sends through the existing `ApiChatSceneGateway.sendMessageContent` path.

**Tech Stack:** Flutter desktop, Dart unit/widget tests, `shared_preferences`, WuKongIM Flutter SDK `WKTextContent`, existing `ChatSceneGateway`

---

### Task 1: Forwarding Service

**Files:**
- Create: `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`
- Create: `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`

- [ ] **Step 1: Write failing service tests**

Add tests for:

- formatting one Feishu event as text with conversation, sender, and body
- forwarding only events that have not been sent in the current runtime
- returning a skipped result when the rule is disabled or the target group id is empty

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart
```

Expected: FAIL because the service does not exist yet.

- [ ] **Step 2: Implement the service**

Create:

- `FeishuMonitorForwardingRule`
- `FeishuMonitorForwardingResult`
- `FeishuMonitorTextSender`
- `WkImFeishuMonitorTextSender`
- `FeishuMonitorForwardingService`
- `formatFeishuMonitorEventForForward`

`WkImFeishuMonitorTextSender` should call:

```dart
ApiChatSceneGateway().sendMessageContent(
  WKTextContent(text),
  channelId: channelId,
  channelType: channelType,
  channelName: channelName,
)
```

Use `WKChannelType.group` as the default target channel type.

- [ ] **Step 3: Verify service tests**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart
```

Expected: PASS.

### Task 2: Monitor Center Forwarding Controls

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Write failing widget tests**

Extend the monitor center widget test to assert:

- a forwarding card is visible
- the target group field can be edited
- tapping the manual forward button calls the forwarding service with that group id
- enabling auto forwarding persists the setting

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart
```

Expected: FAIL because the UI controls do not exist yet.

- [ ] **Step 2: Add settings storage**

Add local settings to `feishu_monitor_forwarding_service.dart`:

- `FeishuMonitorForwardingSettings`
- `FeishuMonitorForwardingSettingsStore`
- `SharedPreferencesFeishuMonitorForwardingSettingsStore`

Persist:

- target group id
- auto forwarding enabled

- [ ] **Step 3: Add UI controls**

In `FeishuMonitorCenterPage`, add a "转发设置" section with:

- target WuKongIM group id text field
- auto forwarding switch
- manual "转发最近事件" button
- short result text showing sent/skipped/failed counts

Poll every 8 seconds only when auto forwarding is enabled and a target group id is present.

- [ ] **Step 4: Verify widget tests**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart
```

Expected: PASS.

### Task 3: Focused Verification

**Files:**
- Verify: `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Run all Feishu monitor tests**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart test/modules/feishu_monitor/feishu_monitor_center_page_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run analyzer on changed files**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat analyze lib/modules/feishu_monitor test/modules/feishu_monitor
```

Expected: PASS.
