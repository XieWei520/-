import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/modules/settings/message_backup/backup_restore_message_service_io.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/auth_api.dart';
import 'package:wukongimfluttersdk/common/options.dart' as wk;
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/wkim.dart';

class LiveBackupRestoreAcceptanceHarness {
  static const Uuid _uuid = Uuid();

  Directory? _backupDirectory;
  String? _databasePath;

  Future<LiveBackupRestoreAcceptanceResult> run() async {
    await _bootstrap();
    final session = await _registerDisposableAccount();
    await _authenticateLocalSession(session);
    await _recreateLocalDatabase();

    final seededMessages = await _seedMessages();
    final service = BackupRestoreMessageService(
      resolveBackupDirectory: () async => _backupDirectory!,
    );

    final backupResult = await service.backup();
    final uploadedArchiveMessageIds = await _readArchiveMessageIds(
      backupResult.localPath,
    );

    await _recreateLocalDatabase();

    final restoreResult = await service.restore();
    final downloadedArchiveMessageIds = await _readArchiveMessageIds(
      restoreResult.localPath,
    );
    final restoredMessagesById = await _queryMessagesById(
      seededMessages.payloadsById.keys.toSet(),
    );

    return LiveBackupRestoreAcceptanceResult(
      exportedCount: backupResult.exportedCount,
      importedCount: restoreResult.importedCount,
      skippedCount: restoreResult.skippedCount,
      conversationCount: restoreResult.conversationCount,
      messageIds: seededMessages.payloadsById.keys.toSet(),
      expectedPayloadsById: seededMessages.payloadsById,
      uploadedArchiveMessageIds: uploadedArchiveMessageIds,
      serverArchiveMessageIds: downloadedArchiveMessageIds,
      restoredMessagesById: restoredMessagesById,
    );
  }

  Future<void> dispose() async {
    final db = WKDBHelper.shared.getDB();
    if (db != null) {
      await _clearImTables(db);
    }
    WKDBHelper.shared.close();

    final databasePath = _databasePath;
    if (databasePath != null && await databaseExists(databasePath)) {
      await deleteDatabase(databasePath);
    }

    final backupDirectory = _backupDirectory;
    if (backupDirectory != null && await backupDirectory.exists()) {
      await backupDirectory.delete(recursive: true);
    }

    if (StorageUtils.isInitialized) {
      await StorageUtils.clear();
    }
    ApiClient.instance.clearToken();
  }

  Future<void> _bootstrap() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PackageInfo.setMockInitialValues(
      appName: 'WuKongIM Test',
      packageName: 'com.wukongim.acceptance',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    if (!StorageUtils.isInitialized) {
      await StorageUtils.init();
    } else {
      await StorageUtils.clear();
    }

    _backupDirectory = await Directory.systemTemp.createTemp(
      'wk_live_backup_acceptance_',
    );
  }

  Future<_LiveAcceptanceSession> _registerDisposableAccount() async {
    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    final username = 'wkb${suffix.substring(suffix.length - 10)}';
    final password = 'BackupPass_${suffix.substring(suffix.length - 8)}';
    final deviceId = _uuid.v4().replaceAll('-', '');
    final deviceInstallId = _uuid.v4().replaceAll('-', '');
    final deviceSessionId = _uuid.v4().replaceAll('-', '');

    final response = await AuthApi.instance.usernameRegister(
      username: username,
      password: password,
      name: 'Backup Acceptance $suffix',
      deviceId: deviceId,
      deviceName: 'Codex Backup Acceptance',
      deviceModel: 'Windows',
      deviceInstallId: deviceInstallId,
    );

    final uid = response.data?.uid?.trim() ?? '';
    final token = response.data?.token?.trim() ?? '';
    if (!response.success || uid.isEmpty || token.isEmpty) {
      throw StateError(
        'Disposable username registration failed: code=${response.code} msg=${response.msg ?? 'unknown'}',
      );
    }

    return _LiveAcceptanceSession(
      uid: uid,
      token: token,
      username: username,
      password: password,
      deviceId: deviceId,
      deviceInstallId: deviceInstallId,
      deviceSessionId: deviceSessionId,
    );
  }

  Future<void> _authenticateLocalSession(_LiveAcceptanceSession session) async {
    await StorageUtils.setUid(session.uid);
    await StorageUtils.setToken(session.token);
    await StorageUtils.setDeviceId(session.deviceId);
    await StorageUtils.setDeviceInstallId(session.deviceInstallId);
    await StorageUtils.setDeviceSessionId(session.deviceSessionId);
    await StorageUtils.setDeviceBindVersion(1);
    await StorageUtils.setDeviceBoundUserId(session.uid);

    ApiClient.instance.setToken(session.token);
    WKIM.shared.options = wk.Options.newDefault(session.uid, session.token);

    final databasesPath = await getDatabasesPath();
    _databasePath = p.join(databasesPath, 'wk_${session.uid}.db');
  }

  Future<void> _recreateLocalDatabase() async {
    WKDBHelper.shared.close();

    final databasePath = _databasePath;
    if (databasePath != null && await databaseExists(databasePath)) {
      await deleteDatabase(databasePath);
    }

    final initialized = await WKDBHelper.shared.init();
    if (!initialized || WKDBHelper.shared.getDB() == null) {
      throw StateError('Failed to initialize the local WuKongIM database.');
    }
  }

