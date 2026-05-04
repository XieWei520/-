# Call Preview And Chat Record Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复桌面端视频通话本地预览不刷新的问题，并在通话结束后把结果写成聊天页可见的本地系统消息。

**Architecture:** 通过一个轻量的 renderer 值监听组件驱动通话页在 `RTCVideoRenderer` 首帧和尺寸变化时重建，从而让 `RTCVideoView` 正常切换到纹理渲染；同时新增一个本地通话会话消息服务，把 `CallHistoryService` 的结果转换成聊天系统消息并插入本地消息库与会话 UI。

**Tech Stack:** Flutter, flutter_webrtc, Flutter widget tests, flutter_test, WuKongIM Flutter SDK local message APIs

---

### Task 1: Renderer Refresh Binding

**Files:**
- Create: `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/video_call/multi_value_listenable_rebuilder.dart`
- Modify: `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/video_call/video_call_page.dart`
- Test: `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/test/modules/video_call/multi_value_listenable_rebuilder_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('rebuilds child when any listened value changes', (tester) async {
  final first = ValueNotifier<int>(0);
  final second = ValueNotifier<int>(0);
  var buildCount = 0;

  await tester.pumpWidget(
    MaterialApp(
      home: MultiValueListenableRebuilder(
        listenables: <ValueListenable<Object?>>[first, second],
        builder: (context) {
          buildCount++;
          return Text('${first.value}-${second.value}', textDirection: TextDirection.ltr);
        },
      ),
    ),
  );

  expect(find.text('0-0'), findsOneWidget);
  expect(buildCount, 1);

  first.value = 1;
  await tester.pump();

  expect(find.text('1-0'), findsOneWidget);
  expect(buildCount, 2);

  second.value = 3;
  await tester.pump();

  expect(find.text('1-3'), findsOneWidget);
  expect(buildCount, 3);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/modules/video_call/multi_value_listenable_rebuilder_test.dart`
Expected: FAIL with missing `MultiValueListenableRebuilder` type or missing file.

- [ ] **Step 3: Write minimal implementation**

```dart
class MultiValueListenableRebuilder extends StatefulWidget {
  const MultiValueListenableRebuilder({
    super.key,
    required this.listenables,
    required this.builder,
  });

  final List<ValueListenable<Object?>> listenables;
  final WidgetBuilder builder;

  @override
  State<MultiValueListenableRebuilder> createState() =>
      _MultiValueListenableRebuilderState();
}

class _MultiValueListenableRebuilderState
    extends State<MultiValueListenableRebuilder> {
  void _handleValueChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    for (final listenable in widget.listenables) {
      listenable.addListener(_handleValueChanged);
    }
  }

  @override
  void didUpdateWidget(MultiValueListenableRebuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final listenable in oldWidget.listenables) {
      listenable.removeListener(_handleValueChanged);
    }
    for (final listenable in widget.listenables) {
      listenable.addListener(_handleValueChanged);
    }
  }

  @override
  void dispose() {
    for (final listenable in widget.listenables) {
      listenable.removeListener(_handleValueChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
```

Then wrap the `Scaffold` in `VideoCallPage.build()`:

```dart
return MultiValueListenableRebuilder(
  listenables: <ValueListenable<Object?>>[
    _callService.localRenderer,
    _callService.remoteRenderer,
  ],
  builder: (context) {
    return PopScope<void>(
      // existing page body
    );
  },
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/modules/video_call/multi_value_listenable_rebuilder_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/modules/video_call/multi_value_listenable_rebuilder.dart lib/modules/video_call/video_call_page.dart test/modules/video_call/multi_value_listenable_rebuilder_test.dart
git commit -m "fix: refresh call page when renderer values change"
```

### Task 2: Add Media Diagnostics

**Files:**
- Modify: `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/video_call/video_call_service.dart`
- Test: `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/test/modules/video_call/call_runtime_recovery_test.dart`

- [ ] **Step 1: Write the failing test**

Add a focused expectation that service-level diagnostics are emitted through an injected logger:

