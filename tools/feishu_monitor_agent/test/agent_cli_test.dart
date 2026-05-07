import 'dart:convert';
import 'dart:io';

import 'package:feishu_monitor_agent/src/agent_cli.dart';
import 'package:feishu_monitor_agent/src/agent_models.dart';
import 'package:feishu_monitor_agent/src/agent_store.dart';
import 'package:feishu_monitor_agent/src/browser_controller.dart';
import 'package:feishu_monitor_agent/src/browser_profile.dart';
import 'package:feishu_monitor_agent/src/feishu_web_adapter.dart';
import 'package:feishu_monitor_agent/src/heartbeat_runner.dart';
import 'package:test/test.dart';

void main() {
  group('runAgentCli', () {
    late Directory tempDir;
    late _FakeAgentApi fakeApi;
    late List<String> output;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('feishu_agent_cli_test_');
      fakeApi = _FakeAgentApi();
      output = <String>[];
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('pair command stores config and does not print token', () async {
      final exitCode = await runAgentCli(
        <String>[
          'pair',
          '--server',
          'https://infoequity.qingyunshe.top',
          '--code',
          'A7K9Q2',
          '--store-dir',
          tempDir.path,
        ],
        apiFactory: (_) => fakeApi,
        writeLine: output.add,
        now: () => DateTime.utc(2026, 5, 6, 10, 15, 3),
        deviceNameProvider: () => 'COLORFUL-PC',
      );

      final config = await AgentStore(tempDir.path).load();

      expect(exitCode, 0);
      expect(output.join('\n'), contains('绑定成功'));
      expect(output.join('\n'), isNot(contains('secret-token')));
      expect(config, isNotNull);
      expect(config!.serverUrl, 'https://infoequity.qingyunshe.top');
      expect(config.agentId, 'agent_1');
      expect(config.agentToken, 'secret-token');
      expect(fakeApi.lastPairRequest!.pairingCode, 'A7K9Q2');
      expect(fakeApi.closed, isTrue);
    });

    test('run command sends one heartbeat from stored config', () async {
      await _saveConfig(tempDir.path);

      final exitCode = await runAgentCli(
        <String>['run', '--once', '--store-dir', tempDir.path],
        apiFactory: (_) => fakeApi,
        writeLine: output.add,
        now: () => DateTime.utc(2026, 5, 6, 10, 15, 20),
      );

      expect(exitCode, 0);
      expect(output.join('\n'), contains('心跳成功'));
      expect(output.join('\n'), isNot(contains('secret-token')));
      expect(fakeApi.heartbeatCount, 1);
      expect(fakeApi.lastHeartbeatToken, 'secret-token');
      expect(fakeApi.lastHeartbeatRequest!.capabilities, <String>[
        'feishu_web_group',
      ]);
      expect(fakeApi.closed, isTrue);
    });

    test('run command reports missing config', () async {
      final exitCode = await runAgentCli(
        <String>['run', '--once', '--store-dir', tempDir.path],
        apiFactory: (_) => fakeApi,
        writeLine: output.add,
      );

      expect(exitCode, 66);
      expect(output.join('\n'), contains('未找到 Agent 配置'));
      expect(fakeApi.heartbeatCount, 0);
    });

    test('browser-status reports status without printing token', () async {
      await _saveConfig(tempDir.path);
      final fakeBrowser = _FakeBrowserController(BrowserLoginStatus.loggedIn);

      final exitCode = await runAgentCli(
        <String>['browser-status', '--store-dir', tempDir.path],
        apiFactory: (_) => fakeApi,
        browserFactory: (_) => fakeBrowser,
        writeLine: output.add,
        now: () => DateTime.utc(2026, 5, 7, 10, 0, 0),
      );

      expect(exitCode, 0);
      expect(output.join('\n'), contains('飞书已登录'));
      expect(output.join('\n'), isNot(contains('secret-token')));
      expect(fakeBrowser.checkStatusCount, 1);
      expect(
        fakeApi.reportedStatuses.single.loginStatus,
        BrowserLoginStatus.loggedIn,
      );
      expect(fakeApi.closed, isTrue);
    });

    test('list-chats prints deduplicated chat JSON without token', () async {
      await _saveConfig(tempDir.path);
      final fakeBrowser = _FakeBrowserController(BrowserLoginStatus.loggedIn)
        ..chatNames = <String>[
          '飞书新闻群',
          '产品交流群',
          '1 企业安全助手 机器人',
          '企业安全助手',
          '飞书新闻群',
        ];

      final exitCode = await runAgentCli(
        <String>['list-chats', '--store-dir', tempDir.path],
        browserFactory: (_) => fakeBrowser,
        writeLine: output.add,
      );

      expect(exitCode, 0);
      expect(output.join('\n'), contains('"name":"飞书新闻群"'));
      expect(output.join('\n'), contains('"name":"产品交流群"'));
      expect(output.join('\n'), contains('"name":"企业安全助手"'));
      expect(output.join('\n'), isNot(contains('"name":"1 企业安全助手 机器人"')));
      expect(output.join('\n'), isNot(contains('secret-token')));
      expect(fakeBrowser.listChatsCount, 1);
      expect(fakeBrowser.closeCount, 1);
    });

    test(
      'list-chats merges cached chat names for manual scroll rescans',
      () async {
        await _saveConfig(tempDir.path);
        final paths = BrowserProfilePaths(tempDir.path);
        await paths.chatCacheFile.parent.create(recursive: true);
        await paths.chatCacheFile.writeAsString(
          jsonEncode(<String>['已缓存群', '飞书新闻群']),
        );
        final fakeBrowser = _FakeBrowserController(BrowserLoginStatus.loggedIn)
          ..chatNames = <String>['飞书新闻群', '新滚动群'];

        final exitCode = await runAgentCli(
          <String>['list-chats', '--store-dir', tempDir.path],
          browserFactory: (_) => fakeBrowser,
          writeLine: output.add,
        );

        expect(exitCode, 0);
        expect(output.join('\n'), contains('"name":"已缓存群"'));
        expect(output.join('\n'), contains('"name":"飞书新闻群"'));
        expect(output.join('\n'), contains('"name":"新滚动群"'));
        expect(jsonDecode(await paths.chatCacheFile.readAsString()), <String>[
          '已缓存群',
          '飞书新闻群',
          '新滚动群',
        ]);
      },
    );

    test('browser-login keeps interactive Chromium window open', () async {
      await _saveConfig(tempDir.path);
      final fakeBrowser = _FakeBrowserController(
        BrowserLoginStatus.loginRequired,
      );

      final exitCode = await runAgentCli(
        <String>['browser-login', '--store-dir', tempDir.path],
        browserFactory: (_) => fakeBrowser,
        writeLine: output.add,
      );

      expect(exitCode, 0);
      expect(output.join('\n'), contains('Chromium'));
      expect(fakeBrowser.openLoginCount, 1);
      expect(fakeBrowser.closeCount, 0);
      expect(
        await File(
          '${tempDir.path}${Platform.pathSeparator}runtime${Platform.pathSeparator}agent.log',
        ).readAsString(),
        contains('browser-login status=login_required'),
      );
    });

    test(
      'browser-login returns failure when Chromium cannot be opened',
      () async {
        await _saveConfig(tempDir.path);
        final fakeBrowser = _FakeBrowserController(
          BrowserLoginStatus.browserError,
        );

        final exitCode = await runAgentCli(
          <String>['browser-login', '--store-dir', tempDir.path],
          browserFactory: (_) => fakeBrowser,
          writeLine: output.add,
        );

        expect(exitCode, isNot(0));
        expect(output.join('\n'), contains('Chromium'));
        expect(fakeBrowser.openLoginCount, 1);
        expect(fakeBrowser.closeCount, 1);
        expect(
          await File(
            '${tempDir.path}${Platform.pathSeparator}runtime${Platform.pathSeparator}agent.log',
          ).readAsString(),
          contains('browser-login status=browser_error'),
        );
      },
    );

    test('clear-browser-profile deletes only chromium profile', () async {
      await _saveConfig(tempDir.path);
      final paths = BrowserProfilePaths(tempDir.path);
      await paths.profileDir.create(recursive: true);
      await File(
        '${paths.profileDir.path}${Platform.pathSeparator}Cookies',
      ).writeAsString('cookie-data');

      final exitCode = await runAgentCli(
        <String>['clear-browser-profile', '--store-dir', tempDir.path],
        apiFactory: (_) => fakeApi,
        writeLine: output.add,
        now: () => DateTime.utc(2026, 5, 7, 10, 0, 0),
      );

      expect(exitCode, 0);
      expect(output.join('\n'), contains('已清除飞书登录状态'));
      expect(await paths.profileDir.exists(), isFalse);
      expect(
        await File(
          '${tempDir.path}${Platform.pathSeparator}agent_config.json',
        ).exists(),
        isTrue,
      );
      expect(
        fakeApi.reportedStatuses.single.loginStatus,
        BrowserLoginStatus.loginRequired,
      );
    });

    test(
      'listen once baselines visible messages without reporting them',
      () async {
        await _saveConfig(tempDir.path);
        final fakeBrowser = _FakeBrowserController(BrowserLoginStatus.loggedIn);

        final exitCode = await runAgentCli(
          <String>['listen', '--once', '--store-dir', tempDir.path],
          apiFactory: (_) => fakeApi,
          browserFactory: (_) => fakeBrowser,
          writeLine: output.add,
          now: () => DateTime.utc(2026, 5, 7, 10, 0, 5),
        );

        expect(exitCode, 0);
        expect(output.join('\n'), contains('监听完成'));
        expect(output.join('\n'), isNot(contains('secret-token')));
        expect(fakeBrowser.observeRouteCount, 1);
        expect(fakeApi.reportedMessages, isEmpty);
      },
    );
  });
}

