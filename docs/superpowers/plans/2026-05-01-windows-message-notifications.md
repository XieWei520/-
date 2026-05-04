# Windows Message Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Windows desktop message sounds and minimized/background notification cards for eligible incoming IM messages.

**Architecture:** Reuse the existing IM realtime message callback as the single source of incoming message alerts. Extract the current Web alert planner into a shared planner, then add a Windows-only desktop alert manager with an injectable policy and presenter. Windows keeps the IM session connected while minimized because this app has no Windows cloud push fallback.

**Tech Stack:** Flutter/Dart, WuKong IM SDK `WKMsg`, `audioplayers`, `local_notifier` `^0.1.6`, `flutter_test`, existing Riverpod/IMService wiring.

---

## File Structure

- Modify: `pubspec.yaml`
  - Add `local_notifier: ^0.1.6` for Windows toast cards.

- Create: `lib/wukong_push/notification/message_alert_plan.dart`
  - Shared message alert planning and eligibility rules.
  - Replaces Web-specific naming with platform-neutral `MessageAlertPlan`.

- Modify: `lib/wukong_push/notification/web_message_alert_plan.dart`
  - Keep the current public Web API as a compatibility wrapper over the shared planner.

- Create: `lib/wukong_push/notification/desktop_message_alert_policy.dart`
  - Pure Dart foreground/background and coalescing decisions.

- Create: `lib/wukong_push/notification/desktop_message_alert_presenter.dart`
  - Abstract presenter interface used by the manager.

- Create: `lib/wukong_push/notification/desktop_message_alert_presenter_factory.dart`
  - Conditional presenter factory.

- Create: `lib/wukong_push/notification/desktop_message_alert_presenter_stub.dart`
  - No-op presenter for unsupported platforms and tests.

- Create: `lib/wukong_push/notification/desktop_message_alert_presenter_io.dart`
  - Native desktop implementation using `audioplayers` and `local_notifier`.

- Create: `lib/wukong_push/notification/desktop_message_alert_manager.dart`
  - Windows-only orchestration: platform guard, planner policy, presenter calls.

- Modify: `lib/service/im/im_service.dart`
  - Track lifecycle state.
  - Keep Windows realtime connected in minimized/hidden state.
  - Call the desktop alert manager for eligible Windows messages.

- Create: `test/wukong_push/message_alert_plan_test.dart`
  - Shared planner tests.

- Create: `test/wukong_push/desktop_message_alert_policy_test.dart`
  - Pure policy and coalescing tests.

- Create: `test/wukong_push/desktop_message_alert_manager_test.dart`
  - Manager orchestration tests with fake presenter.

- Modify: `test/service/im/im_service_test.dart`
  - Add Windows realtime keepalive lifecycle test.

- Modify: `test/wukong_push/web_message_alert_plan_test.dart`
  - Keep existing tests green after the shared planner extraction.

---

### Task 1: Extract Shared Message Alert Planner

**Files:**
- Create: `lib/wukong_push/notification/message_alert_plan.dart`
- Modify: `lib/wukong_push/notification/web_message_alert_plan.dart`
- Create: `test/wukong_push/message_alert_plan_test.dart`
- Verify: `test/wukong_push/web_message_alert_plan_test.dart`

- [ ] **Step 1: Write the failing shared planner test**

Create `test/wukong_push/message_alert_plan_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/message_alert_plan.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('buildMessageAlertPlan', () {
    test('builds an incoming personal message alert', () {
      final message =
          _textMessage(fromUid: 'alice', channelId: 'alice', text: 'hello')
            ..setFrom(
              WKChannel('alice', WKChannelType.personal)
                ..channelRemark = 'Alice'
                ..channelName = 'Alice raw',
            );

      final plan = buildMessageAlertPlan(message, currentUid: 'me');

      expect(plan, isNotNull);
      expect(plan!.title, 'Alice');
      expect(plan.body, 'hello');
      expect(plan.channelId, 'alice');
      expect(plan.channelType, WKChannelType.personal);
      expect(plan.conversationKey, '${WKChannelType.personal}:alice');
    });

    test('builds a group alert with sender and group names', () {
      final message =
          _textMessage(
              fromUid: 'alice',
              channelId: 'group-1',
              channelType: WKChannelType.group,
              text: 'ship it',
            )
            ..setMemberOfFrom(WKChannelMember()..memberName = 'Alice')
            ..setChannelInfo(
              WKChannel('group-1', WKChannelType.group)
                ..channelName = 'Product',
            );

      final plan = buildMessageAlertPlan(message, currentUid: 'me');

      expect(plan, isNotNull);
      expect(plan!.title, 'Alice - Product');
      expect(plan.body, 'ship it');
      expect(plan.conversationKey, '${WKChannelType.group}:group-1');
    });

    test('skips self, muted, deleted, internal, and non-red-dot messages', () {
      final self = _textMessage(fromUid: 'me', channelId: 'alice', text: 'self');
      final muted = _textMessage(
        fromUid: 'alice',
        channelId: 'muted',
        text: 'quiet',
      )..setChannelInfo(WKChannel('muted', WKChannelType.personal)..mute = 1);
      final deleted = _textMessage(
        fromUid: 'alice',
        channelId: 'alice',
        text: 'gone',
      )..isDeleted = 1;
      final internal = _textMessage(
        fromUid: 'alice',
        channelId: 'alice',
        text: 'cmd',
      )..contentType = WkMessageContentType.insideMsg;
      final noRedDot = _textMessage(
        fromUid: 'alice',
        channelId: 'alice',
        text: 'silent',
        redDot: false,
      );

      expect(buildMessageAlertPlan(self, currentUid: 'me'), isNull);
      expect(buildMessageAlertPlan(muted, currentUid: 'me'), isNull);
      expect(buildMessageAlertPlan(deleted, currentUid: 'me'), isNull);
      expect(buildMessageAlertPlan(internal, currentUid: 'me'), isNull);
      expect(buildMessageAlertPlan(noRedDot, currentUid: 'me'), isNull);
    });
  });
}

WKMsg _textMessage({
  required String fromUid,
  required String channelId,
  required String text,
  int channelType = WKChannelType.personal,
  bool redDot = true,
}) {
  final content = WKTextContent(text);
  return WKMsg()
    ..fromUID = fromUid
    ..channelID = channelId
    ..channelType = channelType
    ..contentType = WkMessageContentType.text
    ..content = text
    ..messageContent = content
    ..header.redDot = redDot;
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
flutter test test/wukong_push/message_alert_plan_test.dart
```

