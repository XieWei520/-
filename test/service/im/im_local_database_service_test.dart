import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukong_im_app/service/im/im_local_database_service.dart';
import 'package:wukong_im_app/service/im/message_outbox.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ImLocalDatabaseService', () {
    test(
      'returns false without opening a database when persistence is off',
      () async {
        var opened = false;
        final service = ImLocalDatabaseService(
          usesLocalPersistence: () => false,
          databaseReader: () => null,
          databaseOpener: () async {
            opened = true;
            return true;
          },
        );

        expect(await service.ensureReady(), isFalse);
        expect(opened, isFalse);
      },
    );

    test('ensures outbox schema when required tables already exist', () async {
      final db = await openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await _createRequiredTables(db);

      final service = ImLocalDatabaseService(
        usesLocalPersistence: () => true,
        databaseReader: () => db,
        databaseOpener: () async => true,
      );

      expect(await service.ensureReady(), isTrue);
      expect(await _hasTable(db, MessageOutboxSchema.tableName), isTrue);
      expect(await _hasIndex(db, MessageOutboxSchema.clientMsgNoIndex), isTrue);
    });

    test(
      'runs SDK migrations and waits for required tables when schema is incomplete',
      () async {
        final db = await openDatabase(inMemoryDatabasePath);
        addTearDown(db.close);
        var migrated = false;
        var delayCount = 0;
        final service = ImLocalDatabaseService(
          usesLocalPersistence: () => true,
          databaseReader: () => db,
          databaseOpener: () async => true,
          sdkMigrator: (database) async {
            migrated = true;
            await _createRequiredTables(database);
            return true;
          },
          delay: (_) async {
            delayCount++;
          },
        );

        expect(await service.ensureReady(), isTrue);
        expect(migrated, isTrue);
        expect(delayCount, 0);
        expect(await _hasTable(db, MessageOutboxSchema.tableName), isTrue);
      },
    );

    test('returns false when the database cannot be reopened', () async {
      final service = ImLocalDatabaseService(
        usesLocalPersistence: () => true,
        databaseReader: () => null,
        databaseOpener: () async => false,
      );

      expect(await service.ensureReady(), isFalse);
    });

    test('returns false when outbox schema creation fails', () async {
      final db = await openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await _createRequiredTables(db);

      final service = ImLocalDatabaseService(
        usesLocalPersistence: () => true,
        databaseReader: () => db,
        databaseOpener: () async => true,
        outboxSchemaEnsurer: (_) async {
          throw StateError('outbox schema failed');
        },
      );

      expect(await service.ensureReady(), isFalse);
    });
  });
}

Future<void> _createRequiredTables(Database db) async {
  await db.execute('CREATE TABLE IF NOT EXISTS message (id INTEGER)');
  await db.execute('CREATE TABLE IF NOT EXISTS channel (id INTEGER)');
  await db.execute('CREATE TABLE IF NOT EXISTS conversation (id INTEGER)');
  await db.execute('CREATE TABLE IF NOT EXISTS message_extra (id INTEGER)');
}

Future<bool> _hasTable(Database db, String tableName) async {
  final rows = await db.rawQuery(
    "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
    <Object>[tableName],
  );
  return rows.isNotEmpty;
}

Future<bool> _hasIndex(Database db, String indexName) async {
  final rows = await db.rawQuery(
    "SELECT 1 FROM sqlite_master WHERE type='index' AND name=? LIMIT 1",
    <Object>[indexName],
  );
  return rows.isNotEmpty;
}
