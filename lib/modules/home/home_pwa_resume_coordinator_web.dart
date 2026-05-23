import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'home_pwa_resume_coordinator_contract.dart';

HomePwaResumeCoordinator createHomePwaResumeCoordinator({
  required HomePwaResumeRecovery onRecover,
  Duration resumeThrottle = const Duration(seconds: 12),
}) {
  return WebHomePwaResumeCoordinator(
    onRecover: onRecover,
    resumeThrottle: resumeThrottle,
  );
}

class WebHomePwaResumeCoordinator implements HomePwaResumeCoordinator {
  WebHomePwaResumeCoordinator({
    required HomePwaResumeRecovery onRecover,
    this.resumeThrottle = const Duration(seconds: 12),
  }) : _onRecover = onRecover;

  final HomePwaResumeRecovery _onRecover;
  final Duration resumeThrottle;

  web.EventListener? _visibilityChangeListener;
  web.EventListener? _pageShowListener;
  web.EventListener? _focusListener;
  web.EventListener? _onlineListener;
  web.EventListener? _serviceWorkerMessageListener;
  DateTime? _lastRecoveryAt;
  Future<void>? _inFlight;
  bool _started = false;

  @override
  void start() {
    if (_started) {
      return;
    }
    _started = true;

    _visibilityChangeListener = ((web.Event event) {
      if (web.document.visibilityState == 'visible') {
        triggerRecovery('visibilitychange');
      }
    }).toJS;
    web.document.addEventListener(
      'visibilitychange',
      _visibilityChangeListener,
    );

    _pageShowListener = ((web.Event event) {
      triggerRecovery('pageshow');
    }).toJS;
    web.window.addEventListener('pageshow', _pageShowListener);

    _focusListener = ((web.Event event) {
      triggerRecovery('focus');
    }).toJS;
    web.window.addEventListener('focus', _focusListener);

    _onlineListener = ((web.Event event) {
      triggerRecovery('online');
    }).toJS;
    web.window.addEventListener('online', _onlineListener);

    if (web.window.navigator.has('serviceWorker')) {
      _serviceWorkerMessageListener = ((web.Event event) {
        if (_isServiceWorkerRecoveryMessage(event)) {
          triggerRecovery('service-worker-message');
        }
      }).toJS;
      web.window.navigator.serviceWorker.addEventListener(
        'message',
        _serviceWorkerMessageListener,
      );
    }
  }

  void triggerRecovery(String reason) {
    final now = DateTime.now();
    final lastRecoveryAt = _lastRecoveryAt;
    if (lastRecoveryAt != null &&
        now.difference(lastRecoveryAt) < resumeThrottle) {
      return;
    }

    final inFlight = _inFlight;
    if (inFlight != null) {
      return;
    }

    _lastRecoveryAt = now;
    final future = _onRecover(reason);
    _inFlight = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_inFlight, future)) {
          _inFlight = null;
        }
      }),
    );
  }

  bool _isServiceWorkerRecoveryMessage(web.Event event) {
    try {
      final message = event as web.MessageEvent;
      final data = message.data.dartify();
      if (data is! Map) {
        return false;
      }
      final type = data['type']?.toString();
      return type == 'wk.push.subscriptionchange' ||
          type == 'wk.notification.click';
    } catch (error, stackTrace) {
      debugPrint('PWA resume message parsing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  @override
  void dispose() {
    final visibilityChangeListener = _visibilityChangeListener;
    if (visibilityChangeListener != null) {
      web.document.removeEventListener(
        'visibilitychange',
        visibilityChangeListener,
      );
    }
    _visibilityChangeListener = null;

    final pageShowListener = _pageShowListener;
    if (pageShowListener != null) {
      web.window.removeEventListener('pageshow', pageShowListener);
    }
    _pageShowListener = null;

    final focusListener = _focusListener;
    if (focusListener != null) {
      web.window.removeEventListener('focus', focusListener);
    }
    _focusListener = null;

    final onlineListener = _onlineListener;
    if (onlineListener != null) {
      web.window.removeEventListener('online', onlineListener);
    }
    _onlineListener = null;

    final serviceWorkerMessageListener = _serviceWorkerMessageListener;
    if (serviceWorkerMessageListener != null &&
        web.window.navigator.has('serviceWorker')) {
      web.window.navigator.serviceWorker.removeEventListener(
        'message',
        serviceWorkerMessageListener,
      );
    }
    _serviceWorkerMessageListener = null;
    _inFlight = null;
    _started = false;
  }
}