Expected: FAIL because `message_alert_plan.dart`, `MessageAlertPlan`, and `buildMessageAlertPlan` do not exist.

- [ ] **Step 3: Implement the shared planner**

Create `lib/wukong_push/notification/message_alert_plan.dart` by moving the logic from `web_message_alert_plan.dart` and adding channel metadata:

```dart
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../modules/chat/message_content_preview.dart';

const int _maxAlertTitleLength = 80;
const int _maxAlertBodyLength = 240;

class MessageAlertPlan {
  const MessageAlertPlan({
    required this.title,
    required this.body,
    required this.channelId,
    required this.channelType,
  });

  final String title;
  final String body;
  final String channelId;
  final int channelType;

  String get conversationKey => '$channelType:$channelId';
}

MessageAlertPlan? buildMessageAlertPlan(
  WKMsg message, {
  required String currentUid,
}) {
  if (!shouldTriggerMessageAlert(message, currentUid: currentUid)) {
    return null;
  }

  final preview = resolveMessagePreview(message);
  final body = _compactText(
    preview.text,
    fallback: '[New message]',
    maxLength: _maxAlertBodyLength,
  );
  if (body.isEmpty) {
    return null;
  }

  return MessageAlertPlan(
    title: _compactText(
      _resolveAlertTitle(message),
      fallback: 'InfoEquity',
      maxLength: _maxAlertTitleLength,
    ),
    body: body,
    channelId: message.channelID.trim(),
    channelType: message.channelType,
  );
}

bool shouldTriggerMessageAlert(WKMsg message, {required String currentUid}) {
  if (message.isDeleted != 0 ||
      message.contentType == WkMessageContentType.insideMsg) {
    return false;
  }
  if (!message.header.redDot) {
    return false;
  }

  final normalizedCurrentUid = currentUid.trim();
  final normalizedFromUid = message.fromUID.trim();
  if (normalizedCurrentUid.isNotEmpty &&
      normalizedFromUid == normalizedCurrentUid) {
    return false;
  }

  final channel = message.getChannelInfo();
  if (channel?.mute == 1) {
    return false;
  }

  return true;
}

String _resolveAlertTitle(WKMsg message) {
  final senderName = _resolveSenderName(message);
  final conversationName = _resolveConversationName(message);

  if (_isGroupLikeChannel(message.channelType)) {
    if (senderName.isNotEmpty &&
        conversationName.isNotEmpty &&
        senderName != conversationName) {
      return '$senderName - $conversationName';
    }
    if (conversationName.isNotEmpty) {
      return conversationName;
    }
    if (senderName.isNotEmpty) {
      return senderName;
    }
  }

  if (senderName.isNotEmpty) {
    return senderName;
  }
  if (conversationName.isNotEmpty) {
    return conversationName;
  }
  return 'InfoEquity';
}

bool _isGroupLikeChannel(int channelType) {
  return channelType == WKChannelType.group ||
      channelType == WKChannelType.community ||
      channelType == WKChannelType.communityTopic;
}

String _resolveSenderName(WKMsg message) {
  final member = message.getMemberOfFrom();
  final memberCandidates = <String>[
    member?.memberRemark ?? '',
    member?.remark ?? '',
    member?.memberName ?? '',
    member?.memberUID ?? '',
  ];
  final memberName = _firstNonEmpty(memberCandidates);
  if (memberName.isNotEmpty) {
    return memberName;
  }

  final from = message.getFrom();
  final fromCandidates = <String>[
    from?.channelRemark ?? '',
    from?.channelName ?? '',
    from?.username ?? '',
    from?.channelID ?? '',
    message.fromUID,
  ];
  return _firstNonEmpty(fromCandidates);
}

String _resolveConversationName(WKMsg message) {
  final channel = message.getChannelInfo();
  final candidates = <String>[
    channel?.channelRemark ?? '',
    channel?.channelName ?? '',
    channel?.channelID ?? '',
    message.channelID,
  ];
  return _firstNonEmpty(candidates);
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    final normalized = _normalizeWhitespace(value);
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}

String _compactText(
  String value, {
  required String fallback,
  required int maxLength,
}) {
  final normalized = _normalizeWhitespace(value);
  final resolved = normalized.isEmpty ? fallback.trim() : normalized;
  if (resolved.length <= maxLength) {
    return resolved;
  }
  if (maxLength <= 3) {
    return resolved.substring(0, maxLength);
  }
  return '${resolved.substring(0, maxLength - 3).trimRight()}...';
}

String _normalizeWhitespace(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}
```

