import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart' as crypto;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dbPath = await getDatabasesPath();
  final uid = 'bd5f7770d6a74cefa3b9c3217598a900';
  final appDb = p.join(dbPath, 'wukong_im.db');
  final sdkDb = p.join(dbPath, 'wk_$uid.db');
  stdout.writeln('dbPath=$dbPath');
  stdout.writeln('appDb=$appDb exists=${File(appDb).existsSync()}');
  stdout.writeln('sdkDb=$sdkDb exists=${File(sdkDb).existsSync()}');

  final db = await databaseFactory.openDatabase(sdkDb);
  final schema = await db.rawQuery("PRAGMA table_info('message')");
  stdout.writeln('messageSchema=$schema');
  final rows = await db.rawQuery(
    "SELECT rowid, message_id, message_seq, client_msg_no, channel_id, channel_type, order_seq, status, content "
    "FROM message WHERE content LIKE ? ORDER BY rowid DESC LIMIT 5",
    <Object?>['%reply-001%'],
  );
  stdout.writeln('replyRows=$rows');
  await db.close();

  if (rows.isEmpty) {
    return;
  }

  final row = rows.first;
  final payload = <String, Object?>{
    'message_id': row['message_id'],
    'message_seq': row['message_seq'],
    'channel_id': row['channel_id'],
    'channel_type': row['channel_type'],
  };
  final body = jsonEncode(payload);
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final nonce = _nonce(16);
  final signSource = '$body$nonce$timestamp${'25b002c6be2d539f264c'}';
  final sign =
      crypto.md5.convert(utf8.encode(signSource)).toString();

  final client = HttpClient();
  final request = await client.postUrl(
    Uri.parse('http://42.194.218.158/v1/message/pinned'),
  );
  request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  request.headers.set('appid', 'wukongchat');
  request.headers.set('timestamp', timestamp);
  request.headers.set('noncestr', nonce);
  request.headers.set('sign', sign);
  request.headers.set('token', '7dedb28a2cc14e989cc36a2126dd6488');
  request.headers.set('X-Device-ID', '68de4b448b894ad19d821135f6319dc8');
  request.headers.set(
    'X-Device-Session-ID',
    '2cb7b37a739448b58baf6fd0b08f7b61',
  );
  request.write(body);
  final response = await request.close();
  final responseBody = await utf8.decodeStream(response);
  stdout.writeln('pinnedStatus=${response.statusCode}');
  stdout.writeln('pinnedBody=$responseBody');

  final syncPayload = <String, Object?>{
    'channel_id': row['channel_id'],
    'channel_type': row['channel_type'],
    'version': 0,
  };
  final syncBody = jsonEncode(syncPayload);
  final syncTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final syncNonce = _nonce(16);
  final syncSignSource =
      '$syncBody$syncNonce$syncTimestamp${'25b002c6be2d539f264c'}';
  final syncSign = crypto.md5.convert(utf8.encode(syncSignSource)).toString();
  final syncRequest = await client.postUrl(
    Uri.parse('http://42.194.218.158/v1/message/pinned/sync'),
  );
  syncRequest.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
  syncRequest.headers.set(HttpHeaders.acceptHeader, 'application/json');
  syncRequest.headers.set('appid', 'wukongchat');
  syncRequest.headers.set('timestamp', syncTimestamp);
  syncRequest.headers.set('noncestr', syncNonce);
  syncRequest.headers.set('sign', syncSign);
  syncRequest.headers.set('token', '7dedb28a2cc14e989cc36a2126dd6488');
  syncRequest.headers.set('X-Device-ID', '68de4b448b894ad19d821135f6319dc8');
  syncRequest.headers.set(
    'X-Device-Session-ID',
    '2cb7b37a739448b58baf6fd0b08f7b61',
  );
  syncRequest.write(syncBody);
  final syncResponse = await syncRequest.close();
  final syncResponseBody = await utf8.decodeStream(syncResponse);
  stdout.writeln('syncPinnedStatus=${syncResponse.statusCode}');
  stdout.writeln('syncPinnedBody=$syncResponseBody');

  final configTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final configNonce = _nonce(16);
  final configSignSource =
      '$configNonce$configTimestamp${'25b002c6be2d539f264c'}';
  final configSign =
      crypto.md5.convert(utf8.encode(configSignSource)).toString();
  final configRequest = await client.getUrl(
    Uri.parse('http://42.194.218.158/v1/manager/common/appconfig'),
  );
  configRequest.headers.set(HttpHeaders.acceptHeader, 'application/json');
  configRequest.headers.set('appid', 'wukongchat');
  configRequest.headers.set('timestamp', configTimestamp);
  configRequest.headers.set('noncestr', configNonce);
  configRequest.headers.set('sign', configSign);
  configRequest.headers.set('token', '7dedb28a2cc14e989cc36a2126dd6488');
  configRequest.headers.set('X-Device-ID', '68de4b448b894ad19d821135f6319dc8');
  configRequest.headers.set(
    'X-Device-Session-ID',
    '2cb7b37a739448b58baf6fd0b08f7b61',
  );
  final configResponse = await configRequest.close();
  final configResponseBody = await utf8.decodeStream(configResponse);
  stdout.writeln('appConfigStatus=${configResponse.statusCode}');
  stdout.writeln('appConfigBody=$configResponseBody');
  client.close(force: true);
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
