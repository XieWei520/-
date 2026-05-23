import 'package:flutter/material.dart';

import '../../realtime/session/session_event_frame.dart';
import 'call_coordinator.dart';
import 'video_call_service.dart';

void startVideoCallCoordinator(GlobalKey<NavigatorState> navigatorKey) {
  CallCoordinator.instance.start(navigatorKey);
}

void stopVideoCallCoordinator() {
  CallCoordinator.instance.stop();
}

Future<void> handleVideoCallSessionFrame(SessionEventFrame frame) {
  return CallCoordinator.instance.handleSessionFrame(frame);
}

void setVideoCallGatewayDegradationReader(
  bool Function(Duration threshold) reader,
) {
  CallCoordinator.instance.setGatewayDegradationReader(reader);
  VideoCallService.instance.setGatewayDegradationReader(reader);
}

bool hasActiveVideoCallOrPendingSetup() {
  return VideoCallService.instance.hasActiveCallOrPendingSetup;
}