Modify `lib/wukong_push/notification/web_message_alert_plan.dart` to be a compatibility wrapper:

```dart
import 'package:wukongimfluttersdk/entity/msg.dart';

import 'message_alert_plan.dart';

typedef WebMessageAlertPlan = MessageAlertPlan;

WebMessageAlertPlan? buildWebMessageAlertPlan(
  WKMsg message, {
  required String currentUid,
}) {
  return buildMessageAlertPlan(message, currentUid: currentUid);
}

bool shouldTriggerWebMessageAlert(WKMsg message, {required String currentUid}) {
  return shouldTriggerMessageAlert(message, currentUid: currentUid);
}
```

- [ ] **Step 4: Run planner tests to verify they pass**

Run:

```bash
flutter test test/wukong_push/message_alert_plan_test.dart test/wukong_push/web_message_alert_plan_test.dart
```

Expected: PASS. If existing Web tests assert the old separator character, update the expected string to `Alice - Product` because the shared planner uses ASCII and avoids encoding-sensitive punctuation.

- [ ] **Step 5: Commit Task 1**

```bash
git add lib/wukong_push/notification/message_alert_plan.dart lib/wukong_push/notification/web_message_alert_plan.dart test/wukong_push/message_alert_plan_test.dart test/wukong_push/web_message_alert_plan_test.dart
git commit -m "refactor: share message alert planning"
```

---

### Task 2: Keep Windows Realtime Connected While Minimized

**Files:**
- Modify: `lib/service/im/im_service.dart`
- Modify: `test/service/im/im_service_test.dart`

- [ ] **Step 1: Write the failing lifecycle keepalive test**

Add this test inside the existing `Task 2 parity hooks` group in `test/service/im/im_service_test.dart`:

```dart
test('windows desktop notification mode keeps realtime connected in background', () {
  expect(
    shouldDisconnectForBackgroundLifecycle(
      isWeb: false,
      hasActiveCallOrPendingSetup: false,
      keepRealtimeForDesktopNotifications: true,
    ),
    isFalse,
  );

  expect(
    shouldDisconnectForBackgroundLifecycle(
      isWeb: false,
      hasActiveCallOrPendingSetup: false,
    ),
    isTrue,
  );
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
flutter test test/service/im/im_service_test.dart --plain-name "windows desktop notification mode keeps realtime connected in background"
```

Expected: FAIL because `keepRealtimeForDesktopNotifications` is not a parameter yet.

- [ ] **Step 3: Implement the lifecycle helper change**

Modify `shouldDisconnectForBackgroundLifecycle` in `lib/service/im/im_service.dart`:

```dart
@visibleForTesting
bool shouldDisconnectForBackgroundLifecycle({
  required bool isWeb,
  required bool hasActiveCallOrPendingSetup,
  bool keepRealtimeForDesktopNotifications = false,
}) {
  if (isWeb || keepRealtimeForDesktopNotifications) {
    return false;
  }
  return !hasActiveCallOrPendingSetup;
}
```

Modify `_disconnectForBackgroundIfNeeded()` in the same file:

```dart
    if (!shouldDisconnectForBackgroundLifecycle(
      isWeb: kIsWeb,
      hasActiveCallOrPendingSetup: shouldKeepConnectionInBackground(),
      keepRealtimeForDesktopNotifications:
          !kIsWeb && defaultTargetPlatform == TargetPlatform.windows,
    )) {
      return;
    }
```

- [ ] **Step 4: Run the lifecycle tests**

Run:

```bash
flutter test test/service/im/im_service_test.dart --plain-name "windows desktop notification mode keeps realtime connected in background"
flutter test test/service/im/im_service_test.dart --plain-name "background keepalive matches Android calling exception"
```

Expected: PASS.

- [ ] **Step 5: Commit Task 2**

```bash
git add lib/service/im/im_service.dart test/service/im/im_service_test.dart
git commit -m "fix: keep windows realtime connected for notifications"
```

---

### Task 3: Add Desktop Alert Policy and Coalescing

**Files:**
- Create: `lib/wukong_push/notification/desktop_message_alert_policy.dart`
- Create: `test/wukong_push/desktop_message_alert_policy_test.dart`

