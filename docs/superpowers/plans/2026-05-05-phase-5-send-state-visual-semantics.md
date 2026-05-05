# Phase 5 Send-State Visual Semantics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace raw outgoing-message send status rendering with a conservative semantic visual model: sending, sent, delivered, read, and failed.

**Architecture:** Add a pure Dart semantic mapper in `message_bubble.dart`, then let `MessageStatusInfo` carry that semantic state into the existing compact status badge. Keep current chat bubble layout and retry behavior, but derive icons/colors from `ChatSendVisualState` instead of ad-hoc raw status checks. Preserve `SendStatusIndicator(status: int)` compatibility while adding a semantic constructor.

**Tech Stack:** Flutter/Dart 3.11, `flutter_test`, WuKong SDK `WKMsg` / `WKMsgExtra` / `WKSendMsgResult`, existing `WKReferenceAssets` send status icons, existing `ChatMotionDurations.statusChange` token.

---

## File Structure

- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-send-state-visual-semantics\lib\widgets\message_bubble.dart`
  - Responsibility: outgoing-message status semantic mapping and compact badge rendering.
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-send-state-visual-semantics\lib\core\transitions\message_animations.dart`
  - Responsibility: standalone animated send status indicator; keep raw int compatibility but render through semantic state.
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-send-state-visual-semantics\test\modules\chat\message_bubble_experience_test.dart`
  - Responsibility: mapping and rendered badge asset/color/retry tests.
- Create: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-send-state-visual-semantics\test\core\transitions\send_status_indicator_test.dart`
  - Responsibility: widget coverage for standalone `SendStatusIndicator`.

Do not modify service/server code, WuKong SDK files, Jank telemetry, or unrelated encoded Chinese copy.

---

### Task 1: Lock down semantic mapping tests

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-send-state-visual-semantics\test\modules\chat\message_bubble_experience_test.dart`

- [ ] **Step 1: Add mapping tests**

In `test/modules/chat/message_bubble_experience_test.dart`, insert this block before the existing test named `resolveMessageStatusInfo returns personal read state`:

```dart
    test('resolveMessageStatusInfo maps outgoing send status to visual states', () {
      final sendingMessage = WKMsg()
        ..fromUID = 'u_self'
        ..status = WKSendMsgResult.sendLoading
        ..channelType = WKChannelType.personal;
      final sentMessage = WKMsg()
        ..fromUID = 'u_self'
        ..status = WKSendMsgResult.sendSuccess
        ..channelType = WKChannelType.personal;
      final deliveredMessage = WKMsg()
        ..fromUID = 'u_self'
        ..status = WKSendMsgResult.sendSuccess
        ..channelType = WKChannelType.personal
        ..wkMsgExtra = WKMsgExtra();
      final readMessage = WKMsg()
        ..fromUID = 'u_self'
        ..status = WKSendMsgResult.sendSuccess
        ..channelType = WKChannelType.personal
        ..wkMsgExtra = (WKMsgExtra()..readed = 1);
      final failedMessage = WKMsg()
        ..fromUID = 'u_self'
        ..status = WKSendMsgResult.sendFail
        ..channelType = WKChannelType.personal;
      final unknownMessage = WKMsg()
        ..fromUID = 'u_self'
        ..status = 999
        ..channelType = WKChannelType.personal;

      expect(
        resolveMessageStatusInfo(sendingMessage, isSelf: true)?.visualState,
        ChatSendVisualState.sending,
      );
      expect(
        resolveMessageStatusInfo(sentMessage, isSelf: true)?.visualState,
        ChatSendVisualState.sent,
      );
      expect(
        resolveMessageStatusInfo(deliveredMessage, isSelf: true)?.visualState,
        ChatSendVisualState.delivered,
      );
      expect(
        resolveMessageStatusInfo(readMessage, isSelf: true)?.visualState,
        ChatSendVisualState.read,
      );
      expect(
        resolveMessageStatusInfo(failedMessage, isSelf: true)?.visualState,
        ChatSendVisualState.failed,
      );
      expect(
        resolveMessageStatusInfo(unknownMessage, isSelf: true)?.visualState,
        ChatSendVisualState.sent,
      );
      expect(resolveMessageStatusInfo(sentMessage, isSelf: false), isNull);
    });

    test('resolveMessageStatusInfo treats server-acknowledged loading as sent', () {
      final syncedLoadingMessage = WKMsg()
        ..fromUID = 'u_self'
        ..status = WKSendMsgResult.sendLoading
        ..channelType = WKChannelType.personal
        ..messageID = 'server-msg-1';

      final status = resolveMessageStatusInfo(
        syncedLoadingMessage,
        isSelf: true,
      );

      expect(status?.visualState, ChatSendVisualState.sent);
      expect(status?.isLoading, isFalse);
    });
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
flutter test test/modules/chat/message_bubble_experience_test.dart --plain-name "resolveMessageStatusInfo maps outgoing send status to visual states"
```

Expected before implementation:

```text
Error: The getter 'visualState' isn't defined for the type 'MessageStatusInfo'.
Error: Undefined name 'ChatSendVisualState'.
```

- [ ] **Step 3: Commit failing tests**

Run:

```powershell
git add test/modules/chat/message_bubble_experience_test.dart
git commit -m "test: lock down send-state visual semantics"
```

---

### Task 2: Implement semantic mapper

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-send-state-visual-semantics\lib\widgets\message_bubble.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-send-state-visual-semantics\test\modules\chat\message_bubble_experience_test.dart`

