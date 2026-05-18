import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wukong_im_app/core/config/app_config.dart';
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

  testWidgets('about page shows the Android system-team avatar', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutPage()));
    await tester.pumpAndSettle();

    expect(find.byType(WKSubPageScaffold), findsOneWidget);
    expect(
      find.byKey(const ValueKey('about-system-team-avatar')),
      findsOneWidget,
    );
    expect(find.byType(WKAvatar), findsOneWidget);
  });

  testWidgets('about page hides legacy executable name behind brand name', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'wukong_im_app',
      packageName: 'com.example.wukong',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'test',
    );

    await tester.pumpWidget(const MaterialApp(home: AboutPage()));
    await tester.pumpAndSettle();

    expect(find.text(AppConfig.appName), findsOneWidget);
    expect(find.text('wukong_im_app'), findsNothing);
  });

  testWidgets('about page does not show the web ICP filing number', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutPage()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('\u6e58ICP\u59072026016828\u53f7'),
      findsNothing,
    );
    expect(find.textContaining('?ICP?2026016828?'), findsNothing);
    expect(
      find.textContaining('\u6caaICP\u59072026016828\u53f7'),
      findsNothing,
    );
  });

  testWidgets('about page footer does not overflow on narrow screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AboutPage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('about-legal-link')),
      findsNothing,
    );
    expect(find.textContaining('Copyright'), findsOneWidget);
  });
}
