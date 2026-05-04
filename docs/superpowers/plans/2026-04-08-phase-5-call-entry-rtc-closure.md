# Phase 5 Call Entry RTC Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the active personal-chat audio and video buttons into the current production 1v1 call chain with explicit permission feedback, duplicate-call protection, focused regression coverage, and cleanup of the unused legacy RTC manager file.

**Architecture:** Keep the existing production owner path centered on `ChatPageShell -> VideoCallPage -> VideoCallService -> CallCoordinator -> CallApi`. Introduce a small chat-scoped call-entry decision service for permission and runtime gating, plus a call-page builder provider so widget tests can verify navigation without touching the real RTC stack.

**Tech Stack:** Flutter, flutter_riverpod, flutter_test, permission_handler, flutter_webrtc, WKIM SDK, existing VideoCallService/CallCoordinator runtime, PowerShell

---

**Workspace constraint:** `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app` is not currently a Git repository. Each task ends with a local checkpoint step instead of a git commit step.

### Task 1: Add a Testable Chat Call Entry Decision Service

**Files:**
- Create: `lib/modules/chat/chat_call_entry_service.dart`
- Modify: `lib/modules/chat/chat_scene_providers.dart`
- Test: `test/modules/chat/chat_call_entry_service_test.dart`

- [ ] **Step 1: Write the failing service tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/modules/chat/chat_call_entry_service.dart';

void main() {
  group('PlatformChatCallEntryService', () {
    test('blocks when another call is already active', () async {
      final service = PlatformChatCallEntryService(
        hasActiveCallOrPendingSetup: () => true,
        requestMicrophone: () async => true,
        requestCameraAndMicrophone: () async => true,
        isMicrophonePermanentlyDenied: () async => false,
        isCameraPermanentlyDenied: () async => false,
      );

      final decision = await service.prepareOutgoingCall(CallType.audio);

      expect(decision.shouldStart, isFalse);
      expect(decision.feedbackMessage, 'A call is already in progress.');
    });

    test('allows audio calls when microphone permission is granted', () async {
      final service = PlatformChatCallEntryService(
        hasActiveCallOrPendingSetup: () => false,
        requestMicrophone: () async => true,
        requestCameraAndMicrophone: () async => false,
        isMicrophonePermanentlyDenied: () async => false,
        isCameraPermanentlyDenied: () async => false,
      );

      final decision = await service.prepareOutgoingCall(CallType.audio);

      expect(decision.shouldStart, isTrue);
      expect(decision.callType, CallType.audio);
      expect(decision.feedbackMessage, isNull);
    });

    test('returns inline denial feedback for video permission failures', () async {
      final service = PlatformChatCallEntryService(
        hasActiveCallOrPendingSetup: () => false,
        requestMicrophone: () async => false,
        requestCameraAndMicrophone: () async => false,
        isMicrophonePermanentlyDenied: () async => false,
        isCameraPermanentlyDenied: () async => false,
      );

      final decision = await service.prepareOutgoingCall(CallType.video);

      expect(decision.shouldStart, isFalse);
      expect(
        decision.feedbackMessage,
        'Camera and microphone permissions are required for video calls.',
      );
    });

    test('returns settings guidance for permanent microphone denial', () async {
      final service = PlatformChatCallEntryService(
        hasActiveCallOrPendingSetup: () => false,
        requestMicrophone: () async => false,
        requestCameraAndMicrophone: () async => false,
        isMicrophonePermanentlyDenied: () async => true,
        isCameraPermanentlyDenied: () async => false,
      );

      final decision = await service.prepareOutgoingCall(CallType.audio);

      expect(decision.shouldStart, isFalse);
      expect(
        decision.feedbackMessage,
        'Microphone permission is permanently denied. Enable it in system settings.',
      );
    });
  });
}
```

- [ ] **Step 2: Run the service tests to verify they fail**

Run:

```powershell
flutter test test/modules/chat/chat_call_entry_service_test.dart --no-pub
```

Expected: FAIL with file or symbol errors because `chat_call_entry_service.dart`, `PlatformChatCallEntryService`, and `prepareOutgoingCall()` do not exist yet.

- [ ] **Step 3: Write the minimal call-entry service and provider**

Create `lib/modules/chat/chat_call_entry_service.dart`:

```dart
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/call.dart';
import '../video_call/video_call_service.dart';
import '../../wukong_base/utils/permission_utils.dart';

