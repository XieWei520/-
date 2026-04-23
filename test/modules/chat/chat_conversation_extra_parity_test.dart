import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_conversation_extra_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/chat/chat_page_shell.dart'
    show ChatPageShell, ChatViewportRestoreResult;
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageUtils.init();
    await StorageUtils.setUid('u_self');
    ApiClient.instance.dio.httpClientAdapter = _ImmediateSuccessAdapter();
  });

  Widget wrapWithApp(
    Widget child, {
    List<Override> overrides = const <Override>[],
  }) {
    return ProviderScope(
      overrides: [
        chatMarkConversationReadProvider.overrideWithValue(
          (session, messageIds) async {},
        ),
        messageListProvider.overrideWith(
          (ref, session) =>
              _EmptyMessageListNotifier(session.channelId, session.channelType),
        ),
        ...overrides,
      ],
      child: MaterialApp(home: child),
    );
  }

  Future<void> pumpChatPageRoute(
    WidgetTester tester, {
    required String channelId,
    required int channelType,
    required String channelName,
    List<Override> overrides = const <Override>[],
  }) async {
    await tester.pumpWidget(
      wrapWithApp(
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey<String>('open-chat-route'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChatPage(
                          channelId: channelId,
                          channelType: channelType,
                          channelName: channelName,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open chat'),
                ),
              ),
            );
          },
        ),
        overrides: overrides,
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('open-chat-route')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(ChatPageShell), findsOneWidget);
  }

  testWidgets(
    'chat page restores Android keepOffsetY from conversation extra gateway',
    (tester) async {
      const channelId = 'u_restore_cover_extra';
      const channelType = WKChannelType.personal;
      final gateway = _FakeConversationExtraGateway(
        loadedExtra: WKConversationMsgExtra()
          ..channelID = channelId
          ..channelType = channelType
          ..browseTo = 25
          ..keepMessageSeq = 5
          ..keepOffsetY = 64,
      );
      final notifier = _RecordingAroundMessageListNotifier(
        channelId,
        channelType,
        _buildDescendingMessages(
          channelId: channelId,
          channelType: channelType,
          highestSeq: 22,
          lowestSeq: 1,
        ),
      );
      final restoreResults = <ChatViewportRestoreResult>[];

      await tester.pumpWidget(
        wrapWithApp(
          ChatPageShell(
            channelId: channelId,
            channelType: channelType,
            channelName: 'Restore Extra',
            onRestoreAnchorApplied: restoreResults.add,
          ),
          overrides: <Override>[
            chatConversationExtraGatewayProvider.overrideWithValue(gateway),
            messageListProvider.overrideWith((ref, session) {
              if (session.channelId == channelId &&
                  session.channelType == channelType) {
                return notifier;
              }
              return _EmptyMessageListNotifier(
                session.channelId,
                session.channelType,
              );
            }),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(notifier.lastAroundOrderSeq, 5000);
      expect(restoreResults, isNotEmpty);
      expect(restoreResults.last.keepMessageSeq, 5);
      expect(restoreResults.last.requestedOffsetY, 64);
      expect(
        restoreResults.last.appliedOffsetY,
        moreOrLessEquals(64, epsilon: 24),
      );
    },
  );

  testWidgets(
    'chat page saves Android conversation extra snapshot on pop',
    (tester) async {
      const channelId = 'u_exit_cover_extra';
      const channelType = WKChannelType.personal;
      final gateway = _FakeConversationExtraGateway();

      await pumpChatPageRoute(
        tester,
        channelId: channelId,
        channelType: channelType,
        channelName: 'Exit Extra',
        overrides: <Override>[
          chatConversationExtraGatewayProvider.overrideWithValue(gateway),
          messageListProvider.overrideWith((ref, session) {
            if (session.channelId == channelId &&
                session.channelType == channelType) {
              return _StaticMessageListNotifier(
                session.channelId,
                session.channelType,
                _buildDescendingMessages(
                  channelId: channelId,
                  channelType: channelType,
                  highestSeq: 30,
                  lowestSeq: 1,
                ),
              );
            }
            return _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            );
          }),
        ],
      );
      await tester.drag(find.byType(ListView), const Offset(0, 480));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.enterText(find.byType(TextField).first, 'exit cover extra');
      await tester.pump();

      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(IconButton),
        ).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(gateway.saveCalls, hasLength(1));
      expect(gateway.saveCalls.single.draft, 'exit cover extra');
      expect(gateway.saveCalls.single.browseTo, greaterThan(0));
      expect(gateway.saveCalls.single.keepMessageSeq, greaterThan(0));
      expect(gateway.saveCalls.single.keepOffsetY, isNonZero);
    },
  );
}

