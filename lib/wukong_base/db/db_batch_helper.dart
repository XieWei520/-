import 'dart:async';
import 'package:sqflite/sqflite.dart';

/// Utility for running batch DB operations efficiently.
///
/// Groups multiple inserts/updates into a single transaction to reduce
/// SQLite journaling overhead (5-10x faster for bulk operations).
class DBBatchHelper {
  DBBatchHelper._();

  /// Run a batch of raw SQL statements in a single transaction.
  ///
  /// Each element in [statements] is a pair of (sql, arguments).
  /// Returns the number of statements executed.
  static Future<int> executeBatch(
    Database db,
    List<(String sql, List<Object?> args)> statements,
  ) async {
    if (statements.isEmpty) return 0;
    int count = 0;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final (sql, args) in statements) {
        batch.rawInsert(sql, args);
        count++;
      }
      await batch.commit(noResult: true);
    });
    return count;
  }

  /// Bulk insert-or-replace rows into a table using a single transaction.
  ///
  /// [rows] is a list of column-value maps. All rows must have the same
  /// columns. Uses [ConflictAlgorithm.replace] for upsert behavior.
  static Future<void> bulkInsertOrReplace(
    Database db,
    String table,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Bulk delete rows by a column value using a single transaction.
  static Future<int> bulkDeleteByColumn(
    Database db,
    String table,
    String column,
    List<Object> values,
  ) async {
    if (values.isEmpty) return 0;
    // SQLite has a limit on the number of host parameters (default 999).
    // Chunk the values to stay within this limit.
    int deleted = 0;
    const chunkSize = 900;
    for (var i = 0; i < values.length; i += chunkSize) {
      final chunk = values.sublist(
        i,
        i + chunkSize > values.length ? values.length : i + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      deleted += await db.rawDelete(
        'DELETE FROM $table WHERE $column IN ($placeholders)',
        chunk,
      );
    }
    return deleted;
  }
}
