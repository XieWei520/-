import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukongimfluttersdk/common/mode.dart';
import 'package:wukongimfluttersdk/common/options.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WKDBHelper migrations', () {
    late String uid;
    late String dbPath;
    late Database db;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      uid = 'migration_no_fts_${DateTime.now().microsecondsSinceEpoch}';
      WKIM.shared.runMode = Model.app;
      WKIM.shared.options = Options.newDefault(uid, 'token');
      dbPath = p.join(await getDatabasesPath(), 'wk_$uid.db');
      if (File(dbPath).existsSync()) {
        await deleteDatabase(dbPath);
      }
      db = await openDatabase(dbPath, version: 1);
    });

    tearDown(() async {
      await db.close();
      if (File(dbPath).existsSync()) {
        await deleteDatabase(dbPath);
      }
    });

    test('continues core migrations when sqlite does not provide FTS5',
        () async {
      final androidLikeDb = _Fts5UnavailableDatabase(db);
      final result = await WKDBHelper.shared.onUpgrade(androidLikeDb);

      expect(result, isTrue);
      final tables = await _tableNames(db);
      expect(
        tables,
        containsAll(<String>{
          'message',
          'channel',
          'conversation',
          'message_extra',
        }),
      );
      expect(tables, isNot(contains('message_fts')));
      expect(androidLikeDb.ftsCreateAttempts, 0);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('wk_max_sql_version_$uid'), 202604271430);
    });
  });
}

Future<Set<String>> _tableNames(Database db) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table'",
  );
  return rows
      .map((row) => row['name']?.toString() ?? '')
      .where((name) => name.isNotEmpty)
      .toSet();
}

class _Fts5UnavailableDatabase implements Database {
  _Fts5UnavailableDatabase(this._delegate);

  final Database _delegate;
  int ftsCreateAttempts = 0;

  @override
  String get path => _delegate.path;

  @override
  bool get isOpen => _delegate.isOpen;

  @override
  Database get database => this;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    if (RegExp(r'\busing\s+fts5\b', caseSensitive: false).hasMatch(sql)) {
      ftsCreateAttempts += 1;
      throw Exception('DatabaseException(no such module: fts5)');
    }
    return _delegate.execute(sql, arguments);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    if (sql.trim().toLowerCase() == 'pragma compile_options') {
      return Future<List<Map<String, Object?>>>.value(
        const <Map<String, Object?>>[
          <String, Object?>{'compile_options': 'THREADSAFE=1'},
        ],
      );
    }
    return _delegate.rawQuery(sql, arguments);
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) =>
      _delegate.rawInsert(sql, arguments);

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      _delegate.rawUpdate(sql, arguments);

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) =>
      _delegate.rawDelete(sql, arguments);

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _delegate.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      );

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      _delegate.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _delegate.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      );

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) =>
      _delegate.delete(table, where: where, whereArgs: whereArgs);

  @override
  Batch batch() => _delegate.batch();

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) =>
      _delegate.rawQueryCursor(sql, arguments, bufferSize: bufferSize);

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) =>
      _delegate.queryCursor(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
        bufferSize: bufferSize,
      );

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) =>
      _delegate.transaction(action, exclusive: exclusive);

  @override
  Future<T> readTransaction<T>(Future<T> Function(Transaction txn) action) =>
      _delegate.readTransaction(action);

  @override
  Future<void> close() => _delegate.close();

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) =>
      _delegate.devInvokeMethod(method, arguments);

  @override
  Future<T> devInvokeSqlMethod<T>(
    String method,
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _delegate.devInvokeSqlMethod(method, sql, arguments);
}
