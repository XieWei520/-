import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/app_config.dart';
import 'package:wukong_im_app/core/utils/qr_export_utils.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_qr_page.dart';
import 'package:wukong_im_app/wukong_uikit/user/user_qr_page.dart';

void main() {
  testWidgets('user qr page builds with provided qr data', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UserQrPage(
          qrData: 'http://103.207.68.33:8090/v1/qrcode/vercode_demo',
          username: '测试用户',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试用户'), findsOneWidget);
    expect(find.byType(WKSubPageScaffold), findsOneWidget);
    expect(find.text('扫一扫上面的二维码图案，加我${AppConfig.appName}'), findsOneWidget);
  });

  test('group qr page and export utility compile', () {
    expect(const GroupQrPage(groupId: 'g_demo'), isA<GroupQrPage>());
    expect(QrExportUtils.saveQrCodeAsPng, isA<Function>());
  });

  testWidgets('group qr page uses Android sub page scaffold shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: GroupQrPage(groupId: 'g_demo', autoLoad: false)),
    );

    expect(find.byType(WKSubPageScaffold), findsOneWidget);
  });
}
