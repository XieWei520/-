import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/user/set_user_remark_page.dart';

void main() {
  Widget wrapWithApp(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets(
    'set user remark page matches Android shell and hides confirm until changed',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const SetUserRemarkPage(uid: 'u_alice', initialValue: 'Alice'),
        ),
      );

      expect(find.byType(WKSubPageScaffold), findsOneWidget);
      expect(find.text('设置备注'), findsOneWidget);
      expect(find.byKey(const ValueKey('set_user_remark_input')), findsOneWidget);
      expect(find.text('确定'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('set_user_remark_input')),
        'Alice备注',
      );
      await tester.pump();

      expect(find.text('确定'), findsOneWidget);
    },
  );

  testWidgets('set user remark page uses Android confirm action', (tester) async {
    String? savedRemark;

    await tester.pumpWidget(
      wrapWithApp(
        SetUserRemarkPage(
          uid: 'u_alice',
          initialValue: 'Alice',
          onSave: (value) async {
            savedRemark = value;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('set_user_remark_input')),
      '新的备注',
    );
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(savedRemark, '新的备注');
  });
}