const String chatCallAlreadyActiveMessage = 'A call is already in progress.';
const String chatAudioPermissionDeniedMessage =
    'Microphone permission is required for audio calls.';
const String chatAudioPermissionSettingsMessage =
    'Microphone permission is permanently denied. Enable it in system settings.';
const String chatVideoPermissionDeniedMessage =
    'Camera and microphone permissions are required for video calls.';
const String chatVideoPermissionSettingsMessage =
    'Camera or microphone permission is permanently denied. Enable them in system settings.';

class ChatCallEntryDecision {
  const ChatCallEntryDecision._({
    this.callType,
    this.feedbackMessage,
  });

  final CallType? callType;
  final String? feedbackMessage;

  bool get shouldStart => callType != null;

  static ChatCallEntryDecision start(CallType callType) {
    return ChatCallEntryDecision._(callType: callType);
  }

  static ChatCallEntryDecision blocked(String message) {
    return ChatCallEntryDecision._(feedbackMessage: message);
  }
}

abstract class ChatCallEntryService {
  Future<ChatCallEntryDecision> prepareOutgoingCall(CallType callType);
}

class PlatformChatCallEntryService implements ChatCallEntryService {
  PlatformChatCallEntryService({
    bool Function()? hasActiveCallOrPendingSetup,
    Future<bool> Function()? requestMicrophone,
    Future<bool> Function()? requestCameraAndMicrophone,
    Future<bool> Function()? isMicrophonePermanentlyDenied,
    Future<bool> Function()? isCameraPermanentlyDenied,
  }) : _hasActiveCallOrPendingSetup =
           hasActiveCallOrPendingSetup ?? _defaultHasActiveCallOrPendingSetup,
       _requestMicrophone =
           requestMicrophone ?? WKPermissions.requestMicrophone,
       _requestCameraAndMicrophone =
           requestCameraAndMicrophone ??
           WKPermissions.requestCameraAndMicrophone,
       _isMicrophonePermanentlyDenied =
           isMicrophonePermanentlyDenied ??
           _defaultIsMicrophonePermanentlyDenied,
       _isCameraPermanentlyDenied =
           isCameraPermanentlyDenied ?? _defaultIsCameraPermanentlyDenied;

  final bool Function() _hasActiveCallOrPendingSetup;
  final Future<bool> Function() _requestMicrophone;
  final Future<bool> Function() _requestCameraAndMicrophone;
  final Future<bool> Function() _isMicrophonePermanentlyDenied;
  final Future<bool> Function() _isCameraPermanentlyDenied;

  @override
  Future<ChatCallEntryDecision> prepareOutgoingCall(CallType callType) async {
    if (_hasActiveCallOrPendingSetup()) {
      return ChatCallEntryDecision.blocked(chatCallAlreadyActiveMessage);
    }

    if (callType == CallType.audio) {
      final granted = await _requestMicrophone();
      if (granted) {
        return ChatCallEntryDecision.start(CallType.audio);
      }
      final permanentlyDenied = await _isMicrophonePermanentlyDenied();
      return ChatCallEntryDecision.blocked(
        permanentlyDenied
            ? chatAudioPermissionSettingsMessage
            : chatAudioPermissionDeniedMessage,
      );
    }

    final granted = await _requestCameraAndMicrophone();
    if (granted) {
      return ChatCallEntryDecision.start(CallType.video);
    }
    final cameraDenied = await _isCameraPermanentlyDenied();
    final microphoneDenied = await _isMicrophonePermanentlyDenied();
    return ChatCallEntryDecision.blocked(
      cameraDenied || microphoneDenied
          ? chatVideoPermissionSettingsMessage
          : chatVideoPermissionDeniedMessage,
    );
  }

  static bool _defaultHasActiveCallOrPendingSetup() {
    return VideoCallService.instance.hasActiveCallOrPendingSetup;
  }

