import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_center_page.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_shell_client.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_shell_models.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  final probeObservedAt = DateTime(2026, 5, 9, 10, 30);
  final observedConversations = <FeishuMonitorObservedConversation>[
    FeishuMonitorObservedConversation(
      id: 'feed:alpha',
      name: 'Project Phoenix',
      type: 'group',
      lastMessagePreview: 'Daily sync moved to 3 PM',
      observedAt: probeObservedAt,
    ),
    FeishuMonitorObservedConversation(
      id: 'feed:mm12',
      name: 'MM12 交流群',
      type: 'group',
      lastMessagePreview: '今天盘中、多空来回拉锯较强',
      observedAt: probeObservedAt,
    ),
    FeishuMonitorObservedConversation(
      id: 'feed:service',
      name: '服务机器人',
      type: 'bot',
      lastMessagePreview: '猜你想问以下问题',
      observedAt: probeObservedAt,
    ),
  ];
  final observedMessages = List<FeishuMonitorObservedMessage>.generate(
    3,
    (index) => FeishuMonitorObservedMessage(
      id: 'msg-${index + 1}',
      conversationId: 'feed:mm12',
      conversationName: 'MM12 交流群',
      senderName: 'MM12机器人',
      messageType: 'text',
      text: index == 0 ? '今天盘中、多空来回拉锯较强' : '候选消息 ${index + 1}',
      observedAt: probeObservedAt,
      captureSource: 'feed_card_probe',
    ),
  );
  final recentEvents = List<FeishuMonitorMessageEvent>.generate(
    4,
    (index) => FeishuMonitorMessageEvent(
      eventId: 'event_msg_${index + 1}',
      dedupeKey: 'feed-dedupe-${index + 1}',
      accountId: '',
      conversationId: index.isEven ? 'feed:mm12' : 'feed:alpha',
      conversationName: index.isEven ? 'MM12 交流群' : 'Project Phoenix',
      conversationType: 'group',
      messageId: 'event-only-message-${index + 1}',
      senderId: '',
      senderName: index.isEven ? 'MM12机器人' : 'Alice',
      messageType: 'text',
      text: index == 0
          ? '今天盘中、多空来回拉锯较强'
          : 'event-only timeline text ${index + 1}',
      sentAt: null,
      observedAt: probeObservedAt,
      captureSource: 'feed_card_probe',
    ),
  );

  testWidgets('renders monitor console structure', (tester) async {
    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages,
        recentEvents: recentEvents,
      ),
    );

    expect(find.text('飞书信息转发中心'), findsOneWidget);
    expect(find.text('状态总览'), findsOneWidget);
    expect(find.text('Shell 程序'), findsOneWidget);
    expect(find.text('飞书账号'), findsOneWidget);
    expect(find.text('监听状态'), findsOneWidget);
    expect(find.text('今日捕获'), findsOneWidget);
    expect(find.text('今日成功'), findsOneWidget);
    expect(find.text('今日失败'), findsOneWidget);
    expect(find.text('快捷操作'), findsOneWidget);
    expect(find.text('运行日志'), findsWidgets);
    expect(find.text('转发规则'), findsOneWidget);
    expect(find.text('飞书群组'), findsOneWidget);
    expect(find.text('图片处理'), findsOneWidget);
    expect(find.text('系统设置'), findsOneWidget);
    expect(find.text('启动转发'), findsOneWidget);
    expect(find.text('停止转发'), findsOneWidget);
  });

  testWidgets('quick capture actions show visible success feedback', (
    tester,
  ) async {
    final client = _FakeShellClient(
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages,
        recentEvents: recentEvents,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          client: client,
          forwardingService: _FakeForwardingService(),
          forwardingSettingsStore: _MemoryForwardingSettingsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-monitor-start-capture-button')),
    );

    expect(client.startCaptureCount, 1);
    expect(find.textContaining('已启动飞书转发'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-monitor-stop-capture-button')),
    );

    expect(client.stopCaptureCount, 1);
    expect(find.textContaining('已停止飞书转发'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-monitor-reload-runtime-button')),
    );

    expect(client.reloadRuntimeCount, 1);
    expect(find.textContaining('已重新加载飞书'), findsWidgets);
  });

  testWidgets('status overview shows worker and media queue diagnostics', (
    tester,
  ) async {
    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages,
        recentEvents: recentEvents,
        workerId: 'worker-2',
        mediaQueueDepth: 3,
        mediaQueueOldestWaitSeconds: 45,
        mediaQueueEstimatedNextDelaySeconds: 60,
        mediaQueueLastSkipReason: 'image_extraction_timeout',
      ),
    );

    expect(find.text('worker-2'), findsWidgets);
    expect(find.textContaining('Media queue'), findsWidgets);
    expect(find.textContaining('3'), findsWidgets);
    expect(find.textContaining('45s'), findsWidgets);
    expect(find.textContaining('60s'), findsWidgets);
    expect(find.textContaining('image_extraction_timeout'), findsWidgets);
  });

  testWidgets(
    'status overview warns when routes exceed single worker capacity',
    (tester) async {
      await _pumpCenter(
        tester,
        status: _onlineStatus(
          probeObservedAt: probeObservedAt,
          observedConversations: observedConversations,
          observedMessages: observedMessages,
          recentEvents: recentEvents,
        ),
        settingsStore: _MemoryForwardingSettingsStore(
          initial: FeishuMonitorForwardingSettings(
            enabled: true,
            routes: List<FeishuMonitorForwardingRoute>.generate(
              21,
              (index) => _route(
                id: 'route_$index',
                sourceConversationId: 'feed:$index',
                sourceConversationName: 'Source $index',
                targetGroupId: 'wk_$index',
                targetGroupName: 'Target $index',
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('worker capacity 20'), findsOneWidget);
      expect(find.textContaining('21'), findsWidgets);
    },
  );

  testWidgets('status overview falls back to observed event counts', (
    tester,
  ) async {
    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages,
        recentEvents: recentEvents,
        messagesToday: 0,
        deliveriesSucceededToday: 0,
      ),
      settingsStore: _MemoryForwardingSettingsStore(
        initial: FeishuMonitorForwardingSettings(
          enabled: true,
          routes: <FeishuMonitorForwardingRoute>[
            _route(
              id: 'route_alpha',
              sourceConversationId: 'feed:alpha',
              sourceConversationName: 'Project Phoenix',
              targetGroupId: 'wk_alpha',
              targetGroupName: '悟空 Alpha 群',
            ),
          ],
        ),
      ),
    );

    expect(find.text('4'), findsWidgets);
    expect(find.textContaining('消息 3，事件 4'), findsOneWidget);
    expect(find.textContaining('匹配可转发 2'), findsOneWidget);
  });

  testWidgets('runtime logs tab shows recent events and can switch tabs', (
    tester,
  ) async {
    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages,
        recentEvents: recentEvents,
      ),
    );

    expect(find.text('全部'), findsOneWidget);
    expect(find.text('成功'), findsWidgets);
    expect(find.text('错误'), findsOneWidget);
    expect(find.text('捕获'), findsWidgets);
    expect(find.text('转发'), findsWidgets);
    expect(find.textContaining('feed_card_probe'), findsWidgets);
    expect(find.textContaining('今天盘中、多空来回拉锯较强'), findsWidgets);

    await _tapVisible(tester, find.text('转发规则'));

    expect(find.text('新增规则'), findsOneWidget);
    expect(find.text('清空日志'), findsNothing);
  });

  testWidgets('rules and groups tabs show route and observed data', (
    tester,
  ) async {
    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages,
        recentEvents: recentEvents,
      ),
      settingsStore: _MemoryForwardingSettingsStore(
        initial: FeishuMonitorForwardingSettings(
          enabled: true,
          routes: <FeishuMonitorForwardingRoute>[
            _route(targetGroupId: 'group_1', targetGroupName: 'group_1'),
          ],
        ),
      ),
    );

    await _tapVisible(tester, find.text('转发规则'));

    expect(find.text('规则名称'), findsOneWidget);
    expect(find.text('来源飞书群'), findsOneWidget);
    expect(find.text('目标悟空IM群'), findsOneWidget);
    expect(find.text('group_1'), findsOneWidget);

    await _tapVisible(tester, find.text('飞书群组'));

    expect(find.text('刷新列表'), findsOneWidget);
    expect(find.text('聊天类型'), findsOneWidget);
    expect(find.text('群名称'), findsOneWidget);
    expect(find.text('飞书群 ID'), findsOneWidget);
    expect(find.text('最近消息'), findsOneWidget);
    expect(find.text('转发状态'), findsOneWidget);
    expect(find.text('Project Phoenix'), findsWidgets);
    expect(find.text('MM12 交流群'), findsWidgets);
  });

  testWidgets('image processing and system settings tabs render forms', (
    tester,
  ) async {
    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages,
        recentEvents: recentEvents,
      ),
    );

    await _tapVisible(tester, find.text('图片处理'));

    expect(find.text('文字转图片'), findsOneWidget);
    expect(find.text('图片水印'), findsOneWidget);
    expect(find.text('触发几率'), findsWidgets);
    expect(find.text('水印文字'), findsOneWidget);
    expect(find.text('保存设置'), findsOneWidget);

    await _tapVisible(tester, find.text('系统设置'));

    expect(find.text('本地 Shell 程序'), findsOneWidget);
    expect(find.text('Token'), findsOneWidget);
    expect(find.text('刷新间隔'), findsOneWidget);
    expect(find.text('自动转发'), findsWidgets);
    expect(find.text('去重窗口'), findsOneWidget);
    expect(find.text('投递通道'), findsOneWidget);
  });

  testWidgets(
    'manual forwarding sends recent events through configured routes',
    (tester) async {
      final forwardingService = _FakeForwardingService();
      final settingsStore = _MemoryForwardingSettingsStore(
        initial: FeishuMonitorForwardingSettings(
          enabled: true,
          routes: <FeishuMonitorForwardingRoute>[
            _route(
              id: 'route_alpha',
              sourceConversationId: 'feed:alpha',
              sourceConversationName: 'Project Phoenix',
              targetGroupId: 'wk_alpha',
              targetGroupName: '悟空 Alpha 群',
            ),
          ],
        ),
      );

      await _pumpCenter(
        tester,
        status: _onlineStatus(
          probeObservedAt: probeObservedAt,
          observedConversations: observedConversations,
          observedMessages: observedMessages.take(1).toList(),
          recentEvents: recentEvents.take(2).toList(),
        ),
        forwardingService: forwardingService,
        settingsStore: settingsStore,
      );

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('feishu-monitor-forward-recent-button')),
      );

      expect(forwardingService.lastSettings?.routes, hasLength(1));
      expect(
        forwardingService.lastSettings?.routes.single.targetGroupId,
        'wk_alpha',
      );
      expect(forwardingService.lastEvents, hasLength(2));
      expect(find.textContaining('已转发 2 条'), findsOneWidget);
    },
  );

  testWidgets('manual forwarding ignores global auto-forwarding switch', (
    tester,
  ) async {
    final forwardingService = _FakeForwardingService();
    final settingsStore = _MemoryForwardingSettingsStore(
      initial: FeishuMonitorForwardingSettings(
        enabled: false,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            id: 'route_alpha',
            sourceConversationId: 'feed:alpha',
            sourceConversationName: 'Project Phoenix',
            targetGroupId: 'wk_alpha',
            targetGroupName: '悟空 Alpha 群',
          ),
        ],
      ),
    );

    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(2).toList(),
      ),
      forwardingService: forwardingService,
      settingsStore: settingsStore,
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-monitor-forward-recent-button')),
    );

    expect(forwardingService.lastSettings?.enabled, isTrue);
    expect(settingsStore.saved?.enabled, isFalse);
    expect(forwardingService.lastEvents, hasLength(2));
  });

  testWidgets('manual forwarding result shows disabled skips', (tester) async {
    final forwardingService = _FixedResultForwardingService(
      const FeishuMonitorForwardingResult(
        sent: 0,
        skippedDisabled: 2,
        failed: 0,
      ),
    );

    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(2).toList(),
      ),
      forwardingService: forwardingService,
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-monitor-forward-recent-button')),
    );

    expect(find.textContaining('停用跳过 2 条'), findsOneWidget);
  });

  testWidgets('rules tab renders multiple forwarding routes', (tester) async {
    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(2).toList(),
      ),
      settingsStore: _MemoryForwardingSettingsStore(
        initial: FeishuMonitorForwardingSettings(
          enabled: true,
          routes: <FeishuMonitorForwardingRoute>[
            _route(
              id: 'route_alpha',
              sourceConversationId: 'feed:alpha',
              sourceConversationName: 'Project Phoenix',
              targetGroupId: 'wk_alpha',
              targetGroupName: '悟空 Alpha 群',
            ),
            _route(
              id: 'route_mm12',
              sourceConversationId: 'feed:mm12',
              sourceConversationName: 'MM12 交流群',
              targetGroupId: 'wk_mm12',
              targetGroupName: '悟空 MM12 群',
            ),
          ],
        ),
      ),
    );

    await _tapVisible(tester, find.text('转发规则'));

    expect(find.text('Project Phoenix'), findsWidgets);
    expect(find.text('悟空 Alpha 群'), findsOneWidget);
    expect(find.text('MM12 交流群'), findsOneWidget);
    expect(find.text('悟空 MM12 群'), findsOneWidget);
  });

  testWidgets('target group can be selected from WuKong IM groups', (
    tester,
  ) async {
    final settingsStore = _MemoryForwardingSettingsStore();

    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(1).toList(),
      ),
      settingsStore: settingsStore,
      loadTargetGroups: () async => <GroupInfo>[
        GroupInfo(groupNo: 'group_alpha', name: '飞书转发测试群'),
        GroupInfo(groupNo: 'group_beta', name: '交易提醒群'),
      ],
    );

    await _tapVisible(tester, find.text('飞书群组'));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-configure-feed:alpha')),
    );
    await _tapVisible(tester, find.text('飞书转发测试群'));

    expect(settingsStore.saved?.routes.single.targetGroupId, 'group_alpha');
  });

  testWidgets('route relay identity can be customized after group selection', (
    tester,
  ) async {
    final settingsStore = _MemoryForwardingSettingsStore();

    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(1).toList(),
      ),
      settingsStore: settingsStore,
      loadTargetGroups: () async => <GroupInfo>[
        GroupInfo(
          groupNo: 'wk_relay',
          name: 'Relay Target',
          save: 1,
          status: 1,
        ),
      ],
    );

    await _tapVisible(tester, find.text('飞书群组'));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-configure-feed:alpha')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('feishu-route-relay-name-field')),
      '飞书转发助手 A',
    );
    await tester.enterText(
      find.byKey(const ValueKey('feishu-route-relay-avatar-field')),
      'https://cdn.example.com/relay-a.png',
    );
    await _tapVisible(tester, find.text('Relay Target'));

    final saved = settingsStore.saved;
    expect(saved, isNotNull);
    expect(saved!.routes.single.targetGroupId, 'wk_relay');
    expect(saved.routes.single.relayDisplayName, '飞书转发助手 A');
    expect(
      saved.routes.single.relayAvatar,
      'https://cdn.example.com/relay-a.png',
    );
  });

  testWidgets('route relay avatar can be uploaded from local image', (
    tester,
  ) async {
    final settingsStore = _MemoryForwardingSettingsStore();
    var pickedPath = '';
    var uploadedPath = '';

    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(1).toList(),
      ),
      settingsStore: settingsStore,
      loadTargetGroups: () async => <GroupInfo>[
        GroupInfo(
          groupNo: 'wk_relay',
          name: 'Relay Target',
          save: 1,
          status: 1,
        ),
      ],
      pickRelayAvatarImage: () async {
        pickedPath = r'C:\avatars\relay.png';
        return pickedPath;
      },
      uploadRelayAvatarImage: (path) async {
        uploadedPath = path;
        return 'https://cdn.example.com/uploaded-relay.png';
      },
    );

    await _tapVisible(tester, find.text('\u98de\u4e66\u7fa4\u7ec4'));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-configure-feed:alpha')),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-relay-avatar-upload-button')),
    );

    expect(pickedPath, r'C:\avatars\relay.png');
    expect(uploadedPath, r'C:\avatars\relay.png');
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('feishu-route-relay-avatar-field')),
          )
          .controller
          ?.text,
      'https://cdn.example.com/uploaded-relay.png',
    );

    await _tapVisible(tester, find.text('Relay Target'));

    final saved = settingsStore.saved;
    expect(saved, isNotNull);
    expect(
      saved!.routes.single.relayAvatar,
      'https://cdn.example.com/uploaded-relay.png',
    );
  });

  testWidgets(
    'target group picker uses cached channel name when api name empty',
    (tester) async {
      final cachedChannel = WKChannel(
        '063db9c564e64e7d839887a022b86189',
        WKChannelType.group,
      )..channelName = '飞书转发测试群';
      WKIM.shared.channelManager.addOrUpdateChannel(cachedChannel);

      await _pumpCenter(
        tester,
        status: _onlineStatus(
          probeObservedAt: probeObservedAt,
          observedConversations: observedConversations,
          observedMessages: observedMessages.take(1).toList(),
          recentEvents: recentEvents.take(1).toList(),
        ),
        loadTargetGroups: () async => <GroupInfo>[
          GroupInfo(groupNo: '063db9c564e64e7d839887a022b86189'),
        ],
      );

      await _tapVisible(tester, find.text('飞书群组'));
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('feishu-route-configure-feed:alpha')),
      );

      expect(find.text('飞书转发测试群'), findsOneWidget);
      expect(find.text('063db9c564e64e7d839887a022b86189'), findsOneWidget);
    },
  );

  testWidgets('target group picker hides inactive or unsaved groups', (
    tester,
  ) async {
    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(1).toList(),
      ),
      loadTargetGroups: () async => <GroupInfo>[
        GroupInfo(groupNo: 'group_active', name: '当前可用群', save: 1, status: 1),
        GroupInfo(groupNo: 'group_unsaved', name: '已退出群', save: 0, status: 1),
        GroupInfo(groupNo: 'group_inactive', name: '已解散群', save: 1, status: 2),
      ],
    );

    await _tapVisible(tester, find.text('飞书群组'));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-configure-feed:alpha')),
    );

    expect(find.text('当前可用群'), findsOneWidget);
    expect(find.text('已退出群'), findsNothing);
    expect(find.text('已解散群'), findsNothing);
  });

  testWidgets(
    'console card headers wrap long trailing content on narrow width',
    (tester) async {
      final forwardingService = _FailingForwardingService(
        Exception(
          'network timeout while forwarding to a very long target group id '
          'with detailed diagnostic context from the local SDK channel',
        ),
      );

      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpCenter(
        tester,
        status: _onlineStatus(
          probeObservedAt: probeObservedAt,
          observedConversations: observedConversations,
          observedMessages: observedMessages.take(1).toList(),
          recentEvents: recentEvents.take(2).toList(),
        ),
        forwardingService: forwardingService,
      );

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('feishu-monitor-forward-recent-button')),
      );

      expect(find.textContaining('转发失败'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Feishu groups table exposes a horizontal scrollbar on narrow width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(560, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpCenter(
        tester,
        status: _onlineStatus(
          probeObservedAt: probeObservedAt,
          observedConversations: observedConversations,
          observedMessages: observedMessages.take(1).toList(),
          recentEvents: recentEvents.take(2).toList(),
        ),
      );

      await _tapVisible(tester, find.text('\u98de\u4e66\u7fa4\u7ec4'));

      final scrollbar = tester.widget<Scrollbar>(
        find.byKey(const ValueKey('feishu-groups-table-horizontal-scrollbar')),
      );
      expect(scrollbar.thumbVisibility, isTrue);
      expect(scrollbar.interactive, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('auto forwarding toggle persists setting', (tester) async {
    final settingsStore = _MemoryForwardingSettingsStore();
    final forwardingService = _FakeForwardingService();

    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(1).toList(),
      ),
      settingsStore: settingsStore,
      forwardingService: forwardingService,
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-monitor-auto-forward-switch')),
    );

    expect(settingsStore.saved?.enabled, isTrue);
    expect(forwardingService.lastSettings, isNull);
    expect(forwardingService.lastEvents, isEmpty);
  });

  testWidgets('runtime logs can be filtered and cleared', (tester) async {
    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(2).toList(),
      ),
    );

    expect(find.textContaining('event-only timeline text 2'), findsOneWidget);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-log-filter-capture')),
    );
    expect(find.text('当前筛选：捕获'), findsOneWidget);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-log-clear-button')),
    );

    expect(find.textContaining('日志已清空'), findsWidgets);
    expect(find.textContaining('event-only timeline text 2'), findsNothing);
  });

  testWidgets('rules tab can test and delete a route', (tester) async {
    final forwardingService = _FakeForwardingService();
    final settingsStore = _MemoryForwardingSettingsStore(
      initial: FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            id: 'route_alpha',
            sourceConversationId: 'feed:alpha',
            sourceConversationName: 'Project Phoenix',
            targetGroupId: 'wk_alpha',
            targetGroupName: '悟空 Alpha 群',
          ),
        ],
      ),
    );

    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(2).toList(),
      ),
      forwardingService: forwardingService,
      settingsStore: settingsStore,
    );

    await _tapVisible(tester, find.text('转发规则'));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-test-route_alpha')),
    );

    expect(forwardingService.lastSettings?.routes.single.id, 'route_alpha');
    expect(
      forwardingService.lastEvents.map((event) => event.conversationId),
      everyElement('feed:alpha'),
    );
    expect(find.textContaining('测试完成'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-delete-route_alpha')),
    );

    expect(settingsStore.saved?.routes, isEmpty);
    expect(find.textContaining('已删除规则'), findsOneWidget);
  });

  testWidgets('system settings save persists auto-forwarding changes', (
    tester,
  ) async {
    final settingsStore = _MemoryForwardingSettingsStore();

    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(1).toList(),
      ),
      settingsStore: settingsStore,
    );

    await _tapVisible(tester, find.text('系统设置'));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-settings-auto-forward-switch')),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-settings-save-button')),
    );

    expect(settingsStore.saved?.enabled, isTrue);
    expect(find.textContaining('系统设置已保存'), findsOneWidget);
  });

  testWidgets('route editor selects source and target groups without manual ids', (
    tester,
  ) async {
    final settingsStore = _MemoryForwardingSettingsStore();

    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(2).toList(),
      ),
      settingsStore: settingsStore,
      loadTargetGroups: () async => <GroupInfo>[
        GroupInfo(groupNo: 'wk_alpha', name: '悟空 Alpha 群', save: 1, status: 1),
        GroupInfo(groupNo: 'wk_beta', name: '悟空 Beta 群', save: 1, status: 1),
      ],
    );

    await _tapVisible(tester, find.text('转发规则'));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-add-button')),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-editor-source-feed:mm12')),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-editor-target-wk_beta')),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-editor-save-button')),
    );

    final saved = settingsStore.saved;
    expect(saved, isNotNull);
    expect(saved!.routes, hasLength(1));
    expect(saved.routes.single.sourceConversationId, 'feed:mm12');
    expect(saved.routes.single.sourceConversationName, 'MM12 交流群');
    expect(saved.routes.single.targetGroupId, 'wk_beta');
    expect(saved.routes.single.targetGroupName, '悟空 Beta 群');
  });

  testWidgets('creates forwarding route from Feishu group row', (tester) async {
    final settingsStore = _MemoryForwardingSettingsStore();

    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(2).toList(),
      ),
      settingsStore: settingsStore,
      loadTargetGroups: () async => <GroupInfo>[
        GroupInfo(groupNo: 'wk_alpha', name: '悟空 Alpha 群', save: 1, status: 1),
        GroupInfo(groupNo: 'wk_beta', name: '悟空 Beta 群', save: 1, status: 1),
      ],
    );

    await _tapVisible(tester, find.text('飞书群组'));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-configure-feed:alpha')),
    );
    await _tapVisible(tester, find.text('悟空 Alpha 群'));

    final saved = settingsStore.saved;
    expect(saved, isNotNull);
    expect(saved!.routes, hasLength(1));
    expect(saved.routes.single.id, 'route_feed_alpha');
    expect(saved.routes.single.enabled, isTrue);
    expect(saved.routes.single.sourceConversationId, 'feed:alpha');
    expect(saved.routes.single.sourceConversationName, 'Project Phoenix');
    expect(saved.routes.single.sourceConversationType, 'group');
    expect(saved.routes.single.targetGroupId, 'wk_alpha');
    expect(saved.routes.single.targetGroupName, '悟空 Alpha 群');
    expect(
      saved.routes.single.createdAt,
      isNot(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
    );
    expect(
      saved.routes.single.updatedAt,
      isNot(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
    );
  });

  testWidgets('creates multiple forwarding routes from different Feishu rows', (
    tester,
  ) async {
    final settingsStore = _MemoryForwardingSettingsStore();

    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(2).toList(),
      ),
      settingsStore: settingsStore,
      loadTargetGroups: () async => <GroupInfo>[
        GroupInfo(groupNo: 'wk_alpha', name: '悟空 Alpha 群', save: 1, status: 1),
        GroupInfo(groupNo: 'wk_beta', name: '悟空 Beta 群', save: 1, status: 1),
      ],
    );

    await _tapVisible(tester, find.text('飞书群组'));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-configure-feed:alpha')),
    );
    await _tapVisible(tester, find.text('悟空 Alpha 群'));

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-configure-feed:mm12')),
    );
    await _tapVisible(tester, find.text('悟空 Beta 群'));

    final saved = settingsStore.saved;
    expect(saved, isNotNull);
    expect(saved!.routes, hasLength(2));
    expect(
      saved.routes.map((route) => route.sourceConversationId),
      containsAll(<String>['feed:alpha', 'feed:mm12']),
    );
    expect(
      saved.routes.map((route) => route.targetGroupId),
      containsAll(<String>['wk_alpha', 'wk_beta']),
    );
  });

  testWidgets('assigns newly created routes to deterministic worker shards', (
    tester,
  ) async {
    final settingsStore = _MemoryForwardingSettingsStore(
      initial: FeishuMonitorForwardingSettings(
        enabled: true,
        routes: List<FeishuMonitorForwardingRoute>.generate(
          20,
          (index) => _route(
            id: 'route_$index',
            sourceConversationId: 'feed:existing:$index',
            sourceConversationName: 'Existing $index',
            targetGroupId: 'wk_existing_$index',
            targetGroupName: 'Existing Target $index',
            workerId: 'worker-1',
          ),
        ),
      ),
    );

    await _pumpCenter(
      tester,
      status: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages.take(1).toList(),
        recentEvents: recentEvents.take(2).toList(),
      ),
      settingsStore: settingsStore,
      loadTargetGroups: () async => <GroupInfo>[
        GroupInfo(
          groupNo: 'wk_beta',
          name: 'Worker Beta Target',
          save: 1,
          status: 1,
        ),
      ],
    );

    await _tapVisible(tester, find.text('\u98de\u4e66\u7fa4\u7ec4'));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('feishu-route-configure-feed:mm12')),
    );
    await _tapVisible(tester, find.text('Worker Beta Target'));

    final saved = settingsStore.saved;
    expect(saved, isNotNull);
    expect(saved!.routes.last.sourceConversationId, 'feed:mm12');
    expect(saved.routes.last.workerId, 'worker-2');
  });

  testWidgets(
    'updating existing route preserves disabled state and createdAt',
    (tester) async {
      final createdAt = DateTime.parse('2026-05-09T01:00:00Z');
      final settingsStore = _MemoryForwardingSettingsStore(
        initial: FeishuMonitorForwardingSettings(
          enabled: true,
          legacyTargetGroupId: 'legacy_group',
          routes: <FeishuMonitorForwardingRoute>[
            FeishuMonitorForwardingRoute(
              id: 'route_feed_alpha',
              enabled: false,
              sourceConversationId: 'feed:alpha',
              sourceConversationName: 'Project Phoenix',
              sourceConversationType: 'group',
              targetGroupId: 'old_target',
              targetGroupName: '旧目标群',
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          ],
        ),
      );

      await _pumpCenter(
        tester,
        status: _onlineStatus(
          probeObservedAt: probeObservedAt,
          observedConversations: observedConversations,
          observedMessages: observedMessages.take(1).toList(),
          recentEvents: recentEvents.take(2).toList(),
        ),
        settingsStore: settingsStore,
        loadTargetGroups: () async => <GroupInfo>[
          GroupInfo(groupNo: 'new_target', name: '新目标群', save: 1, status: 1),
        ],
      );

      await _tapVisible(tester, find.text('飞书群组'));
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('feishu-route-configure-feed:alpha')),
      );
      await _tapVisible(tester, find.text('新目标群'));

      final saved = settingsStore.saved!;
      expect(saved.enabled, isTrue);
      expect(saved.legacyTargetGroupId, 'legacy_group');
      expect(saved.routes, hasLength(1));
      expect(saved.routes.single.id, 'route_feed_alpha');
      expect(saved.routes.single.enabled, isFalse);
      expect(saved.routes.single.createdAt, createdAt);
      expect(saved.routes.single.updatedAt.isAfter(createdAt), isTrue);
      expect(saved.routes.single.targetGroupId, 'new_target');
      expect(saved.routes.single.targetGroupName, '新目标群');
    },
  );

  testWidgets('refresh button reloads latest shell status', (tester) async {
    final client = _MutableFakeShellClient(
      first: const FeishuMonitorShellStatus(
        shellState: 'offline',
        captureState: 'stopped',
        loginState: 'needs_login',
        hookState: 'down',
        runtimeUrl: '',
        pageTitle: '',
        pageKind: '',
        webviewAvailable: false,
        shellMode: 'service',
        queueDepth: 0,
        messagesToday: 0,
        deliveriesSucceededToday: 0,
        deliveriesFailedToday: 0,
        lastUpdatedAt: null,
        probeObservedAt: null,
        observedConversations: <FeishuMonitorObservedConversation>[],
        observedMessages: <FeishuMonitorObservedMessage>[],
        lastError: 'offline',
      ),
      second: _onlineStatus(
        probeObservedAt: probeObservedAt,
        observedConversations: observedConversations,
        observedMessages: observedMessages,
        recentEvents: recentEvents,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          client: client,
          forwardingService: _FakeForwardingService(),
          forwardingSettingsStore: _MemoryForwardingSettingsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('feishu-monitor-refresh-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('feishu-monitor-refresh-button')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Project Phoenix'), findsWidgets);
    await _tapVisible(tester, find.text('系统设置'));
    expect(find.text('https://feishu.cn/messenger'), findsOneWidget);
  });
}

