import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/providers/chat_history_gateway.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry_provider.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

void main() {
  late HttpClientAdapter originalAdapter;
  late RealtimeRolloutTelemetry telemetry;

  setUp(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.dio.httpClientAdapter = _ChatPageRouteAdapter();
    telemetry = RealtimeRolloutTelemetry(flushInterval: Duration.zero);
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    telemetry.dispose();
  });

  test('loadAroundOrderSeq uses injected gateway around-order-seq', () async {
    final gateway = _RecordingHistoryGateway();
    final notifier = MessageListNotifier(
      'g1001',
      2,
      historyGateway: gateway,
      autoLoad: false,
    );

    await notifier.loadAroundOrderSeq(42000);

    expect(gateway.lastAroundOrderSeq, 42000);
    expect(gateway.aroundCalls, 1);
    expect(notifier.state, hasLength(1));
    expect(notifier.state.single.orderSeq, 42000);
    notifier.dispose();
  });

  test('newer anchored load wins over stale latest load completion', () async {
    final gateway = _ControllableHistoryGateway();
    final notifier = MessageListNotifier(
      'g1001',
      2,
      historyGateway: gateway,
      autoLoad: false,
    );

    final latest = notifier.loadMessages();
    final around = notifier.loadAroundOrderSeq(42000);

    gateway.completeAround([
      WKMsg()
        ..channelID = 'g1001'
        ..channelType = 2
        ..orderSeq = 42000,
    ]);
    await around;
    expect(notifier.state.single.orderSeq, 42000);

    gateway.completeLatest([
      WKMsg()
        ..channelID = 'g1001'
        ..channelType = 2
        ..orderSeq = 100,
    ]);
    await latest;
    expect(notifier.state.single.orderSeq, 42000);
    notifier.dispose();
  });

  test('loadMore coalesces concurrent older-page requests', () async {
    final gateway = _BlockingLoadMoreGateway();
    final notifier = MessageListNotifier(
      'g1001',
      2,
      historyGateway: gateway,
      autoLoad: false,
    );

    await notifier.loadMessages();

    final first = notifier.loadMore();
    final second = notifier.loadMore();

    expect(gateway.moreCalls, 1);

    gateway.completeMore(const <WKMsg>[]);
    await Future.wait<void>(<Future<void>>[first, second]);
    notifier.dispose();
  });

  test(
    'loadMore skips repeated empty older-page query for unchanged oldest item',
    () async {
      final gateway = _EmptyOlderPageGateway();
      final notifier = MessageListNotifier(
        'g1001',
        2,
        historyGateway: gateway,
        autoLoad: false,
      );

      await notifier.loadMessages();
      await notifier.loadMore();
      await notifier.loadMore();

      expect(gateway.moreCalls, 1);
      notifier.dispose();
    },
  );

  testWidgets('ChatPage forwards initialAroundOrderSeq to ChatPageShell', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          realtimeRolloutTelemetryProvider.overrideWithValue(telemetry),
          messageListProvider.overrideWith(
            (ref, session) => _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            ),
          ),
        ],
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'fileHelper',
            channelType: 1,
            channelName: 'Design',
            initialAroundOrderSeq: 42000,
          ),
        ),
      ),
    );
    await tester.pump();

    final shell = tester.widget<ChatPageShell>(find.byType(ChatPageShell));
    expect(shell.initialAroundOrderSeq, 42000);
  });

  testWidgets('ChatPage forwards initialLocateMessageSeq to ChatPageShell', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          realtimeRolloutTelemetryProvider.overrideWithValue(telemetry),
          messageListProvider.overrideWith(
            (ref, session) => _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            ),
          ),
        ],
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'fileHelper',
            channelType: 1,
            channelName: 'Design',
            initialAroundOrderSeq: 42000,
            initialLocateMessageSeq: 42,
          ),
        ),
      ),
    );
    await tester.pump();

    final shell = tester.widget<ChatPageShell>(find.byType(ChatPageShell));
    expect(shell.initialLocateMessageSeq, 42);
  });

  testWidgets(
    'ChatPageShell triggers anchored loading and skips initial latest load',
    (tester) async {
      final gateway = _RecordingHistoryGateway();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatHistoryGatewayProvider.overrideWithValue(gateway),
            realtimeRolloutTelemetryProvider.overrideWithValue(telemetry),
          ],
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'fileHelper',
              channelType: 1,
              channelName: 'Design',
              initialAroundOrderSeq: 42000,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(gateway.latestCalls, 0);
      expect(gateway.aroundCalls, 1);
      expect(gateway.lastAroundOrderSeq, 42000);
    },
  );

  testWidgets(
    'ChatPageShell applies initial locate anchor after around loading',
    (tester) async {
      final gateway = _AnchoredHistoryGateway();
      int? restoredKeepMessageSeq;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatHistoryGatewayProvider.overrideWithValue(gateway),
            realtimeRolloutTelemetryProvider.overrideWithValue(telemetry),
          ],
          child: MaterialApp(
            home: ChatPageShell(
              channelId: 'fileHelper',
              channelType: 1,
              channelName: 'Design',
              initialAroundOrderSeq: 42000,
              initialLocateMessageSeq: 42,
              onRestoreAnchorApplied: (result) {
                restoredKeepMessageSeq = result.keepMessageSeq;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(restoredKeepMessageSeq, 42);
    },
  );

  testWidgets('ChatPageShell normal open triggers latest loading', (
    tester,
  ) async {
    final gateway = _RecordingHistoryGateway();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatHistoryGatewayProvider.overrideWithValue(gateway),
          realtimeRolloutTelemetryProvider.overrideWithValue(telemetry),
        ],
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'fileHelper',
            channelType: 1,
            channelName: 'Design',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(gateway.latestCalls, 1);
    expect(gateway.aroundCalls, 0);
  });
}

