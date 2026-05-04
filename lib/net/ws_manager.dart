import 'dart:async';

/// WebSocket manager for real-time communication
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
