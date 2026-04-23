import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

Future<void> main() async {
  final client = HttpClient();
  final payload = <String, Object?>{
    'channel_id': 'e572e880870a46ca8305a368740067ed',
    'channel_type': 1,
  };
  final body = jsonEncode(payload);

  final clearResponse = await _post(
    client: client,
    url: 'http://42.194.218.158/v1/message/pinned/clear',
    body: body,
  );
  stdout.writeln('clearStatus=${clearResponse.$1}');
  stdout.writeln('clearBody=${clearResponse.$2}');

  final syncResponse = await _post(
    client: client,
    url: 'http://42.194.218.158/v1/message/pinned/sync',
    body: jsonEncode(<String, Object?>{
      'channel_id': payload['channel_id'],
      'channel_type': payload['channel_type'],
      'version': 0,
    }),
  );
  stdout.writeln('syncPinnedStatus=${syncResponse.$1}');
  stdout.writeln('syncPinnedBody=${syncResponse.$2}');

  client.close(force: true);
}

Future<(int, String)> _post({
  required HttpClient client,
  required String url,
  required String body,
}) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final nonce = _nonce(16);
  final signSource = '$body$nonce$timestamp${'25b002c6be2d539f264c'}';
  final sign = crypto.md5.convert(utf8.encode(signSource)).toString();

  final request = await client.postUrl(Uri.parse(url));
  request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  request.headers.set('appid', 'wukongchat');
  request.headers.set('timestamp', timestamp);
  request.headers.set('noncestr', nonce);
  request.headers.set('sign', sign);
  request.headers.set('token', '7dedb28a2cc14e989cc36a2126dd6488');
  request.headers.set('X-Device-ID', '68de4b448b894ad19d821135f6319dc8');
  request.headers.set('X-Device-Session-ID', '2cb7b37a739448b58baf6fd0b08f7b61');
  request.write(body);

  final response = await request.close();
  final responseBody = await utf8.decodeStream(response);
  return (response.statusCode, responseBody);
}

String _nonce(int length) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final millis = DateTime.now().millisecondsSinceEpoch;
  return List<String>.generate(
    length,
    (index) => chars[(millis + index * 17) % chars.length],
  ).join();
}
