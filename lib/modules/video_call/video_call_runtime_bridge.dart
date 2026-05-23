import 'dart:async';

import 'package:flutter/material.dart';

import '../../realtime/session/session_event_frame.dart';
import 'video_call_runtime.dart' deferred as video_call_runtime;

class VideoCallRuntimeBridge {
  VideoCallRuntimeBridge._();

  static final VideoCallRuntimeBridge instance = VideoCallRuntimeBridge._();

  bool _coordinatorRunning = false;
  bool _shouldRunCoordinator = false;
  bool _loaded = false;
  bool Function(Duration threshold)? _gatewayDegradationReader;
  Future<void>? _loadFuture;

  Future<void> startCoordinator(GlobalKey<NavigatorState> navigatorKey) async {
    _shouldRunCoordinator = true;
    if (_coordinatorRunning) {
      return;
    }
    await _ensureLoaded();
    if (_coordinatorRunning) {
      return;
    }
    if (!_shouldRunCoordinator) {
      return;
    }
    video_call_runtime.startVideoCallCoordinator(navigatorKey);
    _coordinatorRunning = true;
  }

  Future<void> stopCoordinator() async {
    _shouldRunCoordinator = false;
    if (!_coordinatorRunning) {
      return;
    }
    await _ensureLoaded();
    video_call_runtime.stopVideoCallCoordinator();
    _coordinatorRunning = false;
  }

  Future<void> handleSessionFrame(SessionEventFrame frame) async {
    await _ensureLoaded();
    return video_call_runtime.handleVideoCallSessionFrame(frame);
  }

  void setGatewayDegradationReader(bool Function(Duration threshold) reader) {
    _gatewayDegradationReader = reader;
    if (_loadFuture != null) {
      unawaited(_applyGatewayDegradationReaderWhenLoaded());
    }
  }

  Future<bool> hasActiveCallOrPendingSetup() async {
    await _ensureLoaded();
    return video_call_runtime.hasActiveVideoCallOrPendingSetup();
  }

  bool hasActiveCallOrPendingSetupSync() {
    if (!_loaded) {
      return false;
    }
    return video_call_runtime.hasActiveVideoCallOrPendingSetup();
  }

  Future<void> _ensureLoaded() {
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    await video_call_runtime.loadLibrary();
    _loaded = true;
    final reader = _gatewayDegradationReader;
    if (reader != null) {
      video_call_runtime.setVideoCallGatewayDegradationReader(reader);
    }
  }

  Future<void> _applyGatewayDegradationReaderWhenLoaded() async {
    await _ensureLoaded();
    final reader = _gatewayDegradationReader;
    if (reader != null) {
      video_call_runtime.setVideoCallGatewayDegradationReader(reader);
    }
  }
}
