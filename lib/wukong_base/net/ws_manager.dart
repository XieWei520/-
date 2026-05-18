import 'dart:async';

/// WebSocket manager for real-time communication
@Deprecated(
  'Use SessionRuntime with SessionEventGateway and ConnectionCoordinator instead. Will be removed in v2.0',
)
class WSManager {
  WSManager._();
  static final WSManager _instance = WSManager._();
  static WSManager get instance => _instance;

  bool get isConnected => _connected;
  bool _connected = false;

  Future<void> connect(String url) async {
    _connected = true;
  }

  void disconnect() {
    _connected = false;
  }

  void send(String message) {
    // TODO: Implement
  }
}
