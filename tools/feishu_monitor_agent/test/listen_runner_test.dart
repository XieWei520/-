import 'dart:io';

import 'package:feishu_monitor_agent/src/agent_models.dart';
import 'package:feishu_monitor_agent/src/browser_controller.dart';
import 'package:feishu_monitor_agent/src/browser_profile.dart';
import 'package:feishu_monitor_agent/src/feishu_web_adapter.dart';
import 'package:feishu_monitor_agent/src/heartbeat_runner.dart';
import 'package:feishu_monitor_agent/src/listen_runner.dart';
import 'package:feishu_monitor_agent/src/message_dedupe_store.dart';
import 'package:test/test.dart';

void main() {
  group('ListenRunner', () {
    late Directory tempDir;
    late BrowserProfilePaths paths;
    late _FakeAgentApi api;
    late _FakeBrowserController browser;
    late ListenRunner runner;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('feishu_listen_test_');
      paths = BrowserProfilePaths(tempDir.path);
      api = _FakeAgentApi();
      browser = _FakeBrowserController();
      runner = ListenRunner(
        api: api,
        browser: browser,
        dedupeStore: MessageDedupeStore(paths.dedupeCacheFile),
        now: () => DateTime.utc(2026, 5, 7, 10, 0, 5),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('skips repeated observed messages after baseline', () async {
      const config = AgentConfig(
        serverUrl: 'https://infoequity.qingyunshe.top',
        agentId: 'agent_1',
        agentToken: 'secret-token',
        deviceName: 'COLORFUL-PC',
        agentVersion: '0.1.0',
        pairedAt: '2026-05-07T10:00:00Z',
        heartbeatIntervalSeconds: 20,
      );

      final first = await runner.runOnce(config);
      final second = await runner.runOnce(config);

      expect(first.routeCount, 1);
      expect(first.observedCount, 1);
      expect(first.reportedCount, 0);
      expect(second.routeCount, 1);
      expect(second.observedCount, 1);
      expect(second.reportedCount, 0);
      expect(api.reportedMessages, isEmpty);
      expect(
        api.reportedStatuses.map((request) => request.loginStatus),
        everyElement(BrowserLoginStatus.loggedIn),
      );
    });

    test(
      'baselines existing visible messages on first listen without reporting',
      () async {
        const config = AgentConfig(
          serverUrl: 'https://infoequity.qingyunshe.top',
          agentId: 'agent_1',
          agentToken: 'secret-token',
          deviceName: 'COLORFUL-PC',
          agentVersion: '0.1.0',
          pairedAt: '2026-05-07T10:00:00Z',
          heartbeatIntervalSeconds: 20,
        );
        browser.messageBatches = <List<FeishuObservedMessage>>[
          <FeishuObservedMessage>[
            FeishuObservedMessage.fromRaw(
              routeId: 'route_1',
              sourceChatName: '\u98de\u4e66\u65b0\u95fb\u7fa4',
              rawId: 'old_1',
              messageType: 'text',
              content: '\u5386\u53f2\u6d88\u606f',
              observedAt: '2026-05-07T10:00:05Z',
              domOrder: 1,
            ),
          ],
          <FeishuObservedMessage>[
            FeishuObservedMessage.fromRaw(
              routeId: 'route_1',
              sourceChatName: '\u98de\u4e66\u65b0\u95fb\u7fa4',
              rawId: 'old_1',
              messageType: 'text',
              content: '\u5386\u53f2\u6d88\u606f',
              observedAt: '2026-05-07T10:00:25Z',
              domOrder: 1,
            ),
            FeishuObservedMessage.fromRaw(
              routeId: 'route_1',
              sourceChatName: '\u98de\u4e66\u65b0\u95fb\u7fa4',
              rawId: 'new_1',
              messageType: 'text',
              content: '\u65b0\u6d88\u606f',
              observedAt: '2026-05-07T10:00:25Z',
              domOrder: 2,
            ),
          ],
        ];

        final first = await runner.runOnce(config);
        final second = await runner.runOnce(config);

        expect(first.routeCount, 1);
        expect(first.observedCount, 1);
        expect(first.reportedCount, 0);
        expect(second.routeCount, 1);
        expect(second.observedCount, 2);
        expect(second.reportedCount, 1);
        expect(api.reportedMessages.single.sourceMessageId, 'new_1');
        expect(api.reportedMessages.single.content, '\u65b0\u6d88\u606f');
      },
    );
  });
}

class _FakeAgentApi implements AgentApiLike {
  final reportedStatuses = <BrowserStatusReportRequest>[];
  final reportedMessages = <ObservedMessageRequest>[];

  @override
  Future<List<AgentMonitorRoute>> fetchAssignedRoutes({
    required String agentToken,
  }) async {
    return const <AgentMonitorRoute>[
      AgentMonitorRoute(
        routeId: 'route_1',
        platform: 'feishu',
        connectorType: 'feishu_web_group',
        routeType: 'feishu_web_group_to_wukong_im_group',
        sourceChatName: '\u98de\u4e66\u65b0\u95fb\u7fa4',
        destinationType: 'wukong_im_group',
        destinationGroupNo: 'group_1',
        destinationGroupName: '\u609f\u7a7a IM \u65b0\u95fb\u7fa4',
        includeText: true,
        includeLinks: true,
        includeImages: false,
        includeFiles: false,
      ),
    ];
  }

  @override
  Future<void> reportBrowserStatus({
    required String agentToken,
    required BrowserStatusReportRequest request,
  }) async {
    reportedStatuses.add(request);
  }

  @override
  Future<ObservedMessageResponse> reportObservedMessage({
    required String agentToken,
    required ObservedMessageRequest request,
  }) async {
    reportedMessages.add(request);
    return const ObservedMessageResponse(
      accepted: true,
      duplicate: false,
      forwardStatus: 'forwarded',
      messageId: 'message_1',
    );
  }

  @override
  Future<HeartbeatResponse> heartbeat({
    required String agentToken,
    required HeartbeatRequest request,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PairAgentResponse> pair(PairAgentRequest request) {
    throw UnimplementedError();
  }

  @override
  void close() {}
}

class _FakeBrowserController implements BrowserControllerLike {
  List<List<FeishuObservedMessage>>? messageBatches;
  var observeCount = 0;

  @override
  Future<BrowserLoginStatus> checkStatus() async => BrowserLoginStatus.loggedIn;

  @override
  Future<List<FeishuObservedMessage>> observeRoute({
    required AgentMonitorRoute route,
    required String observedAt,
  }) async {
    final batches = messageBatches;
    if (batches != null) {
      final index = observeCount < batches.length
          ? observeCount
          : batches.length - 1;
      observeCount += 1;
      return batches[index];
    }
    return <FeishuObservedMessage>[
      FeishuObservedMessage.fromRaw(
        routeId: route.routeId,
        sourceChatName: route.sourceChatName,
        rawId: 'om_1',
        messageType: 'text',
        content: '\u65b0\u95fb\u6b63\u6587',
        observedAt: observedAt,
        domOrder: 1,
      ),
    ];
  }

  @override
  Future<BrowserLoginStatus> openLogin({required bool keepOpen}) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> listChats() {
    throw UnimplementedError();
  }

  @override
  Future<void> close() async {}
}
