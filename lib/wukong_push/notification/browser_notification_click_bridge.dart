import 'dart:async';
import 'dart:convert';

import 'browser_notification_click_gateway_stub.dart'
    if (dart.library.js_interop) 'browser_notification_click_gateway_web.dart';

const String browserNotificationClickMessageType = 'wk.notification.click';

typedef BrowserNotificationClickHandler = void Function(String payload);

abstract class BrowserNotificationClickGateway {
  bool get isSupported;

  Stream<Object?> get messages;
}

class BrowserNotificationClickBridge {
  BrowserNotificationClickBridge({BrowserNotificationClickGateway? gateway})
    : _gateway = gateway ?? createBrowserNotificationClickGateway();

  static final BrowserNotificationClickBridge instance =
      BrowserNotificationClickBridge();

  final BrowserNotificationClickGateway _gateway;
  StreamSubscription<Object?>? _subscription;

  void start({required BrowserNotificationClickHandler onNotificationClick}) {
    if (_subscription != null || !_gateway.isSupported) {
      return;
    }

    _subscription = _gateway.messages.listen((message) {
      final payload = extractBrowserNotificationClickPayload(message);
      if (payload != null) {
        onNotificationClick(payload);
      }
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}

String? extractBrowserNotificationClickPayload(Object? message) {
  final data = _decodeMaybeJson(message);
  if (data is! Map) {
    return null;
  }
  final normalized = Map<String, dynamic>.from(data);
  if (normalized['type'] != browserNotificationClickMessageType) {
    return null;
  }

  final payload = _decodeMaybeJson(normalized['payload']);
  if (payload is String) {
    final trimmed = payload.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (payload is Map) {
    return jsonEncode(_normalizeClickPayloadMap(payload));
  }
  return null;
}

Map<String, dynamic> _normalizeClickPayloadMap(Map payload) {
  final normalized = Map<String, dynamic>.from(payload);
  final nestedPayload = _decodeMaybeJson(normalized['payload']);
  if (nestedPayload is Map) {
    normalized['payload'] = Map<String, dynamic>.from(nestedPayload);
    return normalized;
  }

  if (!_looksLikeConversationPayload(normalized)) {
    return normalized;
  }

  final wrapped = <String, dynamic>{'payload': normalized};
  final title = _trimmedValue(normalized['title']);
  if (title != null) {
    wrapped['title'] = title;
  }
  final body = _trimmedValue(normalized['body']);
  if (body != null) {
    wrapped['body'] = body;
  }
  return wrapped;
}

bool _looksLikeConversationPayload(Map<String, dynamic> data) {
  return _hasAnyKey(data, const <String>['channel_id', 'channelId']) &&
      _hasAnyKey(data, const <String>['channel_type', 'channelType']);
}

bool _hasAnyKey(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    if (data.containsKey(key) && data[key] != null) {
      return true;
    }
  }
  return false;
}

String? _trimmedValue(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

Object? _decodeMaybeJson(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return value;
    }
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return value;
    }
  }
  return value;
}