  static Future<bool> _defaultIsMicrophonePermanentlyDenied() {
    return WKPermissions.isPermanentlyDenied(Permission.microphone);
  }

  static Future<bool> _defaultIsCameraPermanentlyDenied() {
    return WKPermissions.isPermanentlyDenied(Permission.camera);
  }
}
```

Update `lib/modules/chat/chat_scene_providers.dart`:

```dart
import 'chat_call_entry_service.dart';

final chatCallEntryServiceProvider =
    Provider.autoDispose<ChatCallEntryService>((ref) {
      return PlatformChatCallEntryService();
    });
```

- [ ] **Step 4: Run the service tests to verify they pass**

Run:

```powershell
flutter test test/modules/chat/chat_call_entry_service_test.dart --no-pub
```

Expected: PASS

- [ ] **Step 5: Checkpoint the Task 1 changes locally**

Run:

```powershell
Get-ChildItem 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat' -File | Where-Object { $_.Name -like 'chat_call_entry_service.dart' -or $_.Name -like 'chat_scene_providers.dart' }
Get-ChildItem 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat' -File | Where-Object { $_.Name -like 'chat_call_entry_service_test.dart' }
```

Expected: The new service file and test file exist, and `chat_scene_providers.dart` remains in place with the added provider.

### Task 2: Wire Chat Header Buttons Through the Decision Service

**Files:**
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `lib/modules/chat/chat_scene_providers.dart`
- Test: `test/modules/chat/chat_call_entry_flow_test.dart`

- [ ] **Step 1: Write the failing widget tests**

Create `test/modules/chat/chat_call_entry_flow_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_call_entry_service.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  testWidgets('personal chat audio action opens the configured call page', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageListProvider.overrideWith(
            (ref, session) =>
                _EmptyMessageListNotifier(session.channelId, session.channelType),
          ),
          chatCallEntryServiceProvider.overrideWithValue(
            _FakeChatCallEntryService(
              ChatCallEntryDecision.start(CallType.audio),
            ),
          ),
          chatCallPageBuilderProvider.overrideWithValue(
            ({
              required channelId,
              channelName,
              required callType,
            }) => _FakeCallPage(callType: callType),
          ),
        ],
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'u_call',
            channelType: WKChannelType.personal,
            channelName: 'Peer',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-call-audio-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-call-video-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-call-audio-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('fake-call-page-audio')),
      findsOneWidget,
    );
  });

  testWidgets('group chat hides the call actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageListProvider.overrideWith(
            (ref, session) =>
                _EmptyMessageListNotifier(session.channelId, session.channelType),
          ),
        ],
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'g_call',
            channelType: WKChannelType.group,
            channelName: 'Group',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-call-audio-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-call-video-button')),
      findsNothing,
    );
  });

  testWidgets('blocked call entry shows feedback and does not navigate', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageListProvider.overrideWith(
            (ref, session) =>
                _EmptyMessageListNotifier(session.channelId, session.channelType),
          ),
          chatCallEntryServiceProvider.overrideWithValue(
            _FakeChatCallEntryService(
              ChatCallEntryDecision.blocked(
                'Microphone permission is required for audio calls.',
              ),
            ),
          ),
          chatCallPageBuilderProvider.overrideWithValue(
            ({
              required channelId,
              channelName,
              required callType,
            }) => _FakeCallPage(callType: callType),
          ),
        ],
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'u_call',
            channelType: WKChannelType.personal,
            channelName: 'Peer',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-call-audio-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Microphone permission is required for audio calls.'),
      findsOneWidget,
    );
    expect(find.byType(_FakeCallPage), findsNothing);
  });
}

class _EmptyMessageListNotifier extends MessageListNotifier {
  _EmptyMessageListNotifier(super.channelId, super.channelType);

  @override
  Future<void> loadMessages() async {
    state = <WKMsg>[];
  }

  @override
  Future<void> loadMore() async {}
}

class _FakeChatCallEntryService implements ChatCallEntryService {
  _FakeChatCallEntryService(this.decision);

  final ChatCallEntryDecision decision;

