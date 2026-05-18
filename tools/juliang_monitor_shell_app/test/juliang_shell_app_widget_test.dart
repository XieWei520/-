import 'package:flutter_test/flutter_test.dart';
import 'package:juliang_monitor_shell_app/main.dart';

void main() {
  testWidgets('runtime UI states manual login is required every launch', (
    tester,
  ) async {
    await tester.pumpWidget(const JuliangMonitorShellApp());

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
}