- [ ] **Step 1: Add enum and extend `MessageStatusInfo`**

In `lib/widgets/message_bubble.dart`, add this enum immediately before `class MessageStatusInfo`:

```dart
enum ChatSendVisualState { sending, sent, delivered, read, failed }
```

Replace `MessageStatusInfo` with:

```dart
class MessageStatusInfo {
  final ChatSendVisualState visualState;
  final String label;
  final IconData? icon;
  final String? assetIcon;
  final Color foregroundColor;
  final bool isLoading;

  const MessageStatusInfo({
    required this.visualState,
    required this.label,
    this.icon,
    this.assetIcon,
    required this.foregroundColor,
    this.isLoading = false,
  });
}
```

- [ ] **Step 2: Add semantic colors and mapper helpers**

Insert after `MessageStatusInfo`:

```dart
const Color _sendStatusPendingColor = Color(0xFF7A8799);
const Color _sendStatusNeutralColor = Color(0xFF677487);
const Color _sendStatusReadColor = Color(0xFF2196F3);
const Color _sendStatusFailedColor = Color(0xFFD64545);

@visibleForTesting
ChatSendVisualState resolveChatSendVisualState(
  WKMsg message, {
  required bool isSelf,
}) {
  if (!isSelf) {
    return ChatSendVisualState.sent;
  }

  final hasServerIdentity =
      message.messageID.trim().isNotEmpty || message.messageSeq > 0;
  final status = message.status;

  if (status == WKSendMsgResult.sendFail) {
    return ChatSendVisualState.failed;
  }

  if (status == WKSendMsgResult.sendLoading && !hasServerIdentity) {
    return ChatSendVisualState.sending;
  }

  final extra = message.wkMsgExtra;
  final isRead =
      (extra?.readed ?? 0) == 1 ||
      (extra?.readedCount ?? 0) > 0 ||
      message.viewed == 1 ||
      message.viewedAt > 0;
  if (isRead) {
    return ChatSendVisualState.read;
  }

  if (extra != null) {
    return ChatSendVisualState.delivered;
  }

  return ChatSendVisualState.sent;
}

MessageStatusInfo _messageStatusInfoForState(
  ChatSendVisualState state, {
  String? label,
}) {
  switch (state) {
    case ChatSendVisualState.sending:
      return MessageStatusInfo(
        visualState: state,
        label: label ?? '发送中',
        icon: Icons.schedule_rounded,
        foregroundColor: _sendStatusPendingColor,
        isLoading: true,
      );
    case ChatSendVisualState.failed:
      return MessageStatusInfo(
        visualState: state,
        label: label ?? '发送失败',
        icon: Icons.error_outline_rounded,
        foregroundColor: _sendStatusFailedColor,
      );
    case ChatSendVisualState.read:
      return MessageStatusInfo(
        visualState: state,
        label: label ?? '已读',
        icon: Icons.done_all_rounded,
        foregroundColor: _sendStatusReadColor,
      );
    case ChatSendVisualState.delivered:
      return MessageStatusInfo(
        visualState: state,
        label: label ?? '已送达',
        icon: Icons.done_all_rounded,
        foregroundColor: _sendStatusNeutralColor,
      );
    case ChatSendVisualState.sent:
      return MessageStatusInfo(
        visualState: state,
        label: label ?? '已发送',
        icon: Icons.check_rounded,
        foregroundColor: _sendStatusNeutralColor,
      );
  }
}
```

