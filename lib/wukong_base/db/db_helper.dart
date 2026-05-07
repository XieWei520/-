import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../service/im/im_word_sync_models.dart';
import 'contacts_db.dart';

/// Database helper singleton
class DBHelper {
  static DBHelper? _instance;
  static Database? _database;

  DBHelper._();

  static DBHelper get instance {
    _instance ??= DBHelper._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wukong_im.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // User settings table
    await db.execute('''
      CREATE TABLE user_setting (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        to_uid TEXT NOT NULL,
        blacklist INTEGER DEFAULT 0,
        chat_pwd_on INTEGER DEFAULT 0,
        mute INTEGER DEFAULT 0,
        top INTEGER DEFAULT 0,
        receipt INTEGER DEFAULT 1,
        screenshot INTEGER DEFAULT 1,
        revoke_remind INTEGER DEFAULT 1,
        flame INTEGER DEFAULT 0,
        flame_second INTEGER DEFAULT 0,
        remark TEXT DEFAULT '',
        version INTEGER DEFAULT 0,
        created_at INTEGER DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Friend apply record table
    await db.execute('''
      CREATE TABLE friend_apply_record (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        to_uid TEXT NOT NULL,
        remark TEXT DEFAULT '',
        status INTEGER DEFAULT 1,
        token TEXT DEFAULT '',
        created_at INTEGER DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Group setting table
    await db.execute('''
      CREATE TABLE group_setting (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        group_no TEXT NOT NULL,
        chat_pwd_on INTEGER DEFAULT 0,
        mute INTEGER DEFAULT 0,
        top INTEGER DEFAULT 0,
        show_nick INTEGER DEFAULT 1,
        save INTEGER DEFAULT 1,
        revoke_remind INTEGER DEFAULT 1,
        join_group_remind INTEGER DEFAULT 0,
        screenshot INTEGER DEFAULT 1,
        receipt INTEGER DEFAULT 1,
        flame INTEGER DEFAULT 0,
        flame_second INTEGER DEFAULT 0,
        remark TEXT DEFAULT '',
        version INTEGER DEFAULT 0,
        created_at INTEGER DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Message extra table
    await db.execute('''
      CREATE TABLE message_extra (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id TEXT NOT NULL,
        message_seq INTEGER DEFAULT 0,
        from_uid TEXT DEFAULT '',
        channel_id TEXT DEFAULT '',
        channel_type INTEGER DEFAULT 0,
        readed_count INTEGER DEFAULT 0,
        readed_at INTEGER,
        revoke INTEGER DEFAULT 0,
        revoker TEXT DEFAULT '',
        is_deleted INTEGER DEFAULT 0,
        is_pinned INTEGER DEFAULT 0,
        content_edit TEXT,
        content_edit_hash TEXT DEFAULT '',
        edited_at INTEGER DEFAULT 0,
        version INTEGER DEFAULT 0,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Message reaction table
    await db.execute('''
      CREATE TABLE message_reaction (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id TEXT NOT NULL,
        channel_id TEXT DEFAULT '',
        channel_type INTEGER DEFAULT 0,
        uid TEXT NOT NULL,
        name TEXT DEFAULT '',
        emoji TEXT NOT NULL,
        seq INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Conversation extra table
    await db.execute('''
      CREATE TABLE conversation_extra (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        channel_id TEXT NOT NULL,
        channel_type INTEGER DEFAULT 0,
        browse_to INTEGER DEFAULT 0,
        keep_message_seq INTEGER DEFAULT 0,
        keep_offset_y INTEGER DEFAULT 0,
        draft TEXT,
        version INTEGER DEFAULT 0,
        created_at INTEGER DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Prohibit words table
    await db.execute('''
      CREATE TABLE prohibit_word (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sid INTEGER DEFAULT 0,
        content TEXT DEFAULT '',
        is_deleted INTEGER DEFAULT 0,
        version INTEGER DEFAULT 0,
        created_at TEXT DEFAULT '',
        word TEXT NOT NULL,
        level INTEGER DEFAULT 0,
        legacy_created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_user_setting_uid ON user_setting(uid)');
    await db.execute(
      'CREATE INDEX idx_friend_apply_uid ON friend_apply_record(uid)',
    );
    await db.execute(
      'CREATE INDEX idx_group_setting_uid ON group_setting(uid)',
    );
    await db.execute(
      'CREATE INDEX idx_message_extra_msgid ON message_extra(message_id)',
    );
    await db.execute(
      'CREATE INDEX idx_message_reaction_msgid ON message_reaction(message_id)',
    );
    await db.execute(
      'CREATE INDEX idx_conversation_extra_uid ON conversation_extra(uid)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_prohibit_word_sid ON prohibit_word(sid) WHERE sid > 0',
    );
    await db.execute(
      'CREATE INDEX idx_prohibit_word_version ON prohibit_word(version)',
    );
    await _ensureMessageIndexes(db);

    // Contacts table (v2)
    await ContactsDB.createTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await ContactsDB.createTable(db);
    }
    if (oldVersion < 3) {
      await _upgradeProhibitWordTable(db);
    }
    await _ensureMessageIndexes(db);
    await _ensureProhibitWordIndexes(db);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<void> saveProhibitWords(List<ProhibitWordEntry> words) async {
    if (words.isEmpty) {
      return;
    }
    final db = await database;
    final batch = db.batch();
    for (final word in words) {
      batch.insert(
        'prohibit_word',
        word.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> getMaxProhibitWordVersion() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT MAX(version) AS version FROM prohibit_word',
    );
    if (rows.isEmpty) {
      return 0;
    }
    final value = rows.first['version'];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<List<ProhibitWordEntry>> getProhibitWords() async {
    final db = await database;
    final rows = await db.query(
      'prohibit_word',
      where: 'is_deleted=0 AND content<>?',
      whereArgs: <Object>[''],
      orderBy: 'version ASC, sid ASC',
    );
    return rows
        .map((row) => ProhibitWordEntry.fromDynamic(row))
        .where((item) => item.sid > 0 && item.content.trim().isNotEmpty)
        .toList(growable: false);
  }

  @visibleForTesting
  Future<void> deleteDatabaseForTesting() async {
    await close();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wukong_im.db');
    await deleteDatabase(path);
  }

  Future<void> _upgradeProhibitWordTable(Database db) async {
    await _safeExecute(
      db,
      "ALTER TABLE prohibit_word ADD COLUMN sid INTEGER DEFAULT 0",
    );
    await _safeExecute(
      db,
      "ALTER TABLE prohibit_word ADD COLUMN content TEXT DEFAULT ''",
    );
    await _safeExecute(
      db,
      "ALTER TABLE prohibit_word ADD COLUMN is_deleted INTEGER DEFAULT 0",
    );
    await _safeExecute(
      db,
      "ALTER TABLE prohibit_word ADD COLUMN version INTEGER DEFAULT 0",
    );
    await _safeExecute(
      db,
      "ALTER TABLE prohibit_word ADD COLUMN legacy_created_at INTEGER DEFAULT (strftime('%s', 'now'))",
    );
    await db.execute(
      "UPDATE prohibit_word SET content = CASE WHEN content = '' THEN word ELSE content END",
    );
  }

  Future<void> _ensureProhibitWordIndexes(Database db) async {
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_prohibit_word_sid ON prohibit_word(sid) WHERE sid > 0',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_prohibit_word_version ON prohibit_word(version)',
    );
  }

  Future<void> _ensureMessageIndexes(Database db) async {
    await _safeExecute(db, '''
      CREATE INDEX IF NOT EXISTS idx_message_channel_seq
      ON message(channel_id, channel_type, message_seq DESC)
      ''');
    await _safeExecute(db, '''
      CREATE INDEX IF NOT EXISTS idx_message_channel_order_seq
      ON message(channel_id, channel_type, order_seq DESC)
      ''');
    await _safeExecute(db, '''
      CREATE INDEX IF NOT EXISTS idx_message_client_msg_no
      ON message(client_msg_no)
      ''');
    await _safeExecute(db, '''
      CREATE INDEX IF NOT EXISTS idx_message_message_id
      ON message(message_id)
      ''');
  }

  Future<void> _safeExecute(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (error) {
      debugPrint('DBHelper safe execute ignored migration SQL error: $error');
      // Ignore duplicate column/index errors during migrations.
    }
  }
}
