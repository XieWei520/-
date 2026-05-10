import 'dart:async';

import 'package:flutter/services.dart';

import 'feishu_network_capture.dart';

class FeishuNetworkCaptureBridge {
  FeishuNetworkCaptureBridge({MethodChannel? channel})
    : channel =
          channel ?? const MethodChannel('wukong/feishu_network_capture') {
    this.channel.setMethodCallHandler(_handleMethodCall);
  }

  final MethodChannel channel;
  final StreamController<FeishuNetworkCaptureEvent> _events =
      StreamController<FeishuNetworkCaptureEvent>.broadcast();
  final StreamController<String> _unavailableErrors =
      StreamController<String>.broadcast();
  bool _disposed = false;

  Stream<FeishuNetworkCaptureEvent> get events => _events.stream;
  Stream<String> get unavailableErrors => _unavailableErrors.stream;

  Future<void> start() async {
    await channel.invokeMethod<Object?>('start');
  }

  Future<void> stop() async {
    await channel.invokeMethod<Object?>('stop');
  }

  Future<void> dispose() async {
    channel.setMethodCallHandler(null);
    if (_disposed) {
      return;
    }
    _disposed = true;
    try {
      await stop();
    } catch (_) {
      // Stop is best-effort during disposal; cleanup must still complete.
    } finally {
      await _events.close();
      await _unavailableErrors.close();
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (_disposed) {
      return;
    }
    if (call.method == 'networkUnavailable') {
      if (!_unavailableErrors.isClosed) {
        _unavailableErrors.add(_unavailableMessage(call.arguments));
      }
      return;
    }
    if (call.method != 'networkEvent' || _events.isClosed) {
      return;
    }
    final arguments = call.arguments;
    if (arguments is! Map) {
      return;
    }
    _events.add(_eventFromMap(Map<Object?, Object?>.from(arguments)));
  }
}

String _unavailableMessage(Object? arguments) {
  if (arguments is Map) {
    final map = Map<Object?, Object?>.from(arguments);
    final message = _stringValue(map['message']).trim();
    if (message.isNotEmpty) {
      return message;
    }
    final error = _stringValue(map['error']).trim();
    if (error.isNotEmpty) {
      return error;
    }
  }
  return 'Network capture is unavailable.';
}

FeishuNetworkCaptureEvent _eventFromMap(Map<Object?, Object?> map) {
  return FeishuNetworkCaptureEvent(
    id: _stringValue(map['id']),
    observedAt: _observedAt(map['observed_at']),
    source: _sourceFromString(_stringValue(map['source'])),
    url: _stringValue(map['url']),
    method: _stringValue(map['method']),
    statusCode: _statusCode(map['status_code']),
    mimeType: _stringValue(map['mime_type']),
    payloadPreview: _stringValue(map['payload_preview']),
    bodyLocalPath: _stringValue(map['body_local_path']),
    bodySha1: _stringValue(map['body_sha1']),
    bodySize: _statusCode(map['body_size']),
    bodyMimeType: _stringValue(map['body_mime_type']),
    bodyBase64Encoded: _boolValue(map['body_base64_encoded']),
    bodySaved: _boolValue(map['body_saved']),
    bodySaveError: _stringValue(map['body_save_error']),
  );
}

String _stringValue(Object? value) => value == null ? '' : '$value';

DateTime _observedAt(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  return DateTime.tryParse(_stringValue(value))?.toUtc() ??
      DateTime.now().toUtc();
}

int _statusCode(Object? value) {
  if (value is num) {
    return value.round();
  }
  return int.tryParse(_stringValue(value)) ?? 0;
}

bool _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  final normalized = _stringValue(value).trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}

FeishuNetworkEventSource _sourceFromString(String value) {
  for (final source in FeishuNetworkEventSource.values) {
    if (source.name == value) {
      return source;
    }
  }
  return FeishuNetworkEventSource.unknown;
}