  @override
  Future<ChatCallEntryDecision> prepareOutgoingCall(CallType callType) async {
    return decision;
  }
}

class _FakeCallPage extends StatelessWidget {
  const _FakeCallPage({required this.callType});

  final CallType callType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          callType == CallType.audio ? 'audio' : 'video',
          key: ValueKey<String>('fake-call-page-${callType.name}'),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run the widget tests to verify they fail**

Run:

```powershell
flutter test test/modules/chat/chat_call_entry_flow_test.dart --no-pub
```

Expected: FAIL because `chatCallPageBuilderProvider` and the `chat-call-audio-button` / `chat-call-video-button` keys and handlers do not exist yet.

- [ ] **Step 3: Wire the chat header to the decision service and inject a testable page builder**

Update `lib/modules/chat/chat_scene_providers.dart` so the relevant section becomes:

```dart
import '../../data/models/call.dart';
import '../video_call/video_call_page.dart';
import 'chat_call_entry_service.dart';

typedef ChatCallPageBuilder = Widget Function({
  required String channelId,
  String? channelName,
  required CallType callType,
});

final chatCallEntryServiceProvider =
    Provider.autoDispose<ChatCallEntryService>((ref) {
      return PlatformChatCallEntryService();
    });

final chatCallPageBuilderProvider =
    Provider.autoDispose<ChatCallPageBuilder>((ref) {
      return ({
        required String channelId,
        String? channelName,
        required CallType callType,
      }) {
        return VideoCallPage(
          channelId: channelId,
          channelName: channelName,
          callType: callType,
        );
      };
    });
```

Update `lib/modules/chat/chat_page_shell.dart`:

```dart
import '../../data/models/call.dart';
```

```dart
class _ChatPageShellState extends ConsumerState<ChatPageShell> {
  WKChannel? _channel;
  bool _isOpeningCallPage = false;
```

```dart
                if (_showCallActions())
                  IconButton(
                    key: const ValueKey<String>('chat-call-audio-button'),
                    tooltip: _voiceTooltip,
                    onPressed: () =>
                        unawaited(_handleCallActionTap(CallType.audio)),
                    icon: WKReferenceAssets.image(
                      WKReferenceAssets.chatCallVoice,
                      width: 20,
                      height: 20,
                      tint: WKColors.popupText,
                    ),
                  ),
                if (_showCallActions())
                  IconButton(
                    key: const ValueKey<String>('chat-call-video-button'),
                    tooltip: _videoTooltip,
                    onPressed: () =>
                        unawaited(_handleCallActionTap(CallType.video)),
                    icon: WKReferenceAssets.image(
                      WKReferenceAssets.chatCallVideo,
                      width: 20,
                      height: 20,
                      tint: WKColors.popupText,
                    ),
                  ),
```

```dart
  Future<void> _handleCallActionTap(CallType callType) async {
    if (_isOpeningCallPage) {
      return;
    }
    _isOpeningCallPage = true;
    try {
      final decision = await ref
          .read(chatCallEntryServiceProvider)
          .prepareOutgoingCall(callType);
      if (!mounted) {
        return;
      }
      if (!decision.shouldStart) {
        final message = decision.feedbackMessage?.trim();
        if (message != null && message.isNotEmpty) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
        return;
      }
      final pageBuilder = ref.read(chatCallPageBuilderProvider);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => pageBuilder(
            channelId: widget.channelId,
            channelName: _resolveTitle(),
            callType: decision.callType!,
          ),
        ),
      );
    } finally {
      _isOpeningCallPage = false;
    }
  }
```

- [ ] **Step 4: Run the widget tests to verify they pass**

Run:

```powershell
flutter test test/modules/chat/chat_call_entry_flow_test.dart --no-pub
```

Expected: PASS

- [ ] **Step 5: Checkpoint the Task 2 changes locally**

Run:

```powershell
Select-String -Path 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page_shell.dart' -Pattern 'chat-call-audio-button|chat-call-video-button|_handleCallActionTap'
Select-String -Path 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_scene_providers.dart' -Pattern 'chatCallPageBuilderProvider|ChatCallPageBuilder'
```

Expected: Both call-button keys and the page-builder provider are present exactly once.

### Task 3: Retire the Unused Legacy RTC Manager File

**Files:**
- Delete: `lib/modules/video_call/rtc_manager.dart`
- Test: `test/modules/video_call/rtc_manager_cleanup_test.dart`

- [ ] **Step 1: Write the failing cleanup test**

Create `test/modules/video_call/rtc_manager_cleanup_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy rtc manager file has been retired', () {
    expect(
      File('lib/modules/video_call/rtc_manager.dart').existsSync(),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Run the cleanup test to verify it fails**

Run:

```powershell
flutter test test/modules/video_call/rtc_manager_cleanup_test.dart --no-pub
```

Expected: FAIL because `lib/modules/video_call/rtc_manager.dart` still exists.

- [ ] **Step 3: Delete the unused legacy RTC manager file**

Delete:

```text
lib/modules/video_call/rtc_manager.dart
```

- [ ] **Step 4: Run the cleanup test and the reference search**

Run:

```powershell
flutter test test/modules/video_call/rtc_manager_cleanup_test.dart --no-pub
Get-ChildItem 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib' -Recurse -File | Select-String -Pattern 'RTCManager|rtc_manager.dart'
```

Expected:
- The test PASSes.
- The search prints no matches.

- [ ] **Step 5: Checkpoint the Task 3 cleanup locally**

Run:

```powershell
Test-Path 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\video_call\rtc_manager.dart'
```

Expected: `False`

### Task 4: Run the Focused Regression and Analyze Sweep

**Files:**
- Verify: `lib/modules/chat/chat_call_entry_service.dart`
- Verify: `lib/modules/chat/chat_page_shell.dart`
- Verify: `lib/modules/chat/chat_scene_providers.dart`
- Verify: `test/modules/chat/chat_call_entry_service_test.dart`
- Verify: `test/modules/chat/chat_call_entry_flow_test.dart`
- Verify: `test/modules/chat/chat_page_scene_flow_test.dart`
- Verify: `test/modules/video_call/video_call_page_test.dart`
- Verify: `test/modules/video_call/call_runtime_recovery_test.dart`
- Verify: `test/modules/video_call/rtc_manager_cleanup_test.dart`

- [ ] **Step 1: Run the focused chat and video-call tests**

Run:

```powershell
flutter test test/modules/chat/chat_call_entry_service_test.dart test/modules/chat/chat_call_entry_flow_test.dart test/modules/chat/chat_page_scene_flow_test.dart test/modules/video_call/video_call_page_test.dart test/modules/video_call/call_runtime_recovery_test.dart test/modules/video_call/rtc_manager_cleanup_test.dart --no-pub
```

Expected: PASS

- [ ] **Step 2: Run focused analyze on the touched production files**

Run:

```powershell
flutter analyze lib/modules/chat/chat_call_entry_service.dart lib/modules/chat/chat_page_shell.dart lib/modules/chat/chat_scene_providers.dart lib/modules/video_call/video_call_page.dart lib/modules/video_call/video_call_service.dart lib/modules/video_call/call_coordinator.dart lib/wukong_base/utils/permission_utils.dart
```

Expected: No new analyze errors in the touched files.

- [ ] **Step 3: Run a manual smoke pass on device or emulator**

Check:

```text
1. Open a personal chat and tap the audio button.
2. Confirm audio-call permission gating works and the call page opens only after permission is granted.
3. Open a personal chat and tap the video button.
4. Confirm camera + microphone gating works and the call page opens only after permission is granted.
5. Deny permission and confirm the chat page stays visible with feedback.
6. Trigger an incoming call and confirm the overlay, accept path, and reject path still behave as before.
```

- [ ] **Step 4: Checkpoint the final verification evidence locally**

Run:

```powershell
Get-ChildItem 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat' -File | Where-Object { $_.Name -like 'chat_call_entry_*' }
Get-ChildItem 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\video_call' -File | Where-Object { $_.Name -like 'rtc_manager_cleanup_test.dart' }
```

Expected: The new focused call-entry tests and the RTC cleanup test are present and ready to remain as regression coverage.