- [ ] **Step 1: Write the failing policy tests**

Create `test/wukong_push/desktop_message_alert_policy_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_policy.dart';
import 'package:wukong_im_app/wukong_push/notification/message_alert_plan.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('DesktopMessageAlertPolicy', () {
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 5, 1, 12);
    });

    test('focused resumed app plays foreground sound without a card', () {
      final policy = DesktopMessageAlertPolicy(now: () => now);

      final decision = policy.resolve(
        plan: _plan('alice', 'Alice', 'hello'),
        lifecycleState: AppLifecycleState.resumed,
      );

      expect(decision.playForegroundSound, isTrue);
      expect(decision.playMessageSound, isFalse);
      expect(decision.notification, isNull);
    });

    test('hidden app shows a silent notification card and message sound', () {
      final policy = DesktopMessageAlertPolicy(now: () => now);

      final decision = policy.resolve(
        plan: _plan('alice', 'Alice', 'hello'),
        lifecycleState: AppLifecycleState.hidden,
      );

      expect(decision.playForegroundSound, isFalse);
      expect(decision.playMessageSound, isTrue);
      expect(decision.notification, isNotNull);
      expect(decision.notification!.identifier, 'wk-message-1-alice');
      expect(decision.notification!.title, 'Alice');
      expect(decision.notification!.body, 'hello');
    });

    test('coalesces rapid messages from the same conversation', () {
      final policy = DesktopMessageAlertPolicy(now: () => now);

      final first = policy.resolve(
        plan: _plan('alice', 'Alice', 'first'),
        lifecycleState: AppLifecycleState.hidden,
      );
      now = now.add(const Duration(milliseconds: 800));
      final second = policy.resolve(
        plan: _plan('alice', 'Alice', 'second'),
        lifecycleState: AppLifecycleState.hidden,
      );

      expect(first.notification!.body, 'first');
      expect(second.notification!.identifier, 'wk-message-1-alice');
      expect(second.notification!.body, '2 new messages');
    });

    test('does not coalesce different conversations', () {
      final policy = DesktopMessageAlertPolicy(now: () => now);

      final first = policy.resolve(
        plan: _plan('alice', 'Alice', 'hello'),
        lifecycleState: AppLifecycleState.hidden,
      );
      final second = policy.resolve(
        plan: _plan('bob', 'Bob', 'hello'),
        lifecycleState: AppLifecycleState.hidden,
      );

      expect(first.notification!.identifier, 'wk-message-1-alice');
      expect(second.notification!.identifier, 'wk-message-1-bob');
      expect(second.notification!.body, 'hello');
    });
  });
}

MessageAlertPlan _plan(String channelId, String title, String body) {
  return MessageAlertPlan(
    title: title,
    body: body,
    channelId: channelId,
    channelType: WKChannelType.personal,
  );
}
```

- [ ] **Step 2: Run the policy tests to verify they fail**

Run:

```bash
flutter test test/wukong_push/desktop_message_alert_policy_test.dart
```

Expected: FAIL because `desktop_message_alert_policy.dart` does not exist.

- [ ] **Step 3: Implement the pure policy**

Create `lib/wukong_push/notification/desktop_message_alert_policy.dart`:

```dart
import 'package:flutter/widgets.dart';

import 'message_alert_plan.dart';

class DesktopMessageNotification {
  const DesktopMessageNotification({
    required this.identifier,
    required this.title,
    required this.body,
  });

  final String identifier;
  final String title;
  final String body;
}

class DesktopMessageAlertDecision {
  const DesktopMessageAlertDecision({
    required this.playForegroundSound,
    required this.playMessageSound,
    this.notification,
  });

  const DesktopMessageAlertDecision.none()
    : playForegroundSound = false,
      playMessageSound = false,
      notification = null;

  final bool playForegroundSound;
  final bool playMessageSound;
  final DesktopMessageNotification? notification;
}

class DesktopMessageAlertPolicy {
  DesktopMessageAlertPolicy({
    DateTime Function()? now,
    this.coalesceWindow = const Duration(seconds: 2),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration coalesceWindow;
  final Map<String, _ConversationAlertWindow> _windows =
      <String, _ConversationAlertWindow>{};

  DesktopMessageAlertDecision resolve({
    required MessageAlertPlan plan,
    required AppLifecycleState lifecycleState,
  }) {
    if (_isForeground(lifecycleState)) {
      return const DesktopMessageAlertDecision(
        playForegroundSound: true,
        playMessageSound: false,
      );
    }

    final current = _now();
    final key = plan.conversationKey;
    final previous = _windows[key];
    final count =
        previous != null && current.difference(previous.lastAlertAt) <= coalesceWindow
        ? previous.count + 1
        : 1;
    _windows[key] = _ConversationAlertWindow(
      count: count,
      lastAlertAt: current,
    );

    return DesktopMessageAlertDecision(
      playForegroundSound: false,
      playMessageSound: true,
      notification: DesktopMessageNotification(
        identifier: _notificationIdentifier(plan),
        title: plan.title,
        body: count <= 1 ? plan.body : '$count new messages',
      ),
    );
  }

  bool _isForeground(AppLifecycleState lifecycleState) {
    return lifecycleState == AppLifecycleState.resumed;
  }

  String _notificationIdentifier(MessageAlertPlan plan) {
    final normalizedChannelId = plan.channelId
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');
    return 'wk-message-${plan.channelType}-$normalizedChannelId';
  }
}

class _ConversationAlertWindow {
  const _ConversationAlertWindow({
    required this.count,
    required this.lastAlertAt,
  });

  final int count;
  final DateTime lastAlertAt;
}
```

