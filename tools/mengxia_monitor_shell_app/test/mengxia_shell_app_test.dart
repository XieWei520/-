import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mengxia_monitor_shell_app/main.dart';

void main() {
  testWidgets('info UI uses the product name without showing the runtime URL', (
    tester,
  ) async {
    await tester.pumpWidget(const MengxiaMonitorShellApp());

    expect(find.text('MX信息监控'), findsOneWidget);
    expect(find.textContaining(defaultMengxiaRuntimeUrl), findsNothing);
    expect(find.textContaining('mx.2026.naaifu.cn'), findsNothing);
  });

  testWidgets('runtime UI states manual login is required every launch', (
    tester,
  ) async {
    await tester.pumpWidget(const MengxiaMonitorShellApp());

    expect(
      find.textContaining('Manual login is required every launch'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'No cookies, localStorage, history, profile, or session directory are reused',
      ),
      findsOneWidget,
    );
  });

  testWidgets('info UI says manual wheel scrolling is available', (
    tester,
  ) async {
    await tester.pumpWidget(const MengxiaMonitorShellApp());

    expect(find.textContaining('可使用鼠标滚轮滚动群列表和消息区'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
  });

  testWidgets('info UI explains configured source cycling', (tester) async {
    await tester.pumpWidget(const MengxiaMonitorShellApp());

    expect(find.textContaining('轮询已配置且页面可点击的萌侠来源'), findsOneWidget);
  });
}