class _RecordingHistoryGateway implements ChatHistoryGateway {
  int latestCalls = 0;
  int moreCalls = 0;
  int aroundCalls = 0;
  int? lastAroundOrderSeq;

  @override
  Future<List<WKMsg>> loadAroundOrderSeq({
    required String channelId,
    required int channelType,
    required int limit,
    required int aroundOrderSeq,
  }) async {
    aroundCalls += 1;
    lastAroundOrderSeq = aroundOrderSeq;
    return [
      WKMsg()
        ..channelID = channelId
        ..channelType = channelType
        ..orderSeq = aroundOrderSeq,
    ];
  }

  @override
  Future<List<WKMsg>> loadLatest({
    required String channelId,
    required int channelType,
    required int limit,
  }) async {
    latestCalls += 1;
    return const <WKMsg>[];
  }

  @override
  Future<List<WKMsg>> loadMore({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int limit,
  }) async {
    moreCalls += 1;
    return const <WKMsg>[];
  }
}

class _BlockingLoadMoreGateway implements ChatHistoryGateway {
  final Completer<List<WKMsg>> _loadMore = Completer<List<WKMsg>>();
  int moreCalls = 0;

  @override
  Future<List<WKMsg>> loadAroundOrderSeq({
    required String channelId,
    required int channelType,
    required int limit,
    required int aroundOrderSeq,
  }) async {
    return const <WKMsg>[];
  }

  @override
  Future<List<WKMsg>> loadLatest({
    required String channelId,
    required int channelType,
    required int limit,
  }) async {
    return <WKMsg>[
      WKMsg()
        ..channelID = channelId
        ..channelType = channelType
        ..orderSeq = 1000
        ..contentType = 1,
    ];
  }

  @override
  Future<List<WKMsg>> loadMore({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int limit,
  }) {
    moreCalls += 1;
    return _loadMore.future;
  }

  void completeMore(List<WKMsg> messages) {
    if (!_loadMore.isCompleted) {
      _loadMore.complete(messages);
    }
  }
}

