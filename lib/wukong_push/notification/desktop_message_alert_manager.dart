import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'desktop_message_alert_policy.dart';
import 'desktop_message_alert_presenter.dart';
import 'desktop_message_alert_presenter_factory.dart';
import 'message_alert_plan.dart';

class DesktopMessageAlertManager {
  DesktopMessageAlertManager({
    DesktopMessageAlertPresenter? presenter,
    DesktopMessageAlertPolicy? policy,
    bool Function()? isWeb,
    TargetPlatform Function()? targetPlatform,
  }) : _presenter = presenter ?? createDefaultDesktopMessageAlertPresenter(),
       _policy = policy ?? DesktopMessageAlertPolicy(),
       _isWeb = isWeb ?? (() => kIsWeb),
       _targetPlatform = targetPlatform ?? (() => defaultTargetPlatform);

  static final DesktopMessageAlertManager instance =
      DesktopMessageAlertManager();

  final DesktopMessageAlertPresenter _presenter;
  final DesktopMessageAlertPolicy _policy;
  final bool Function() _isWeb;
  final TargetPlatform Function() _targetPlatform;

  Future<void> showNewMessageAlert({
    required MessageAlertPlan plan,
    required AppLifecycleState lifecycleState,
  }) async {
    if (_isWeb() || _targetPlatform() != TargetPlatform.windows) {
      return;
    }

    final decision = _policy.resolve(
      plan: plan,
      lifecycleState: lifecycleState,
    );

    if (decision.playForegroundSound) {
      await _presenter.playForegroundTick();
    }
    if (decision.playMessageSound) {
      await _presenter.playMessageSound();
    }
    final notification = decision.notification;
    if (notification != null) {
      await _presenter.showNotification(notification);
    }
  }

  Future<void> dispose() => _presenter.dispose();
}
