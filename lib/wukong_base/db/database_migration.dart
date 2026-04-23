import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

/// Database migration version info
class MigrationVersion {
  final int version;
  final String name;
  final String description;
  final bool isBreaking;

  const MigrationVersion({
    required this.version,
    required this.name,
    required this.description,
    this.isBreaking = false,
  });
}

/// Migration definition
class Migration {
  final int fromVersion;
  final int toVersion;
  final List<String> sqlStatements;
  final bool isBreaking;

  const Migration({
    required this.fromVersion,
    required this.toVersion,
    required this.sqlStatements,
    this.isBreaking = false,
  });

  MigrationVersion get version => MigrationVersion(
    version: toVersion,
    name: 'Migration $fromVersion -> $toVersion',
    description: '${sqlStatements.length} statements',
    isBreaking: isBreaking,
  );
}

/// Database migration helper
class DatabaseMigrationHelper {
  static final DatabaseMigrationHelper _instance = DatabaseMigrationHelper._internal();
  factory DatabaseMigrationHelper() => _instance;
  DatabaseMigrationHelper._internal();

  // Current database version
  int _currentVersion = 0;

  // Migration definitions
  final List<Migration> _migrations = [];

  /// Initialize migrations
  void initMigrations() {
    _migrations.addAll([
      // Migration 1 -> 2: Add user_settings table
      Migration(
        fromVersion: 1,
        toVersion: 2,
        sqlStatements: [
          '''
          CREATE TABLE IF NOT EXISTS user_settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            update_time INTEGER
          )
          ''',
        ],
      ),

      // Migration 2 -> 3: Add friend_apply_record table
      Migration(
        fromVersion: 2,
        toVersion: 3,
        sqlStatements: [
          '''
          CREATE TABLE IF NOT EXISTS friend_apply_record (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            friend_uid TEXT,
            nickname TEXT,
            remark TEXT,
            status INTEGER DEFAULT 0,
            create_time INTEGER,
            update_time INTEGER
          )
          ''',
        ],
      ),

      // Migration 3 -> 4: Add message_extra table
      Migration(
        fromVersion: 3,
        toVersion: 4,
        sqlStatements: [
          '''
          CREATE TABLE IF NOT EXISTS message_extra (
            message_id TEXT PRIMARY KEY,
            is_deleted INTEGER DEFAULT 0,
            is_read INTEGER DEFAULT 0,
            is_mutual INTEGER DEFAULT 0,
            is_pinned INTEGER DEFAULT 0,
            is_private INTEGER DEFAULT 0,
            recall INTEGER DEFAULT 0,
            mute_duration INTEGER DEFAULT 0
          )
          ''',
          '''
          CREATE INDEX IF NOT EXISTS idx_message_extra_message_id ON message_extra(message_id)
          ''',
        ],
      ),

      // Migration 4 -> 5: Add message_reaction table
      Migration(
        fromVersion: 4,
        toVersion: 5,
        sqlStatements: [
          '''
          CREATE TABLE IF NOT EXISTS message_reaction (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message_id TEXT,
            user_id TEXT,
            emoji TEXT,
            create_time INTEGER,
            UNIQUE(message_id, user_id, emoji)
          )
          ''',
          '''
          CREATE INDEX IF NOT EXISTS idx_message_reaction_message_id ON message_reaction(message_id)
          ''',
        ],
      ),

      // Migration 5 -> 6: Add drafts table
      Migration(
        fromVersion: 5,
        toVersion: 6,
        sqlStatements: [
          '''
          CREATE TABLE IF NOT EXISTS drafts (
            channel_id TEXT,
            channel_type INTEGER,
            content TEXT,
            reply_msg_id TEXT,
            reply_content TEXT,
            update_time INTEGER,
            PRIMARY KEY (channel_id, channel_type)
          )
          ''',
        ],
      ),

      // Migration 6 -> 7: Add conversations table improvements
      Migration(
        fromVersion: 6,
        toVersion: 7,
        sqlStatements: [
          '''
          ALTER TABLE conversations ADD COLUMN is_pinned INTEGER DEFAULT 0
          ''',
          '''
          ALTER TABLE conversations ADD COLUMN is_muted INTEGER DEFAULT 0
          ''',
          '''
          ALTER TABLE conversations ADD COLUMN is_distinguish INTEGER DEFAULT 0
          ''',
          '''
          ALTER TABLE conversations ADD COLUMN is_top INTEGER DEFAULT 0
          ''',
        ],
        isBreaking: true,
      ),

      // Migration 7 -> 8: Add typing_indicators table
      Migration(
        fromVersion: 7,
        toVersion: 8,
        sqlStatements: [
          '''
          CREATE TABLE IF NOT EXISTS typing_indicators (
            channel_id TEXT,
            channel_type INTEGER,
            user_id TEXT,
            expire_time INTEGER,
            PRIMARY KEY (channel_id, channel_type, user_id)
          )
          ''',
        ],
      ),
    ]);
  }

