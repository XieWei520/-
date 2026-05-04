import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wukong_im_app/core/config/app_config.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/user/user_qr_page.dart';

void main() {
  Widget wrapWithApp(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('user qr page matches Android centered card shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        const UserQrPage(
          qrData: 'https://example.com/u_self',
          username: 'Alice',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final avatar = tester.widget<WKAvatar>(find.byType(WKAvatar));

    expect(find.byType(WKSubPageScaffold), findsOneWidget);
    expect(find.text('我的二维码'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('扫一扫上面的二维码图案，加我${AppConfig.appName}'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(avatar.size, 60);
    expect(find.text('保存二维码图片'), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.byIcon(Icons.copy_all_outlined), findsNothing);
    expect(find.byIcon(Icons.copy), findsNothing);
  });

  testWidgets('user qr page exposes Android save-only more menu', (
    tester,
  ) async {
    Uint8List? savedBytes;

    await tester.pumpWidget(
      wrapWithApp(
        UserQrPage(
          qrData: 'https://example.com/u_self',
          username: 'Alice',
          onSaveCardBytes: (bytes) async {
            savedBytes = bytes;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('user_qr_more_action')));
    await tester.pumpAndSettle();

    expect(find.text('保存到本地'), findsOneWidget);
    expect(find.text('复制二维码内容'), findsNothing);

    await tester.tap(find.text('保存到本地'));
    await tester.pumpAndSettle();

    expect(savedBytes, isNotNull);
    expect(savedBytes, isNotEmpty);
  });
}