- [ ] **Step 4: Run the policy tests to verify they pass**

Run:

```bash
flutter test test/wukong_push/desktop_message_alert_policy_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 3**

```bash
git add lib/wukong_push/notification/desktop_message_alert_policy.dart test/wukong_push/desktop_message_alert_policy_test.dart
git commit -m "feat: add desktop message alert policy"
```

---

### Task 4: Add Windows Presenter Backend

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/wukong_push/notification/desktop_message_alert_presenter.dart`
- Create: `lib/wukong_push/notification/desktop_message_alert_presenter_factory.dart`
- Create: `lib/wukong_push/notification/desktop_message_alert_presenter_stub.dart`
- Create: `lib/wukong_push/notification/desktop_message_alert_presenter_io.dart`

- [ ] **Step 1: Add the dependency**

Modify `pubspec.yaml` under dependencies:

```yaml
  local_notifier: ^0.1.6
```

Run:

```bash
flutter pub get
```

Expected: PASS and `pubspec.lock` includes `local_notifier`. This package supports Windows, macOS, and Linux and exposes `LocalNotification(identifier: ..., silent: ...)`.

- [ ] **Step 2: Create the presenter interface**

Create `lib/wukong_push/notification/desktop_message_alert_presenter.dart`:

```dart
import 'desktop_message_alert_policy.dart';

abstract class DesktopMessageAlertPresenter {
  Future<void> initialize();

  Future<void> playForegroundTick();

  Future<void> playMessageSound();

  Future<void> showNotification(DesktopMessageNotification notification);

  Future<void> dispose();
}
```

- [ ] **Step 3: Create the conditional factory and stub**

Create `lib/wukong_push/notification/desktop_message_alert_presenter_factory.dart`:

```dart
import 'desktop_message_alert_presenter.dart';
import 'desktop_message_alert_presenter_stub.dart'
    if (dart.library.io) 'desktop_message_alert_presenter_io.dart';

DesktopMessageAlertPresenter createDefaultDesktopMessageAlertPresenter() {
  return createDesktopMessageAlertPresenter();
}
```

Create `lib/wukong_push/notification/desktop_message_alert_presenter_stub.dart`:

```dart
import 'desktop_message_alert_policy.dart';
import 'desktop_message_alert_presenter.dart';

DesktopMessageAlertPresenter createDesktopMessageAlertPresenter() {
  return const DesktopMessageAlertPresenterStub();
}

class DesktopMessageAlertPresenterStub implements DesktopMessageAlertPresenter {
  const DesktopMessageAlertPresenterStub();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playForegroundTick() async {}

  @override
  Future<void> playMessageSound() async {}

  @override
  Future<void> showNotification(DesktopMessageNotification notification) async {}

  @override
  Future<void> dispose() async {}
}
```

- [ ] **Step 4: Create the IO presenter**

Create `lib/wukong_push/notification/desktop_message_alert_presenter_io.dart`:

