import 'dart:convert';

import 'foreground_notification_plan.dart';
import 'browser_notification_gateway_stub.dart'
    if (dart.library.js_interop) 'browser_notification_gateway_web.dart';

enum BrowserNotificationPermission { granted, denied, prompt }

enum BrowserNotificationDelivery { shown, unsupported, permissionDenied }

class BrowserNotificationPayload {
  const BrowserNotificationPayload({
    required this.title,
    required this.body,
    required this.tag,
    required this.icon,
    required this.badge,
    required this.data,
    this.onClick,
  });

  final String title;
  final String body;
  final String tag;
  final String icon;
  final String badge;
  final String data;
  final Future<void> Function()? onClick;
}

abstract class BrowserNotificationGateway {
  bool get isSupported;

  BrowserNotificationPermission get permission;

  Future<BrowserNotificationPermission> requestPermission();

  Future<void> show(BrowserNotificationPayload notification);

  Future<void> focusWindow();
}

class BrowserForegroundNotificationService {
  BrowserForegroundNotificationService({BrowserNotificationGateway? gateway})
    : _gateway = gateway ?? createBrowserNotificationGateway();

  final BrowserNotificationGateway _gateway;

  Future<BrowserNotificationDelivery> showPlan(
    ForegroundNotificationPlan plan, {
    Future<void> Function()? onClick,
  }) async {
    if (!_gateway.isSupported) {
      return BrowserNotificationDelivery.unsupported;
    }

    var permission = _gateway.permission;
    if (permission == BrowserNotificationPermission.prompt) {
      try {
        permission = await _gateway.requestPermission();
      } catch (_) {
        return BrowserNotificationDelivery.permissionDenied;
      }
    }
    if (permission != BrowserNotificationPermission.granted) {
      return BrowserNotificationDelivery.permissionDenied;
    }

    await _gateway.show(_payloadFromPlan(plan, onClick: onClick));
    return BrowserNotificationDelivery.shown;
  }

  BrowserNotificationPayload _payloadFromPlan(
    ForegroundNotificationPlan plan, {
    Future<void> Function()? onClick,
  }) {
    final messageId = _messageIdFromPayload(plan.payload);
    return BrowserNotificationPayload(
      title: plan.title,
      body: plan.body,
      tag:
          'wk-message-${messageId.isEmpty ? plan.payload.hashCode : messageId}',
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-maskable-192.png',
      data: plan.payload,
      onClick: () async {
        try {
          await _gateway.focusWindow();
        } catch (_) {}
        await onClick?.call();
      },
    );
  }

  String _messageIdFromPayload(String encodedPayload) {
    try {
      final decoded = jsonDecode(encodedPayload);
      if (decoded is! Map) {
        return '';
      }
      final payload = decoded['payload'];
      if (payload is! Map) {
        return '';
      }
      for (final key in const <String>['message_id', 'messageId', 'msg_id']) {
        final value = payload[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
    } catch (_) {
      return '';
    }
    return '';
  }
}
