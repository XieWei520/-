import 'dart:async';

enum CallMediaConnectionState {
  connecting,
  connected,
  reconnecting,
  disconnected,
  failed,
}

abstract interface class CallMediaEngine {
  bool get isConnected;

  Stream<CallMediaConnectionState> get connectionStates;

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
