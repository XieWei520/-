import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_notice_page.dart';

void main() {
  testWidgets(
    'group notice page uses Android shell and save action when editable',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GroupNoticePage(
            groupId: 'g_demo',
            initialNotice: '测试公告',
            canEdit: true,
          ),
        ),
      );

      expect(find.byType(WKSubPageScaffold), findsOneWidget);
      expect(find.text('群公告'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    },
  );

  testWidgets('group notice page shows manager-only hint when read only', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GroupNoticePage(
          groupId: 'g_demo',
          initialNotice: '测试公告',
          canEdit: false,
        ),
      ),
    );

    expect(find.text('只有群主及管理员可以编辑'), findsOneWidget);
    expect(find.text('保存'), findsNothing);
  });
}
