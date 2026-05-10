# Feishu Monitor Shell Phase 4 Message Candidates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a narrow message-candidate observation slice so the standalone shell can expose recently observed page messages and WuKongIM can display them without forwarding yet.

**Architecture:** Build on Phase 3 probe metadata. The shared shell snapshot gains a list of normalized observed message candidates and a `GET /messages/recent` localhost endpoint. The desktop shell DOM probe extracts lightweight text message candidates from the current WebView page. WuKongIM parses and displays those candidates as diagnostics only; routing, dedupe queues, and delivery to WuKongIM groups stay out of scope.

**Tech Stack:** Dart shared shell package, Flutter Windows shell app, `webview_windows.executeScript`, Flutter widget tests, Dart package tests

---

### Task 1: Shared Message Candidate Contract

**Files:**
- Modify: `tools/feishu_monitor_shell/lib/src/shell_models.dart`
- Modify: `tools/feishu_monitor_shell/lib/src/shell_server.dart`
- Modify: `tools/feishu_monitor_shell/test/shell_server_test.dart`

- [ ] **Step 1: Write failing model and endpoint tests**

Add a test to `tools/feishu_monitor_shell/test/shell_server_test.dart` that stores a snapshot with one observed message candidate, expects `/status` to include `observed_messages`, and expects `GET /messages/recent` to return the list.

Use this candidate shape:

```dart
ObservedMessageCandidate(
  id: 'msg_1',
  conversationId: 'chat_1',
  conversationName: 'Alpha Group',
  senderName: 'Alice',
  messageType: 'text',
  text: 'hello from Feishu',
  observedAt: '2026-05-09T12:00:00Z',
  captureSource: 'dom_probe',
)
```

Run: `dart test test/shell_server_test.dart`

Expected: FAIL because `ObservedMessageCandidate`, `observedMessages`, and `/messages/recent` do not exist yet.

- [ ] **Step 2: Implement the shared model**

In `tools/feishu_monitor_shell/lib/src/shell_models.dart`, add:

```dart
class ObservedMessageCandidate {
  const ObservedMessageCandidate({
    required this.id,
    required this.conversationId,
    required this.conversationName,
    required this.senderName,
    required this.messageType,
    required this.text,
    required this.observedAt,
    required this.captureSource,
  });

  final String id;
  final String conversationId;
  final String conversationName;
  final String senderName;
  final String messageType;
  final String text;
  final String observedAt;
  final String captureSource;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'conversation_id': conversationId,
      'conversation_name': conversationName,
      'sender_name': senderName,
      'message_type': messageType,
      'text': text,
      'observed_at': observedAt,
      'capture_source': captureSource,
    };
  }

  factory ObservedMessageCandidate.fromJson(Map<String, dynamic> json) {
    return ObservedMessageCandidate(
      id: (json['id'] ?? '').toString(),
      conversationId: (json['conversation_id'] ?? '').toString(),
      conversationName: (json['conversation_name'] ?? '').toString(),
      senderName: (json['sender_name'] ?? '').toString(),
      messageType: (json['message_type'] ?? 'text').toString(),
      text: (json['text'] ?? '').toString(),
      observedAt: (json['observed_at'] ?? '').toString(),
      captureSource: (json['capture_source'] ?? 'dom_probe').toString(),
    );
  }
}
```

Extend `ShellSnapshot` with:

```dart
required this.observedMessages,
final List<ObservedMessageCandidate> observedMessages;
List<ObservedMessageCandidate>? observedMessages,
```

Default to `const <ObservedMessageCandidate>[]`, serialize as `observed_messages`, and parse missing or invalid lists as an empty list.

- [ ] **Step 3: Add recent messages endpoint**

In `tools/feishu_monitor_shell/lib/src/shell_server.dart`, add:

```dart
if (request.method == 'GET' && path == '/messages/recent') {
  final snapshot = await store.load();
  await _writeJson(
    request.response,
    HttpStatus.ok,
    snapshot.observedMessages
        .map((message) => message.toJson())
        .toList(growable: false),
  );
  return;
}
```

- [ ] **Step 4: Verify shared package**

Run: `dart test`

Expected: PASS with all shared shell tests green.

