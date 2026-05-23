import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_call_entry_service.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukong_im_app/modules/video_call/group_call_member_picker_page.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  Future<void> pumpChat(
    WidgetTester tester, {
    required String channelId,
    required int channelType,
    required String channelName,
    required List<Override> overrides,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageListProvider.overrideWith(
            (ref, session) => _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            ),
          ),
          ...overrides,
        ],
        child: MaterialApp(
          home: ChatPage(
            channelId: channelId,
            channelType: channelType,
            channelName: channelName,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('personal chat audio action opens the configured call page', (
    tester,
  ) async {
    final requestedTypes = <CallType>[];
    _CallPageArgs? openedPageArgs;

    await pumpChat(
      tester,
      channelId: 'u_audio_entry',
      channelType: WKChannelType.personal,
      channelName: 'Alice',
      overrides: [
        chatCallEntryServiceProvider.overrideWithValue(
          _FakeChatCallEntryService((
            callType, {
            required channelId,
            required channelType,
          }) async {
            requestedTypes.add(callType);
            return ChatCallEntryDecision.start(callType);
          }),
        ),
        chatCallPageBuilderProvider.overrideWithValue(({
          required String channelId,
          String? channelName,
          required CallType callType,
        }) {
          openedPageArgs = _CallPageArgs(
            channelId: channelId,
            channelName: channelName,
            callType: callType,
          );
          return const _StubCallPage();
        }),
      ],
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-call-audio-button')),
    );
    await tester.pumpAndSettle();

    expect(requestedTypes, <CallType>[CallType.audio]);
    expect(openedPageArgs, isNotNull);
    expect(openedPageArgs!.channelId, 'u_audio_entry');
    expect(openedPageArgs!.channelName, 'Alice');
    expect(openedPageArgs!.callType, CallType.audio);
    expect(
      find.byKey(const ValueKey<String>('stub-call-page')),
      findsOneWidget,
    );
  });

  testWidgets('personal chat video action opens the configured call page', (
    tester,
  ) async {
    final requestedTypes = <CallType>[];
    _CallPageArgs? openedPageArgs;

    await pumpChat(
      tester,
      channelId: 'u_video_entry',
      channelType: WKChannelType.personal,
      channelName: 'Bob',
      overrides: [
        chatCallEntryServiceProvider.overrideWithValue(
          _FakeChatCallEntryService((
            callType, {
            required channelId,
            required channelType,
          }) async {
            requestedTypes.add(callType);
            return ChatCallEntryDecision.start(callType);
          }),
        ),
        chatCallPageBuilderProvider.overrideWithValue(({
          required String channelId,
          String? channelName,
          required CallType callType,
        }) {
          openedPageArgs = _CallPageArgs(
            channelId: channelId,
            channelName: channelName,
            callType: callType,
          );
          return const _StubCallPage();
        }),
      ],
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-call-video-button')),
    );
    await tester.pumpAndSettle();

    expect(requestedTypes, <CallType>[CallType.video]);
    expect(openedPageArgs, isNotNull);
    expect(openedPageArgs!.channelId, 'u_video_entry');
    expect(openedPageArgs!.channelName, 'Bob');
    expect(openedPageArgs!.callType, CallType.video);
    expect(
      find.byKey(const ValueKey<String>('stub-call-page')),
      findsOneWidget,
    );
  });

  testWidgets('group chat hides the call actions', (tester) async {
    await pumpChat(
      tester,
      channelId: 'g_no_calls',
      channelType: WKChannelType.group,
      channelName: 'No Calls',
      overrides: const <Override>[],
    );

    expect(
      find.byKey(const ValueKey<String>('chat-call-audio-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-call-video-button')),
      findsNothing,
    );
  });

  testWidgets('group chat group-call action opens the configured picker page', (
    tester,
  ) async {
    var builderCallCount = 0;
    final requestedTypes = <CallType>[];

    await pumpChat(
      tester,
      channelId: 'g_group_call',
      channelType: WKChannelType.group,
      channelName: 'Team Room',
      overrides: [
        chatCallEntryServiceProvider.overrideWithValue(
          _FakeChatCallEntryService((
            callType, {
            required channelId,
            required channelType,
          }) async {
            requestedTypes.add(callType);
            return ChatCallEntryDecision.start(callType);
          }),
        ),
        chatGroupCallPageBuilderProvider.overrideWithValue(({
          required String channelId,
          required int channelType,
          String? channelName,
        }) {
          builderCallCount += 1;
          return const _StubGroupCallPage();
        }),
      ],
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-group-call-button')),
    );
    await tester.pumpAndSettle();

    expect(requestedTypes, <CallType>[CallType.video]);
    expect(builderCallCount, 1);
    expect(find.byType(GroupCallMemberPickerPage), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('stub-group-call-page')),
      findsOneWidget,
    );
  });

  testWidgets(
    'group chat group-call action shows mute feedback and does not open picker',
    (tester) async {
      var builderCallCount = 0;

      await pumpChat(
        tester,
        channelId: 'g_muted_group_call',
        channelType: WKChannelType.group,
        channelName: 'Muted Team',
        overrides: [
          chatCallEntryServiceProvider.overrideWithValue(
            _FakeChatCallEntryService((
              callType, {
              required channelId,
              required channelType,
            }) async {
              return ChatCallEntryDecision.blocked('group call muted');
            }),
          ),
          chatGroupCallPageBuilderProvider.overrideWithValue(({
            required String channelId,
            required int channelType,
            String? channelName,
          }) {
            builderCallCount += 1;
            return const _StubGroupCallPage();
          }),
        ],
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-group-call-button')),
      );
      await tester.pumpAndSettle();

      expect(builderCallCount, 0);
      expect(
        find.byKey(const ValueKey<String>('stub-group-call-page')),
        findsNothing,
      );
      expect(find.text('group call muted'), findsOneWidget);
    },
  );

  testWidgets(
    'blocked call feedback is trimmed, replaces current snackbar, and does not navigate',
    (tester) async {
      final requestedTypes = <CallType>[];
      var pageBuilderCalls = 0;
      final feedbackByCall = <String>[
        '  first blocked reason  ',
        '  second blocked reason  ',
      ];
      var feedbackIndex = 0;

      await pumpChat(
        tester,
        channelId: 'u_blocked_entry',
        channelType: WKChannelType.personal,
        channelName: 'Blocked',
        overrides: [
          chatCallEntryServiceProvider.overrideWithValue(
            _FakeChatCallEntryService((
              callType, {
              required channelId,
              required channelType,
            }) async {
              requestedTypes.add(callType);
              final feedback = feedbackByCall[feedbackIndex];
              feedbackIndex += 1;
              return ChatCallEntryDecision.blocked(feedback);
            }),
          ),
          chatCallPageBuilderProvider.overrideWithValue(({
            required String channelId,
            String? channelName,
            required CallType callType,
          }) {
            pageBuilderCalls += 1;
            return const _StubCallPage();
          }),
        ],
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-call-video-button')),
      );
      await tester.pump();

      expect(find.text('first blocked reason'), findsOneWidget);
      expect(find.text('  first blocked reason  '), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-call-video-button')),
      );
      await tester.pump();

      expect(find.text('first blocked reason'), findsNothing);
      expect(find.text('second blocked reason'), findsOneWidget);
      expect(find.text('  second blocked reason  '), findsNothing);
      expect(requestedTypes, <CallType>[CallType.video, CallType.video]);
      expect(pageBuilderCalls, 0);
      expect(
        find.byKey(const ValueKey<String>('stub-call-page')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'blocked call with empty-trimmed feedback does not show snackbar and does not navigate',
    (tester) async {
      final requestedTypes = <CallType>[];
      var pageBuilderCalls = 0;

      await pumpChat(
        tester,
        channelId: 'u_blocked_empty',
        channelType: WKChannelType.personal,
        channelName: 'Blocked Empty',
        overrides: [
          chatCallEntryServiceProvider.overrideWithValue(
            _FakeChatCallEntryService((
              callType, {
              required channelId,
              required channelType,
            }) async {
              requestedTypes.add(callType);
              return ChatCallEntryDecision.blocked('   ');
            }),
          ),
          chatCallPageBuilderProvider.overrideWithValue(({
            required String channelId,
            String? channelName,
            required CallType callType,
          }) {
            pageBuilderCalls += 1;
            return const _StubCallPage();
          }),
        ],
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-call-audio-button')),
      );
      await tester.pump();

      expect(requestedTypes, <CallType>[CallType.audio]);
      expect(pageBuilderCalls, 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('stub-call-page')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'call page ended cleanup pops only the call route and keeps chat visible',
    (tester) async {
      await pumpChat(
        tester,
        channelId: 'u_double_pop_guard',
        channelType: WKChannelType.personal,
        channelName: 'Double Pop Guard',
        overrides: [
          chatCallEntryServiceProvider.overrideWithValue(
            _FakeChatCallEntryService((
              callType, {
              required channelId,
              required channelType,
            }) async {
              return ChatCallEntryDecision.start(callType);
            }),
          ),
          chatCallPageBuilderProvider.overrideWithValue(({
            required String channelId,
            String? channelName,
            required CallType callType,
          }) {
            return const _DoublePopCallPage();
          }),
        ],
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-call-audio-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('double-pop-call-page')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-call-audio-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'call page returned error is trimmed, replaces current snackbar, and keeps chat visible',
    (tester) async {
      final requestedTypes = <CallType>[];
      var pageBuilderCalls = 0;
      final returnedMessages = <String>[
        '  first start failure  ',
        '  second start failure  ',
      ];
      var messageIndex = 0;

      await pumpChat(
        tester,
        channelId: 'u_returned_error',
        channelType: WKChannelType.personal,
        channelName: 'Returned Error',
        overrides: [
          chatCallEntryServiceProvider.overrideWithValue(
            _FakeChatCallEntryService((
              callType, {
              required channelId,
              required channelType,
            }) async {
              requestedTypes.add(callType);
              return ChatCallEntryDecision.start(callType);
            }),
          ),
          chatCallPageBuilderProvider.overrideWithValue(({
            required String channelId,
            String? channelName,
            required CallType callType,
          }) {
            pageBuilderCalls += 1;
            final message = returnedMessages[messageIndex];
            messageIndex += 1;
            return _AutoPopCallPage(popResult: message);
          }),
        ],
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-call-audio-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('first start failure'), findsOneWidget);
      expect(find.text('  first start failure  '), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('chat-call-audio-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-call-audio-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('first start failure'), findsNothing);
      expect(find.text('second start failure'), findsOneWidget);
      expect(find.text('  second start failure  '), findsNothing);
      expect(requestedTypes, <CallType>[CallType.audio, CallType.audio]);
      expect(pageBuilderCalls, 2);
      expect(find.byType(_AutoPopCallPage), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('stub-call-page')),
        findsNothing,
      );
    },
  );
}

class _CallPageArgs {
  const _CallPageArgs({
    required this.channelId,
    required this.channelName,
    required this.callType,
  });

  final String channelId;
  final String? channelName;
  final CallType callType;
}

class _StubCallPage extends StatelessWidget {
  const _StubCallPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox(key: ValueKey<String>('stub-call-page')),
    );
  }
}

class _StubGroupCallPage extends StatelessWidget {
  const _StubGroupCallPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox(key: ValueKey<String>('stub-group-call-page')),
    );
  }
}

class _AutoPopCallPage extends StatefulWidget {
  const _AutoPopCallPage({required this.popResult});

  final String popResult;

  @override
  State<_AutoPopCallPage> createState() => _AutoPopCallPageState();
}

class _AutoPopCallPageState extends State<_AutoPopCallPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop<String>(widget.popResult);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox(key: ValueKey<String>('auto-pop-call-page')),
    );
  }
}

class _DoublePopCallPage extends StatefulWidget {
  const _DoublePopCallPage();

  @override
  State<_DoublePopCallPage> createState() => _DoublePopCallPageState();
}

class _DoublePopCallPageState extends State<_DoublePopCallPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      navigator.maybePop();
      navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox(key: ValueKey<String>('double-pop-call-page')),
    );
  }
}

class _FakeChatCallEntryService implements ChatCallEntryService {
  _FakeChatCallEntryService(this._onPrepareOutgoingCall);

  final Future<ChatCallEntryDecision> Function(
    CallType callType, {
    required String channelId,
    required int channelType,
  })
  _onPrepareOutgoingCall;

  @override
  Future<ChatCallEntryDecision> prepareOutgoingCall(
    CallType callType, {
    required String channelId,
    required int channelType,
  }) {
    return _onPrepareOutgoingCall(
      callType,
      channelId: channelId,
      channelType: channelType,
    );
  }
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
