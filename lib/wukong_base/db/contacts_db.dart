import 'package:sqflite/sqflite.dart';

import '../../data/models/friend.dart';
import 'db_helper.dart';

/// Local database for contacts (friends).
///
/// Provides offline access to the friend list and incremental sync
/// via the `version` column.
class ContactsDB {
  ContactsDB._();
  static final ContactsDB instance = ContactsDB._();

  static const String table = 'contacts';

  // ---------------------------------------------------------------------------
  // DDL
  // ---------------------------------------------------------------------------

  /// Called from [DBHelper._onUpgrade] when migrating to version 2+.
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        uid             TEXT    NOT NULL DEFAULT '',
        name            TEXT    NOT NULL DEFAULT '',
        avatar          TEXT    NOT NULL DEFAULT '',
        remark          TEXT    NOT NULL DEFAULT '',
        category        TEXT    NOT NULL DEFAULT '',
        status          INTEGER NOT NULL DEFAULT 0,
        robot           INTEGER NOT NULL DEFAULT 0,
        be_deleted      INTEGER NOT NULL DEFAULT 0,
        be_blacklist    INTEGER NOT NULL DEFAULT 0,
        is_upload_avatar INTEGER NOT NULL DEFAULT 0,
        created_at      INTEGER NOT NULL DEFAULT 0,
        updated_at      INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_contacts_uid ON $table (uid)',
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<Database> get _db async => DBHelper.instance.database;

  Map<String, Object?> _toRow(Friend f) {
    return {
      'uid': f.uid,
      'name': f.name ?? '',
      'avatar': f.avatar ?? '',
      'remark': f.remark ?? '',
      'category': f.category ?? '',
      'status': f.status ?? 0,
      'robot': f.robot ?? 0,
      'be_deleted': f.beDeleted ?? 0,
      'be_blacklist': f.beBlacklist ?? 0,
      'is_upload_avatar': f.isUploadAvatar ?? 0,
      'created_at': f.createdAt ?? 0,
      'updated_at': f.updatedAt ?? 0,
    };
  }

  Friend _fromRow(Map<String, Object?> row) {
    return Friend(
      uid: row['uid'] as String? ?? '',
      name: row['name'] as String?,
      avatar: row['avatar'] as String?,
      remark: row['remark'] as String?,
      category: row['category'] as String?,
      status: row['status'] as int?,
      robot: row['robot'] as int?,
      beDeleted: row['be_deleted'] as int?,
      beBlacklist: row['be_blacklist'] as int?,
      isUploadAvatar: row['is_upload_avatar'] as int?,
      createdAt: row['created_at'] as int?,
      updatedAt: row['updated_at'] as int?,
    );
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Insert or replace a single contact.
  Future<void> insertOrUpdate(Friend friend) async {
    final db = await _db;
    await db.insert(
      table,
      _toRow(friend),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Batch insert or replace contacts inside a transaction.
  Future<void> insertOrUpdateAll(List<Friend> friends) async {
    if (friends.isEmpty) return;
    final db = await _db;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final f in friends) {
        batch.insert(
          table,
          _toRow(f),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Query all non-deleted contacts.
  Future<List<Friend>> queryAll() async {
    final db = await _db;
    final rows = await db.query(
      table,
      where: 'be_deleted = ?',
      whereArgs: [0],
      orderBy: 'name ASC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Query a single contact by uid.
  Future<Friend?> queryByUid(String uid) async {
    if (uid.isEmpty) return null;
    final db = await _db;
    final rows = await db.query(
      table,
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// Mark a contact as deleted by uid.
  Future<void> markDeleted(String uid) async {
    if (uid.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update(
      table,
      {'be_deleted': 1, 'updated_at': now},
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  /// Delete a contact row by uid (hard delete).
  Future<void> deleteByUid(String uid) async {
    if (uid.isEmpty) return;
    final db = await _db;
    await db.delete(table, where: 'uid = ?', whereArgs: [uid]);
  }

  /// Delete all contacts (used on logout).
  Future<void> deleteAll() async {
    final db = await _db;
    await db.delete(table);
  }
}
