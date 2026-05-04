import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/web_notification_manager.dart';

void main() {
  test('web notification manager is safe to call from non-web tests', () async {
    final manager = WebNotificationManager.instance;

    await manager.init();
    manager.startTitleBlink();
    manager.stopTitleBlink();
    await manager.showNewMessageAlert(title: 'Alice', body: 'Hello');

    expect(manager.isPageVisible(), isTrue);
  });
}
