import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/launch_policy/launch_policy_dialogs.dart';
import 'package:wukong_im_app/modules/launch_policy/launch_policy_models.dart';

void main() {
  testWidgets('forced upgrade dialog shows one update action', (tester) async {
    final launched = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showForcedUpgradeDialog(
                  context,
                  policy: const VersionPolicy(
                    platform: LaunchPlatform.windows,
                    latestVersion: '1.3.0',
                    latestBuild: 130,
                    minimumVersion: '1.2.0',
                    minimumBuild: 120,
                    forceUpgrade: true,
                    updateUrl: 'https://example.com/windows',
                    title: '必须更新',
                    message: '当前版本已不可用',
                  ),
                  launchExternalUrl: (uri) async {
                    launched.add(uri);
                    return true;
                  },
                );
              },
              child: const Text('show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('必须更新'), findsOneWidget);
    expect(find.text('当前版本已不可用'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
    expect(find.text('关闭'), findsNothing);

    await tester.tap(find.text('立即更新'));
    await tester.pump();

    expect(launched.single.toString(), 'https://example.com/windows');
  });

  testWidgets('startup notice dialog renders text and image', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showStartupNoticeDialog(
                  context,
                  notice: const StartupNotice(
                    id: 'notice-1',
                    title: '系统通知',
                    content: '欢迎使用新版本',
                    imageUrl: 'https://example.com/notice.png',
                    frequency: StartupNoticeFrequency.everyStart,
                  ),
                );
              },
              child: const Text('show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('系统通知'), findsOneWidget);
    expect(find.text('欢迎使用新版本'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}
