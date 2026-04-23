abstract interface class CallMediaEngine {
  bool get isConnected;

  Object? get session;

  Future<void> connect({
    required String url,
    required String token,
    required bool enableVideo,
  });

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setCameraEnabled(bool enabled);

  Future<Map<String, dynamic>> collectStats();

  Future<void> disconnect();
}