### Task 2: Desktop Shell Message Probe

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/feishu_page_probe.dart`
- Modify: `tools/feishu_monitor_shell_app/lib/src/runtime_snapshot_mapper.dart`
- Modify: `tools/feishu_monitor_shell_app/test/feishu_page_probe_test.dart`
- Modify: `tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart`

- [ ] **Step 1: Write failing probe normalization tests**

In `tools/feishu_monitor_shell_app/test/feishu_page_probe_test.dart`, add a test where `FeishuPageProbe.fromScriptResult` receives:

```dart
<String, dynamic>{
  'page_kind': 'messenger',
  'observed_at': '2026-05-09T12:00:00Z',
  'observed_messages': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'msg_1',
      'conversation_id': 'chat_1',
      'conversation_name': 'Alpha Group',
      'sender_name': 'Alice',
      'message_type': 'text',
      'text': 'hello from Feishu',
      'observed_at': '2026-05-09T12:00:00Z',
      'capture_source': 'dom_probe',
    },
    <String, dynamic>{
      'id': '',
      'conversation_id': 'chat_1',
      'text': 'skip empty id',
    },
  ],
}
```

Assert that one message candidate remains and its `text` is `hello from Feishu`.

Run: `flutter test test/feishu_page_probe_test.dart`

Expected: FAIL because `FeishuPageProbe` does not expose observed messages.

- [ ] **Step 2: Extend probe result and script**

In `tools/feishu_monitor_shell_app/lib/src/feishu_page_probe.dart`, add `observedMessages` to `FeishuPageProbe`.

Update `feishuPageProbeScript` to build `observed_messages` from common rendered message selectors:

```javascript
const messageSelectors = [
  '[data-testid*="message"]',
  '[class*="message"]',
  '[class*="Message"]'
];
const observedMessages = [];
const messageSeen = new Set();
for (const selector of messageSelectors) {
  const nodes = Array.from(document.querySelectorAll(selector));
  for (const node of nodes) {
    const text = (node.innerText || '').trim();
    if (!text || text.length < 2) continue;
    const id =
      node.getAttribute('data-id') ||
      node.getAttribute('data-message-id') ||
      `${selector}:${text.slice(0, 48)}`;
    if (messageSeen.has(id)) continue;
    messageSeen.add(id);
    observedMessages.push({
      id,
      conversation_id: '',
      conversation_name: '',
      sender_name: '',
      message_type: 'text',
      text: text.slice(0, 500),
      observed_at: observedAt,
      capture_source: 'dom_probe'
    });
    if (observedMessages.length >= 20) break;
  }
  if (observedMessages.length >= 20) break;
}
```

Include `observed_messages: observedMessages` in the returned script object.

Add a private Dart `_readObservedMessages(dynamic value)` helper mirroring the conversation parser and skipping items with empty `id` or empty `text`.

- [ ] **Step 3: Persist observed messages into the snapshot**

In `tools/feishu_monitor_shell_app/lib/src/runtime_snapshot_mapper.dart`, update `applyPageProbe`:

```dart
ShellSnapshot applyPageProbe(ShellSnapshot snapshot, FeishuPageProbe probe) {
  return snapshot.copyWith(
    pageKind: probe.pageKind,
    probeObservedAt: probe.observedAt,
    observedConversations: probe.observedConversations,
    observedMessages: probe.observedMessages,
  );
}
```

Add a test in `tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart` asserting that `applyPageProbe` copies one observed message into the snapshot.

- [ ] **Step 4: Verify shell app tests**

Run: `flutter test test/feishu_page_probe_test.dart test/runtime_snapshot_mapper_test.dart`

Expected: PASS.

### Task 3: WuKongIM Recent Message Candidate Surface

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_shell_models.dart`
- Modify: `lib/modules/feishu_monitor/feishu_monitor_shell_client.dart`
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Write failing client parsing tests**

In `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`, extend the `/status` JSON fixture with:

```dart
'observed_messages': <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'msg_1',
    'conversation_id': 'chat_1',
    'conversation_name': 'Alpha Group',
    'sender_name': 'Alice',
    'message_type': 'text',
    'text': 'hello from Feishu',
    'observed_at': '2026-05-09T10:02:00Z',
    'capture_source': 'dom_probe',
  },
],
```

Assert that `status.observedMessages.first.text == 'hello from Feishu'`.

Run: `flutter test test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`

Expected: FAIL because WuKongIM model does not expose observed messages.

- [ ] **Step 2: Add WuKongIM model**

In `lib/modules/feishu_monitor/feishu_monitor_shell_models.dart`, add:

```dart
class FeishuMonitorObservedMessage {
  const FeishuMonitorObservedMessage({
    required this.id,
    required this.conversationId,
    required this.conversationName,
    required this.senderName,
    required this.messageType,
    required this.text,
    required this.observedAt,
    required this.captureSource,
  });

  final String id;
  final String conversationId;
  final String conversationName;
  final String senderName;
  final String messageType;
  final String text;
  final DateTime? observedAt;
  final String captureSource;

  factory FeishuMonitorObservedMessage.fromJson(Map<String, dynamic> json) {
    return FeishuMonitorObservedMessage(
      id: (json['id'] ?? '').toString(),
      conversationId: (json['conversation_id'] ?? '').toString(),
      conversationName: (json['conversation_name'] ?? '').toString(),
      senderName: (json['sender_name'] ?? '').toString(),
      messageType: (json['message_type'] ?? 'text').toString(),
      text: (json['text'] ?? '').toString(),
      observedAt: FeishuMonitorShellStatus.asDateTime(json['observed_at']),
      captureSource: (json['capture_source'] ?? 'dom_probe').toString(),
    );
  }
}
```

Expose a public static date parser if needed:

```dart
static DateTime? asDateTime(dynamic value) => _asDateTime(value);
```

Extend `FeishuMonitorShellStatus` with `observedMessages`, defaulting missing or invalid lists to empty.

- [ ] **Step 3: Display recent message candidates**

In `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`, add a small diagnostics section under the observed conversation list inside the runtime card:

- Heading text: `Observed Messages`
- Empty state text when no messages are present
- Show up to 5 messages
- Each row should show message text, optional sender/conversation label, and `captureSource`

Keep existing action buttons, metrics, runtime URL, page kind, and observed conversations visible.

- [ ] **Step 4: Write UI tests**

In `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`, extend the fake status with one `FeishuMonitorObservedMessage`:

```dart
FeishuMonitorObservedMessage(
  id: 'msg_1',
  conversationId: 'chat_1',
  conversationName: 'Alpha Group',
  senderName: 'Alice',
  messageType: 'text',
  text: 'hello from Feishu',
  observedAt: probeObservedAt,
  captureSource: 'dom_probe',
)
```

Assert that `Observed Messages`, `hello from Feishu`, `Alice`, and `dom_probe` are visible.

Run: `flutter test test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

Expected: PASS after implementation.

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

- Spec coverage: This plan implements the next narrow step toward the design's normalized message observation model while deliberately excluding route matching, queueing, and delivery.
- Placeholder scan: No `TBD`, `TODO`, or unspecified test instructions remain.
- Type consistency: Shared shell uses `ObservedMessageCandidate`; WuKongIM uses `FeishuMonitorObservedMessage`; JSON field is consistently `observed_messages`.
