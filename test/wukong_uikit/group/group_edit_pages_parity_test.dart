import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_remark_page.dart';
import 'package:wukong_im_app/wukong_uikit/group/update_group_name_page.dart';

void main() {
  testWidgets('update group name page matches Android shell', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UpdateGroupNamePage(groupId: 'g_demo', initialName: '项目群'),
      ),
    );

    expect(find.byType(WKSubPageScaffold), findsOneWidget);
    expect(find.text('群名片'), findsOneWidget);
    expect(find.text('群聊名称'), findsAtLeastNWidgets(1));
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('项目群'), findsOneWidget);
  });

  testWidgets('group remark page matches Android structure and disabled save', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GroupRemarkPage(
          groupId: 'g_demo',
          groupName: '项目群',
          initialRemark: '原备注',
        ),
      ),
    );

    expect(find.byType(WKSubPageScaffold), findsOneWidget);
    expect(find.text('备注'), findsAtLeastNWidgets(1));
    expect(find.text('群聊的备注仅自己可见'), findsOneWidget);
    expect(find.text('项目群'), findsOneWidget);
    expect(find.text('填入'), findsOneWidget);

    final saveButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('group remark page fills group name and enables save', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GroupRemarkPage(
          groupId: 'g_demo',
          groupName: '项目群',
          initialRemark: '',
        ),
      ),
    );

    await tester.tap(find.text('填入'));
    await tester.pump();

    expect(find.text('项目群'), findsAtLeastNWidgets(2));

    final saveButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(saveButton.onPressed, isNotNull);
  });
}