This deliberately treats `sendSuccess` alone as `sent`; `wkMsgExtra != null` as existing delivered evidence; read counters/flags as `read`; and unknown raw statuses as `sent`.

- [ ] **Step 3: Replace `resolveMessageStatusInfo` body**

Replace the whole function with:

```dart
MessageStatusInfo? resolveMessageStatusInfo(
  WKMsg message, {
  required bool isSelf,
}) {
  if (!isSelf) {
    return null;
  }

  final state = resolveChatSendVisualState(message, isSelf: isSelf);
  final extra = message.wkMsgExtra;

  if (message.channelType == WKChannelType.group &&
      extra != null &&
      state == ChatSendVisualState.read) {
    final readedCount = extra.readedCount;
    final unreadCount = extra.unreadCount;
    if (readedCount > 0 || unreadCount > 0) {
      final label = unreadCount > 0
          ? '$readedCount已读 · $unreadCount未读'
          : '$readedCount已读';
      return _messageStatusInfoForState(state, label: label);
    }
  }

  return _messageStatusInfoForState(state);
}
```

- [ ] **Step 4: Remove the now-unused private `copyWith` extension**

At the bottom of `lib/widgets/message_bubble.dart`, delete the full private extension block that currently starts with `extension on MessageStatusInfo {` and contains this method:

```dart
extension on MessageStatusInfo {
  MessageStatusInfo copyWith({
    String? label,
    IconData? icon,
    String? assetIcon,
    Color? foregroundColor,
    bool? isLoading,
  }) {
    return MessageStatusInfo(
      label: label ?? this.label,
      icon: icon ?? this.icon,
      assetIcon: assetIcon ?? this.assetIcon,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
```

No external caller can depend on this unnamed private extension, and the new resolver no longer needs it.

- [ ] **Step 5: Format and verify GREEN**

Run:

```powershell
dart format lib/widgets/message_bubble.dart test/modules/chat/message_bubble_experience_test.dart
flutter test test/modules/chat/message_bubble_experience_test.dart --plain-name "resolveMessageStatusInfo maps outgoing send status to visual states"
flutter test test/modules/chat/message_bubble_experience_test.dart --plain-name "resolveMessageStatusInfo treats server-acknowledged loading as sent"
flutter test test/modules/chat/message_bubble_experience_test.dart --plain-name "resolveMessageStatusInfo returns personal read state"
flutter test test/modules/chat/message_bubble_experience_test.dart --plain-name "resolveMessageStatusInfo returns group receipt summary"
```

Expected for each `flutter test` command:

```text
All tests passed!
```

- [ ] **Step 6: Commit mapper implementation**

Run:

```powershell
git add lib/widgets/message_bubble.dart test/modules/chat/message_bubble_experience_test.dart
git commit -m "feat: map chat send status to visual states"
```

---

