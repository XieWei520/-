import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = await getDatabasesPath();
  final sdkDb = p.join(
    dbPath,
    'wk_bd5f7770d6a74cefa3b9c3217598a900.db',
  );
  final db = await databaseFactory.openDatabase(sdkDb);
  final rows = await db.rawQuery(
    "SELECT message_id, message_seq, client_msg_no, channel_id, channel_type, content "
    "FROM message WHERE content LIKE ? ORDER BY rowid DESC LIMIT 5",
    <Object?>['%revoke-001%'],
  );
  await db.close();

  stdout.writeln('revokeRows=$rows');
  if (rows.isEmpty) {
    return;
  }

  final row = rows.first;
  final clientMsgNo = row['client_msg_no']!.toString();
  final channelId = row['channel_id']!.toString();
  final channelType = (row['channel_type'] as num).toInt();

  final client = HttpClient();

  final bodyOnly = await _post(
    client: client,
    uri: Uri.parse('http://42.194.218.158/v1/message/revoke'),
    body: jsonEncode(<String, Object?>{
      'client_msg_no': clientMsgNo,
      'channel_id': channelId,
      'channel_type': channelType,
    }),
  );
  stdout.writeln('bodyOnlyStatus=${bodyOnly.$1}');
  stdout.writeln('bodyOnlyResponse=${bodyOnly.$2}');

  final queryOnly = await _post(
    client: client,
    uri: Uri.parse(
      'http://42.194.218.158/v1/message/revoke',
    ).replace(
      queryParameters: <String, String>{
        'client_msg_no': clientMsgNo,
        'channel_id': channelId,
        'channel_type': '$channelType',
        'message_id': row['message_id']!.toString(),
      },
    ),
    body: '',
  );
  stdout.writeln('queryOnlyStatus=${queryOnly.$1}');
  stdout.writeln('queryOnlyResponse=${queryOnly.$2}');

  client.close(force: true);
}

Future<(int, String)> _post({
  required HttpClient client,
  required Uri uri,
  required String body,
}) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final nonce = _nonce(16);
  final signSource = '$body$nonce$timestamp${'25b002c6be2d539f264c'}';
  final sign = crypto.md5.convert(utf8.encode(signSource)).toString();

  final request = await client.postUrl(uri);
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
  request.headers.set('appid', 'wukongchat');
  request.headers.set('timestamp', timestamp);
  request.headers.set('noncestr', nonce);
  request.headers.set('sign', sign);
  request.headers.set('token', '7dedb28a2cc14e989cc36a2126dd6488');
  request.headers.set('X-Device-ID', '68de4b448b894ad19d821135f6319dc8');
  request.headers.set('X-Device-Session-ID', '2cb7b37a739448b58baf6fd0b08f7b61');
  if (body.isNotEmpty) {
    request.write(body);
  }
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
