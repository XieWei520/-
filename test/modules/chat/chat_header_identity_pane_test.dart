import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/data/models/chat_session.dart';
import 'package:wukong_im_app/modules/chat/panes/chat_header_pane.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_search_mode_bar.dart';
import 'package:wukong_im_app/modules/vip/vip_badge.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  setUp(() {
    WKAvatar.setBytesLoaderForTesting((_) async => null);
  });

  tearDown(() {
    WKAvatar.setBytesLoaderForTesting(null);
  });

  testWidgets('renders production chat header identity content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: ChatHeaderIdentityPane(
              title: 'VIP Alice',
              subtitle: '手机在线',
              secondarySubtitle: '正在输入',
              avatarUrl: 'https://example.com/avatar.png',
              isGroup: false,
              avatarSize: 40,
              primaryColor: Colors.black,
              secondaryColor: Colors.grey,
              vipLevel: 1,
              tags: const <Widget>[
                Text(
                  '官方',
                  key: ValueKey<String>('chat-header-test-official-tag'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ChatHeaderIdentityPane), findsOneWidget);
    expect(find.byType(WKAvatar), findsOneWidget);
    expect(find.byType(VipBadge), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('chat-header-vip-badge')),
      findsOneWidget,
    );
    expect(find.text('VIP Alice'), findsOneWidget);
    expect(find.text('手机在线'), findsOneWidget);
    expect(find.text('正在输入'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('chat-header-test-official-tag')),
      findsOneWidget,
    );
  });

  testWidgets('omits optional subtitle row and vip badge when absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const ChatHeaderIdentityPane(
              title: 'Alice',
              avatarSize: 40,
              primaryColor: Colors.black,
              secondaryColor: Colors.grey,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Alice'), findsOneWidget);
    expect(find.byType(WKAvatar), findsOneWidget);
    expect(find.byType(VipBadge), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('chat-header-vip-badge')),
      findsNothing,
    );
  });

  testWidgets('production chat header pane owns app bar chrome', (
    tester,
  ) async {
    final session = ChatSession(
      channelId: 'u_alice',
      channelType: WKChannelType.personal,
    );
    var openedSearch = false;
    var openedDetails = false;
    var changedKeyword = '';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return Scaffold(
                appBar: ChatHeaderPane(
                  session: session,
                  state: const ChatHeaderPaneState(
                    title: 'Alice',
                    subtitle: 'mobile online',
                    showSearchAction: true,
                  ),
                  productionChrome: true,
                  useLiquidShell: true,
                  onOpenSearch: () {
                    openedSearch = true;
                    ref
                        .read(
                          chatSearchModeControllerProvider(session).notifier,
                        )
                        .open(anchorOrderSeq: 7);
                  },
                  onSearchKeywordChanged: (value) {
                    changedKeyword = value;
                  },
                  onCloseSearch: () {
                    ref
                        .read(
                          chatSearchModeControllerProvider(session).notifier,
                        )
                        .close();
                  },
                  onOpenDetails: () {
                    openedDetails = true;
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('chat-back-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-open-search')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-open-more')),
      findsOneWidget,
    );
    expect(find.byType(ChatHeaderIdentityPane), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('chat-open-more')));
    expect(openedDetails, isTrue);

    await tester.tap(find.byKey(const ValueKey<String>('chat-open-search')));
    await tester.pump();

    expect(openedSearch, isTrue);
    expect(find.byType(ChatSearchModeBar), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hello');
    expect(changedKeyword, 'hello');
  });

  test('resolves fixed Android chat header identity', () {
    final state = resolveChatHeaderPaneState(
      channelId: 'fileHelper',
      channelType: WKChannelType.personal,
      channelName: 'Temporary Alias',
      initialVipLevel: 1,
      friends: <Friend>[
        Friend(uid: 'fileHelper', name: 'File Helper', vipLevel: 1),
      ],
      showSearchAction: true,
    );

    expect(state.title, '\u6587\u4ef6\u4f20\u8f93\u52a9\u624b');
    expect(state.vipLevel, 0);
    expect(state.subtitle, isNull);
    expect(isAndroidFixedChat('fileHelper', WKChannelType.personal), isTrue);
  });

  test('resolves personal online vip and category tags', () {
    final channel = WKChannel('u_vip', WKChannelType.personal)
      ..channelName = 'VIP Alice'
      ..avatar = 'https://example.com/a.png'
      ..online = 1
      ..category = 'customerService'
      ..robot = 1;

    final state = resolveChatHeaderPaneState(
      channelId: 'u_vip',
      channelType: WKChannelType.personal,
      channelName: 'Fallback Alice',
      channelCategory: 'system',
      channel: channel,
      initialVipLevel: 0,
      friends: <Friend>[Friend(uid: 'u_vip', vipLevel: 1)],
      showSearchAction: true,
    );

    expect(state.title, 'VIP Alice');
    expect(state.avatarUrl, 'https://example.com/a.png');
    expect(state.vipLevel, 1);
    expect(state.subtitle, '\u624b\u673a\u5728\u7ebf');
    expect(
      state.tagWidgets
          .where(
            (widget) =>
                widget.key ==
                const ValueKey<String>('chat-header-customer-service-badge'),
          )
          .length,
      1,
    );
    expect(
      state.tagWidgets
          .whereType<ChatHeaderTag>()
          .map((tag) => tag.label)
          .toList(),
      contains('\u673a\u5668\u4eba'),
    );
  });

  test('resolves group member and online subtitles', () {
    final channel = WKChannel('g_demo', WKChannelType.group)
      ..channelName = 'Demo Group'
      ..remoteExtraMap = <String, dynamic>{
        'member_count': '32',
        'onlineCount': 5,
      };

    final state = resolveChatHeaderPaneState(
      channelId: 'g_demo',
      channelType: WKChannelType.group,
      channelName: 'Fallback Group',
      channel: channel,
      initialVipLevel: 1,
      friends: <Friend>[Friend(uid: 'g_demo', vipLevel: 1)],
      showSearchAction: false,
    );

    expect(state.title, 'Demo Group');
    expect(state.vipLevel, 0);
    expect(state.subtitle, '32\u4e2a\u6210\u5458');
    expect(state.secondarySubtitle, '5\u4eba\u5728\u7ebf');
    expect(state.isGroup, isTrue);
    expect(state.showSearchAction, isFalse);
  });
}