### Task 3: Render compact badges from semantic state

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-send-state-visual-semantics\lib\widgets\message_bubble.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-send-state-visual-semantics\test\modules\chat\message_bubble_experience_test.dart`

- [ ] **Step 1: Add test helper**

Add this top-level helper after imports in `test/modules/chat/message_bubble_experience_test.dart`:

```dart
Finder _statusAssetFinder(String assetName) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == assetName,
  );
}
```

- [ ] **Step 2: Add badge rendering tests**

Insert after the mapping tests:

```dart
    testWidgets('send status badge renders sent as a single neutral check', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('sent only')
        ..status = WKSendMsgResult.sendSuccess;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );

      expect(_statusAssetFinder(WKReferenceAssets.sendSingle), findsOneWidget);
      expect(_statusAssetFinder(WKReferenceAssets.sendDouble), findsNothing);
      final image = tester.widget<Image>(
        _statusAssetFinder(WKReferenceAssets.sendSingle),
      );
      expect(image.color, const Color(0xFF677487));
    });

    testWidgets('send status badge renders delivered as double neutral checks', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('delivered')
        ..status = WKSendMsgResult.sendSuccess
        ..wkMsgExtra = WKMsgExtra();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );

      expect(_statusAssetFinder(WKReferenceAssets.sendDouble), findsOneWidget);
      final image = tester.widget<Image>(
        _statusAssetFinder(WKReferenceAssets.sendDouble),
      );
      expect(image.color, const Color(0xFF677487));
    });

    testWidgets('send status badge renders read as double blue checks', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('read')
        ..status = WKSendMsgResult.sendSuccess
        ..wkMsgExtra = (WKMsgExtra()..readedCount = 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );

      expect(_statusAssetFinder(WKReferenceAssets.sendDouble), findsOneWidget);
      final image = tester.widget<Image>(
        _statusAssetFinder(WKReferenceAssets.sendDouble),
      );
      expect(image.color, const Color(0xFF2196F3));
    });

    testWidgets('send status badge keeps failed retry affordance red', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('failed')
        ..status = WKSendMsgResult.sendFail;
      var retryCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              onRetrySend: () => retryCount += 1,
            ),
          ),
        ),
      );

      expect(_statusAssetFinder(WKReferenceAssets.sendFail), findsOneWidget);
      final image = tester.widget<Image>(
        _statusAssetFinder(WKReferenceAssets.sendFail),
      );
      expect(image.color, const Color(0xFFD64545));

      await tester.tap(
        find.byKey(const ValueKey<String>('message-retry-send-button')),
      );
      expect(retryCount, 1);
    });
```

- [ ] **Step 3: Update compact badge implementation**

In `_CompactMessageStatusBadge.build`, replace the existing `statusColor` expression with direct semantic colors:

```dart
    final statusColor = status?.foregroundColor;
```

This makes sent/delivered/read/failed icon colors follow the approved visual semantics even when the timestamp text still uses bubble-specific contrast colors.

Then replace icon-based failed checks with visual-state checks:

    final canRetry =
        isSelf &&
        onRetrySend != null &&
        status?.visualState == ChatSendVisualState.failed;
```

Also replace `shouldShake` with:

```dart
    final shouldShake =
        isSelf &&
        status?.visualState == ChatSendVisualState.failed &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
```

Replace `_statusAssetIcon` with:

```dart
  String? _statusAssetIcon(MessageStatusInfo status) {
    if (status.assetIcon != null && status.assetIcon!.isNotEmpty) {
      return status.assetIcon;
    }
    switch (status.visualState) {
      case ChatSendVisualState.failed:
        return WKReferenceAssets.sendFail;
      case ChatSendVisualState.read:
      case ChatSendVisualState.delivered:
        return WKReferenceAssets.sendDouble;
      case ChatSendVisualState.sent:
        return WKReferenceAssets.sendSingle;
      case ChatSendVisualState.sending:
        return null;
    }
  }
```

- [ ] **Step 4: Format and run badge tests**

Run:

