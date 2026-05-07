import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/wukong_scan/scan_result_page.dart';
import 'package:wukong_im_app/wukong_scan/scan_service.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_detail_page.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ScanResultPage group flow', () {
    test('default group chat destination is ChatPage', () {
      final destination = buildDefaultScanGroupChatPage('g_1001');

      expect(destination, isA<ChatPage>());
      final page = destination as ChatPage;
      expect(page.channelId, 'g_1001');
      expect(page.channelType, WKChannelType.group);
    });

    testWidgets('native group result opens chat for active members', (
      tester,
    ) async {
      final result = ScanServiceResult.fromJson({
        'forward': 'native',
        'type': 'group',
        'data': {'group_no': 'g_1001'},
      }, 'raw-content');

      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultPage(
            result: result,
            resolveGroupMember: (_) async => WKChannelMember()..isDeleted = 0,
            buildChatPage: (groupNo) => _MarkerPage(label: 'chat:$groupNo'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('scan_group_chat_button')));
      await tester.pumpAndSettle();

      expect(find.text('chat:g_1001'), findsOneWidget);
    });

    testWidgets(
      'native group result still opens chat when local membership cache is missing',
      (tester) async {
        final result = ScanServiceResult.fromJson({
          'forward': 'native',
          'type': 'group',
          'data': {'group_no': 'g_1001'},
        }, 'raw-content');

        await tester.pumpWidget(
          MaterialApp(
            home: ScanResultPage(
              result: result,
              resolveGroupMember: (_) async => null,
              buildChatPage: (groupNo) => _MarkerPage(label: 'chat:$groupNo'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('scan_group_chat_button')));
        await tester.pumpAndSettle();

        expect(find.text('chat:g_1001'), findsOneWidget);
      },
    );

    testWidgets(
      'removed members see disabled state and never route to GroupDetailPage',
      (tester) async {
        final result = ScanServiceResult.fromJson({
          'forward': 'native',
          'type': 'group',
          'data': {'group_no': 'g_1001'},
        }, 'raw-content');

        await tester.pumpWidget(
          MaterialApp(
            home: ScanResultPage(
              result: result,
              resolveGroupMember: (_) async => WKChannelMember()..isDeleted = 1,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('scan_group_removed_hint')), findsOne);
        expect(find.byType(GroupDetailPage), findsNothing);

        final button = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('scan_group_chat_button')),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'internal join-group urls route to native join-confirm page instead of link utility',
      (tester) async {
        final base = Uri.parse(ApiConfig.baseUrl);
        final joinUri = Uri(
          scheme: base.scheme,
          host: base.host,
          port: base.hasPort ? base.port : null,
          path: '/join_group.html',
          queryParameters: const {
            'group_no': 'g_1001',
            'auth_code': 'auth_123',
          },
        );

        final result = ScanServiceResult.fromJson({
          'forward': 'h5',
          'type': 'webview',
          'data': {'url': joinUri.toString()},
        }, joinUri.toString());

        await tester.pumpWidget(
          MaterialApp(
            home: ScanResultPage(
              result: result,
              buildGroupScanJoinPage: (groupNo, authCode) =>
                  _MarkerPage(label: 'join:$groupNo:$authCode'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('scan_open_link_button')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('scan_copy_link_button')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const ValueKey('scan_internal_join_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('join:g_1001:auth_123'), findsOneWidget);
      },
    );

    testWidgets(
      'generic web urls open an in-app webview page as primary flow',
      (tester) async {
        final result = ScanServiceResult.fromJson({
          'forward': 'h5',
          'type': 'webview',
          'data': {'url': 'https://example.com/docs'},
        }, 'https://example.com/docs');
        Uri? launchedUri;

        await tester.pumpWidget(
          MaterialApp(
            home: ScanResultPage(
              result: result,
              buildWebviewPage: (url) => _MarkerPage(label: 'webview:$url'),
              launchUrlExternally: (uri) async {
                launchedUri = uri;
                return true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('scan_open_in_app_button')), findsOne);
        expect(find.byKey(const ValueKey('scan_open_link_button')), findsOne);

        await tester.tap(find.byKey(const ValueKey('scan_open_in_app_button')));
        await tester.pumpAndSettle();

        expect(find.text('webview:https://example.com/docs'), findsOneWidget);
        expect(launchedUri, isNull);
      },
    );
  });
}

class _MarkerPage extends StatelessWidget {
  final String label;

  const _MarkerPage({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
