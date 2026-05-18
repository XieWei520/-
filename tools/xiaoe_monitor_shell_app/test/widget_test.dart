import 'package:flutter_test/flutter_test.dart';

import 'package:xiaoe_monitor_shell_app/main.dart';

void main() {
  testWidgets('shell info home explains manual target-page workflow', (
    tester,
  ) async {
    await tester.pumpWidget(const XiaoeMonitorShellApp());

    expect(find.text(xiaoeShellAppTitle), findsOneWidget);
    expect(find.textContaining('手动停留'), findsOneWidget);
    expect(find.textContaining('直播评论'), findsOneWidget);
  });
}