```powershell
dart format lib/widgets/message_bubble.dart test/modules/chat/message_bubble_experience_test.dart
flutter test test/modules/chat/message_bubble_experience_test.dart --plain-name "send status badge renders sent as a single neutral check"
flutter test test/modules/chat/message_bubble_experience_test.dart --plain-name "send status badge renders delivered as double neutral checks"
flutter test test/modules/chat/message_bubble_experience_test.dart --plain-name "send status badge renders read as double blue checks"
flutter test test/modules/chat/message_bubble_experience_test.dart --plain-name "send status badge keeps failed retry affordance red"
flutter test test/modules/chat/message_bubble_experience_test.dart --plain-name "failed outgoing status exposes a retry tap target"
flutter test test/modules/chat/message_bubble_experience_test.dart --plain-name "failed outgoing status plays a short shake affordance"
flutter test test/modules/chat/message_bubble_experience_test.dart --plain-name "pending outgoing status shows a subtle pulse affordance"
flutter test test/modules/chat/message_bubble_experience_test.dart --plain-name "text bubble shows delivery state and selection support"
```

Expected for each `flutter test` command:

```text
All tests passed!
```

- [ ] **Step 5: Commit badge rendering**

Run:

```powershell
git add lib/widgets/message_bubble.dart test/modules/chat/message_bubble_experience_test.dart
git commit -m "refactor: render chat send badges from visual state"
```

---

### Task 4: Refactor standalone `SendStatusIndicator`

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-send-state-visual-semantics\lib\core\transitions\message_animations.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-send-state-visual-semantics\test\core\transitions\send_status_indicator_test.dart`

- [ ] **Step 1: Create failing transition tests**

Create `test/core/transitions/send_status_indicator_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/transitions/message_animations.dart';
import 'package:wukong_im_app/widgets/message_bubble.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  testWidgets('SendStatusIndicator maps raw success to a neutral sent check', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SendStatusIndicator(status: WKSendMsgResult.sendSuccess),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    expect(icon.color, const Color(0xFF677487));
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });

  testWidgets('SendStatusIndicator renders delivered and read semantic states', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SendStatusIndicator.visual(
                state: ChatSendVisualState.delivered,
              ),
              SendStatusIndicator.visual(state: ChatSendVisualState.read),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final deliveredIcon = tester.widget<Icon>(
      find.byKey(const ValueKey<String>('send-status-delivered')),
    );
    final readIcon = tester.widget<Icon>(
      find.byKey(const ValueKey<String>('send-status-read')),
    );

    expect(deliveredIcon.icon, Icons.done_all_rounded);
    expect(deliveredIcon.color, const Color(0xFF677487));
    expect(readIcon.icon, Icons.done_all_rounded);
    expect(readIcon.color, const Color(0xFF2196F3));
  });

  testWidgets('SendStatusIndicator keeps loading and failed affordances', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SendStatusIndicator(status: WKSendMsgResult.sendLoading),
              SendStatusIndicator(status: WKSendMsgResult.sendFail),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 48));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final failedIcon = tester.widget<Icon>(
      find.byKey(const ValueKey<String>('send-status-failed')),
    );
    expect(failedIcon.icon, Icons.error_outline);
    expect(failedIcon.color, Colors.red.shade400);
  });
}
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
flutter test test/core/transitions/send_status_indicator_test.dart
```

Expected before implementation:

```text
Error: Couldn't find constructor 'SendStatusIndicator.visual'.
```

- [ ] **Step 3: Update imports and constructors**

In `lib/core/transitions/message_animations.dart`, add:

```dart
import '../../widgets/message_bubble.dart';
```

Replace `SendStatusIndicator` with:

```dart
class SendStatusIndicator extends StatefulWidget {
  const SendStatusIndicator({
    super.key,
    required int status,
    this.size = 16.0,
  }) : state = status == WKSendMsgResult.sendFail
           ? ChatSendVisualState.failed
           : status == WKSendMsgResult.sendLoading
           ? ChatSendVisualState.sending
           : ChatSendVisualState.sent;

  const SendStatusIndicator.visual({
    super.key,
    required this.state,
    this.size = 16.0,
  });

  final ChatSendVisualState state;
  final double size;

  @override
  State<SendStatusIndicator> createState() => _SendStatusIndicatorState();
}
```

Also add this SDK import because the constructor references `WKSendMsgResult`:

```dart
import 'package:wukongimfluttersdk/type/const.dart';
```

- [ ] **Step 4: Track semantic state in animation state**

Replace `_previousStatus` and status comparisons with:

```dart
  ChatSendVisualState _previousState = ChatSendVisualState.sending;
