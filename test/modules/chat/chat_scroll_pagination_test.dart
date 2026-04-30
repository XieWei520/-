import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_page_shell.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
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

  testWidgets('chat list requests older messages at reversed max extent', (
    tester,
  ) async {
    const channelId = 'u_scroll_pagination';
    const channelType = WKChannelType.personal;
    final notifier = _RecordingMessageListNotifier(
      channelId,
      channelType,
      _buildMessages(channelId: channelId, channelType: channelType, count: 80),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatMarkConversationReadProvider.overrideWithValue(
            (session, messageIds) async {},
          ),
          messageListProvider.overrideWith((ref, session) {
            if (session.channelId == channelId &&
                session.channelType == channelType) {
              return notifier;
            }
            return _RecordingMessageListNotifier(
              session.channelId,
              session.channelType,
              const <WKMsg>[],
            );
          }),
        ],
        child: const MaterialApp(
          home: ChatPageShell(
            channelId: channelId,
            channelType: channelType,
            channelName: 'Scroll Pagination',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(
      scrollable.position.maxScrollExtent,
      greaterThan(scrollable.position.minScrollExtent),
    );

    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();

    expect(notifier.loadMoreCalls, 1);
  });

  testWidgets('chat list shows a compact older-message loading indicator', (
    tester,
  ) async {
    const channelId = 'u_scroll_loading';
    const channelType = WKChannelType.personal;
    final notifier = _DelayedMessageListNotifier(
      channelId,
      channelType,
      _buildMessages(channelId: channelId, channelType: channelType, count: 80),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatMarkConversationReadProvider.overrideWithValue(
            (session, messageIds) async {},
          ),
          messageListProvider.overrideWith((ref, session) {
            if (session.channelId == channelId &&
                session.channelType == channelType) {
              return notifier;
            }
            return _RecordingMessageListNotifier(
              session.channelId,
              session.channelType,
              const <WKMsg>[],
            );
          }),
        ],
        child: const MaterialApp(
          home: ChatPageShell(
            channelId: channelId,
            channelType: channelType,
            channelName: 'Scroll Loading',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('chat-older-loading-indicator')),
      findsOneWidget,
    );

    notifier.completeLoadMore();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('chat-older-loading-indicator')),
      findsNothing,
    );
  });

  test('older-message load trigger tolerates near-tail scroll metrics', () {
    expect(shouldTriggerOlderMessageLoad(extentAfter: 299.5), isTrue);
    expect(shouldTriggerOlderMessageLoad(extentAfter: 300.5), isFalse);
  });

  test('chat list cache extent adapts to platform memory profile', () {
    expect(
      chatListCacheExtent(
        viewportHeight: 900,
        platform: TargetPlatform.android,
        isWeb: false,
      ),
      900,
    );
    expect(
      chatListCacheExtent(
        viewportHeight: 1800,
        platform: TargetPlatform.android,
        isWeb: false,
      ),
      1200,
    );
    expect(
      chatListCacheExtent(
        viewportHeight: 1200,
        platform: TargetPlatform.windows,
        isWeb: false,
      ),
      1600,
    );
    expect(
      chatListCacheExtent(
        viewportHeight: 1200,
        platform: TargetPlatform.windows,
        isWeb: true,
      ),
      1000,
    );
  });
}

class _RecordingMessageListNotifier extends MessageListNotifier {
  _RecordingMessageListNotifier(
    super.channelId,
    super.channelType,
    List<WKMsg> messages,
  ) : _messages = List<WKMsg>.from(messages, growable: false),
      super(autoLoad: false);

  final List<WKMsg> _messages;
  int loadMoreCalls = 0;

  @override
  Future<void> loadMessages() async {
    state = List<WKMsg>.from(_messages, growable: false);
  }

  @override
  Future<void> loadMore() async {
    loadMoreCalls += 1;
  }
}

class _DelayedMessageListNotifier extends _RecordingMessageListNotifier {
  _DelayedMessageListNotifier(
    super.channelId,
    super.channelType,
    super.messages,
  );

  Completer<void>? _loadMoreCompleter;

  @override
  Future<void> loadMore() async {
    loadMoreCalls += 1;
    final completer = Completer<void>();
    _loadMoreCompleter = completer;
    return completer.future;
  }

  void completeLoadMore() {
    final completer = _loadMoreCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete();
  }
}

List<WKMsg> _buildMessages({
  required String channelId,
  required int channelType,
  required int count,
}) {
  return <WKMsg>[
    for (var seq = count; seq >= 1; seq -= 1)
      WKMsg()
        ..messageID = 'm$seq'
        ..channelID = channelId
        ..channelType = channelType
        ..fromUID = seq.isEven ? 'u_other' : 'u_self'
        ..messageSeq = seq
        ..orderSeq = seq * 1000
        ..contentType = WkMessageContentType.text
        ..content = '{"content":"message $seq","type":1}'
        ..messageContent = WKTextContent('message $seq'),
  ];
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
