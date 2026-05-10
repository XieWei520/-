# Feishu Monitor Shell Phase 5 Normalized Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert observed message candidates into deduped normalized local message events and expose a recent event timeline to WuKongIM without forwarding messages yet.

**Architecture:** The shared shell package owns the stable event contract and dedupe helper. The desktop shell maps DOM probe message candidates into normalized events whenever page probe state is persisted. WuKongIM parses and displays the recent normalized event timeline as diagnostics. Route matching, queue persistence, retry, and delivery remain out of scope.

**Tech Stack:** Dart shared shell package, Flutter Windows shell app, `webview_windows.executeScript`, Flutter widget tests, Dart package tests

---

### Task 1: Shared Normalized Event Contract

**Files:**
- Modify: `tools/feishu_monitor_shell/lib/src/shell_models.dart`
- Modify: `tools/feishu_monitor_shell/lib/src/shell_server.dart`
- Modify: `tools/feishu_monitor_shell/test/shell_server_test.dart`

- [ ] **Step 1: Write failing tests**

In `tools/feishu_monitor_shell/test/shell_server_test.dart`, add tests for:

```dart
NormalizedMessageEvent(
  eventId: 'event_msg_1',
  dedupeKey: 'chat_1:msg_1',
  accountId: '',
  conversationId: 'chat_1',
  conversationName: 'Alpha Group',
  conversationType: 'unknown',
  messageId: 'msg_1',
  senderId: '',
  senderName: 'Alice',
  messageType: 'text',
  text: 'hello from Feishu',
  sentAt: '',
  observedAt: '2026-05-09T12:00:00Z',
  captureSource: 'dom_probe',
)
```

Assert:
- `/status` includes `recent_events`.
- `GET /events/recent` returns one event.
- `mergeRecentEvents(existing, incoming, limit: 3)` dedupes by `dedupeKey`, keeps the newer event, and limits the list to 3.

Run: `dart test test/shell_server_test.dart`

Expected: FAIL because `NormalizedMessageEvent`, `recentEvents`, `/events/recent`, and `mergeRecentEvents` do not exist.

- [ ] **Step 2: Implement event model**

In `tools/feishu_monitor_shell/lib/src/shell_models.dart`, add:

```dart
class NormalizedMessageEvent {
  const NormalizedMessageEvent({
    required this.eventId,
    required this.dedupeKey,
    required this.accountId,
    required this.conversationId,
    required this.conversationName,
    required this.conversationType,
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.messageType,
    required this.text,
    required this.sentAt,
    required this.observedAt,
    required this.captureSource,
  });

  // fields matching constructor

  Map<String, dynamic> toJson() { ... }

  factory NormalizedMessageEvent.fromJson(Map<String, dynamic> json) { ... }
}
```

Use JSON field names:
- `event_id`
- `dedupe_key`
- `account_id`
- `conversation_id`
- `conversation_name`
- `conversation_type`
- `message_id`
- `sender_id`
- `sender_name`
- `message_type`
- `text`
- `sent_at`
- `observed_at`
- `capture_source`

Extend `ShellSnapshot` with `recentEvents`, defaulting missing or invalid lists to empty and serializing as `recent_events`.

- [ ] **Step 3: Implement merge helper**

In `tools/feishu_monitor_shell/lib/src/shell_models.dart`, add:

```dart
List<NormalizedMessageEvent> mergeRecentEvents(
  List<NormalizedMessageEvent> existing,
  List<NormalizedMessageEvent> incoming, {
  int limit = 50,
}) {
  final byKey = <String, NormalizedMessageEvent>{};
  for (final event in <NormalizedMessageEvent>[...existing, ...incoming]) {
    final key = event.dedupeKey.trim().isEmpty ? event.eventId : event.dedupeKey;
    if (key.trim().isEmpty) {
      continue;
    }
    final current = byKey[key];
    if (current == null || _compareObservedAt(event, current) >= 0) {
      byKey[key] = event;
    }
  }
  final merged = byKey.values.toList()
    ..sort((a, b) => _compareObservedAt(b, a));
  return merged.take(limit).toList(growable: false);
}
```

Use an internal `_compareObservedAt` that parses `observedAt` and falls back to string comparison when parsing fails.

- [ ] **Step 4: Add recent events endpoint**

In `tools/feishu_monitor_shell/lib/src/shell_server.dart`, add:

```dart
if (request.method == 'GET' && path == '/events/recent') {
  final snapshot = await store.load();
  await _writeJson(
    request.response,
    HttpStatus.ok,
    snapshot.recentEvents.map((event) => event.toJson()).toList(growable: false),
  );
  return;
}
```

- [ ] **Step 5: Verify shared package**

Run: `dart test`

Expected: PASS.

