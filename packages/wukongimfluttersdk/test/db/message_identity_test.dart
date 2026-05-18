import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukongimfluttersdk/common/mode.dart';
import 'package:wukongimfluttersdk/common/options.dart';
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/db/message.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('message identity upsert', () {
    late String uid;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      uid = 'message_identity_${DateTime.now().microsecondsSinceEpoch}';
      WKIM.shared.runMode = Model.app;
      WKIM.shared.options = Options.newDefault(uid, 'token');
      await _deleteDatabaseForUid(uid);
      final initResult = await WKDBHelper.shared.init();
      expect(initResult, isTrue);
    });

    tearDown(() async {
      WKDBHelper.shared.close();
      await _deleteDatabaseForUid(uid);
    });

    test('pending ack merges into single record by client_msg_no fallback',
        () async {
      await MessageDB.shared.insert(
        _buildMessage(clientMsgNo: 'c1', contentText: 'pending'),
      );
      await MessageDB.shared.insert(
        _buildMessage(
          clientMsgNo: 'c1',
          serverMsgId: 's100',
          messageId: 'm100',
          messageSeq: 100,
          orderSeq: 100000,
          contentText: 'ack',
        ),
      );

      final rows = await _queryAllMessageRows();
      expect(rows.length, 1);
      expect(rows.first['client_msg_no'], 'c1');
      expect(rows.first['server_msg_id'], 's100');
      expect(rows.first['is_deleted'], 0);
    });

    test('same server_msg_id with different client_msg_no does not create dup',
        () async {
      await MessageDB.shared.insert(
        _buildMessage(
          clientMsgNo: 'c1',
          serverMsgId: 's100',
          messageId: 'm100',
          messageSeq: 100,
          orderSeq: 100000,
          contentText: 'first',
        ),
      );
      await MessageDB.shared.insert(
        _buildMessage(
          clientMsgNo: 'c2',
          serverMsgId: 's100',
          messageId: 'm100_dup',
          messageSeq: 100,
          orderSeq: 100000,
          contentText: 'duplicate',
        ),
      );

      final rows = await _queryAllMessageRows();
      expect(rows.length, 1);
      expect(rows.first['server_msg_id'], 's100');
      expect(rows.first['is_deleted'], 0);
    });

    test('batch insert keeps pending and ack as one logical message', () async {
      await MessageDB.shared.insert(
        _buildMessage(clientMsgNo: 'c1', contentText: 'pending'),
      );

      await MessageDB.shared.insertMsgList(<WKMsg>[
        _buildMessage(
          clientMsgNo: 'c1',
          serverMsgId: 's100',
          messageId: 'm100',
          messageSeq: 100,
          orderSeq: 100000,
          contentText: 'ack',
        ),
        _buildMessage(
          clientMsgNo: 'c2',
          serverMsgId: 's100',
          messageId: 'm100_dup',
          messageSeq: 100,
          orderSeq: 100000,
          contentText: 'duplicate packet',
        ),
      ]);

      final rows = await _queryAllMessageRows();
      expect(rows.length, 1);
      expect(rows.first['client_msg_no'], 'c1');
      expect(rows.first['server_msg_id'], 's100');
      expect(rows.first['is_deleted'], 0);
    });

    test(
        'legacy migrated row backfilled to server_msg_id merges replay by server identity',
        () async {
      await _insertLegacyRowWithoutServerMsgId(
        messageId: 'm100',
        clientMsgNo: 'legacy_c1',
      );
      await _rerunMigrations(uid);

      await MessageDB.shared.insert(
        _buildMessage(
          clientMsgNo: 'replay_c2',
          serverMsgId: 'm100',
          messageId: 'm100',
          messageSeq: 100,
          orderSeq: 100000,
          contentText: 'replay packet',
        ),
      );

      final rows = await _queryAllMessageRows();
      expect(rows.length, 1);
      expect(rows.first['message_id'], 'm100');
      expect(rows.first['server_msg_id'], 'm100');
    });

    test('message extra batch update keeps each row payload isolated',
        () async {
      await MessageDB.shared.insertMsgExtras(<WKMsgExtra>[
        _buildExtra(messageId: 'm1', readedCount: 1),
        _buildExtra(messageId: 'm2', readedCount: 2),
      ]);

      await MessageDB.shared.insertOrUpdateMsgExtras(<WKMsgExtra>[
        _buildExtra(messageId: 'm1', readedCount: 10),
        _buildExtra(messageId: 'm2', readedCount: 20),
      ]);

      final first = await MessageDB.shared.queryMsgExtraWithMsgID('m1');
      final second = await MessageDB.shared.queryMsgExtraWithMsgID('m2');

      expect(first?.readedCount, 10);
      expect(second?.readedCount, 20);
      expect(second?.messageID, 'm2');
    });
  });
}

WKMsg _buildMessage({
  required String clientMsgNo,
  String serverMsgId = '',
  String messageId = '',
  int messageSeq = 0,
  int orderSeq = 1,
  String contentText = 'hello',
}) {
  final message = WKMsg()
    ..clientMsgNO = clientMsgNo
    ..serverMsgID = serverMsgId
    ..messageID = messageId
    ..messageSeq = messageSeq
    ..channelID = 'ch1'
    ..channelType = WKChannelType.personal
    ..fromUID = 'u1'
    ..timestamp = 1700000000
    ..orderSeq = orderSeq
    ..contentType = WkMessageContentType.text
    ..content = '{"type":1,"content":"$contentText"}'
    ..status = WKSendMsgResult.sendSuccess
    ..isDeleted = 0;
  return message;
}

WKMsgExtra _buildExtra({
  required String messageId,
  required int readedCount,
}) {
  return WKMsgExtra()
    ..messageID = messageId
    ..channelID = 'ch1'
    ..channelType = WKChannelType.personal
    ..readedCount = readedCount;
}

Future<void> _deleteDatabaseForUid(String uid) async {
  final databasesPath = await getDatabasesPath();
  final dbPath = p.join(databasesPath, 'wk_$uid.db');
  if (File(dbPath).existsSync()) {
    await deleteDatabase(dbPath);
  }
}

Future<List<Map<String, Object?>>> _queryAllMessageRows() async {
  final db = WKDBHelper.shared.getDB();
  if (db == null) {
    return <Map<String, Object?>>[];
  }
  return db.query(
    WKDBConst.tableMessage,
    orderBy: 'client_seq ASC',
  );
}

Future<void> _insertLegacyRowWithoutServerMsgId({
  required String messageId,
  required String clientMsgNo,
}) async {
  final db = WKDBHelper.shared.getDB();
  if (db == null) {
    throw StateError('database not initialized');
  }
  await db.insert(WKDBConst.tableMessage, <String, Object>{
    'message_id': messageId,
    'server_msg_id': '',
    'channel_id': 'ch1',
    'channel_type': WKChannelType.personal,
    'from_uid': 'u1',
    'type': WkMessageContentType.text,
    'content': '{"type":1,"content":"legacy"}',
    'status': WKSendMsgResult.sendSuccess,
    'client_msg_no': clientMsgNo,
    'timestamp': 1700000000,
    'order_seq': 1,
    'is_deleted': 0,
    'setting': 0,
    'extra': '',
  });
}

Future<void> _rerunMigrations(String uid) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.remove('wk_max_sql_version_$uid');
  final db = WKDBHelper.shared.getDB();
  if (db == null) {
    throw StateError('database not initialized');
  }
  await WKDBHelper.shared.onUpgrade(db);
}
