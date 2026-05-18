import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';

import 'message_outbox.dart';

typedef ImLocalPersistencePolicy = bool Function();
typedef ImLocalDatabaseReader = Database? Function();
typedef ImLocalDatabaseOpener = Future<bool> Function();
typedef ImSdkDatabaseMigrator = Future<bool> Function(Database db);
typedef ImOutboxSchemaEnsurer = Future<void> Function(Database db);
typedef ImLocalDatabaseDelay = Future<void> Function(Duration duration);

class ImLocalDatabaseService {
  ImLocalDatabaseService({
    required ImLocalPersistencePolicy usesLocalPersistence,
    ImLocalDatabaseReader? databaseReader,
    ImLocalDatabaseOpener? databaseOpener,
    ImSdkDatabaseMigrator? sdkMigrator,
    ImOutboxSchemaEnsurer? outboxSchemaEnsurer,
    ImLocalDatabaseDelay? delay,
  }) : _usesLocalPersistence = usesLocalPersistence,
       _databaseReader = databaseReader ?? WKDBHelper.shared.getDB,
       _databaseOpener = databaseOpener ?? WKDBHelper.shared.init,
       _sdkMigrator = sdkMigrator ?? WKDBHelper.shared.onUpgrade,
       _outboxSchemaEnsurer = outboxSchemaEnsurer ?? ensureMessageOutboxSchema,
       _delay = delay ?? Future<void>.delayed;

  static const Set<String> requiredTables = <String>{
    'message',
    'channel',
    'conversation',
    'message_extra',
  };

  final ImLocalPersistencePolicy _usesLocalPersistence;
  final ImLocalDatabaseReader _databaseReader;
  final ImLocalDatabaseOpener _databaseOpener;
  final ImSdkDatabaseMigrator _sdkMigrator;
  final ImOutboxSchemaEnsurer _outboxSchemaEnsurer;
  final ImLocalDatabaseDelay _delay;

  Future<bool> ensureReady() async {
    if (!_usesLocalPersistence()) {
      return false;
    }

    if (_databaseReader() == null) {
      final reopened = await _databaseOpener();
      if (!reopened) {
        return false;
      }
    }

    final db = _databaseReader();
    if (db == null) {
      return false;
    }

    if (await hasRequiredTables(db)) {
      return _ensureOutboxSchema(db);
    }

    final migrated = await _applySdkMigrations(db);
    if (!migrated) {
      return false;
    }

    final ready = await waitForRequiredTables();
    if (!ready) {
      return false;
    }

    final migratedDb = _databaseReader();
    if (migratedDb == null) {
      return false;
    }
    return _ensureOutboxSchema(migratedDb);
  }

  Future<bool> hasRequiredTables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final names = rows
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
    return requiredTables.every(names.contains);
  }

  Future<bool> waitForRequiredTables() async {
    for (var index = 0; index < 20; index++) {
      final db = _databaseReader();
      if (db != null && await hasRequiredTables(db)) {
        return true;
      }
      await _delay(const Duration(milliseconds: 100));
    }
    return false;
  }

  Future<bool> _ensureOutboxSchema(Database db) async {
    try {
      await _outboxSchemaEnsurer(db);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Ensuring message outbox schema failed: $error');
      debugPrint('$stackTrace');
      return false;
    }
  }

  Future<bool> _applySdkMigrations(Database db) async {
    try {
      return await _sdkMigrator(db);
    } catch (error, stackTrace) {
      debugPrint('Applying SDK migrations failed: $error');
      debugPrint('$stackTrace');
      return false;
    }
  }
}
