import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/group/delete_group_members_page.dart';

void main() {
  testWidgets('delete group members page matches Android shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeleteGroupMembersPage(
          groupId: 'g_demo',
          members: [
            GroupMember(groupNo: 'g_demo', uid: 'u1', name: '成员A'),
            GroupMember(groupNo: 'g_demo', uid: 'u2', name: '成员B'),
          ],
        ),
      ),
    );

    expect(find.byType(WKSubPageScaffold), findsOneWidget);
    expect(find.text('删除群成员'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.textContaining('删除('), findsNothing);
  });

  testWidgets(
    'delete group members page updates delete count after selection',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeleteGroupMembersPage(
            groupId: 'g_demo',
            members: [
              GroupMember(groupNo: 'g_demo', uid: 'u1', name: '成员A'),
              GroupMember(groupNo: 'g_demo', uid: 'u2', name: '成员B'),
            ],
          ),
        ),
      );

      await tester.tap(find.text('成员A'));
      await tester.pump();

      expect(find.text('删除(1)'), findsOneWidget);
      expect(find.text('成员A'), findsAtLeastNWidgets(1));
    },
  );
}
