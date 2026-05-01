import 'dart:convert';

const String sessionSocketTokenProtocolPrefix = 'wk-token.';
const String sessionSocketControlProtocolPrefix = 'wk-control.';

List<String>? buildBrowserSessionSocketProtocols(Map<String, String>? headers) {
  final protocols = <String>[];
  final token = headers?['token']?.trim() ?? '';
  if (token.isNotEmpty) {
    protocols.add(
      '$sessionSocketTokenProtocolPrefix${_encodeProtocolValue(token)}',
    );
  }

  final controlProtocol = headers?['X-Realtime-Control-Protocol']?.trim() ?? '';
  if (controlProtocol.isNotEmpty) {
    protocols.add(
      '$sessionSocketControlProtocolPrefix'
      '${_encodeProtocolToken(controlProtocol)}',
    );
  }

  return protocols.isEmpty ? null : List<String>.unmodifiable(protocols);
}

String _encodeProtocolValue(String value) {
  return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
}

String _encodeProtocolToken(String value) {
  return value.replaceAll(RegExp(r'[^A-Za-z0-9!#$%&*+\-.^_`|~]'), '-');
}