```

In `initState`:

```dart
    _previousState = widget.state;
```

Replace `didUpdateWidget` with:

```dart
  @override
  void didUpdateWidget(SendStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state && widget.state != _previousState) {
      _previousState = widget.state;
      _controller.forward(from: 0.0);
    }
  }
```

- [ ] **Step 5: Render by semantic state**

Replace the `switch (widget.status)` block in `build` with:

```dart
    switch (widget.state) {
      case ChatSendVisualState.sending:
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
            ),
          ),
        );
      case ChatSendVisualState.sent:
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            Icons.check_rounded,
            size: widget.size,
            color: const Color(0xFF677487),
          ),
        );
      case ChatSendVisualState.delivered:
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            Icons.done_all_rounded,
            key: const ValueKey<String>('send-status-delivered'),
            size: widget.size,
            color: const Color(0xFF677487),
          ),
        );
      case ChatSendVisualState.read:
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            Icons.done_all_rounded,
            key: const ValueKey<String>('send-status-read'),
            size: widget.size,
            color: const Color(0xFF2196F3),
          ),
        );
      case ChatSendVisualState.failed:
        return AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final offset =
                _shakeAnimation.value *
                4.0 *
                (1 - 2 * ((_shakeAnimation.value * 4).floor() % 2));
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: Icon(
            Icons.error_outline,
            key: const ValueKey<String>('send-status-failed'),
            size: widget.size,
            color: Colors.red.shade400,
          ),
        );
    }
```

- [ ] **Step 6: Format, test, analyze, commit**

Run:

```powershell
dart format lib/core/transitions/message_animations.dart test/core/transitions/send_status_indicator_test.dart
flutter test test/core/transitions/send_status_indicator_test.dart
flutter analyze lib/core/transitions/message_animations.dart lib/widgets/message_bubble.dart test/core/transitions/send_status_indicator_test.dart
git add lib/core/transitions/message_animations.dart lib/widgets/message_bubble.dart test/core/transitions/send_status_indicator_test.dart
git commit -m "refactor: align send status indicator semantics"
```

Expected:

```text
All tests passed!
No issues found!
```

---

### Task 5: Final verification and scope review

**Files:**
- All files modified in Tasks 1-4.

- [ ] **Step 1: Run affected test files**

Run:

```powershell
flutter test test/modules/chat/message_bubble_experience_test.dart
flutter test test/core/transitions/send_status_indicator_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 2: Run analyzer gates**

Run:

```powershell
flutter analyze lib/widgets/message_bubble.dart lib/core/transitions/message_animations.dart test/modules/chat/message_bubble_experience_test.dart test/core/transitions/send_status_indicator_test.dart
flutter analyze
```

Expected:

```text
No issues found!
```

- [ ] **Step 3: Verify no out-of-scope files changed**

Run:

```powershell
git diff --name-only codex/phase-5-motion-tokens..HEAD
```

Expected changed files are limited to:

```text
docs/superpowers/specs/2026-05-05-phase-5-send-state-visual-semantics-design.md
docs/superpowers/plans/2026-05-05-phase-5-send-state-visual-semantics.md
lib/widgets/message_bubble.dart
lib/core/transitions/message_animations.dart
test/modules/chat/message_bubble_experience_test.dart
test/core/transitions/send_status_indicator_test.dart
```

- [ ] **Step 4: Check diff whitespace**

Run:

```powershell
git diff --check codex/phase-5-motion-tokens..HEAD
```

Expected: no output and exit code 0.

- [ ] **Step 5: Prepare final evidence summary**

Final response must include:

```text
Verification:
- flutter test test/modules/chat/message_bubble_experience_test.dart: All tests passed!
- flutter test test/core/transitions/send_status_indicator_test.dart: All tests passed!
- flutter analyze: No issues found!
- git diff --check codex/phase-5-motion-tokens..HEAD: clean
- Full flutter test: not run for this slice because existing unrelated full-suite failures were already documented
```

Do not claim completion unless Steps 1-4 pass in the current session.
