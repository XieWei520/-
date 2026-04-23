import 'package:flutter/material.dart';

import '../../realtime/session/session_event_frame.dart';

class CallCoordinator {
  CallCoordinator._();

  static final CallCoordinator instance = CallCoordinator._();

  void start(GlobalKey<NavigatorState> navigatorKey) {}

  void stop() {}

  void setGatewayDegradationReader(bool Function(Duration threshold) reader) {}

  Future<void> handleSessionFrame(SessionEventFrame frame) async {}
}
