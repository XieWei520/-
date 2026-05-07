import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukong_im_app/service/im/message_outbox.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MessageEnvelope', () {
    test(
      'keeps client idempotency id separate from server ordering fields',
      () {
        const envelope = MessageEnvelope(
          clientMsgNo: 'client-1',
          channelId: 'ch1',
          channelType: 1,
          serverMsgId: '',
          messageSeq: 0,
          orderSeq: 1000,
        );

        final acked = envelope.withServerAck(
          serverMsgId: 'server-1',
          messageSeq: 9,
        );

        expect(acked.clientMsgNo, 'client-1');
        expect(acked.serverMsgId, 'server-1');
        expect(acked.messageSeq, 9);
        expect(acked.orderSeq, 9000);
      },
    );
  });

  group('MessageOutboxSchema', () {
    test('creates idempotent outbox table and indexes', () async {
      final db = await openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);

      await ensureMessageOutboxSchema(db);
      await ensureMessageOutboxSchema(db);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        <Object?>[MessageOutboxSchema.tableName],
      );
      expect(tables, isNotEmpty);

      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name=?",
        <Object?>[MessageOutboxSchema.tableName],
      );
      expect(
        indexes.map((row) => row['name']).toSet(),
        containsAll(<String>{
          MessageOutboxSchema.clientMsgNoIndex,
          MessageOutboxSchema.channelOrderIndex,
          MessageOutboxSchema.stateUpdatedIndex,
        }),
      );
    });

    test('serializes outbox record rows with a stable JSON payload', () {
      const record = MessageOutboxRecord(
        envelope: MessageEnvelope(
          clientMsgNo: 'client-1',
          channelId: 'ch1',
          channelType: 1,
          serverMsgId: '',
          messageSeq: 0,
          orderSeq: 1000,
        ),
        state: MessageOutboxState.pending,
        payload: <String, Object?>{'type': 1, 'content': 'hello'},
        retryCount: 2,
        createdAt: 100,
        updatedAt: 200,
      );

      final row = record.toRow();

      expect(row['client_msg_no'], 'client-1');
      expect(row['state'], 'pending');
      expect(jsonDecode(row['payload'] as String), <String, Object?>{
        'type': 1,
        'content': 'hello',
      });
      expect(MessageOutboxRecord.fromRow(row), record);
    });
  });
}
