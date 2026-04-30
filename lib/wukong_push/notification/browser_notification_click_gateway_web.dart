import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'browser_notification_click_bridge.dart';

BrowserNotificationClickGateway createBrowserNotificationClickGateway() {
  return WebBrowserNotificationClickGateway();
}

class WebBrowserNotificationClickGateway
    implements BrowserNotificationClickGateway {
  WebBrowserNotificationClickGateway();

  StreamController<Object?>? _controller;
  JSFunction? _listener;

  @override
  bool get isSupported => globalContext.has('window');

  @override
  Stream<Object?> get messages {
    _controller ??= StreamController<Object?>.broadcast(
      onListen: _attach,
      onCancel: _detach,
    );
    return _controller!.stream;
  }

  void _attach() {
    if (_listener != null) {
      return;
    }
    _listener = ((web.Event event) {
      if (!event.isA<web.MessageEvent>()) {
        return;
      }
      final messageEvent = event as web.MessageEvent;
      _controller?.add(messageEvent.data.dartify());
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  void _detach() {
    final listener = _listener;
    if (listener == null) {
      return;
    }
    web.window.removeEventListener('message', listener);
    _listener = null;
  }
}