```dart
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

import '../../core/config/app_config.dart';
import 'desktop_message_alert_policy.dart';
import 'desktop_message_alert_presenter.dart';

DesktopMessageAlertPresenter createDesktopMessageAlertPresenter() {
  return DesktopMessageAlertPresenterIo();
}

class DesktopMessageAlertPresenterIo implements DesktopMessageAlertPresenter {
  DesktopMessageAlertPresenterIo({
    String foregroundSoundAssetPath = 'audio/im_tick.wav',
    String messageSoundAssetPath = 'audio/im_message.wav',
    double foregroundVolume = 0.35,
    double messageVolume = 0.65,
    Duration foregroundSoundMaxDuration = const Duration(milliseconds: 180),
    Duration messageSoundMaxDuration = const Duration(milliseconds: 900),
  }) : _foregroundSoundAssetPath = foregroundSoundAssetPath,
       _messageSoundAssetPath = messageSoundAssetPath,
       _foregroundVolume = foregroundVolume.clamp(0.0, 1.0).toDouble(),
       _messageVolume = messageVolume.clamp(0.0, 1.0).toDouble(),
       _foregroundSoundMaxDuration = foregroundSoundMaxDuration,
       _messageSoundMaxDuration = messageSoundMaxDuration;

  final AudioPlayer _foregroundPlayer = AudioPlayer(
    playerId: 'wk_desktop_notification_foreground',
  );
  final AudioPlayer _messagePlayer = AudioPlayer(
    playerId: 'wk_desktop_notification_message',
  );
  final String _foregroundSoundAssetPath;
  final String _messageSoundAssetPath;
  final double _foregroundVolume;
  final double _messageVolume;
  final Duration _foregroundSoundMaxDuration;
  final Duration _messageSoundMaxDuration;

  bool _initialized = false;
  Timer? _foregroundStopTimer;
  Timer? _messageStopTimer;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    try {
      await localNotifier.setup(
        appName: AppConfig.appName,
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      await Future.wait<void>([
        _foregroundPlayer.setReleaseMode(ReleaseMode.stop),
        _messagePlayer.setReleaseMode(ReleaseMode.stop),
      ]);
      _initialized = true;
    } catch (error, stackTrace) {
      _logError('Desktop notification presenter initialization failed', error, stackTrace);
    }
  }

  @override
  Future<void> playForegroundTick() async {
    await _play(
      player: _foregroundPlayer,
      assetPath: _foregroundSoundAssetPath,
      volume: _foregroundVolume,
      maxDuration: _foregroundSoundMaxDuration,
      replaceTimer: (timer) => _foregroundStopTimer = timer,
      cancelTimer: () => _foregroundStopTimer?.cancel(),
    );
  }

  @override
  Future<void> playMessageSound() async {
    await _play(
      player: _messagePlayer,
      assetPath: _messageSoundAssetPath,
      volume: _messageVolume,
      maxDuration: _messageSoundMaxDuration,
      replaceTimer: (timer) => _messageStopTimer = timer,
      cancelTimer: () => _messageStopTimer?.cancel(),
    );
  }

  @override
  Future<void> showNotification(DesktopMessageNotification notification) async {
    await initialize();
    try {
      final localNotification = LocalNotification(
        identifier: notification.identifier,
        title: notification.title,
        body: notification.body,
        silent: true,
      );
      await localNotification.show();
    } catch (error, stackTrace) {
      _logError('Showing desktop message notification failed', error, stackTrace);
    }
  }

  @override
  Future<void> dispose() async {
    _foregroundStopTimer?.cancel();
    _messageStopTimer?.cancel();
    await Future.wait<void>([
      _safeStop(_foregroundPlayer),
      _safeStop(_messagePlayer),
    ]);
    await Future.wait<void>([
      _foregroundPlayer.dispose(),
      _messagePlayer.dispose(),
    ]);
  }

  Future<void> _play({
    required AudioPlayer player,
    required String assetPath,
    required double volume,
    required Duration maxDuration,
    required void Function(Timer timer) replaceTimer,
    required void Function() cancelTimer,
  }) async {
    await initialize();
    try {
      cancelTimer();
      await _safeStop(player);
      await player.play(
        AssetSource(assetPath),
        volume: volume,
        mode: PlayerMode.lowLatency,
      );
      replaceTimer(Timer(maxDuration, () => unawaited(_safeStop(player))));
    } catch (error, stackTrace) {
      _logError('Playing desktop message alert sound failed', error, stackTrace);
    }
  }

  Future<void> _safeStop(AudioPlayer player) async {
    try {
      await player.stop();
    } catch (error, stackTrace) {
      _logError('Stopping desktop alert sound failed', error, stackTrace);
    }
  }

  void _logError(String message, Object error, StackTrace stackTrace) {
    debugPrint('$message: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
```

- [ ] **Step 5: Run dependency and analyzer checks**

Run:

```bash
flutter pub get
flutter analyze lib/wukong_push/notification/desktop_message_alert_presenter_io.dart
```

Expected: PASS. If `AppConfig.appName` is unavailable or not a `String`, replace it with the literal `'InfoEquity'`.

- [ ] **Step 6: Commit Task 4**

```bash
git add pubspec.yaml pubspec.lock lib/wukong_push/notification/desktop_message_alert_presenter.dart lib/wukong_push/notification/desktop_message_alert_presenter_factory.dart lib/wukong_push/notification/desktop_message_alert_presenter_stub.dart lib/wukong_push/notification/desktop_message_alert_presenter_io.dart
git commit -m "feat: add windows desktop notification presenter"
```

---

### Task 5: Add Desktop Alert Manager and Wire IMService

**Files:**
- Create: `lib/wukong_push/notification/desktop_message_alert_manager.dart`
- Create: `test/wukong_push/desktop_message_alert_manager_test.dart`
- Modify: `lib/service/im/im_service.dart`

- [ ] **Step 1: Write the failing manager tests**

