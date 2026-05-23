import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'browser_startup_recovery_service.dart';

@JS('wkRecoverFromStartupFailure')
external JSPromise<JSBoolean> _recoverFromStartupFailure();

BrowserStartupRecoveryService createPlatformBrowserStartupRecoveryService() =>
    const WebBrowserStartupRecoveryService();

class WebBrowserStartupRecoveryService
    extends BrowserStartupRecoveryService {
  const WebBrowserStartupRecoveryService();

  @override
  Future<bool> recoverFromStartupFailure() async {
    if (hasRecoveredStartupFailure) {
      return false;
    }
    if (globalContext.has('wkRecoverFromStartupFailure')) {
      try {
        final result = await _recoverFromStartupFailure().toDart;
        return result.toDart;
      } catch (error, stackTrace) {
        debugPrint('Web startup recovery failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    _navigateToResetUrl();
    return true;
  }

  @override
  bool get hasRecoveredStartupFailure {
    final uri = Uri.parse(web.window.location.href);
    if (uri.queryParameters['wk_reset_sw'] == '1') {
      return true;
    }
    try {
      return web.window.sessionStorage.getItem('wk_sw_recovery_attempted') ==
          '1';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> resetDamagedSession() async {
    try {
      web.window.localStorage.clear();
    } catch (error, stackTrace) {
      debugPrint('Web local session reset failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    try {
      web.window.sessionStorage.clear();
    } catch (_) {}
    web.window.location.replace('/#/login');
    return true;
  }

  void _navigateToResetUrl() {
    final uri = Uri.parse(web.window.location.href);
    final query = Map<String, String>.from(uri.queryParameters)
      ..['wk_reset_sw'] = '1';
    web.window.location.replace(
      uri.replace(queryParameters: query).toString(),
    );
  }
}
