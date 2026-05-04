import 'browser_notification_service.dart';

BrowserNotificationGateway createBrowserNotificationGateway() {
  return const StubBrowserNotificationGateway();
}

class StubBrowserNotificationGateway implements BrowserNotificationGateway {
  const StubBrowserNotificationGateway();

  @override
  bool get isSupported => false;

  @override
  BrowserNotificationPermission get permission =>
      BrowserNotificationPermission.denied;

  @override
  Future<BrowserNotificationPermission> requestPermission() async {
    return BrowserNotificationPermission.denied;
  }

  @override
  Future<void> show(BrowserNotificationPayload notification) async {}

  @override
  Future<void> focusWindow() async {}
}
