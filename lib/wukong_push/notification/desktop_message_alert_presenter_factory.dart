import 'desktop_message_alert_presenter.dart';
import 'desktop_message_alert_presenter_stub.dart'
    if (dart.library.io) 'desktop_message_alert_presenter_io.dart';

DesktopMessageAlertPresenter createDefaultDesktopMessageAlertPresenter() {
  return createDesktopMessageAlertPresenter();
}
