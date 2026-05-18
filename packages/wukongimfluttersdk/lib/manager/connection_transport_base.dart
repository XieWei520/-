import 'dart:typed_data';

enum WKTransportType {
  tcp,
  ws,
  wss,
}

class WKConnectTarget {
  final WKTransportType type;
  final String host;
  final int? port;
  final Uri? uri;

  const WKConnectTarget._({
    required this.type,
    required this.host,
    required this.port,
    required this.uri,
  });

  static WKConnectTarget parse(String rawAddress) {
    final address = rawAddress.trim();
    if (address.isEmpty) {
      throw const FormatException('Connection address is empty');
    }

    if (address.startsWith('ws://') || address.startsWith('wss://')) {
      return _parseWebSocket(address);
    }

    if (address.contains('://')) {
      throw FormatException('Unsupported connection scheme: $address');
    }

    return _parseTcp(address);
  }

  static WKConnectTarget _parseTcp(String address) {
    final splitIndex = address.lastIndexOf(':');
    if (splitIndex <= 0 || splitIndex == address.length - 1) {
      throw FormatException('Invalid tcp address: $address');
    }

    final host = address.substring(0, splitIndex).trim();
    final portText = address.substring(splitIndex + 1).trim();
    final port = int.tryParse(portText);
    if (host.isEmpty || port == null || port <= 0 || port > 65535) {
      throw FormatException('Invalid tcp address: $address');
    }

    return WKConnectTarget._(
      type: WKTransportType.tcp,
      host: host,
      port: port,
      uri: null,
    );
  }

  static WKConnectTarget _parseWebSocket(String address) {
    final uri = Uri.tryParse(address);
    if (uri == null) {
      throw FormatException('Invalid websocket uri: $address');
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'ws' && scheme != 'wss') {
      throw FormatException('Invalid websocket uri: $address');
    }
    if (uri.host.isEmpty) {
      throw FormatException('Invalid websocket uri: $address');
    }

    return WKConnectTarget._(
      type: scheme == 'wss' ? WKTransportType.wss : WKTransportType.ws,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      uri: uri,
    );
  }
}

class WKWebSocketFrameConverter {
  static Uint8List? toBytes(dynamic frame) {
    if (frame is Uint8List) {
      return frame;
    }
    if (frame is ByteBuffer) {
      return frame.asUint8List();
    }
    if (frame is ByteData) {
      return frame.buffer.asUint8List(frame.offsetInBytes, frame.lengthInBytes);
    }
    if (frame is List<int>) {
      return Uint8List.fromList(frame);
    }
    return null;
  }
}

abstract class WKConnectionTransport {
  Future<void> send(Uint8List data);

  void listen(
    void Function(Uint8List data) onData, {
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onDone,
  });

  Future<void> close();
}