  /// Get all migration versions
  List<MigrationVersion> getAllVersions() {
    return _migrations.map((m) => m.version).toList();
  }

  /// Get pending migrations
  List<Migration> getPendingMigrations(int currentVersion) {
    return _migrations
        .where((m) => m.fromVersion >= currentVersion)
        .toList()
      ..sort((a, b) => a.fromVersion.compareTo(b.fromVersion));
  }

  /// Run migrations
  Future<MigrationResult> runMigrations(Database db, int targetVersion) async {
    final results = <MigrationResultItem>[];

    for (final migration in _migrations) {
      if (migration.fromVersion >= targetVersion) break;

      try {
        await db.transaction((txn) async {
          for (final sql in migration.sqlStatements) {
            await txn.execute(sql);
          }
        });

        results.add(MigrationResultItem(
          migration: migration,
          success: true,
        ));

        _currentVersion = migration.toVersion;
      } catch (e) {
        results.add(MigrationResultItem(
          migration: migration,
          success: false,
          error: e.toString(),
        ));

        // Stop on error
        break;
      }
    }

    return MigrationResult(
      fromVersion: _currentVersion,
      toVersion: targetVersion,
      items: results,
    );
  }

  /// Validate database schema
  Future<List<SchemaIssue>> validateSchema(Database db) async {
    final issues = <SchemaIssue>[];

    // Check required tables
    final requiredTables = [
      'conversations',
      'messages',
      'users',
      'friends',
      'groups',
    ];

    for (final table in requiredTables) {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'"
      );
      if (result.isEmpty) {
        issues.add(SchemaIssue(
          type: SchemaIssueType.missingTable,
          description: 'Missing required table: $table',
        ));
      }
    }

    // Check conversations table columns
    try {
      final columns = await db.rawQuery("PRAGMA table_info(conversations)");
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      if (!columnNames.contains('channel_id')) {
        issues.add(SchemaIssue(
          type: SchemaIssueType.missingColumn,
          table: 'conversations',
          description: 'Missing column: channel_id',
        ));
      }
    } catch (e) {
      // Table doesn't exist
    }

    return issues;
  }

  /// Backup database
  Future<String?> backupDatabase(Database db) async {
    try {
      final backupDir = await _getBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = path.join(backupDir, 'backup_$timestamp.db');

      // Use sqflite's backup mechanism
      await db.execute("VACUUM INTO '$backupPath'");

      return backupPath;
    } catch (e) {
      return null;
    }
  }

  Future<String> _getBackupDirectory() async {
    // In a real app, use path_provider
    return '.';
  }
}

/// Migration result
class MigrationResult {
  final int fromVersion;
  final int toVersion;
  final List<MigrationResultItem> items;

  MigrationResult({
    required this.fromVersion,
    required this.toVersion,
    required this.items,
  });

  bool get success => items.every((item) => item.success);
  int get completedCount => items.where((item) => item.success).length;
  int get failedCount => items.where((item) => !item.success).length;

  String get summary {
    if (success) {
      return 'Successfully migrated from v$fromVersion to v$toVersion ($completedCount migrations)';
    } else {
      final failed = items.firstWhere((item) => !item.success);
      return 'Migration failed at v${failed.migration.toVersion}: ${failed.error}';
    }
  }
}

/// Migration result item
class MigrationResultItem {
  final Migration migration;
  final bool success;
  final String? error;

  MigrationResultItem({
    required this.migration,
    required this.success,
    this.error,
  });
}

/// Schema issue
class SchemaIssue {
  final SchemaIssueType type;
  final String? table;
  final String description;

  SchemaIssue({
    required this.type,
    this.table,
    required this.description,
  });
}

/// Schema issue type
enum SchemaIssueType {
  missingTable,
  missingColumn,
  invalidColumn,
  corruptedData,
}