class _FakeConversationExtraGateway implements ChatConversationExtraGateway {
  _FakeConversationExtraGateway({this.loadedExtra});

  final WKConversationMsgExtra? loadedExtra;
  final List<_SavedConversationExtra> saveCalls =
      <_SavedConversationExtra>[];

  @override
  Future<WKConversationMsgExtra?> load({
    required String channelId,
    required int channelType,
  }) async {
    return loadedExtra;
  }

  @override
  Future<void> save({
    required String channelId,
    required int channelType,
    required int browseTo,
    required int keepMessageSeq,
    required int keepOffsetY,
    required String draft,
  }) async {
    saveCalls.add(
      _SavedConversationExtra(
        channelId: channelId,
        channelType: channelType,
        browseTo: browseTo,
        keepMessageSeq: keepMessageSeq,
        keepOffsetY: keepOffsetY,
        draft: draft,
      ),
    );
  }
}

class _SavedConversationExtra {
  const _SavedConversationExtra({
    required this.channelId,
    required this.channelType,
    required this.browseTo,
    required this.keepMessageSeq,
    required this.keepOffsetY,
    required this.draft,
  });

  final String channelId;
  final int channelType;
  final int browseTo;
  final int keepMessageSeq;
  final int keepOffsetY;
  final String draft;
}

class _ImmediateSuccessAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
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

class _StaticMessageListNotifier extends MessageListNotifier {
  _StaticMessageListNotifier(
    super.channelId,
    super.channelType,
    List<WKMsg> messages,
  ) : _messages = List<WKMsg>.from(messages, growable: false);

  final List<WKMsg> _messages;

  @override
  Future<void> loadMessages() async {
    state = List<WKMsg>.from(_messages, growable: false);
  }

  @override
  Future<void> loadMore() async {}
}

class _RecordingAroundMessageListNotifier extends MessageListNotifier {
  _RecordingAroundMessageListNotifier(
    super.channelId,
    super.channelType,
    List<WKMsg> messages,
  ) : _messages = List<WKMsg>.from(messages, growable: false);

  final List<WKMsg> _messages;
  int? lastAroundOrderSeq;

  @override
  Future<void> loadMessages() async {
    state = List<WKMsg>.from(_messages, growable: false);
  }

  @override
  Future<void> loadAroundOrderSeq(int aroundOrderSeq) async {
    lastAroundOrderSeq = aroundOrderSeq;
    state = List<WKMsg>.from(_messages, growable: false);
  }

  @override
  Future<void> loadMore() async {}
}

List<WKMsg> _buildDescendingMessages({
  required String channelId,
  required int channelType,
  required int highestSeq,
  required int lowestSeq,
}) {
  return <WKMsg>[
    for (var seq = lowestSeq; seq <= highestSeq; seq++)
      WKMsg()
        ..messageID = 'm$seq'
        ..channelID = channelId
        ..channelType = channelType
        ..fromUID = seq.isEven ? 'u_other' : 'u_self'
        ..messageSeq = seq
        ..orderSeq = seq * 1000
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('message $seq'),
  ];
}
