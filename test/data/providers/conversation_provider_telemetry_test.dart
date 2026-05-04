import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/chat_session.dart';
import 'package:wukong_im_app/data/providers/chat_history_gateway.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/data/telemetry/message_query_jank_monitor.dart';
import 'package:wukong_im_app/modules/conversation/conversation_projection_repository.dart';
import 'package:wukong_im_app/modules/conversation/conversation_projection_reducer.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry_provider.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('message list loadMore records sqlite page query telemetry', () async {
    final telemetry = _RecordingConversationTelemetry();
    final gateway = _RecordingHistoryGateway();
    final notifier = MessageListNotifier(
      'g1001',
      2,
      historyGateway: gateway,
      autoLoad: false,
      telemetry: telemetry,
    );
    addTearDown(notifier.dispose);

    await notifier.loadMessages();
    telemetry.reset();

    await notifier.loadMore();

    expect(telemetry.sqliteModes, <String>['older_page']);
    expect(telemetry.sqliteDurations, hasLength(1));
  });

  test('message list records sqlite telemetry for each paging mode', () async {
    final telemetry = _RecordingConversationTelemetry();
    final gateway = _RecordingHistoryGateway();
    final notifier = MessageListNotifier(
      'g1001',
      2,
      historyGateway: gateway,
      autoLoad: false,
      telemetry: telemetry,
    );
    addTearDown(notifier.dispose);

    await notifier.loadMessages();
    await notifier.loadMore();
    await notifier.loadAroundOrderSeq(75);

    expect(telemetry.sqliteModes, <String>[
      'latest_page',
      'older_page',
      'around_page',
    ]);
    expect(telemetry.sqliteDurations, hasLength(3));
  });

  test(
    'conversation applyPatch records patch latency without changing behavior',
    () {
      final telemetry = _RecordingConversationTelemetry();
      final notifier = ConversationNotifier(
        attachSdkListeners: false,
        loadInitialConversations: false,
        projectionRepository: ConversationProjectionRepository(
          const ConversationProjectionReducer(),
        ),
        telemetry: telemetry,
      );
      addTearDown(notifier.dispose);

      notifier.applyPatch(
        const ConversationPatch.unreadAndDigest(
          channelId: 'u_patch_01',
          channelType: 1,
          unreadCount: 3,
          lastMessageDigest: 'hello',
          sortTimestamp: 123,
        ),
      );

      expect(notifier.state, hasLength(1));
      expect(notifier.state.single.channelID, 'u_patch_01');
      expect(telemetry.patchDurations, hasLength(1));
    },
  );

  test('conversation provider wires shared patch telemetry by default', () {
    final telemetry = _RecordingConversationTelemetry();
    final container = ProviderContainer(
      overrides: [
        conversationPatchTelemetryProvider.overrideWithValue(telemetry),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(conversationProvider.notifier);

    notifier.applyPatch(
      const ConversationPatch.unreadAndDigest(
        channelId: 'u_provider_patch',
        channelType: 1,
        unreadCount: 2,
        lastMessageDigest: 'provider',
        sortTimestamp: 456,
      ),
    );

    expect(telemetry.patchDurations, hasLength(1));
  });

  test(
    'message list provider wires shared sqlite telemetry by default',
    () async {
      final telemetry = _RecordingConversationTelemetry();
      final gateway = _RecordingHistoryGateway();
      final session = const ChatSession(
        channelId: 'g_provider_telemetry',
        channelType: 2,
      );
      final container = ProviderContainer(
        overrides: [
          chatHistoryGatewayProvider.overrideWithValue(gateway),
          messageQueryTelemetryProvider.overrideWithValue(telemetry),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(messageListProvider(session).notifier);

      await notifier.loadMessages();
      telemetry.reset();
      await notifier.loadMore();

      expect(telemetry.sqliteModes, <String>['older_page']);
      expect(telemetry.sqliteDurations, hasLength(1));
    },
  );

  test('message list provider does not own chat scroll jank monitoring', () {
    final telemetry = _RecordingConversationTelemetry();
    final gateway = _RecordingHistoryGateway();
    final session = const ChatSession(
      channelId: 'g_provider_jank_monitor',
      channelType: 2,
    );
    final monitors = <_RecordingJankMonitor>[];
    final container = ProviderContainer(
      overrides: [
        chatHistoryGatewayProvider.overrideWithValue(gateway),
        messageQueryTelemetryProvider.overrideWithValue(telemetry),
        messageQueryJankMonitorFactoryProvider.overrideWithValue((
          telemetry, {
          enabled,
        }) {
          final monitor = _RecordingJankMonitor(telemetry);
          monitors.add(monitor);
          return monitor;
        }),
      ],
    );

    container.read(messageListProvider(session).notifier);

    expect(monitors, isEmpty);

    container.dispose();
  });

  test('chat viewport provider scopes chat scroll jank monitoring', () async {
    final telemetry = _RecordingConversationTelemetry();
    final gateway = _RecordingHistoryGateway();
    final session = const ChatSession(
      channelId: 'g_viewport_jank_monitor',
      channelType: 2,
    );
    final monitors = <_RecordingJankMonitor>[];
    final container = ProviderContainer(
      overrides: [
        chatHistoryGatewayProvider.overrideWithValue(gateway),
        messageQueryTelemetryProvider.overrideWithValue(telemetry),
        messageQueryJankMonitorFactoryProvider.overrideWithValue((
          telemetry, {
          enabled,
        }) {
          final monitor = _RecordingJankMonitor(telemetry);
          monitors.add(monitor);
          return monitor;
        }),
      ],
    );

    final subscription = container.listen(
      chatViewportProvider(session),
      (_, _) {},
      fireImmediately: true,
    );

    expect(monitors, hasLength(1));
    expect(monitors.single.registered, isTrue);

    subscription.close();
    await container.pump();

    expect(monitors.single.disposed, isTrue);
    container.dispose();
  });
}

class _RecordingConversationTelemetry
    implements ConversationPatchTelemetry, MessageQueryTelemetry {
  final List<Duration> patchDurations = <Duration>[];
  final List<Duration> sqliteDurations = <Duration>[];
  final List<String> sqliteModes = <String>[];

  @override
  void recordConversationPatchApply(Duration duration) {
    patchDurations.add(duration);
  }

  @override
  void recordSqlitePageQuery(Duration duration, {required String mode}) {
    sqliteDurations.add(duration);
    sqliteModes.add(mode);
  }

  void reset() {
    patchDurations.clear();
    sqliteDurations.clear();
    sqliteModes.clear();
  }
}

class _RecordingHistoryGateway implements ChatHistoryGateway {
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
        ..orderSeq = 100
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
    return <WKMsg>[
      WKMsg()
        ..channelID = channelId
        ..channelType = channelType
        ..orderSeq = oldestOrderSeq - 1
        ..contentType = 1,
    ];
  }
}

class _RecordingJankMonitor extends MessageQueryJankMonitor {
  _RecordingJankMonitor(MessageQueryJankTelemetry telemetry)
    : super(telemetry: telemetry, enabled: true);

  bool registered = false;
  bool disposed = false;

  @override
  void register() {
    registered = true;
  }

  @override
  void dispose() {
    disposed = true;
  }
}