Future<void> _saveConfig(String storeDir) {
  return AgentStore(storeDir).save(
    const AgentConfig(
      serverUrl: 'https://infoequity.qingyunshe.top',
      agentId: 'agent_1',
      agentToken: 'secret-token',
      deviceName: 'COLORFUL-PC',
      agentVersion: agentVersion,
      pairedAt: '2026-05-06T10:15:03Z',
      heartbeatIntervalSeconds: 20,
    ),
  );
}

class _FakeAgentApi implements AgentApiLike {
  PairAgentRequest? lastPairRequest;
  HeartbeatRequest? lastHeartbeatRequest;
  String? lastHeartbeatToken;
  int heartbeatCount = 0;
  bool closed = false;
  final reportedStatuses = <BrowserStatusReportRequest>[];
  final reportedMessages = <ObservedMessageRequest>[];

  @override
  Future<PairAgentResponse> pair(PairAgentRequest request) async {
    lastPairRequest = request;
    return const PairAgentResponse(
      agentId: 'agent_1',
      agentToken: 'secret-token',
      heartbeatIntervalSeconds: 20,
      serverTime: '2026-05-06T10:15:03Z',
    );
  }

  @override
  Future<HeartbeatResponse> heartbeat({
    required String agentToken,
    required HeartbeatRequest request,
  }) async {
    heartbeatCount += 1;
    lastHeartbeatToken = agentToken;
    lastHeartbeatRequest = request;
    return const HeartbeatResponse(
      agentId: 'agent_1',
      status: 'online',
      nextHeartbeatAfterSeconds: 20,
      serverTime: '2026-05-06T10:15:20Z',
    );
  }

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
        sourceChatName: '飞书新闻群',
        destinationType: 'wukong_im_group',
        destinationGroupNo: 'group_1',
        destinationGroupName: '悟空 IM 新闻群',
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
  void close() {
    closed = true;
  }
}

