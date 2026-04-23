import 'dart:async';

import 'package:flutter/material.dart';

import '../modules/settings/notification_settings_page.dart';
import '../wukong_base/endpoint/endpoint_handler.dart';
import '../wukong_base/endpoint/endpoint_manager.dart';

const String showOpenNotificationDialogEndpoint =
    'show_open_notification_dialog';

typedef NotificationSettingsPageBuilder = Widget Function();

class NotificationPermissionPromptBridge {
  NotificationPermissionPromptBridge({
    EndpointManager? endpointManager,
    NotificationSettingsPageBuilder? settingsPageBuilder,
  }) : _endpointManager = endpointManager ?? EndpointManager.getInstance(),
       _settingsPageBuilder =
           settingsPageBuilder ?? _defaultNotificationSettingsPageBuilder;

  static final NotificationPermissionPromptBridge instance =
      NotificationPermissionPromptBridge();

  final EndpointManager _endpointManager;
  final NotificationSettingsPageBuilder _settingsPageBuilder;

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _registered = false;
  bool _dialogVisible = false;
  bool _promptPending = false;

  void bindNavigator(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    if (_promptPending) {
      unawaited(showPrompt());
    }
  }

  void ensureRegistered() {
    if (_registered || _endpointManager.hasEndpoint(showOpenNotificationDialogEndpoint)) {
      _registered = true;
      return;
    }
    _endpointManager.setMethod(
      showOpenNotificationDialogEndpoint,
      '',
      0,
      AsyncFunctionHandler(([dynamic param]) => showPrompt(param)),
    );
    _registered = true;
  }

  Future<bool> showPrompt([dynamic param]) async {
    final context = _resolveContext(param);
    if (context == null) {
      _promptPending = true;
      return false;
    }
    if (_dialogVisible) {
      return false;
    }

    _dialogVisible = true;
    _promptPending = false;
    try {
      final shouldOpenSettings =
          await showDialog<bool>(
            context: context,
            barrierDismissible: true,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Enable notifications'),
                content: const Text(
                  'WuKongIM needs notification permission so new messages and call invitations can alert you in time.',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Not now'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Open Settings'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!shouldOpenSettings) {
        return false;
      }

      final navigatorState = _navigatorKey?.currentState;
      final navigatorContext = navigatorState?.overlay?.context;
      if (navigatorState == null || navigatorContext == null) {
        _promptPending = true;
        return false;
      }
      unawaited(
        navigatorState.push(
          MaterialPageRoute<void>(
            builder: (_) => _settingsPageBuilder(),
          ),
        ),
      );
      return true;
    } finally {
      _dialogVisible = false;
    }
  }

  BuildContext? _resolveContext(dynamic raw) {
    if (raw is BuildContext) {
      return raw;
    }
    return _navigatorKey?.currentContext ?? _navigatorKey?.currentState?.overlay?.context;
  }

  static Widget _defaultNotificationSettingsPageBuilder() {
    return const NotificationSettingsPage();
  }
}
