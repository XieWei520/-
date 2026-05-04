import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukong_im_app/modules/search/data/search_local_timeline_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'background date bucket runner reads buckets from a fresh db connection',
    () async {
      final db = await _openTimelineDb();
      addTearDown(db.close);
      await _insertMessage(
        db,
        messageId: 'm1',
        channelId: 'c1',
        channelType: 1,
        timestamp: DateTime(2026, 4, 1, 9).millisecondsSinceEpoch ~/ 1000,
        orderSeq: 1000,
      );
      await _insertMessage(
        db,
        messageId: 'm2',
        channelId: 'c1',
        channelType: 1,
        timestamp: DateTime(2026, 4, 1, 10).millisecondsSinceEpoch ~/ 1000,
        orderSeq: 2000,
      );
      await _insertMessage(
        db,
        messageId: 'm3',
        channelId: 'c1',
        channelType: 1,
        timestamp: DateTime(2026, 4, 2, 10).millisecondsSinceEpoch ~/ 1000,
        orderSeq: 3000,
        revoked: true,
      );

      final runner = SearchDateBucketQueryRunner();
      final rows = await runner.run(
        database: db,
        sql: loadDateBucketsSql,
        arguments: const <Object?>['c1', 1],
        forceBackground: true,
      );

      expect(rows, hasLength(1));
      expect(rows.single['day_key'], '2026-04-01');
      expect(rows.single['message_count'], 2);
      expect(rows.single['anchor_order_seq'], 2000);
    },
  );

  test(
    'local timeline data source delegates SQL through injected runner',
    () async {
      final database = _FakeDatabase();
      final source = SearchLocalTimelineDataSource(
        databaseProvider: () => database,
        queryRunner: _CapturingDateBucketQueryRunner(
          rows: const <Map<String, Object?>>[
            <String, Object?>{
              'day_key': '2026-04-03',
              'message_count': '3',
              'anchor_order_seq': 9000,
            },
          ],
        ),
      );

      final buckets = await source.loadDateBuckets(
        channelId: 'c1',
        channelType: 1,
      );

      expect(buckets, hasLength(1));
      expect(buckets.single.dayKey, '2026-04-03');
      expect(buckets.single.messageCount, 3);
      expect(buckets.single.anchorOrderSeq, 9000);
    },
  );
}

class _CapturingDateBucketQueryRunner extends SearchDateBucketQueryRunner {
  _CapturingDateBucketQueryRunner({required this.rows});

  final List<Map<String, Object?>> rows;

  @override
  Future<List<Map<String, Object?>>> run({
    required Database database,
    required String sql,
    required List<Object?> arguments,
    bool forceBackground = false,
  }) async {
    expect(database, isA<_FakeDatabase>());
    expect(sql, loadDateBucketsSql);
    expect(arguments, const <Object?>['c1', 1]);
    return rows;
  }
}

class _FakeDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Database> _openTimelineDb() async {
  final directory = await Directory.systemTemp.createTemp(
    'search_timeline_worker_test_',
  );
  final db = await openDatabase(p.join(directory.path, 'timeline.db'));
  await db.execute('''
CREATE TABLE message (
  message_id TEXT PRIMARY KEY,
  channel_id TEXT NOT NULL,
  channel_type INTEGER NOT NULL,
  timestamp INTEGER NOT NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  order_seq INTEGER NOT NULL
)
''');
  await db.execute('''
CREATE TABLE message_extra (
  message_id TEXT PRIMARY KEY,
  revoke INTEGER NOT NULL DEFAULT 0,
  is_mutual_deleted INTEGER NOT NULL DEFAULT 0
)
''');
  return db;
}

Future<void> _insertMessage(
  Database db, {
  required String messageId,
  required String channelId,
  required int channelType,
  required int timestamp,
  required int orderSeq,
  bool revoked = false,
}) async {
  await db.insert('message', <String, Object?>{
    'message_id': messageId,
    'channel_id': channelId,
    'channel_type': channelType,
    'timestamp': timestamp,
    'is_deleted': 0,
    'order_seq': orderSeq,
  });
  await db.insert('message_extra', <String, Object?>{
    'message_id': messageId,
    'revoke': revoked ? 1 : 0,
    'is_mutual_deleted': 0,
  });
}