```dart
test('logs local media binding details during peer setup', () async {
  final logs = <String>[];
  final service = VideoCallService(
    callStore: CallStore(machine: const CallStateMachine()),
    currentUidReader: () => 'u_self',
    logger: logs.add,
    mediaFactory: FakeCallMediaFactory.withVideoTrack(),
  );

  await service.debugSetupLocalMediaForTest(enableVideo: true);

  expect(logs.any((item) => item.contains('local media acquired')), isTrue);
  expect(logs.any((item) => item.contains('videoTracks=1')), isTrue);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/modules/video_call/call_runtime_recovery_test.dart`
Expected: FAIL because `logger` injection and debug helper do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Add a `void Function(String message)? logger` dependency to `VideoCallService`, defaulting to `debugPrint`, and emit diagnostics at:

```dart
_log('call initialize renderers initialized=$_renderersInitialized');
_log('requesting local media enableVideo=$enableVideo constraints=$constraints');
_log('local media acquired stream=${_localStream?.id} audioTracks=${_localStream?.getAudioTracks().length ?? 0} videoTracks=${_localStream?.getVideoTracks().length ?? 0}');
_log('local renderer bound stream=${_localStream?.id} renderVideo=${_localRenderer.renderVideo} width=${_localRenderer.videoWidth} height=${_localRenderer.videoHeight}');
_localRenderer.onFirstFrameRendered = () => _log('local renderer first frame');
_localRenderer.onResize = () => _log('local renderer resize width=${_localRenderer.videoWidth} height=${_localRenderer.videoHeight} renderVideo=${_localRenderer.renderVideo}');
```

