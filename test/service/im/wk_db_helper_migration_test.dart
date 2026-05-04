import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukongimfluttersdk/common/options.dart' as wk;
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'onUpgrade completes when a pre-message-extra database loses its migration version marker',
    () async {
      final uid =
          'wk_db_partial_${DateTime.now().microsecondsSinceEpoch.toString()}';
      WKIM.shared.options = wk.Options.newDefault(uid, 'token');

      final db = await _openTempDatabase('partial');
      addTearDown(() async {
        await db.close();
      });

      await _applySqlFile(
        db,
        '../TangSengDaoDao/WuKongIMFlutterSDK-master/assets/202008292051.sql',
      );

      await expectLater(WKDBHelper.shared.onUpgrade(db), completes);

      expect(await _hasTable(db, 'message_extra'), isTrue);
      expect(await _hasTable(db, 'conversation_extra'), isTrue);
      expect(await _hasColumn(db, 'message', 'expire_time'), isTrue);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('wk_max_sql_version_$uid'), 202604251100);
    },
  );

  test(
    'onUpgrade is idempotent when the latest database loses its migration version marker',
    () async {
      final uid =
          'wk_db_latest_${DateTime.now().microsecondsSinceEpoch.toString()}';
      WKIM.shared.options = wk.Options.newDefault(uid, 'token');

      final db = await _openTempDatabase('latest');
      addTearDown(() async {
        await db.close();
      });

      await expectLater(WKDBHelper.shared.onUpgrade(db), completes);

      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('wk_max_sql_version_$uid');

      await expectLater(WKDBHelper.shared.onUpgrade(db), completes);

      expect(await _hasTable(db, 'message_extra'), isTrue);
      expect(await _hasColumn(db, 'message_extra', 'is_pinned'), isTrue);
    },
  );

  test('onUpgrade backfills server_msg_id from legacy message_id', () async {
    final uid =
        'wk_db_backfill_${DateTime.now().microsecondsSinceEpoch.toString()}';
    WKIM.shared.options = wk.Options.newDefault(uid, 'token');

    final db = await _openTempDatabase('backfill');
    addTearDown(() async {
      await db.close();
    });

    await _applySqlFile(
      db,
      '../TangSengDaoDao/WuKongIMFlutterSDK-master/assets/202008292051.sql',
    );
    await db.insert('message', <String, Object>{
      'message_id': 'm100',
      'channel_id': 'ch1',
      'channel_type': 1,
      'timestamp': 1700000000,
      'from_uid': 'u1',
      'type': 1,
      'content': '{"type":1,"content":"legacy"}',
      'status': 1,
      'voice_status': 0,
      'client_msg_no': 'legacy_c1',
      'is_deleted': 0,
      'setting': 0,
      'order_seq': 1,
      'extra': '',
    });

    await expectLater(WKDBHelper.shared.onUpgrade(db), completes);

    expect(await _hasColumn(db, 'message', 'server_msg_id'), isTrue);
    final rows = await db.rawQuery(
      'SELECT message_id, server_msg_id FROM message WHERE message_id=? LIMIT 1',
      <Object>['m100'],
    );
    expect(rows, isNotEmpty);
    expect(rows.first['server_msg_id'], 'm100');
    expect(await _hasIndex(db, 'idx_message_server_msg_id'), isTrue);
  });

  test(
    'onUpgrade collapses duplicates and preserves conversation last_client_msg_no linkage',
    () async {
      final uid =
          'wk_db_dupe_${DateTime.now().microsecondsSinceEpoch.toString()}';
      WKIM.shared.options = wk.Options.newDefault(uid, 'token');

      final db = await _openTempDatabase('duplicate_backfill');
      addTearDown(() async {
        await db.close();
      });

      await _applySqlFile(
        db,
        '../TangSengDaoDao/WuKongIMFlutterSDK-master/assets/202008292051.sql',
      );

      await db.insert('message', <String, Object>{
        'message_id': 'm-dup',
        'channel_id': 'ch-dup',
        'channel_type': 1,
        'timestamp': 1700000000,
        'from_uid': 'u1',
        'type': 1,
        'content': '{"type":1,"content":"legacy-1"}',
        'status': 1,
        'voice_status': 0,
        'client_msg_no': 'legacy_dup_1',
        'is_deleted': 0,
        'setting': 0,
        'order_seq': 1,
        'extra': '',
      });

      await db.insert('message', <String, Object>{
        'message_id': 'm-dup',
        'channel_id': 'ch-dup',
        'channel_type': 1,
        'timestamp': 1700000001,
        'from_uid': 'u2',
        'type': 1,
        'content': '{"type":1,"content":"legacy-2"}',
        'status': 1,
        'voice_status': 0,
        'client_msg_no': 'legacy_dup_2',
        'is_deleted': 0,
        'setting': 0,
        'order_seq': 2,
        'extra': '',
      });

      await db.insert('conversation', <String, Object>{
        'channel_id': 'ch-dup',
        'channel_type': 1,
        'last_client_msg_no': 'legacy_dup_2',
        'last_msg_timestamp': 1700000001,
        'unread_count': 0,
        'is_deleted': 0,
        'version': 1,
        'extra': '',
      });

      await expectLater(WKDBHelper.shared.onUpgrade(db), completes);

      expect(await _hasColumn(db, 'message', 'server_msg_id'), isTrue);
      expect(await _hasIndex(db, 'idx_message_server_msg_id'), isTrue);

      final rows = await db.rawQuery(
        '''
SELECT client_seq, server_msg_id
FROM message
WHERE channel_id=? AND channel_type=? AND message_id=?
ORDER BY client_seq ASC
''',
        <Object>['ch-dup', 1, 'm-dup'],
      );

      expect(rows.length, 1);
      expect(rows.single['server_msg_id'], 'm-dup');

      final conversationRows = await db.rawQuery(
        '''
SELECT last_client_msg_no
FROM conversation
WHERE channel_id=? AND channel_type=?
LIMIT 1
''',
        <Object>['ch-dup', 1],
      );
      expect(conversationRows, isNotEmpty);
      final lastClientMsgNo =
          conversationRows.single['last_client_msg_no']?.toString() ?? '';
      expect(lastClientMsgNo, 'legacy_dup_1');

      final pointerRows = await db.rawQuery(
        '''
SELECT 1
FROM message
WHERE channel_id=? AND channel_type=? AND client_msg_no=?
LIMIT 1
''',
        <Object>['ch-dup', 1, lastClientMsgNo],
      );
      expect(pointerRows, isNotEmpty);
    },
  );

  test(
    'onUpgrade adds hardened indexes for message pagination and conversation sorting',
    () async {
      final uid =
          'wk_db_index_${DateTime.now().microsecondsSinceEpoch.toString()}';
      WKIM.shared.options = wk.Options.newDefault(uid, 'token');

      final db = await _openTempDatabase('index_hardening');
      addTearDown(() async {
        await db.close();
      });

      await _applySqlFile(
        db,
        '../TangSengDaoDao/WuKongIMFlutterSDK-master/assets/202008292051.sql',
      );

      await expectLater(WKDBHelper.shared.onUpgrade(db), completes);

      expect(await _hasIndex(db, 'idx_message_channel_seq'), isTrue);
      expect(await _hasIndex(db, 'idx_conversation_sort'), isTrue);
    },
  );
}

