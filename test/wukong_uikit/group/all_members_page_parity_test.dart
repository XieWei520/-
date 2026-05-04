import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/group/all_members_page.dart';

void main() {
  testWidgets(
    'all members page uses Android shell and shows member count in title',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AllMembersPage(
            channelId: 'group_demo',
            autoLoad: false,
            initialMembers: [
              GroupMember(
                groupNo: 'group_demo',
                uid: 'u_1',
                name: '\u5f20\u4e09',
                role: 0,
              ),
              GroupMember(
                groupNo: 'group_demo',
                uid: 'u_2',
                name: '\u674e\u56db',
                role: 0,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(WKSubPageScaffold), findsOneWidget);
      expect(find.text('\u7fa4\u6210\u5458(2)'), findsOneWidget);
      expect(find.text('鎼滅储'), findsOneWidget);
    },
  );

  testWidgets('all members page shows owner and manager role chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AllMembersPage(
          channelId: 'group_demo',
          autoLoad: false,
          initialMembers: [
            GroupMember(
              groupNo: 'group_demo',
              uid: 'u_owner',
              name: '\u7fa4\u4e3bA',
              role: 1,
            ),
            GroupMember(
              groupNo: 'group_demo',
              uid: 'u_admin',
              name: '\u7ba1\u7406B',
              role: 2,
            ),
          ],
        ),
      ),
    );

    expect(find.text('\u7fa4\u4e3b'), findsOneWidget);
    expect(find.text('\u7ba1\u7406\u5458'), findsOneWidget);
  });
}
