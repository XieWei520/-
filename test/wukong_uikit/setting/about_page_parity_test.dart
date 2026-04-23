import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/setting/about_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'WuKongIM',
      packageName: 'com.example.wukong',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'test',
    );
  });

  testWidgets('about page shows the Android system-team avatar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutPage()));
    await tester.pumpAndSettle();

    expect(find.byType(WKSubPageScaffold), findsOneWidget);
    expect(find.byKey(const ValueKey('about-system-team-avatar')), findsOneWidget);
    expect(find.byType(WKAvatar), findsOneWidget);
  });
}