  Future<_SeededMessages> _seedMessages() async {
    final db = WKDBHelper.shared.getDB();
    if (db == null) {
      throw StateError('Message database is not initialized.');
    }

    final messageOneId = 'live_msg_${_uuid.v4().replaceAll('-', '')}';
    final messageTwoId = 'live_msg_${_uuid.v4().replaceAll('-', '')}';
    final deletedMessageId = 'live_msg_${_uuid.v4().replaceAll('-', '')}';

    final payloadOne = '{"type":1,"content":"backup-acceptance-one"}';
    final payloadTwo = '{"type":1,"content":"backup-acceptance-two"}';

    await db.insert(WKDBConst.tableMessage, <String, Object?>{
      'message_id': messageOneId,
      'message_seq': 101,
      'channel_id': 'g_backup_acceptance',
      'channel_type': 2,
      'timestamp': 1712000000,
      'from_uid': 'u_backup_sender_1',
      'type': 1,
      'content': payloadOne,
      'status': 1,
      'voice_status': 0,
      'searchable_word': 'backup acceptance one',
      'client_msg_no': 'live_client_${_uuid.v4().replaceAll('-', '')}',
      'is_deleted': 0,
      'setting': 0,
      'order_seq': 101000,
      'extra': '',
    });
    await db.insert(WKDBConst.tableMessage, <String, Object?>{
      'message_id': messageTwoId,
      'message_seq': 202,
      'channel_id': 'u_backup_peer',
      'channel_type': 1,
      'timestamp': 1712000100,
      'from_uid': 'u_backup_peer',
      'type': 1,
      'content': payloadTwo,
      'status': 1,
      'voice_status': 0,
      'searchable_word': 'backup acceptance two',
      'client_msg_no': 'live_client_${_uuid.v4().replaceAll('-', '')}',
      'is_deleted': 0,
      'setting': 0,
      'order_seq': 202000,
      'extra': '',
    });
    await db.insert(WKDBConst.tableMessage, <String, Object?>{
      'message_id': deletedMessageId,
      'message_seq': 303,
      'channel_id': 'g_backup_acceptance',
      'channel_type': 2,
      'timestamp': 1712000200,
      'from_uid': 'u_backup_sender_2',
      'type': 1,
      'content': '{"type":1,"content":"deleted-row-should-not-export"}',
      'status': 1,
      'voice_status': 0,
      'searchable_word': 'deleted row',
      'client_msg_no': 'live_client_${_uuid.v4().replaceAll('-', '')}',
      'is_deleted': 1,
      'setting': 0,
      'order_seq': 303000,
      'extra': '',
    });

    return _SeededMessages(
      payloadsById: <String, String>{
        messageOneId: payloadOne,
        messageTwoId: payloadTwo,
      },
    );
  }

  Future<Set<String>> _readArchiveMessageIds(String filePath) async {
    final raw = await File(filePath).readAsString();
    final decoded = jsonDecode(raw);
    final messages = switch (decoded) {
      List<dynamic> list => list,
      Map<dynamic, dynamic> map when map['messages'] is List<dynamic> =>
        map['messages'] as List<dynamic>,
      _ => throw const FormatException('Unexpected backup archive shape.'),
    };

    return messages
        .whereType<Map>()
        .map((message) => message['message_id']?.toString() ?? '')
        .where((messageId) => messageId.isNotEmpty)
        .toSet();
  }

  Future<Map<String, String>> _queryMessagesById(Set<String> messageIds) async {
    if (messageIds.isEmpty) {
      return const <String, String>{};
    }

    final db = WKDBHelper.shared.getDB();
    if (db == null) {
      throw StateError('Message database is not initialized.');
    }

    final rows = await db.query(
      WKDBConst.tableMessage,
      columns: const <String>['message_id', 'content'],
      where: 'message_id in (${_placeholders(messageIds.length)})',
      whereArgs: messageIds.toList(growable: false),
    );

    return <String, String>{
      for (final row in rows)
        row['message_id']!.toString(): row['content']?.toString() ?? '',
    };
  }

  Future<void> _clearImTables(Database db) async {
    await db.delete(WKDBConst.tableMessage);
    await db.delete(WKDBConst.tableMessageExtra);
    await db.delete(WKDBConst.tableConversation);
    await db.delete(WKDBConst.tableConversationExtra);
    await db.delete(WKDBConst.tableChannel);
  }

  String _placeholders(int count) {
    return List<String>.filled(count, '?').join(', ');
  }
}

class LiveBackupRestoreAcceptanceResult {
  const LiveBackupRestoreAcceptanceResult({
    required this.exportedCount,
    required this.importedCount,
    required this.skippedCount,
    required this.conversationCount,
    required this.messageIds,
    required this.expectedPayloadsById,
    required this.uploadedArchiveMessageIds,
    required this.serverArchiveMessageIds,
    required this.restoredMessagesById,
  });

  final int exportedCount;
  final int importedCount;
  final int skippedCount;
  final int conversationCount;
  final Set<String> messageIds;
  final Map<String, String> expectedPayloadsById;
  final Set<String> uploadedArchiveMessageIds;
  final Set<String> serverArchiveMessageIds;
  final Map<String, String> restoredMessagesById;
}

class _LiveAcceptanceSession {
  const _LiveAcceptanceSession({
    required this.uid,
    required this.token,
    required this.username,
    required this.password,
    required this.deviceId,
    required this.deviceInstallId,
    required this.deviceSessionId,
  });

  final String uid;
  final String token;
  final String username;
  final String password;
  final String deviceId;
  final String deviceInstallId;
  final String deviceSessionId;
}

class _SeededMessages {
  const _SeededMessages({required this.payloadsById});

  final Map<String, String> payloadsById;
}