### Task 2: Desktop Shell Candidate-To-Event Mapping

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/runtime_snapshot_mapper.dart`
- Modify: `tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart`

- [ ] **Step 1: Write failing mapping tests**

In `tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart`, add a test that passes a `FeishuPageProbe` with two duplicate `ObservedMessageCandidate` objects with the same `conversationId` and `id`, then asserts `applyPageProbe` writes only one `recentEvents` item with:

```dart
dedupeKey == 'chat_1:msg_1'
messageId == 'msg_1'
conversationName == 'Alpha Group'
text == 'hello from Feishu'
captureSource == 'dom_probe'
```

Run: `flutter test test/runtime_snapshot_mapper_test.dart`

Expected: FAIL because `applyPageProbe` does not create normalized events.

- [ ] **Step 2: Implement candidate mapping**

In `tools/feishu_monitor_shell_app/lib/src/runtime_snapshot_mapper.dart`, add:

```dart
List<NormalizedMessageEvent> normalizeObservedMessages(
  List<ObservedMessageCandidate> messages,
) {
  return messages
      .where((message) => message.id.trim().isNotEmpty && message.text.trim().isNotEmpty)
      .map((message) {
        final conversationId = message.conversationId.trim();
        final messageId = message.id.trim();
        final fallbackKey = '${message.senderName}:${message.observedAt}:${message.text.hashCode}';
        final dedupeKey = conversationId.isNotEmpty && messageId.isNotEmpty
            ? '$conversationId:$messageId'
            : fallbackKey;
        return NormalizedMessageEvent(
          eventId: 'event_$messageId',
          dedupeKey: dedupeKey,
          accountId: '',
          conversationId: conversationId,
          conversationName: message.conversationName,
          conversationType: 'unknown',
          messageId: messageId,
          senderId: '',
          senderName: message.senderName,
          messageType: message.messageType.trim().isEmpty ? 'text' : message.messageType,
          text: message.text,
          sentAt: '',
          observedAt: message.observedAt,
          captureSource: message.captureSource.trim().isEmpty ? 'dom_probe' : message.captureSource,
        );
      })
      .toList(growable: false);
}
```

Update `applyPageProbe`:

```dart
final incomingEvents = normalizeObservedMessages(probe.observedMessages);
return snapshot.copyWith(
  ...
  recentEvents: mergeRecentEvents(snapshot.recentEvents, incomingEvents),
);
```

- [ ] **Step 3: Verify shell app tests**

Run: `flutter test test/feishu_page_probe_test.dart test/runtime_snapshot_mapper_test.dart`

Expected: PASS.

### Task 3: WuKongIM Recent Event Timeline

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_shell_models.dart`
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Write failing parsing tests**

In `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`, extend the `/status` fixture with:

```dart
'recent_events': <Map<String, dynamic>>[
  <String, dynamic>{
    'event_id': 'event_msg_1',
    'dedupe_key': 'chat_1:msg_1',
    'account_id': '',
    'conversation_id': 'chat_1',
    'conversation_name': 'Alpha Group',
    'conversation_type': 'unknown',
    'message_id': 'msg_1',
    'sender_id': '',
    'sender_name': 'Alice',
    'message_type': 'text',
    'text': 'hello from Feishu',
    'sent_at': '',
    'observed_at': '2026-05-09T10:02:00Z',
    'capture_source': 'dom_probe',
  },
],
```

Assert `status.recentEvents.first.dedupeKey == 'chat_1:msg_1'`.

Run: `flutter test test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`

Expected: FAIL because WuKongIM does not parse `recent_events`.

- [ ] **Step 2: Add WuKongIM event model**

In `lib/modules/feishu_monitor/feishu_monitor_shell_models.dart`, add `FeishuMonitorMessageEvent` with fields matching the JSON above. Extend `FeishuMonitorShellStatus` with `recentEvents`, defaulting missing or invalid lists to empty.

- [ ] **Step 3: Display recent event timeline**

In `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`, add an `Event Timeline` diagnostics section under `Observed Messages`:
- show up to 5 events
- display text, sender/conversation, `dedupeKey`, and `captureSource`
- empty state when none exists

- [ ] **Step 4: Write UI tests**

In `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`, add one `FeishuMonitorMessageEvent` to the fake status and assert `Event Timeline`, `chat_1:msg_1`, `hello from Feishu`, and `dom_probe` are visible.

Run: `flutter test test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

Expected: PASS.

### Task 4: Verification

**Files:**
- Verify: `tools/feishu_monitor_shell/test/shell_server_test.dart`
- Verify: `tools/feishu_monitor_shell_app/test/feishu_page_probe_test.dart`
- Verify: `tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`
- Verify: `test/modules/vip/vip_management_page_test.dart`

- [ ] Run `dart test` inside `tools/feishu_monitor_shell`.
- [ ] Run `flutter test test/feishu_page_probe_test.dart test/runtime_snapshot_mapper_test.dart` inside `tools/feishu_monitor_shell_app`.
- [ ] Run `flutter test test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart test/modules/feishu_monitor/feishu_monitor_center_page_test.dart test/modules/vip/vip_management_page_test.dart` at repo root.
- [ ] Run `flutter analyze` at repo root.
- [ ] Run `flutter analyze` inside `tools/feishu_monitor_shell_app`.

Expected: all commands exit 0.

## Self-Review

- Spec coverage: This implements the next narrow step in the normalized event pipeline while still excluding forwarding, queue persistence, and route matching.
- Placeholder scan: No placeholders remain.
- Type consistency: Shared shell uses `NormalizedMessageEvent`; WuKongIM uses `FeishuMonitorMessageEvent`; JSON field is consistently `recent_events`.
