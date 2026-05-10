import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_center_page.dart';
import 'package:wukong_im_app/modules/vip/vip_management_page.dart';

void main() {
  testWidgets('management page renders platform cards', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VipManagementPage()));
    await tester.pumpAndSettle();

    expect(find.byType(VipManagementPage), findsOneWidget);
    expect(find.byKey(const ValueKey('management-center-feishu')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('management-center-dingtalk')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('management-center-xiaoe')), findsOneWidget);
  });

  testWidgets('management page opens Feishu monitor center', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VipManagementPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('management-center-feishu')));
    await tester.pumpAndSettle();

    expect(find.byType(FeishuMonitorCenterPage), findsOneWidget);
  });
}
