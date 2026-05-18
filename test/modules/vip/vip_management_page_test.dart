import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/vip/vip_management_page.dart';

void main() {
  testWidgets('management page renders platform cards', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VipManagementPage()));
    await tester.pumpAndSettle();

    expect(find.byType(VipManagementPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('management-center-robot-config')),
      findsOneWidget,
    );
    expect(find.text('机器人配置'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('management-center-feishu')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('management-center-dingtalk')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('management-center-mengxia')),
      findsOneWidget,
    );
    expect(find.text('萌侠信息转发中心'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('management-center-juliang')),
      findsOneWidget,
    );
    expect(find.text('聚合信息转发中心'), findsOneWidget);

    expect(
      find.byKey(const ValueKey('management-center-xiaoe')),
      findsOneWidget,
    );
    expect(find.text('小鹅通信息转发中心'), findsOneWidget);
    expect(find.text('正常'), findsWidgets);
    expect(find.text('第一阶段'), findsNothing);
    expect(find.text('PoC 可用'), findsNothing);
    expect(find.text('无痕文本'), findsNothing);
  });

  testWidgets('management page opens robot config page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VipManagementPage(
          robotConfigBuilder: (_) =>
              const _FakeCenterPage(title: 'Robot config'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('management-center-robot-config')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Robot config'), findsOneWidget);
  });

  testWidgets('management page opens Feishu monitor center', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VipManagementPage(
          feishuCenterBuilder: (_) =>
              const _FakeCenterPage(title: 'Feishu center'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('management-center-feishu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Feishu center'), findsOneWidget);
  });

  testWidgets('management page opens DingTalk monitor center', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VipManagementPage(
          dingTalkCenterBuilder: (_) =>
              const _FakeCenterPage(title: 'DingTalk center'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('management-center-dingtalk')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('DingTalk center'), findsOneWidget);
  });

  testWidgets('management page opens Mengxia monitor center', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VipManagementPage(
          mengxiaCenterBuilder: (_) =>
              const _FakeCenterPage(title: 'Mengxia center'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('management-center-mengxia')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mengxia center'), findsOneWidget);
  });

  testWidgets('management page opens Juliang monitor center', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VipManagementPage(
          juliangCenterBuilder: (_) =>
              const _FakeCenterPage(title: 'Juliang center'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('management-center-juliang')),
      200,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('management-center-juliang')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('management-center-juliang')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Juliang center'), findsOneWidget);
  });

  testWidgets('management page opens Xiaoe monitor center', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VipManagementPage(
          xiaoeCenterBuilder: (_) =>
              const _FakeCenterPage(title: 'Xiaoe center'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('management-center-xiaoe')),
      200,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('management-center-xiaoe')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('management-center-xiaoe')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Xiaoe center'), findsOneWidget);
  });
}

class _FakeCenterPage extends StatelessWidget {
  const _FakeCenterPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(title)));
  }
}