Future<void> _pumpCenter(
  WidgetTester tester, {
  required FeishuMonitorShellStatus status,
  FeishuMonitorForwardingService? forwardingService,
  _MemoryForwardingSettingsStore? settingsStore,
  Future<List<GroupInfo>> Function()? loadTargetGroups,
  FeishuMonitorRelayAvatarPicker? pickRelayAvatarImage,
  FeishuMonitorRelayAvatarUploader? uploadRelayAvatarImage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FeishuMonitorCenterPage(
        client: _FakeShellClient(status: status),
        forwardingService: forwardingService ?? _FakeForwardingService(),
        forwardingSettingsStore:
            settingsStore ?? _MemoryForwardingSettingsStore(),
        loadTargetGroups: loadTargetGroups,
        pickRelayAvatarImage: pickRelayAvatarImage,
        uploadRelayAvatarImage: uploadRelayAvatarImage,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

FeishuMonitorShellStatus _onlineStatus({
  required DateTime probeObservedAt,
  required List<FeishuMonitorObservedConversation> observedConversations,
  required List<FeishuMonitorObservedMessage> observedMessages,
  required List<FeishuMonitorMessageEvent> recentEvents,
  String workerId = 'worker-1',
  int mediaQueueDepth = 0,
  int mediaQueueOldestWaitSeconds = 0,
  int mediaQueueEstimatedNextDelaySeconds = 0,
  String mediaQueueLastSkipReason = '',
  int messagesToday = 28,
  int deliveriesSucceededToday = 26,
  int deliveriesFailedToday = 2,
}) {
  return FeishuMonitorShellStatus(
    shellState: 'online',
    captureState: 'running',
    loginState: 'logged_in',
    hookState: 'healthy',
    runtimeUrl: 'https://feishu.cn/messenger',
    pageTitle: '消息 - 飞书',
    pageKind: 'messenger',
    webviewAvailable: true,
    shellMode: 'desktop_shell',
    queueDepth: 4,
    messagesToday: messagesToday,
    deliveriesSucceededToday: deliveriesSucceededToday,
    deliveriesFailedToday: deliveriesFailedToday,
    lastUpdatedAt: null,
    probeObservedAt: probeObservedAt,
    observedConversations: observedConversations,
    observedMessages: observedMessages,
    recentEvents: recentEvents,
    workerId: workerId,
    mediaQueueDepth: mediaQueueDepth,
    mediaQueueOldestWaitSeconds: mediaQueueOldestWaitSeconds,
    mediaQueueEstimatedNextDelaySeconds: mediaQueueEstimatedNextDelaySeconds,
    mediaQueueLastSkipReason: mediaQueueLastSkipReason,
    lastError: '',
  );
}

FeishuMonitorForwardingRoute _route({
  String id = 'route_1',
  bool enabled = true,
  String sourceConversationId = 'feed:alpha',
  String sourceConversationName = 'Project Phoenix',
  String sourceConversationType = 'group',
  String targetGroupId = 'wk_alpha',
  String targetGroupName = '悟空 Alpha 群',
  String workerId = '',
}) {
  return FeishuMonitorForwardingRoute(
    id: id,
    enabled: enabled,
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    sourceConversationType: sourceConversationType,
    targetGroupId: targetGroupId,
    targetGroupName: targetGroupName,
    workerId: workerId,
    createdAt: DateTime.parse('2026-05-09T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-09T01:00:00Z'),
  );
}

class _FakeShellClient extends FeishuMonitorShellClient {
  _FakeShellClient({required this.status});

  final FeishuMonitorShellStatus status;
  int startCaptureCount = 0;
  int stopCaptureCount = 0;
  int reloadRuntimeCount = 0;

  @override
  Future<FeishuMonitorShellStatus> fetchStatus() async => status;

  @override
  Future<void> startCapture() async {
    startCaptureCount += 1;
  }

  @override
  Future<void> stopCapture() async {
    stopCaptureCount += 1;
  }

  @override
  Future<void> reloadRuntime() async {
    reloadRuntimeCount += 1;
  }
}

class _MutableFakeShellClient extends FeishuMonitorShellClient {
  _MutableFakeShellClient({required this.first, required this.second});

  final FeishuMonitorShellStatus first;
  final FeishuMonitorShellStatus second;
  int _count = 0;

  @override
  Future<FeishuMonitorShellStatus> fetchStatus() async {
    _count += 1;
    return _count == 1 ? first : second;
  }
}

class _FakeForwardingService extends FeishuMonitorForwardingService {
  _FakeForwardingService() : super(sender: _NoopTextSender());

  FeishuMonitorForwardingSettings? lastSettings;
  List<FeishuMonitorMessageEvent> lastEvents =
      const <FeishuMonitorMessageEvent>[];

  @override
  Future<FeishuMonitorForwardingResult> forwardRoutedRecentEvents({
    required FeishuMonitorForwardingSettings settings,
    required List<FeishuMonitorMessageEvent> events,
  }) async {
    lastSettings = settings;
    lastEvents = List<FeishuMonitorMessageEvent>.from(events);
    return FeishuMonitorForwardingResult(
      sent: events.length,
      skippedUnmatched: 0,
      failed: 0,
    );
  }
}

class _FixedResultForwardingService extends FeishuMonitorForwardingService {
  _FixedResultForwardingService(this.result) : super(sender: _NoopTextSender());

  final FeishuMonitorForwardingResult result;

  @override
  Future<FeishuMonitorForwardingResult> forwardRoutedRecentEvents({
    required FeishuMonitorForwardingSettings settings,
    required List<FeishuMonitorMessageEvent> events,
  }) async {
    return result;
  }
}

class _FailingForwardingService extends FeishuMonitorForwardingService {
  _FailingForwardingService(this.error) : super(sender: _NoopTextSender());

  final Object error;

  @override
  Future<FeishuMonitorForwardingResult> forwardRoutedRecentEvents({
    required FeishuMonitorForwardingSettings settings,
    required List<FeishuMonitorMessageEvent> events,
  }) async {
    throw error;
  }
}

class _NoopTextSender implements FeishuMonitorTextSender {
  @override
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required FeishuMonitorImageAttachment image,
    FeishuMonitorRelayIdentity? relayIdentity,
  }) async {}

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    FeishuMonitorRelayIdentity? relayIdentity,
  }) async {}
}

class _MemoryForwardingSettingsStore
    implements FeishuMonitorForwardingSettingsStore {
  _MemoryForwardingSettingsStore({
    this.initial = const FeishuMonitorForwardingSettings(
      enabled: false,
      routes: <FeishuMonitorForwardingRoute>[],
      legacyTargetGroupId: '',
    ),
  });

  final FeishuMonitorForwardingSettings initial;
  FeishuMonitorForwardingSettings? saved;

  @override
  Future<FeishuMonitorForwardingSettings> load() async {
    return saved ?? initial;
  }

  @override
  Future<void> save(FeishuMonitorForwardingSettings settings) async {
    saved = settings;
  }
}
