import 'desktop_message_alert_policy.dart';
import 'desktop_message_alert_presenter.dart';

DesktopMessageAlertPresenter createDesktopMessageAlertPresenter() {
  return const DesktopMessageAlertPresenterStub();
}

class DesktopMessageAlertPresenterStub implements DesktopMessageAlertPresenter {
  const DesktopMessageAlertPresenterStub();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playForegroundTick() async {}

  @override
  Future<void> playMessageSound() async {}

  @override
  Future<void> showNotification(
    DesktopMessageNotification notification,
  ) async {}

  @override
  Future<void> dispose() async {}
}