Create `test/wukong_push/desktop_message_alert_manager_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_manager.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_policy.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_presenter.dart';
import 'package:wukong_im_app/wukong_push/notification/message_alert_plan.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('DesktopMessageAlertManager', () {
    test('ignores non-Windows platforms', () async {
      final presenter = _FakePresenter();
      final manager = DesktopMessageAlertManager(
        presenter: presenter,
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.macOS,
      );

      await manager.showNewMessageAlert(
        plan: _plan(),
        lifecycleState: AppLifecycleState.hidden,
      );

      expect(presenter.notifications, isEmpty);
      expect(presenter.messageSoundCount, 0);
      expect(presenter.foregroundSoundCount, 0);
    });

    test('focused Windows message only plays foreground sound', () async {
      final presenter = _FakePresenter();
      final manager = DesktopMessageAlertManager(
        presenter: presenter,
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.windows,
      );

      await manager.showNewMessageAlert(
        plan: _plan(),
        lifecycleState: AppLifecycleState.resumed,
      );

      expect(presenter.foregroundSoundCount, 1);
      expect(presenter.messageSoundCount, 0);
      expect(presenter.notifications, isEmpty);
    });

    test('background Windows message plays message sound and shows card', () async {
      final presenter = _FakePresenter();
      final manager = DesktopMessageAlertManager(
        presenter: presenter,
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.windows,
      );

      await manager.showNewMessageAlert(
        plan: _plan(),
        lifecycleState: AppLifecycleState.hidden,
      );

      expect(presenter.foregroundSoundCount, 0);
      expect(presenter.messageSoundCount, 1);
      expect(presenter.notifications.single.title, 'Alice');
    });
  });
}

MessageAlertPlan _plan() {
  return const MessageAlertPlan(
    title: 'Alice',
    body: 'hello',
    channelId: 'alice',
    channelType: WKChannelType.personal,
  );
}

class _FakePresenter implements DesktopMessageAlertPresenter {
  int foregroundSoundCount = 0;
  int messageSoundCount = 0;
  final List<DesktopMessageNotification> notifications =
      <DesktopMessageNotification>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playForegroundTick() async {
    foregroundSoundCount += 1;
  }

  @override
  Future<void> playMessageSound() async {
    messageSoundCount += 1;
  }

  @override
  Future<void> showNotification(DesktopMessageNotification notification) async {
    notifications.add(notification);
  }

  @override
  Future<void> dispose() async {}
}
```

- [ ] **Step 2: Run the manager tests to verify they fail**

Run:

```bash
flutter test test/wukong_push/desktop_message_alert_manager_test.dart
```

Expected: FAIL because `desktop_message_alert_manager.dart` does not exist.

- [ ] **Step 3: Implement the manager**

Create `lib/wukong_push/notification/desktop_message_alert_manager.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'desktop_message_alert_policy.dart';
import 'desktop_message_alert_presenter.dart';
import 'desktop_message_alert_presenter_factory.dart';
import 'message_alert_plan.dart';

class DesktopMessageAlertManager {
  DesktopMessageAlertManager({
    DesktopMessageAlertPresenter? presenter,
    DesktopMessageAlertPolicy? policy,
    bool Function()? isWeb,
    TargetPlatform Function()? targetPlatform,
  }) : _presenter = presenter ?? createDefaultDesktopMessageAlertPresenter(),
       _policy = policy ?? DesktopMessageAlertPolicy(),
       _isWeb = isWeb ?? (() => kIsWeb),
       _targetPlatform = targetPlatform ?? (() => defaultTargetPlatform);

  static final DesktopMessageAlertManager instance =
      DesktopMessageAlertManager();

  final DesktopMessageAlertPresenter _presenter;
  final DesktopMessageAlertPolicy _policy;
  final bool Function() _isWeb;
  final TargetPlatform Function() _targetPlatform;

  Future<void> showNewMessageAlert({
    required MessageAlertPlan plan,
    required AppLifecycleState lifecycleState,
  }) async {
    if (_isWeb() || _targetPlatform() != TargetPlatform.windows) {
      return;
    }

    final decision = _policy.resolve(
      plan: plan,
      lifecycleState: lifecycleState,
    );

    if (decision.playForegroundSound) {
      await _presenter.playForegroundTick();
    }
    if (decision.playMessageSound) {
      await _presenter.playMessageSound();
    }
    final notification = decision.notification;
    if (notification != null) {
      await _presenter.showNotification(notification);
    }
  }

  Future<void> dispose() => _presenter.dispose();
}
```

- [ ] **Step 4: Wire IMService lifecycle state and desktop alerts**

Modify imports in `lib/service/im/im_service.dart`:

```dart
import '../../wukong_push/notification/desktop_message_alert_manager.dart';
import '../../wukong_push/notification/message_alert_plan.dart';
```

Keep the Web imports:

```dart
import '../../wukong_push/notification/web_message_alert_plan.dart';
import '../../wukong_push/notification/web_notification_manager.dart';
```

Add a lifecycle field in `IMService`:

```dart
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
```

At the start of `didChangeAppLifecycleState`:

```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    switch (state) {
```

Update `_handleNewMessages`:

```dart
      if (kIsWeb) {
        _scheduleWebMessageAlert(message, currentUid: currentUid);
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        _scheduleDesktopMessageAlert(message, currentUid: currentUid);
      }
```

Add the helper near `_scheduleWebMessageAlert`:

```dart
  void _scheduleDesktopMessageAlert(
    WKMsg message, {
    required String currentUid,
  }) {
    try {
      final plan = buildMessageAlertPlan(message, currentUid: currentUid);
      if (plan == null) {
        return;
      }
      unawaited(
        DesktopMessageAlertManager.instance.showNewMessageAlert(
          plan: plan,
          lifecycleState: _appLifecycleState,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Desktop message alert scheduling failed: $error');
      debugPrint('$stackTrace');
    }
  }
```