Future<Database> _openTempDatabase(String name) async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'wk_db_helper_migration_test_',
  );
  final dbPath = p.join(tempDirectory.path, '$name.db');
  return openDatabase(dbPath, version: 1);
}

Future<void> _applySqlFile(Database db, String relativePath) async {
  final file = File(p.normalize(p.join(Directory.current.path, relativePath)));
  final rawSql = await file.readAsString();
  for (final statement in _splitSqlStatements(rawSql)) {
    await db.execute(statement);
  }
}

Iterable<String> _splitSqlStatements(String rawSql) sync* {
  for (final statement in rawSql.split(';')) {
    final normalized = statement.replaceAll('\r', '').trim();
    if (normalized.isNotEmpty) {
      yield normalized;
    }
  }
}

Future<bool> _hasTable(Database db, String tableName) async {
  final rows = await db.rawQuery(
    "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
    <Object>[tableName],
  );
  return rows.isNotEmpty;
}

Future<bool> _hasColumn(
  Database db,
  String tableName,
  String columnName,
) async {
  final rows = await db.rawQuery("PRAGMA table_info('$tableName')");
  return rows.any((row) => row['name']?.toString() == columnName);
}

Future<bool> _hasIndex(Database db, String indexName) async {
  final rows = await db.rawQuery(
    "SELECT 1 FROM sqlite_master WHERE type='index' AND name=? LIMIT 1",
    <Object>[indexName],
  );
  return rows.isNotEmpty;
}