Expose only the narrowest visible-for-testing helper needed to drive this path.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/modules/video_call/call_runtime_recovery_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/modules/video_call/video_call_service.dart test/modules/video_call/call_runtime_recovery_test.dart
git commit -m "chore: add call media diagnostics"
```

### Task 3: Persist Call Summaries Into Chat

**Files:**
- Create: `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/video_call/call_conversation_record_service.dart`
- Modify: `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/video_call/video_call_service.dart`
- Test: `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/test/modules/video_call/call_conversation_record_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('builds canceled outgoing video call as a system notice payload', () async {
  final writes = <Map<String, dynamic>>[];
  final service = CallConversationRecordService(
    insertSystemMessage: writes.add,
  );

  await service.recordCallSummary(
    roomId: 'call_1',
    channelId: 'u_b',
    channelType: WKChannelType.personal,
    channelName: 'Test User',
    callType: CallType.video,
    direction: CallDirection.outgoing,
    status: CallHistoryStatus.canceled,
  );

  expect(writes, hasLength(1));
  expect(writes.single['content'], '已取消视频通话');
  expect(writes.single['type'], greaterThanOrEqualTo(1000));
  expect(writes.single['room_id'], 'call_1');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/modules/video_call/call_conversation_record_service_test.dart`
Expected: FAIL with missing `CallConversationRecordService`.

- [ ] **Step 3: Write minimal implementation**

Create a focused service that builds and inserts a local system message payload:

```dart
class CallConversationRecordService {
  CallConversationRecordService({
    Future<void> Function(Map<String, dynamic> payload)? insertSystemMessage,
  }) : _insertSystemMessage = insertSystemMessage ?? _defaultInsertSystemMessage;

  final Future<void> Function(Map<String, dynamic> payload) _insertSystemMessage;

  Future<void> recordCallSummary({
    required String roomId,
    required String channelId,
    required int channelType,
    required String channelName,
    required CallType callType,
    required CallDirection direction,
    required CallHistoryStatus status,
  }) async {
    final text = buildCallSummaryText(
      callType: callType,
      direction: direction,
      status: status,
    );
    if (text.isEmpty) {
      return;
    }
    await _insertSystemMessage(<String, dynamic>{
      'type': 10020,
      'content': text,
      'room_id': roomId,
      'channel_id': channelId,
      'channel_type': channelType,
      'channel_name': channelName,
      'call_type': callType.value,
      'direction': direction.value,
      'status': status.value,
    });
  }
}
```

Use the same local message insertion pattern as the existing sensitive-word tip path: save a local `WKMsg`, trigger `setOnMsgInserted`, then refresh UI conversation rows.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/modules/video_call/call_conversation_record_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/modules/video_call/call_conversation_record_service.dart test/modules/video_call/call_conversation_record_service_test.dart
git commit -m "feat: insert local chat records for call summaries"
```

### Task 4: Hook Call End Paths Into Chat Records

**Files:**
- Modify: `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/video_call/video_call_service.dart`
- Test: `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/test/modules/video_call/call_runtime_recovery_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('writes chat call summary when ending an unconnected outgoing call', () async {
  final summaries = <String>[];
  final service = VideoCallService(
    callStore: CallStore(machine: const CallStateMachine()),
    currentUidReader: () => 'u_self',
    conversationRecordService: FakeConversationRecordService(
      onRecord: (payload) => summaries.add(payload['content'] as String),
    ),
  );

  await service.startTestCall(
    roomId: 'call_test',
    channelId: 'u_b',
    channelName: 'User B',
    callType: CallType.video,
  );
  await service.endCall();

  expect(summaries, contains('已取消视频通话'));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/modules/video_call/call_runtime_recovery_test.dart`
Expected: FAIL because `VideoCallService` does not call the conversation record service.

- [ ] **Step 3: Write minimal implementation**

Inject `CallConversationRecordService` into `VideoCallService` and invoke it in all direct-call terminal branches after `CallHistoryService` status updates:

```dart
if (remote) {
  await _historyService.markRemoteEnded(room.roomId);
  await _recordConversationSummary(status: _deriveRemoteSummaryStatus(room));
} else if (_wasConnected) {
  await _historyService.markCompleted(room.roomId);
  await _recordConversationSummary(status: CallHistoryStatus.completed);
} else {
  await _historyService.markCanceled(room.roomId);
  await _recordConversationSummary(status: CallHistoryStatus.canceled);
}
```

Apply the same pattern in:

- `rejectIncomingCall()`
- `_handleRemoteTermination()`
- `_handleTransportFailure()`

Use current room/channel metadata instead of querying history back from storage.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/modules/video_call/call_runtime_recovery_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/modules/video_call/video_call_service.dart test/modules/video_call/call_runtime_recovery_test.dart
git commit -m "fix: surface call summaries in chat after call end"
```

### Task 5: Verify End To End

**Files:**
- Modify: `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/runtime_logs/` (runtime output only, no source edit)

- [ ] **Step 1: Run focused test suite**

Run: `flutter test test/modules/video_call/multi_value_listenable_rebuilder_test.dart test/modules/video_call/call_conversation_record_service_test.dart test/modules/video_call/video_call_page_test.dart test/modules/video_call/call_runtime_recovery_test.dart`
Expected: PASS

- [ ] **Step 2: Rebuild or rerun the Windows desktop app**

Run: launch `wukong_im_app` desktop executable and start a video call.
Expected:
- local preview appears after opening camera;
- logs contain `local renderer first frame` or `local renderer resize`;
- ending call inserts a visible system message in the chat page.

- [ ] **Step 3: Check generated runtime logs**

Run:
```powershell
Get-Content 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\runtime_logs\<latest-stdout>.log' | Select-String -Pattern 'local media acquired|local renderer first frame|local renderer resize|call summary inserted'
```

Expected: matching lines for the latest call attempt.

- [ ] **Step 4: Commit**

```bash
git add lib/modules/video_call/multi_value_listenable_rebuilder.dart lib/modules/video_call/video_call_page.dart lib/modules/video_call/call_conversation_record_service.dart lib/modules/video_call/video_call_service.dart test/modules/video_call/multi_value_listenable_rebuilder_test.dart test/modules/video_call/call_conversation_record_service_test.dart test/modules/video_call/call_runtime_recovery_test.dart
git commit -m "fix: restore call preview and chat call records"
```
