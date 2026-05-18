import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/panes/chat_header_pane.dart';
import 'package:wukong_im_app/modules/vip/vip_badge.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';

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
}
