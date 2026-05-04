import 'browser_notification_click_bridge.dart';

BrowserNotificationClickGateway createBrowserNotificationClickGateway() {
  return const StubBrowserNotificationClickGateway();
}

class StubBrowserNotificationClickGateway
    implements BrowserNotificationClickGateway {
  const StubBrowserNotificationClickGateway();

  @override
  bool get isSupported => false;

  @override
  Stream<Object?> get messages => const Stream<Object?>.empty();
}
