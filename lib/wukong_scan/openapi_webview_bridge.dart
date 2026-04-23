import 'dart:convert';

import '../data/models/user.dart';
import '../service/api/openapi_api.dart';

typedef OpenApiAppInfoLoader = Future<OpenApiAppInfo> Function(String appId);
typedef OpenApiAuthCodeLoader = Future<String> Function(String appId);
typedef OpenApiCurrentUserLoader = Future<UserInfo?> Function();
typedef OpenApiAuthorizationRequester =
    Future<bool> Function(OpenApiAuthorizationPrompt prompt);

class OpenApiWebViewBridgeController {
  OpenApiWebViewBridgeController({
    required OpenApiAppInfoLoader fetchAppInfo,
    required OpenApiAuthCodeLoader fetchAuthCode,
    required OpenApiCurrentUserLoader loadCurrentUser,
    required OpenApiAuthorizationRequester requestAuthorization,
  }) : _fetchAppInfo = fetchAppInfo,
       _fetchAuthCode = fetchAuthCode,
       _loadCurrentUser = loadCurrentUser,
       _requestAuthorization = requestAuthorization;

  static const String channelName = 'WKFlutterOpenApiBridge';
  static const String authHandlerName = 'auth';

  static String get bootstrapScript =>
      '''
(function() {
  if (window.WebViewJavascriptBridge &&
      window.WebViewJavascriptBridge._wkFlutterBridgeVersion === 1) {
    return;
  }

  var responseCallbacks = {};
  var uniqueId = 1;

  function registerHandler(handlerName, handler) {}

  function callHandler(handlerName, data, responseCallback) {
    if (arguments.length === 2 && typeof data === 'function') {
      responseCallback = data;
      data = null;
    }

    var message = { handlerName: handlerName, data: data };
    if (responseCallback) {
      var callbackId = 'cb_' + (uniqueId++) + '_' + new Date().getTime();
      responseCallbacks[callbackId] = responseCallback;
      message.callbackId = callbackId;
    }

    if (window.$channelName &&
        typeof window.$channelName.postMessage === 'function') {
      window.$channelName.postMessage(JSON.stringify(message));
    }
  }

  function _handleMessageFromFlutter(messageJSON) {
    var message = JSON.parse(messageJSON);
    if (!message.responseId) {
      return;
    }

    var responseCallback = responseCallbacks[message.responseId];
    if (!responseCallback) {
      return;
    }
    responseCallback(message.responseData);
    delete responseCallbacks[message.responseId];
  }

  var bridge = window.WebViewJavascriptBridge = {
    registerHandler: registerHandler,
    callHandler: callHandler,
    _handleMessageFromFlutter: _handleMessageFromFlutter,
    _handleMessageFromNative: _handleMessageFromFlutter,
    _wkFlutterBridgeVersion: 1
  };

  var readyEvent = document.createEvent('Events');
  readyEvent.initEvent('WebViewJavascriptBridgeReady');
  readyEvent.bridge = bridge;
  document.dispatchEvent(readyEvent);

  var callbacks = window.WVJBCallbacks;
  if (!callbacks) {
    return;
  }
  delete window.WVJBCallbacks;
  for (var i = 0; i < callbacks.length; i++) {
    callbacks[i](bridge);
  }
})();
''';

  final OpenApiAppInfoLoader _fetchAppInfo;
  final OpenApiAuthCodeLoader _fetchAuthCode;
  final OpenApiCurrentUserLoader _loadCurrentUser;
  final OpenApiAuthorizationRequester _requestAuthorization;

  Future<OpenApiWebViewBridgeResult> handleRawMessage(String rawMessage) async {
    final message = _decodeMessage(rawMessage);
    if (message == null || message.handlerName != authHandlerName) {
      return const OpenApiWebViewBridgeResult(handled: false);
    }

    final callbackId = message.callbackId;
    if (callbackId.isEmpty) {
      return const OpenApiWebViewBridgeResult(handled: true);
    }

    final appId = _resolveAppId(message.data);
    if (appId.isEmpty) {
      return OpenApiWebViewBridgeResult(
        handled: true,
        callback: OpenApiWebViewBridgeCallback(
          callbackId: callbackId,
          payload: const <String, dynamic>{'error': 'Missing app_id.'},
        ),
      );
    }

    try {
      final appInfo = await _fetchAppInfo(appId);
      final currentUser = await _loadCurrentUser();
      final approved = await _requestAuthorization(
        OpenApiAuthorizationPrompt(appInfo: appInfo, currentUser: currentUser),
      );
      if (!approved) {
        return OpenApiWebViewBridgeResult(
          handled: true,
          callback: OpenApiWebViewBridgeCallback(
            callbackId: callbackId,
            payload: const <String, dynamic>{
              'error': 'Authorization canceled.',
            },
          ),
        );
      }

      final authCode = await _fetchAuthCode(appId);
      return OpenApiWebViewBridgeResult(
        handled: true,
        callback: OpenApiWebViewBridgeCallback(
          callbackId: callbackId,
          payload: <String, dynamic>{'code': authCode},
        ),
      );
    } catch (error) {
      return OpenApiWebViewBridgeResult(
        handled: true,
        callback: OpenApiWebViewBridgeCallback(
          callbackId: callbackId,
          payload: <String, dynamic>{'error': _renderError(error)},
        ),
      );
    }
  }

  _OpenApiBridgeMessage? _decodeMessage(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);
      final data = map['data'];
      return _OpenApiBridgeMessage(
        handlerName: (map['handlerName'] ?? '').toString().trim(),
        callbackId: (map['callbackId'] ?? '').toString().trim(),
        data: data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{},
      );
    } catch (_) {
      return null;
    }
  }

  String _resolveAppId(Map<String, dynamic> data) {
    return (data['app_id'] ?? '').toString().trim();
  }

  String _renderError(Object error) {
    final rendered = error.toString().trim();
    return rendered.isEmpty ? 'Authorization failed.' : rendered;
  }
}

class OpenApiAuthorizationPrompt {
  const OpenApiAuthorizationPrompt({
    required this.appInfo,
    required this.currentUser,
  });

  final OpenApiAppInfo appInfo;
  final UserInfo? currentUser;
}

class OpenApiWebViewBridgeResult {
  const OpenApiWebViewBridgeResult({required this.handled, this.callback});

  final bool handled;
  final OpenApiWebViewBridgeCallback? callback;
}

class OpenApiWebViewBridgeCallback {
  const OpenApiWebViewBridgeCallback({
    required this.callbackId,
    required this.payload,
  });

  final String callbackId;
  final Map<String, dynamic> payload;

  String toJavaScript() {
    final messageJson = jsonEncode(<String, dynamic>{
      'responseId': callbackId,
      'responseData': jsonEncode(payload),
    });
    final encodedMessage = jsonEncode(messageJson);
    return '''
(function() {
  var bridge = window.WebViewJavascriptBridge;
  if (!bridge || typeof bridge._handleMessageFromFlutter !== 'function') {
    return;
  }
  bridge._handleMessageFromFlutter($encodedMessage);
})();
''';
  }
}

class _OpenApiBridgeMessage {
  const _OpenApiBridgeMessage({
    required this.handlerName,
    required this.callbackId,
    required this.data,
  });

  final String handlerName;
  final String callbackId;
  final Map<String, dynamic> data;
}
