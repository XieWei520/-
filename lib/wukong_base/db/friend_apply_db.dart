import 'package:sqflite/sqflite.dart';

import '../../data/models/friend.dart';
import 'db_helper.dart';

/// Local database for friend apply/request records.
///
/// Uses the existing `friend_apply_record` table created in [DBHelper].
class FriendApplyDB {
  FriendApplyDB._();
  static final FriendApplyDB instance = FriendApplyDB._();

  static const String table = 'friend_apply_record';

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<Database> get _db async => DBHelper.instance.database;

  Map<String, Object?> _toRow(FriendRequest r) {
    return {
      'uid': r.fromUid,
      'to_uid': r.toUid ?? '',
      'remark': r.extra ?? '',
      'status': r.status ?? 0,
      'token': r.token ?? '',
      'created_at': r.createdAt ?? 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
  }

  FriendRequest _fromRow(Map<String, Object?> row) {
    return FriendRequest(
      id: row['id'] as int? ?? 0,
      fromUid: row['uid'] as String? ?? '',
      toUid: row['to_uid'] as String?,
      status: row['status'] as int?,
      token: row['token'] as String?,
      extra: row['remark'] as String?,
      createdAt: row['created_at'] as int?,
    );
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Insert or update a single friend request.
  Future<void> insertOrUpdate(FriendRequest request) async {
    final db = await _db;
    final existing = await db.query(
      table,
      where: 'uid = ? AND to_uid = ?',
      whereArgs: [request.fromUid, request.toUid ?? ''],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        table,
        _toRow(request),
        where: 'uid = ? AND to_uid = ?',
        whereArgs: [request.fromUid, request.toUid ?? ''],
      );
    } else {
      await db.insert(table, _toRow(request));
    }
  }

  /// Batch insert or replace friend requests inside a transaction.
  Future<void> insertOrUpdateAll(List<FriendRequest> requests) async {
    if (requests.isEmpty) return;
    final db = await _db;
    await db.transaction((txn) async {
      for (final r in requests) {
        final existing = await txn.query(
          table,
          where: 'uid = ? AND to_uid = ?',
          whereArgs: [r.fromUid, r.toUid ?? ''],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          await txn.update(
            table,
            _toRow(r),
            where: 'uid = ? AND to_uid = ?',
            whereArgs: [r.fromUid, r.toUid ?? ''],
          );
        } else {
          await txn.insert(table, _toRow(r));
        }
      }
    });
  }

  /// Query all friend requests, most recent first.
  Future<List<FriendRequest>> queryAll() async {
    final db = await _db;
    final rows = await db.query(
      table,
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Query pending friend requests.
  Future<List<FriendRequest>> queryPending() async {
    final db = await _db;
    final rows = await db.query(
      table,
      where: 'status = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Update the status of a friend request by fromUid.
  Future<void> updateStatus(String fromUid, int status) async {
    if (fromUid.isEmpty) return;
    final db = await _db;
    await db.update(
      table,
      {
        'status': status,
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      where: 'uid = ?',
      whereArgs: [fromUid],
    );
  }

  /// Delete a friend request by fromUid.
  Future<void> deleteByUid(String fromUid) async {
    if (fromUid.isEmpty) return;
    final db = await _db;
    await db.delete(table, where: 'uid = ?', whereArgs: [fromUid]);
  }

  /// Delete all friend requests (used on logout).
  Future<void> deleteAll() async {
    final db = await _db;
    await db.delete(table);
  }
}
