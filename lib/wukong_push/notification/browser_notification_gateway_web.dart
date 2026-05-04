import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'browser_notification_service.dart';

BrowserNotificationGateway createBrowserNotificationGateway() {
  return const WebBrowserNotificationGateway();
}

class WebBrowserNotificationGateway implements BrowserNotificationGateway {
  const WebBrowserNotificationGateway();

  @override
  bool get isSupported => globalContext.has('Notification');

  @override
  BrowserNotificationPermission get permission {
    if (!isSupported) {
      return BrowserNotificationPermission.denied;
    }
    return _mapPermission(web.Notification.permission);
  }

  @override
  Future<BrowserNotificationPermission> requestPermission() async {
    if (!isSupported) {
      return BrowserNotificationPermission.denied;
    }
    final permission = await web.Notification.requestPermission().toDart;
    return _mapPermission(permission.toDart);
  }

  @override
  Future<void> show(BrowserNotificationPayload payload) async {
    if (!isSupported) {
      return;
    }
    final notification = web.Notification(
      payload.title,
      web.NotificationOptions(
        body: payload.body,
        tag: payload.tag,
        icon: payload.icon,
        badge: payload.badge,
        data: payload.data.toJS,
      ),
    );
    notification.onclick = ((web.Event event) {
      notification.close();
      final onClick = payload.onClick;
      if (onClick != null) {
        unawaited(onClick());
      }
    }).toJS;
  }

  @override
  Future<void> focusWindow() async {
    web.window.focus();
  }

  BrowserNotificationPermission _mapPermission(String value) {
    return switch (value.trim().toLowerCase()) {
      'granted' => BrowserNotificationPermission.granted,
      'denied' => BrowserNotificationPermission.denied,
      _ => BrowserNotificationPermission.prompt,
    };
  }
}