- [ ] **Step 5: Run manager and IM tests**

Run:

```bash
flutter test test/wukong_push/desktop_message_alert_manager_test.dart
flutter test test/service/im/im_service_test.dart --plain-name "windows desktop notification mode keeps realtime connected in background"
```

Expected: PASS.

- [ ] **Step 6: Commit Task 5**

```bash
git add lib/wukong_push/notification/desktop_message_alert_manager.dart test/wukong_push/desktop_message_alert_manager_test.dart lib/service/im/im_service.dart
git commit -m "feat: wire windows message alerts"
```

---

### Task 6: Integration Policy Tests and Final Verification

**Files:**
- Modify: `test/wukong_push/web_notification_integration_policy_test.dart`
- Create: `test/wukong_push/windows_notification_integration_policy_test.dart`

- [ ] **Step 1: Add Windows integration policy test**

Create `test/wukong_push/windows_notification_integration_policy_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IMService forwards Windows incoming messages to desktop alert manager', () {
    final source = File('lib/service/im/im_service.dart').readAsStringSync();

    expect(source, contains('desktop_message_alert_manager.dart'));
    expect(source, contains('message_alert_plan.dart'));
    expect(source, contains('_scheduleDesktopMessageAlert'));
    expect(source, contains('TargetPlatform.windows'));
    expect(source, contains('DesktopMessageAlertManager.instance.showNewMessageAlert'));
  });

  test('Windows presenter uses local_notifier and bundled audio assets', () {
    final source = File(
      'lib/wukong_push/notification/desktop_message_alert_presenter_io.dart',
    ).readAsStringSync();

    expect(source, contains("import 'package:local_notifier/local_notifier.dart';"));
    expect(source, contains("identifier: notification.identifier"));
    expect(source, contains('silent: true'));
    expect(source, contains('audio/im_tick.wav'));
    expect(source, contains('audio/im_message.wav'));
  });

  test('pubspec declares local_notifier dependency', () {
    final source = File('pubspec.yaml').readAsStringSync();

    expect(source, contains('local_notifier: ^0.1.6'));
  });
}
```

- [ ] **Step 2: Run the new integration policy test**

Run:

```bash
flutter test test/wukong_push/windows_notification_integration_policy_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run focused notification test suite**

Run:

```bash
flutter test test/wukong_push/message_alert_plan_test.dart test/wukong_push/web_message_alert_plan_test.dart test/wukong_push/desktop_message_alert_policy_test.dart test/wukong_push/desktop_message_alert_manager_test.dart test/wukong_push/windows_notification_integration_policy_test.dart test/wukong_push/web_notification_integration_policy_test.dart
```

Expected: PASS.

- [ ] **Step 4: Run analyzer on touched code**

Run:

```bash
flutter analyze lib/service/im/im_service.dart lib/wukong_push/notification
```

Expected: PASS or only pre-existing unrelated warnings. If warnings reference touched files, fix them before continuing.

- [ ] **Step 5: Manual Windows smoke test**

Run:

```bash
flutter run -d windows
```

Manual checks:

- Log in and keep the app focused. Send a message from another account. Expected: short foreground tick, no Windows notification card.
- Minimize the app. Send one message from another account. Expected: `im_message.wav` plays and a Windows notification card appears.
- Send two more messages to the same conversation within 2 seconds. Expected: notification identifier stays per conversation and the card body updates to `2 new messages` or `3 new messages`.
- Send a self message. Expected: no sound and no card.
- Mute the conversation, then send a message. Expected: no sound and no card.

- [ ] **Step 6: Commit Task 6**

```bash
git add test/wukong_push/windows_notification_integration_policy_test.dart test/wukong_push/web_notification_integration_policy_test.dart
git commit -m "test: cover windows message notification integration"
```

---

## Self-Review

- Spec coverage:
  - Sound on eligible Windows incoming messages: Tasks 3, 4, 5, and 6.
  - Minimized/background Windows notification card: Tasks 3, 4, 5, and manual smoke test.
  - Foreground sound-only behavior: Tasks 3 and 5.
  - Notification frequency/coalescing: Task 3.
  - Existing Web behavior unchanged: Task 1 compatibility wrapper and Task 6 Web test run.
  - Windows realtime keepalive while minimized: Task 2.

- Placeholder scan:
  - No `TBD`, `TODO`, or unspecified implementation steps are present.
  - Every code creation step includes concrete snippets and commands.

- Type consistency:
  - `MessageAlertPlan`, `DesktopMessageNotification`, `DesktopMessageAlertDecision`, `DesktopMessageAlertPolicy`, `DesktopMessageAlertPresenter`, and `DesktopMessageAlertManager` are introduced before later tasks use them.
  - `playForegroundTick`, `playMessageSound`, and `showNotification` signatures match in interface, stub, IO presenter, fake presenter, and manager.

