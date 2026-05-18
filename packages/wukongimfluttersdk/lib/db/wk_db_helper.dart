import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../wkim.dart';
import 'sqlite_performance_options.dart';

class WKDBHelper {
  WKDBHelper._privateConstructor();
  static final WKDBHelper _instance = WKDBHelper._privateConstructor();
  static WKDBHelper get shared => _instance;
  static const _requiredTables = [
    'message',
    'channel',
    'conversation',
    'message_extra',
  ];
  static const _messageFtsTable = 'message_fts';
  final dbVersion = 1;
  static const List<String> sqlitePerformancePragmas =
      wkSqlitePerformancePragmas;
  Database? _database;
  Future<bool> init() async {
    var databasesPath = await getDatabasesPath();
    String path = p.join(databasesPath, 'wk_${WKIM.shared.options.uid}.db');
    _database = await openDatabase(
      path,
      version: dbVersion,
      onConfigure: _configureDatabase,
      onCreate: (Database db, int version) async {
        // onUpgrade(db);
      },
      // onUpgrade: (db, oldVersion, newVersion) => {
      //   onUpgrade(db)},
    );
    bool result = await onUpgrade(_database!);
    return _database != null && result;
  }

  Future<void> _configureDatabase(Database db) async {
    await applyWkSqlitePerformancePragmas(db);
  }

  Future<bool> onUpgrade(Database db) async {
    String path = await rootBundle
        .loadString('packages/wukongimfluttersdk/assets/sql.txt');
    List<String> names = path.split(';');
    SharedPreferences preferences = await SharedPreferences.getInstance();
    String wkUid = WKIM.shared.options.uid!;
    int maxVersion = preferences.getInt('wk_max_sql_version_$wkUid') ?? 0;
    if (!await _hasRequiredTables(db)) {
      maxVersion = 0;
    }
    int saveVersion = 0;
    bool? supportsFts5;
    for (int i = 0; i < names.length; i++) {
      final rawVersion = names[i].trim();
      if (rawVersion.isEmpty) {
        continue;
      }
      int version = int.parse(rawVersion);
      if (version > maxVersion) {
        String sqlStr = await rootBundle
            .loadString('packages/wukongimfluttersdk/assets/$version.sql');
        var sqlList = sqlStr.split(';');
        for (String sql in sqlList) {
          String exeSql =
              sql.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
          if (exeSql.isNotEmpty &&
              !await _isMigrationStatementApplied(db, exeSql)) {
            if (_isFts5MigrationStatement(exeSql)) {
              supportsFts5 ??= await _supportsFts5(db);
              if (!supportsFts5) {
                continue;
              }
            }
            try {
              await db.execute(exeSql);
            } catch (error) {
              if (_isFts5MigrationStatement(exeSql) &&
                  _isMissingFts5Module(error)) {
                supportsFts5 = false;
                continue;
              }
              rethrow;
            }
          }
        }
        if (version > saveVersion) {
          saveVersion = version;
        }
      }
    }
    if (saveVersion > 0) {
      await preferences.setInt('wk_max_sql_version_$wkUid', saveVersion);
    }
    return true;
  }

  Future<bool> _hasRequiredTables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final names = rows
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
    return _requiredTables.every(names.contains);
  }

  Future<bool> _isMigrationStatementApplied(Database db, String sql) async {
    final createTableName = _matchCreateTableName(sql);
    if (createTableName != null) {
      return _tableExists(db, createTableName);
    }

    final indexName = _matchCreateIndexName(sql);
    if (indexName != null) {
      return _indexExists(db, indexName);
    }

    final alterTarget = _matchAlterTableAddColumn(sql);
    if (alterTarget != null) {
      return _columnExists(db, alterTarget.tableName, alterTarget.columnName);
    }

    return false;
  }

  Future<bool> _supportsFts5(Database db) async {
    final compileOptionSupport = await _supportsFts5FromCompileOptions(db);
    if (compileOptionSupport != null) {
      return compileOptionSupport;
    }
    try {
      await db.execute(
        'CREATE VIRTUAL TABLE IF NOT EXISTS temp.__wk_fts5_probe '
        'USING fts5(content)',
      );
      await db.execute('DROP TABLE IF EXISTS temp.__wk_fts5_probe');
      return true;
    } catch (error) {
      if (_isMissingFts5Module(error)) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool?> _supportsFts5FromCompileOptions(Database db) async {
    try {
      final rows = await db.rawQuery('PRAGMA compile_options');
      if (rows.isEmpty) {
        return null;
      }
      return rows
          .expand((row) => row.values)
          .whereType<Object>()
          .map((value) => value.toString().toUpperCase())
          .any((option) => option == 'ENABLE_FTS5');
    } catch (_) {
      return null;
    }
  }

  bool _isFts5MigrationStatement(String sql) {
    return RegExp(r'\busing\s+fts5\b', caseSensitive: false).hasMatch(sql) ||
        RegExp(
          '(^|[^a-zA-Z0-9_])'
          '${RegExp.escape(_messageFtsTable)}'
          r'([^a-zA-Z0-9_]|$)',
          caseSensitive: false,
        ).hasMatch(sql);
  }

  bool _isMissingFts5Module(Object error) {
    return error.toString().toLowerCase().contains('no such module: fts5');
  }

  String? _matchCreateTableName(String sql) {
    final match = RegExp(
      r'''^create\s+table\s+(?:if\s+not\s+exists\s+)?[`'"]?([a-zA-Z0-9_]+)[`'"]?\s*\(''',
      caseSensitive: false,
    ).firstMatch(sql);
    return match?.group(1);
  }

  String? _matchCreateIndexName(String sql) {
    final match = RegExp(
      r'''^create\s+(?:unique\s+)?index\s+(?:if\s+not\s+exists\s+)?[`'"]?([a-zA-Z0-9_]+)[`'"]?\s+on\s+[`'"]?[a-zA-Z0-9_]+[`'"]?''',
      caseSensitive: false,
    ).firstMatch(sql);
    return match?.group(1);
  }

  _AlterTableAddColumnTarget? _matchAlterTableAddColumn(String sql) {
    final match = RegExp(
      r'''^alter\s+table\s+[`'"]?([a-zA-Z0-9_]+)[`'"]?\s+add(?:\s+column)?\s+[`'"]?([a-zA-Z0-9_]+)[`'"]?''',
      caseSensitive: false,
    ).firstMatch(sql);
    if (match == null) {
      return null;
    }
    return _AlterTableAddColumnTarget(
      tableName: match.group(1)!,
      columnName: match.group(2)!,
    );
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    final rows = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
      [tableName],
    );
    return rows.isNotEmpty;
  }

  Future<bool> _indexExists(Database db, String indexName) async {
    final rows = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type='index' AND name=? LIMIT 1",
      [indexName],
    );
    return rows.isNotEmpty;
  }

  Future<bool> _columnExists(
    Database db,
    String tableName,
    String columnName,
  ) async {
    if (!await _tableExists(db, tableName)) {
      return false;
    }
    final rows = await db.rawQuery("PRAGMA table_info('$tableName')");
    return rows.any((row) => row['name']?.toString() == columnName);
  }

  Database? getDB() {
    return _database;
  }

  close() {
    WKIM.shared.messageManager.stopExpireMessageCheckTimer();
    if (_database != null) {
      _database!.close();
      _database = null;
    }
  }
}

class _AlterTableAddColumnTarget {
  const _AlterTableAddColumnTarget({
    required this.tableName,
    required this.columnName,
  });

  final String tableName;
  final String columnName;
}
