import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/monitor/feishu_monitor_center_page.dart';
import 'package:wukong_im_app/modules/vip/vip_management_page.dart';

void main() {
  testWidgets('management page renders platform-specific monitor centers', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: VipManagementPage()));
    await tester.pumpAndSettle();

    expect(find.text('管理系统'), findsWidgets);
    expect(find.text('飞书信息监控中心'), findsOneWidget);
    expect(find.text('同步飞书 Web 群消息到悟空 IM 群'), findsOneWidget);
    expect(find.text('钉钉信息监控中心'), findsOneWidget);
    expect(find.text('即将上线'), findsNWidgets(2));
    expect(find.text('小鹅通信息监控中心'), findsOneWidget);
  });

  testWidgets('management page opens Feishu monitor center', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VipManagementPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('management-center-feishu')));
    await tester.pumpAndSettle();

    expect(find.byType(FeishuMonitorCenterPage), findsOneWidget);
  });

  testWidgets(
    'Feishu monitor center opened from management wires local Agent browser actions',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VipManagementPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('management-center-feishu')));
      await tester.pumpAndSettle();

      final page = tester.widget<FeishuMonitorCenterPage>(
        find.byType(FeishuMonitorCenterPage),
      );
      expect(page.onBindLocalAgent, isNotNull);
      expect(page.onOpenBrowserLogin, isNotNull);
      expect(page.onCheckBrowserStatus, isNotNull);
      expect(page.onClearBrowserProfile, isNotNull);
      expect(page.onListenOnce, isNotNull);
      expect(page.onRefreshAgentStatus, isNotNull);
      expect(page.loadFeishuChats, isNotNull);
    },
  );
}