class _EmptyOlderPageGateway implements ChatHistoryGateway {
  int moreCalls = 0;

  @override
  Future<List<WKMsg>> loadAroundOrderSeq({
    required String channelId,
    required int channelType,
    required int limit,
    required int aroundOrderSeq,
  }) async {
    return const <WKMsg>[];
  }

  @override
  Future<List<WKMsg>> loadLatest({
    required String channelId,
    required int channelType,
    required int limit,
  }) async {
    return <WKMsg>[
      WKMsg()
        ..channelID = channelId
        ..channelType = channelType
        ..orderSeq = 1000
        ..contentType = 1,
    ];
  }

  @override
  Future<List<WKMsg>> loadMore({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int limit,
  }) async {
    moreCalls += 1;
    return const <WKMsg>[];
  }
}

class _ControllableHistoryGateway implements ChatHistoryGateway {
  final Completer<List<WKMsg>> _latest = Completer<List<WKMsg>>();
  final Completer<List<WKMsg>> _around = Completer<List<WKMsg>>();

  @override
  Future<List<WKMsg>> loadLatest({
    required String channelId,
    required int channelType,
    required int limit,
  }) {
    return _latest.future;
  }

  @override
  Future<List<WKMsg>> loadMore({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int limit,
  }) async {
    return const <WKMsg>[];
  }

  @override
  Future<List<WKMsg>> loadAroundOrderSeq({
    required String channelId,
    required int channelType,
    required int limit,
    required int aroundOrderSeq,
  }) {
    return _around.future;
  }

  void completeLatest(List<WKMsg> messages) {
    if (!_latest.isCompleted) {
      _latest.complete(messages);
    }
  }

  void completeAround(List<WKMsg> messages) {
    if (!_around.isCompleted) {
      _around.complete(messages);
    }
  }
}

class _AnchoredHistoryGateway implements ChatHistoryGateway {
  @override
  Future<List<WKMsg>> loadAroundOrderSeq({
    required String channelId,
    required int channelType,
    required int limit,
    required int aroundOrderSeq,
  }) async {
    return <WKMsg>[
      WKMsg()
        ..channelID = channelId
        ..channelType = channelType
        ..orderSeq = aroundOrderSeq + 1000
        ..messageSeq = 43
        ..contentType = 1
        ..content = 'newer',
      WKMsg()
        ..channelID = channelId
        ..channelType = channelType
        ..orderSeq = aroundOrderSeq
        ..messageSeq = 42
        ..contentType = 1
        ..content = 'target',
    ];
  }

  @override
  Future<List<WKMsg>> loadLatest({
    required String channelId,
    required int channelType,
    required int limit,
  }) async {
    return const <WKMsg>[];
  }

  @override
  Future<List<WKMsg>> loadMore({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int limit,
  }) async {
    return const <WKMsg>[];
  }
}

class _EmptyMessageListNotifier extends MessageListNotifier {
  _EmptyMessageListNotifier(super.channelId, super.channelType)
    : super(autoLoad: false);

  @override
  Future<void> loadMessages() async {
    state = <WKMsg>[];
  }

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> loadAroundOrderSeq(int aroundOrderSeq) async {}
}

class _ChatPageRouteAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;

    if (options.method.toUpperCase() == 'GET' && path.startsWith('/v1/user/')) {
      return _jsonResponse(<String, dynamic>{
        'uid': options.uri.pathSegments.isNotEmpty
            ? options.uri.pathSegments.last
            : 'u_demo',
        'flame': 0,
        'flame_second': 0,
      });
    }

    if (options.method.toUpperCase() == 'POST' &&
        path.contains('/message/pinned/sync')) {
      return _jsonResponse(<String, dynamic>{
        'code': 0,
        'data': <String, dynamic>{
          'pinned_messages': const <dynamic>[],
          'messages': const <dynamic>[],
        },
      });
    }

    return _jsonResponse(const <String, dynamic>{'code': 0, 'data': {}});
  }

  ResponseBody _jsonResponse(Object payload, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
