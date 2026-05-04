class VideoCallService {
  VideoCallService._();

  static final VideoCallService instance = VideoCallService._();

  void setGatewayDegradationReader(bool Function(Duration threshold) reader) {}
}
