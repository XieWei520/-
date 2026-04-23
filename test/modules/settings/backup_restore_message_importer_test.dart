import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukongimfluttersdk/common/options.dart' as wk;
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/db/message.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final testUid =
      'backup_restore_importer_test_${DateTime.now().microsecondsSinceEpoch}';

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    WKIM.shared.options = wk.Options.newDefault(testUid, 'token');
    await WKDBHelper.shared.init();
  });

  setUp(() async {
    await _clearImTables();
  });

  tearDownAll(() {
    WKDBHelper.shared.close();
  });

  test(
    'importBackupArchive restores raw-array backups and skips duplicate clientMsgNo values',
    () async {
      final db = WKDBHelper.shared.getDB();
      expect(db, isNotNull);
      final database = db!;

      await database.insert(WKDBConst.tableMessage, <String, Object?>{
        'message_id': 'already_saved',
        'message_seq': 1,
        'channel_id': 'g1',
        'channel_type': 2,
        'timestamp': 1712000000,
        'from_uid': 'u_seed',
        'type': 1,
        'content': '{"type":1,"content":"seed"}',
        'status': 1,
        'voice_status': 0,
        'searchable_word': '',
        'client_msg_no': 'dup_client_msg_no',
        'is_deleted': 0,
        'setting': 0,
        'order_seq': 1000,
        'extra': '',
      });

      final rawArchive = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'channel_id': 'g1',
          'channel_type': 2,
          'message_id': 'm_new_1',
          'message_seq': 10,
          'order_seq': 0,
          'client_msg_no': 'msg_no_1',
          'from_uid': 'u_alice',
          'payload': '{"type":1,"content":"hello"}',
          'timestamp': 1712000100,
        },
        <String, dynamic>{
          'channel_id': 'g1',
          'channel_type': 2,
          'message_id': 'm_dup',
          'message_seq': 11,
          'order_seq': 0,
          'client_msg_no': 'dup_client_msg_no',
          'from_uid': 'u_alice',
          'payload': '{"type":1,"content":"duplicated"}',
          'timestamp': 1712000200,
        },
        <String, dynamic>{
          'channel_id': 'g_skip_empty',
          'channel_type': 2,
          'message_id': 'm_skip_empty',
          'message_seq': 8,
          'order_seq': 0,
          'client_msg_no': '',
          'from_uid': 'u_alice',
          'payload': '{"type":1,"content":"skip-empty-client-msg-no"}',
          'timestamp': 1712000250,
        },
        <String, dynamic>{
          'channel_id': 'u_bob',
          'channel_type': 1,
          'message_id': 'm_new_2',
          'message_seq': 2,
          'order_seq': 0,
          'client_msg_no': 'msg_no_2',
          'from_uid': 'u_bob',
          'payload': '{"type":1,"content":"ping"}',
          'timestamp': 1712000300,
        },
      ]);

      final result = await MessageDB.shared.importBackupArchive(rawArchive);

      expect(result.importedCount, 2);
      expect(result.skippedCount, 2);
      expect(result.conversationCount, 2);

      final importedRows = await database.query(
        WKDBConst.tableMessage,
        where: 'message_id in (?, ?)',
        whereArgs: <Object>['m_new_1', 'm_new_2'],
      );
      expect(importedRows, hasLength(2));

      final firstImported = importedRows.firstWhere(
        (row) => row['message_id'] == 'm_new_1',
      );
      expect(firstImported['order_seq'], 10000);

      final channelRows = await database.query(
        WKDBConst.tableChannel,
        where:
            '(channel_id=? and channel_type=?) or (channel_id=? and channel_type=?)',
        whereArgs: <Object>['g1', 2, 'u_bob', 1],
      );
      expect(channelRows, hasLength(2));

      final conversationRows = await database.query(
        WKDBConst.tableConversation,
        where:
            '(channel_id=? and channel_type=?) or (channel_id=? and channel_type=?)',
        whereArgs: <Object>['g1', 2, 'u_bob', 1],
      );
      expect(conversationRows, hasLength(2));
    },
  );

  test(
    'importBackupArchive keeps legacy envelope compatibility for existing backups',
    () async {
      final db = WKDBHelper.shared.getDB();
      expect(db, isNotNull);
      final database = db!;

      final rawArchive = jsonEncode(<String, dynamic>{
        'schema_version': 2,
        'uid': testUid,
        'created_at': 1712001111,
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'channel_id': 'g_legacy',
            'channel_type': 2,
            'message_id': 'm_legacy',
            'message_seq': 15,
            'order_seq': 0,
            'client_msg_no': 'legacy_msg_no_1',
            'from_uid': 'u_alice',
            'payload': '{"type":1,"content":"legacy"}',
            'timestamp': 1712000150,
          },
        ],
      });

      final result = await MessageDB.shared.importBackupArchive(rawArchive);

      expect(result.importedCount, 1);
      expect(result.skippedCount, 0);
      expect(result.conversationCount, 1);

      final rows = await database.query(
        WKDBConst.tableMessage,
        where: 'message_id=?',
        whereArgs: <Object>['m_legacy'],
      );
      expect(rows, hasLength(1));
    },
  );

  test(
    'importBackupArchive restores explicit status setting and content_type fields from archive rows',
    () async {
      final db = WKDBHelper.shared.getDB();
      expect(db, isNotNull);
      final database = db!;

      final rawArchive = jsonEncode(<String, dynamic>{
        'schema_version': 2,
        'uid': testUid,
        'created_at': 1712002222,
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'channel_id': 'g_mapping',
            'channel_type': 2,
            'message_id': 'm_mapping',
            'message_seq': 21,
            'order_seq': 0,
            'client_msg_no': 'mapping_msg_no_1',
            'from_uid': 'u_map',
            'payload': '{"type":1,"content":"payload-type-is-1"}',
            'content_type': 88,
            'status': 2,
            'setting': 4,
            'timestamp': 1712002300,
          },
        ],
      });

      final result = await MessageDB.shared.importBackupArchive(rawArchive);
      expect(result.importedCount, 1);
      expect(result.skippedCount, 0);
      expect(result.conversationCount, 1);

      final rows = await database.query(
        WKDBConst.tableMessage,
        where: 'message_id=?',
        whereArgs: <Object>['m_mapping'],
        limit: 1,
      );
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row['type'], 88);
      expect(row['status'], 2);
      expect(row['setting'], 4);

      final channelRows = await database.query(
        WKDBConst.tableChannel,
        where: 'channel_id=? and channel_type=?',
        whereArgs: <Object>['g_mapping', 2],
        limit: 1,
      );
      expect(channelRows, hasLength(1));

      final conversationRows = await database.query(
        WKDBConst.tableConversation,
        where: 'channel_id=? and channel_type=?',
        whereArgs: <Object>['g_mapping', 2],
        limit: 1,
      );
      expect(conversationRows, hasLength(1));
    },
  );

  test(
    'importBackupArchive rejects archives with unsupported schema_version',
    () async {
      final rawArchive = jsonEncode(<String, dynamic>{
        'schema_version': 1,
        'uid': testUid,
        'created_at': 1712001111,
        'messages': <Map<String, dynamic>>[],
      });

      expect(
        () => MessageDB.shared.importBackupArchive(rawArchive),
        throwsA(isA<FormatException>()),
      );
    },
  );
}

Future<void> _clearImTables() async {
  final db = WKDBHelper.shared.getDB();
  if (db == null) {
    return;
  }
  await db.delete(WKDBConst.tableMessage);
  await db.delete(WKDBConst.tableMessageExtra);
  await db.delete(WKDBConst.tableConversation);
  await db.delete(WKDBConst.tableConversationExtra);
  await db.delete(WKDBConst.tableChannel);
}
