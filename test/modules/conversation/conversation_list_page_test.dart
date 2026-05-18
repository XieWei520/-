import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/providers/channel_provider.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/data/providers/user_provider.dart';
import 'package:wukong_im_app/modules/home/home_surface_kernel.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_item_loader.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';
import 'package:wukong_im_app/service/im/im_service.dart';
import 'package:wukong_im_app/widgets/liquid_glass_panel.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';
import 'package:wukong_im_app/widgets/wk_main_top_bar.dart';
import 'package:wukong_im_app/wukong_base/msg/msg_content_type.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test(
    'conversationKeyFor combines channel ID and type for workspace selection',
    () {
      final conversation = _buildConversation(
        channelId: 'u_9001',
        channelType: WKChannelType.personal,
        unreadCount: 0,
        lastMsgTimestamp: 0,
        clientMsgNo: 'client_9001',
      );

      expect(conversationKeyFor(conversation), 'u_9001:1');
    },
  );

  test(
    'conversationSelectionKeyFromRowKey converts only the first separator',
    () {
      expect(
        conversationSelectionKeyFromRowKey('2:group:alpha'),
        'group:alpha:2',
      );
    },
  );

  test('applyPatch keeps existing clientMsgNo identity', () {
    final notifier = ConversationNotifier.forTest(<WKUIConversationMsg>[
      _buildConversation(
        channelId: 'u_2001',
        channelType: WKChannelType.personal,
        unreadCount: 1,
        lastMsgTimestamp: 100,
        clientMsgNo: 'client_real_2001',
      ),
    ]);

    notifier.applyPatch(
      const ConversationPatch.unreadAndDigest(
        channelId: 'u_2001',
        channelType: WKChannelType.personal,
        unreadCount: 9,
        lastMessageDigest: 'digest_only_should_not_replace_client_msg_no',
        sortTimestamp: 999,
      ),
    );

    expect(notifier.state.single.clientMsgNo, 'client_real_2001');
  });

  test('applyPatch bootstrap does not write digest into clientMsgNo', () {
    final notifier = ConversationNotifier.forTest(
      const <WKUIConversationMsg>[],
    );

    notifier.applyPatch(
      const ConversationPatch.unreadAndDigest(
        channelId: 'u_3001',
        channelType: WKChannelType.personal,
        unreadCount: 2,
        lastMessageDigest: 'digest_for_projection_only',
        sortTimestamp: 200,
      ),
    );

    expect(notifier.state.single.clientMsgNo, isEmpty);
  });

  test(
    'refresh deletion keeps projection repository in sync with list state',
    () {
      final notifier = ConversationNotifier.forTest(<WKUIConversationMsg>[
        _buildConversation(
          channelId: 'u_4001',
          channelType: WKChannelType.personal,
          unreadCount: 1,
          lastMsgTimestamp: 1000,
          clientMsgNo: 'client_4001',
        ),
        _buildConversation(
          channelId: 'u_4002',
          channelType: WKChannelType.personal,
          unreadCount: 1,
          lastMsgTimestamp: 900,
          clientMsgNo: 'client_4002',
        ),
      ]);

      notifier.applyRefreshForTest(<WKUIConversationMsg>[
        WKUIConversationMsg()
          ..channelID = 'u_4001'
          ..channelType = WKChannelType.personal
          ..isDeleted = 1,
      ]);

      final stateKeys = notifier.state
          .map((item) => '${item.channelType}:${item.channelID}')
          .toList();

      expect(stateKeys, <String>['1:u_4002']);
      expect(notifier.projectionKeysForTest(), <String>['1:u_4002']);
    },
  );

  test('conversation preview prefers edited text from message extra', () {
    final message = WKMsg()
      ..contentType = WkMessageContentType.text
      ..content = 'edit-007'
      ..messageContent = WKTextContent('edit-007')
      ..wkMsgExtra = (WKMsgExtra()
        ..contentEdit = '{"type":1,"content":"edit-008"}'
        ..messageContent = WKTextContent('edit-008'));

    expect(resolveConversationPreviewText(message), 'edit-008');
  });

  test(
    'resolveConversationSendStatus suppresses stale sending when message already synced',
    () {
      final message = WKMsg()
        ..fromUID = 'u_self'
        ..status = WKSendMsgResult.sendLoading
        ..messageID = 'mid_synced_1';

      final status = resolveConversationSendStatus(
        message,
        currentUid: 'u_self',
      );

      expect(status.showSending, isFalse);
      expect(status.showSingleTick, isTrue);
      expect(status.showDoubleTick, isFalse);
      expect(status.showSendFailed, isFalse);
    },
  );

  test(
    'conversation item request key changes when cached message extra changes',
    () {
      final baseKey = buildConversationListItemRequestKey(
        channelId: 'u_revoke_preview',
        channelType: WKChannelType.personal,
        clientMsgNo: 'client-revoke-preview',
        unreadCount: 0,
        lastMsgTimestamp: 1777185200,
        lastMessageExtraDigest: '',
        refreshToken: 0,
      );
      final revokedKey = buildConversationListItemRequestKey(
        channelId: 'u_revoke_preview',
        channelType: WKChannelType.personal,
        clientMsgNo: 'client-revoke-preview',
        unreadCount: 0,
        lastMsgTimestamp: 1777185200,
        lastMessageExtraDigest: conversationMessageExtraDigest(
          WKMsgExtra()
            ..revoke = 1
            ..extraVersion = 2
            ..revoker = 'u_me',
        ),
        refreshToken: 0,
      );

      expect(revokedKey, isNot(baseKey));
    },
  );

  test('conversation preview prefixes robot display name for group messages', () {
    final message = WKMsg()
      ..contentType = WkMessageContentType.unknown
      ..content =
          '{"type":1,"content":"Daily weather","robot":{"provider":"feishu","display_name":"Weather Robot","display_avatar":"robots/weather/avatar.png"}}';

    expect(
      resolveConversationPreviewText(
        message,
        conversationChannelType: WKChannelType.group,
      ),
      'Weather Robot: Daily weather',
    );
  });

  test(
    'conversation preview does not prefix robot name for non-group messages',
    () {
      final message = WKMsg()
        ..contentType = WkMessageContentType.unknown
        ..content =
            '{"type":1,"content":"Daily weather","robot":{"provider":"feishu","display_name":"Weather Robot","display_avatar":"robots/weather/avatar.png"}}';

      expect(
        resolveConversationPreviewText(
          message,
          conversationChannelType: WKChannelType.personal,
        ),
        'Daily weather',
      );
    },
  );

  test(
    'conversation preview uses robot card plain_text and prefixes robot name in group chat',
    () {
      final message = WKMsg()
        ..contentType = MsgContentType.robotCard
        ..content =
            '{"type":22,"plain_text":"Daily weather summary","title":"Weather title","body":"Weather body","robot_name":"Weather Robot"}';

      expect(
        resolveConversationPreviewText(
          message,
          conversationChannelType: WKChannelType.group,
        ),
        'Weather Robot: Daily weather summary',
      );
    },
  );

  test(
    'conversation preview prefixes robot name and falls back to nested card title/body for raw robot card payload',
    () {
      final message = WKMsg()
        ..contentType = MsgContentType.robotCard
        ..content =
            '{"type":22,"robot":{"provider":"feishu","name":"Weather Robot"},"card":{"style":"showcase","title":"Robot title","body":"Robot body","link_url":"https://example.com","link_mode":"whole_card"}}';

      expect(
        resolveConversationPreviewText(
          message,
          conversationChannelType: WKChannelType.group,
        ),
        'Weather Robot: Robot title Robot body',
      );
    },
  );

  test('conversation preview robot card stays unprefixed in personal chat', () {
    final message = WKMsg()
      ..contentType = MsgContentType.robotCard
      ..content =
          '{"type":22,"plain_text":"Daily weather summary","title":"Weather title","body":"Weather body","robot_name":"Weather Robot"}';

    expect(
      resolveConversationPreviewText(
        message,
        conversationChannelType: WKChannelType.personal,
      ),
      'Daily weather summary',
    );
  });

  testWidgets('conversation list only rebuilds changed tile', (tester) async {
    final builds = <String, int>{};
    final container = ProviderContainer(
      overrides: [
        conversationProvider.overrideWith(
          (ref) => ConversationNotifier.forTest(<WKUIConversationMsg>[
            _buildConversation(
              channelId: 'u_1001',
              channelType: WKChannelType.personal,
              unreadCount: 1,
              lastMsgTimestamp: 1000,
              clientMsgNo: 'client_1001',
            ),
            _buildConversation(
              channelId: 'u_1002',
              channelType: WKChannelType.personal,
              unreadCount: 2,
              lastMsgTimestamp: 900,
              clientMsgNo: 'client_1002',
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: _ConversationListHarness(
            onTileBuild: (channelId) {
              builds[channelId] = (builds[channelId] ?? 0) + 1;
            },
          ),
        ),
      ),
    );

    expect(builds['u_1001'], 1);
    expect(builds['u_1002'], 1);

    container
        .read(conversationProvider.notifier)
        .applyPatch(
          const ConversationPatch.unreadAndDigest(
            channelId: 'u_1001',
            channelType: WKChannelType.personal,
            unreadCount: 9,
            lastMessageDigest: 'ping',
            sortTimestamp: 999,
          ),
        );
    await tester.pump();

    expect(builds['u_1001'], greaterThan(1));
    expect(builds['u_1002'], 1);
  });

  testWidgets('embedded conversation list uses liquid surface search chrome', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        conversationProvider.overrideWith(
          (ref) => ConversationNotifier.forTest(const <WKUIConversationMsg>[]),
        ),
        friendListProvider.overrideWith(
          (ref) => FriendListNotifier(loadOnInit: false),
        ),
        customerServiceConversationAccountsProvider.overrideWith(
          (ref) async => const [],
        ),
        myGroupListProvider.overrideWith(
          (ref) => MyGroupListNotifier(loadOnInit: false),
        ),
        homeSurfaceKernelProvider.overrideWithValue(HomeSurfaceKernel()),
        imServiceProvider.overrideWith(
          (ref) => _ConversationListTestIMService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SizedBox(
            width: 340,
            height: 640,
            child: ConversationListPage(embedded: true),
          ),
        ),
      ),
    );

    final embeddedMaterial = tester.widget<Material>(
      find.byKey(const ValueKey<String>('conversation-list-embedded')),
    );
    expect(embeddedMaterial.color, LiquidGlassColors.surfaceSolid);

    final searchBar = tester.widget<Container>(
      find.byKey(const ValueKey<String>('conversation-list-search-bar')),
    );
    final decoration = searchBar.decoration! as BoxDecoration;
    expect(decoration.color, LiquidGlassColors.surfaceSolid);
    expect(decoration.borderRadius, LiquidGlassRadii.pill);
    expect(decoration.border, Border.all(color: LiquidGlassColors.border));
    expect(
      find.byKey(const ValueKey<String>('conversation-list-liquid-header')),
      findsOneWidget,
    );
    expect(find.text('消息'), findsOneWidget);
    expect(find.byType(WKMainTopBar), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('conversation-list-liquid-top-menu')),
      findsOneWidget,
    );
    expect(find.byType(LiquidGlassPillButton), findsOneWidget);
  });

  testWidgets('embedded conversation list uses dark liquid surface chrome', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        conversationProvider.overrideWith(
          (ref) => ConversationNotifier.forTest(const <WKUIConversationMsg>[]),
        ),
        friendListProvider.overrideWith(
          (ref) => FriendListNotifier(loadOnInit: false),
        ),
        customerServiceConversationAccountsProvider.overrideWith(
          (ref) async => const [],
        ),
        myGroupListProvider.overrideWith(
          (ref) => MyGroupListNotifier(loadOnInit: false),
        ),
        homeSurfaceKernelProvider.overrideWithValue(HomeSurfaceKernel()),
        imServiceProvider.overrideWith(
          (ref) => _ConversationListTestIMService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const SizedBox(
            width: 340,
            height: 640,
            child: ConversationListPage(embedded: true),
          ),
        ),
      ),
    );

    final embeddedMaterial = tester.widget<Material>(
      find.byKey(const ValueKey<String>('conversation-list-embedded')),
    );
    expect(embeddedMaterial.color, LiquidGlassColors.darkSurfaceSolid);

    final searchBar = tester.widget<Container>(
      find.byKey(const ValueKey<String>('conversation-list-search-bar')),
    );
    final decoration = searchBar.decoration! as BoxDecoration;
    expect(decoration.color, LiquidGlassColors.darkSurfaceSolid);
    expect(decoration.border, Border.all(color: LiquidGlassColors.darkBorder));

    final headerTitle = tester.widget<Text>(find.text('消息'));
    expect(headerTitle.style?.color, LiquidGlassColors.darkText);

    final searchHint = tester.widget<Text>(find.text('搜索'));
    expect(searchHint.style?.color, LiquidGlassColors.darkTextSecondary);

    final headerIcon = tester.widget<Icon>(find.byIcon(Icons.add_rounded).last);
    expect(headerIcon.color, LiquidGlassColors.darkText);

    expect(
      find.byKey(const ValueKey<String>('conversation-list-liquid-top-menu')),
      findsOneWidget,
    );
  });

  testWidgets('embedded conversation header disables title switch motion', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        conversationProvider.overrideWith(
          (ref) => ConversationNotifier.forTest(const <WKUIConversationMsg>[]),
        ),
        friendListProvider.overrideWith(
          (ref) => FriendListNotifier(loadOnInit: false),
        ),
        customerServiceConversationAccountsProvider.overrideWith(
          (ref) async => const [],
        ),
        myGroupListProvider.overrideWith(
          (ref) => MyGroupListNotifier(loadOnInit: false),
        ),
        homeSurfaceKernelProvider.overrideWithValue(HomeSurfaceKernel()),
        imServiceProvider.overrideWith(
          (ref) => _ConversationListTestIMService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SizedBox(
              width: 340,
              height: 640,
              child: ConversationListPage(embedded: true),
            ),
          ),
        ),
      ),
    );

    final switcher = tester.widget<AnimatedSwitcher>(
      find.byKey(
        const ValueKey<String>('conversation-list-liquid-title-switcher'),
      ),
    );
    expect(switcher.duration, Duration.zero);
  });

  testWidgets(
    'embedded conversation list uses readable selection header copy',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          conversationProvider.overrideWith(
            (ref) => ConversationNotifier.forTest(<WKUIConversationMsg>[
              _buildConversation(
                channelId: 'u_selectable',
                channelType: WKChannelType.personal,
                unreadCount: 0,
                lastMsgTimestamp: 1000,
                clientMsgNo: 'client_selectable',
              ),
            ]),
          ),
          friendListProvider.overrideWith(
            (ref) => FriendListNotifier(loadOnInit: false),
          ),
          customerServiceConversationAccountsProvider.overrideWith(
            (ref) async => const [],
          ),
          myGroupListProvider.overrideWith(
            (ref) => MyGroupListNotifier(loadOnInit: false),
          ),
          homeSurfaceKernelProvider.overrideWithValue(HomeSurfaceKernel()),
          imServiceProvider.overrideWith(
            (ref) => _ConversationListTestIMService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SizedBox(
              width: 340,
              height: 640,
              child: ConversationListPage(embedded: true),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('conversation-list-liquid-top-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.playlist_add_check_circle_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('u_selectable'));
      await tester.pumpAndSettle();

      expect(find.text('\u5DF2\u9009\u62E9 1 \u9879'), findsOneWidget);
      expect(find.byTooltip('\u53D6\u6D88\u9009\u62E9'), findsOneWidget);
      expect(
        find.byTooltip('\u5220\u9664\u6240\u9009\u4F1A\u8BDD'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('conversation-list-liquid-top-menu')),
        findsNothing,
      );
    },
  );
}

class _ConversationListHarness extends ConsumerWidget {
  const _ConversationListHarness({required this.onTileBuild});

  final ValueChanged<String> onTileBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowKeys = ref.watch(conversationRowOrderProvider);
    return Column(
      children: [
        for (final rowKey in rowKeys)
          _ConversationTileProbe(
            key: ValueKey<String>('row_$rowKey'),
            rowKey: rowKey,
            onTileBuild: onTileBuild,
          ),
      ],
    );
  }
}

class _ConversationTileProbe extends ConsumerWidget {
  const _ConversationTileProbe({
    super.key,
    required this.rowKey,
    required this.onTileBuild,
  });

  final String rowKey;
  final ValueChanged<String> onTileBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref.watch(conversationRowProvider(rowKey));
    final channelId = conversation?.channelID ?? '';
    if (channelId.isNotEmpty) {
      onTileBuild(channelId);
    }
    return Text(channelId, textDirection: TextDirection.ltr);
  }
}

WKUIConversationMsg _buildConversation({
  required String channelId,
  required int channelType,
  required int unreadCount,
  required int lastMsgTimestamp,
  required String clientMsgNo,
}) {
  return WKUIConversationMsg()
    ..channelID = channelId
    ..channelType = channelType
    ..unreadCount = unreadCount
    ..lastMsgTimestamp = lastMsgTimestamp
    ..clientMsgNo = clientMsgNo;
}

class _ConversationListTestIMService extends IMService {
  _ConversationListTestIMService()
    : super(
        realtimeRolloutTelemetry: RealtimeRolloutTelemetry(
          flushInterval: Duration.zero,
        ),
      );

  @override
  Future<bool> init() async => true;

  @override
  void disconnect({bool isLogout = false}) {}
}
