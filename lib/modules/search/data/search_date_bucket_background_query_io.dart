import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

@immutable
class _SearchDateBucketBackgroundQuery {
  const _SearchDateBucketBackgroundQuery({
    required this.databasePath,
    required this.sql,
    required this.arguments,
  });

  final String databasePath;
  final String sql;
  final List<Object?> arguments;
}

Future<List<Map<String, Object?>>> runSearchDateBucketBackgroundQuery({
  required String databasePath,
  required String sql,
  required List<Object?> arguments,
}) {
  return compute(
    _runSearchDateBucketQuery,
    _SearchDateBucketBackgroundQuery(
      databasePath: databasePath,
      sql: sql,
      arguments: arguments,
    ),
  );
}

Future<List<Map<String, Object?>>> _runSearchDateBucketQuery(
  _SearchDateBucketBackgroundQuery query,
) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await openDatabase(
    query.databasePath,
    readOnly: true,
    singleInstance: false,
  );
  try {
    final rows = await db.rawQuery(query.sql, query.arguments);
    return rows
        .map((row) => Map<String, Object?>.from(row))
        .toList(growable: false);
  } finally {
    await db.close();
  }
}