class _FakeBrowserController implements BrowserControllerLike {
  _FakeBrowserController(this.status);

  final BrowserLoginStatus status;
  int openLoginCount = 0;
  int checkStatusCount = 0;
  int listChatsCount = 0;
  int observeRouteCount = 0;
  int closeCount = 0;
  List<String> chatNames = const <String>[];

  @override
  Future<BrowserLoginStatus> openLogin({required bool keepOpen}) async {
    openLoginCount += 1;
    return status;
  }

  @override
  Future<BrowserLoginStatus> checkStatus() async {
    checkStatusCount += 1;
    return status;
  }

  @override
  Future<List<String>> listChats() async {
    listChatsCount += 1;
    return chatNames;
  }

  @override
  Future<List<FeishuObservedMessage>> observeRoute({
    required AgentMonitorRoute route,
    required String observedAt,
  }) async {
    observeRouteCount += 1;
    return <FeishuObservedMessage>[
      FeishuObservedMessage.fromRaw(
        routeId: route.routeId,
        sourceChatName: route.sourceChatName,
        rawId: 'om_1',
        messageType: 'text',
        content: '新闻正文',
        observedAt: observedAt,
        domOrder: 1,
      ),
    ];
  }

  @override
  Future<void> close() async {
    closeCount += 1;
  }
}
