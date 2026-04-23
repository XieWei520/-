import 'package:flutter/foundation.dart';

@immutable
class ImRouteInfo {
  const ImRouteInfo({
    required this.tcpAddr,
    required this.wsAddr,
    required this.wssAddr,
    required this.preferredTransport,
    required this.preferredAddr,
  });

  const ImRouteInfo.empty()
    : tcpAddr = '',
      wsAddr = '',
      wssAddr = '',
      preferredTransport = '',
      preferredAddr = '';

  final String tcpAddr;
  final String wsAddr;
  final String wssAddr;
  final String preferredTransport;
  final String preferredAddr;

  factory ImRouteInfo.fromMap(Map<String, dynamic> raw) {
    return ImRouteInfo(
      tcpAddr: _readString(raw['tcp_addr']),
      wsAddr: _readString(raw['ws_addr']),
      wssAddr: _readString(raw['wss_addr']),
      preferredTransport: _readString(raw['preferred_transport']),
      preferredAddr: _readString(raw['preferred_addr']),
    );
  }

  String resolvePreferredAddr({required String fallbackAddr}) {
    final normalizedFallback = fallbackAddr.trim();
    if (_matchesPreferredTransport(preferredTransport, preferredAddr)) {
      return preferredAddr.trim();
    }
    if (isValidWebSocketConnectUri(wssAddr, expectedScheme: 'wss')) {
      return wssAddr.trim();
    }
    if (isValidWebSocketConnectUri(wsAddr, expectedScheme: 'ws')) {
      return wsAddr.trim();
    }
    if (isValidTcpConnectAddr(tcpAddr)) {
      return tcpAddr.trim();
    }
    return normalizedFallback;
  }
}

bool isValidTcpConnectAddr(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.contains('://')) {
    return false;
  }

  final uri = Uri.tryParse('tcp://$normalized');
  if (uri == null || !uri.hasAuthority) {
    return false;
  }
  if (uri.host.trim().isEmpty) {
    return false;
  }
  if (uri.path.trim().isNotEmpty || uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
    return false;
  }
  final port = uri.port;
  return port > 0 && port <= 65535;
}

bool isValidWebSocketConnectUri(
  String value, {
  required String expectedScheme,
}) {
  final normalized = value.trim();
  final normalizedScheme = expectedScheme.trim().toLowerCase();
  if (normalized.isEmpty ||
      (normalizedScheme != 'ws' && normalizedScheme != 'wss')) {
    return false;
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasAuthority || uri.host.trim().isEmpty) {
    return false;
  }
  return uri.scheme.toLowerCase() == normalizedScheme;
}

bool _matchesPreferredTransport(String transport, String addr) {
  switch (transport.trim().toLowerCase()) {
    case 'wss':
      return isValidWebSocketConnectUri(addr, expectedScheme: 'wss');
    case 'ws':
      return isValidWebSocketConnectUri(addr, expectedScheme: 'ws');
    case 'tcp':
      return isValidTcpConnectAddr(addr);
    default:
      return false;
  }
}

String _readString(dynamic value) => value?.toString().trim() ?? '';
