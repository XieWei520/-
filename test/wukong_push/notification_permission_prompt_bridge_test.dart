import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_manager.dart';
import 'package:wukong_im_app/wukong_push/notification_permission_prompt_bridge.dart';

void main() {
  testWidgets(
    'notification permission prompt endpoint shows a dialog and opens notification settings page',
    (tester) async {
      final endpointManager = EndpointManager.getInstance();
      endpointManager.clear();
      addTearDown(endpointManager.clear);

      final navigatorKey = GlobalKey<NavigatorState>();
      final bridge = NotificationPermissionPromptBridge(
        endpointManager: endpointManager,
        settingsPageBuilder: () => const _FakeNotificationSettingsPage(),
      );

      bridge.bindNavigator(navigatorKey);
      bridge.ensureRegistered();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      unawaited(endpointManager.invoke(showOpenNotificationDialogEndpoint));
      await tester.pumpAndSettle();

      expect(find.text('\u5f00\u542f\u901a\u77e5'), findsOneWidget);
      expect(
        find.text(
          '\u8bf7\u5f00\u542f\u901a\u77e5\u6743\u9650\uff0c'
          '\u4ee5\u4fbf\u65b0\u6d88\u606f\u548c\u901a\u8bdd'
          '\u9080\u8bf7\u80fd\u591f\u53ca\u65f6\u63d0\u9192\u4f60\u3002',
        ),
        findsOneWidget,
      );
      expect(
        find.text('\u6253\u5f00\u8bbe\u7f6e'),
        findsOneWidget,
      );

      await tester.tap(find.text('\u6253\u5f00\u8bbe\u7f6e'));
      await tester.pumpAndSettle();

      expect(find.byType(_FakeNotificationSettingsPage), findsOneWidget);
    },
  );

  testWidgets(
    'notification permission prompt queued before navigator binding is shown once the app shell is ready',
    (tester) async {
      final endpointManager = EndpointManager.getInstance();
      endpointManager.clear();
      addTearDown(endpointManager.clear);

      final navigatorKey = GlobalKey<NavigatorState>();
      final bridge = NotificationPermissionPromptBridge(
        endpointManager: endpointManager,
        settingsPageBuilder: () => const _FakeNotificationSettingsPage(),
      );

      await bridge.showPrompt();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      bridge.bindNavigator(navigatorKey);
      await tester.pumpAndSettle();

      expect(find.text('\u5f00\u542f\u901a\u77e5'), findsOneWidget);
    },
  );
}

class _FakeNotificationSettingsPage extends StatelessWidget {
  const _FakeNotificationSettingsPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('Notification settings page'));
  }
}
