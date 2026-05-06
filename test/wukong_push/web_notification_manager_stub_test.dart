import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/message_alert_plan.dart';
import 'package:wukong_im_app/wukong_push/notification/web_notification_manager.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('web notification manager is safe to call from non-web tests', () async {
    final manager = WebNotificationManager.instance;

    await manager.init();
    await manager.showNewMessageAlert(
      plan: const MessageAlertPlan(
        title: 'Alice',
        body: 'Hello',
        channelId: 'alice',
        channelType: WKChannelType.personal,
      ),
      lifecycleState: AppLifecycleState.hidden,
    );

    expect(manager.isPageVisible(), isTrue);
  });
}
