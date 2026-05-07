import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_scan_join_page.dart';

void main() {
  group('GroupScanJoinPage', () {
    testWidgets('loads and renders group info with join action', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GroupScanJoinPage(
            groupNo: 'g_1001',
            authCode: 'auth_123',
            loadGroupInfo: (groupNo) async =>
                GroupInfo(groupNo: 'g_1001', name: 'Alpha Group', invite: 0),
            joinGroup: (groupNo, authCode) async {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('Alpha Group'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('group_scan_join_primary_button')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('invite-only groups show explanatory disabled state', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GroupScanJoinPage(
            groupNo: 'g_1001',
            authCode: 'auth_123',
            loadGroupInfo: (groupNo) async =>
                GroupInfo(groupNo: 'g_1001', name: 'Invite Only', invite: 1),
            joinGroup: (groupNo, authCode) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('group_scan_join_invite_only_hint')),
        findsOneWidget,
      );
      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('group_scan_join_primary_button')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('join success navigates into chat destination', (tester) async {
      var joined = false;

      await tester.pumpWidget(
        MaterialApp(
          home: GroupScanJoinPage(
            groupNo: 'g_1001',
            authCode: 'auth_123',
            loadGroupInfo: (groupNo) async =>
                GroupInfo(groupNo: 'g_1001', name: 'Alpha Group', invite: 0),
            joinGroup: (groupNo, authCode) async {
              joined = true;
            },
            buildChatPage: (groupNo) => _MarkerPage(label: 'chat:$groupNo'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('group_scan_join_primary_button')),
      );
      await tester.pumpAndSettle();

      expect(joined, isTrue);
      expect(find.text('chat:g_1001'), findsOneWidget);
    });

    testWidgets('join rejection stays retryable and succeeds on retry', (
      tester,
    ) async {
      var joinAttempts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: GroupScanJoinPage(
            groupNo: 'g_1001',
            authCode: 'auth_123',
            loadGroupInfo: (groupNo) async =>
                GroupInfo(groupNo: 'g_1001', name: 'Alpha Group', invite: 0),
            joinGroup: (groupNo, authCode) async {
              joinAttempts += 1;
              if (joinAttempts == 1) {
                throw Exception('scan join rejected');
              }
            },
            buildChatPage: (groupNo) => _MarkerPage(label: 'chat:$groupNo'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('group_scan_join_primary_button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('group_scan_join_error_text')),
        findsOne,
      );
      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('group_scan_join_primary_button')),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(
        find.byKey(const ValueKey('group_scan_join_primary_button')),
      );
      await tester.pumpAndSettle();

      expect(joinAttempts, 2);
      expect(find.text('chat:g_1001'), findsOneWidget);
    });
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
