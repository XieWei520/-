import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/db/message.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../../core/utils/storage_utils.dart';
import '../../../service/api/api_client.dart';

typedef BackupRestoreDirectoryResolver = Future<Directory> Function();
typedef BackupRestoreMessageLoader =
    Future<List<BackupRestoreMessageRecord>> Function();
typedef BackupRestoreUploadAction =
    Future<void> Function(String path, String filePath);
typedef BackupRestoreDownloadAction =
    Future<void> Function(String path, String savePath);
typedef BackupRestoreImportAction =
    Future<BackupRestoreImportResult> Function(String filePath);
typedef BackupRestoreRunner = Future<BackupRestoreMessageResult> Function();

class BackupRestoreMessageService {
  BackupRestoreMessageService({
    String Function()? uidReader,
    BackupRestoreDirectoryResolver? resolveBackupDirectory,
    BackupRestoreMessageLoader? loadMessages,
    BackupRestoreUploadAction? uploadBackupFile,
    BackupRestoreDownloadAction? downloadRecoveryFile,
    BackupRestoreImportAction? importBackupArchive,
    this.backupRunner,
    this.restoreRunner,
  }) : uidReader = uidReader ?? _defaultUidReader,
       resolveBackupDirectory =
           resolveBackupDirectory ?? _defaultResolveBackupDirectory,
       loadMessages = loadMessages ?? _defaultLoadMessages,
       uploadBackupFile = uploadBackupFile ?? _defaultUploadBackupFile,
       downloadRecoveryFile =
           downloadRecoveryFile ?? _defaultDownloadRecoveryFile,
       importBackupArchive = importBackupArchive ?? _defaultImportBackupArchive;

  static const String backupEndpoint = '/v1/message/backup';
  static const String recoveryEndpoint = '/v1/message/recovery';

  final String Function() uidReader;
  final BackupRestoreDirectoryResolver resolveBackupDirectory;
  final BackupRestoreMessageLoader loadMessages;
  final BackupRestoreUploadAction uploadBackupFile;
  final BackupRestoreDownloadAction downloadRecoveryFile;
  final BackupRestoreImportAction importBackupArchive;
  final BackupRestoreRunner? backupRunner;
  final BackupRestoreRunner? restoreRunner;

  Future<BackupRestoreMessageResult> backup() async {
    if (backupRunner != null) {
      return backupRunner!();
    }

    final uid = _readUid();
    final fileStem = _safeBackupFileStem(uid);
    final directory = await resolveBackupDirectory();
    await directory.create(recursive: true);

    final records = await loadMessages();
    final exportedRecords = records
        .where((record) => record.isDeleted != 1)
        .toList(growable: false);
    final archive = exportedRecords
        .map((record) => record.toBackupJson())
        .toList(growable: false);

    final localPath = p.join(directory.path, '$fileStem.json');
    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
    }
    await file.writeAsString(jsonEncode(archive));
    await uploadBackupFile(backupEndpoint, localPath);

    return BackupRestoreMessageResult(
      localPath: localPath,
      exportedCount: exportedRecords.length,
    );
  }

  Future<BackupRestoreMessageResult> restore() async {
    if (restoreRunner != null) {
      return restoreRunner!();
    }

    final uid = _readUid();
    final fileStem = _safeBackupFileStem(uid);
    final directory = await resolveBackupDirectory();
    await directory.create(recursive: true);

    final localPath = p.join(directory.path, '${fileStem}_recovery.json');
    await downloadRecoveryFile(recoveryEndpoint, localPath);
    final importResult = await importBackupArchive(localPath);

    return BackupRestoreMessageResult(
      localPath: localPath,
      importedCount: importResult.importedCount,
      skippedCount: importResult.skippedCount,
      conversationCount: importResult.conversationCount,
    );
  }

  String _readUid() {
    final uid = uidReader().trim();
    if (uid.isEmpty) {
      throw StateError('Current user uid is empty.');
    }
    return uid;
  }

  String _safeBackupFileStem(String uid) {
    final normalized = uid.trim().replaceAll(RegExp(r'[\\/]+'), '_');
    final safe = normalized.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final collapsed = safe
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^\.+'), '')
        .replaceAll(RegExp(r'\.+$'), '')
        .replaceAll(RegExp(r'^_+'), '')
        .replaceAll(RegExp(r'_+$'), '');
    return collapsed.isEmpty ? 'user' : collapsed;
  }

  static String _defaultUidReader() {
    return StorageUtils.getUid()?.trim() ??
        WKIM.shared.options.uid?.trim() ??
        '';
  }

  static Future<Directory> _defaultResolveBackupDirectory() async {
    final rootDirectory = await getApplicationDocumentsDirectory();
    return Directory(p.join(rootDirectory.path, 'message_backup'));
  }

  static Future<List<BackupRestoreMessageRecord>> _defaultLoadMessages() async {
    Database? database = WKDBHelper.shared.getDB();
    if (database == null) {
      await WKDBHelper.shared.init();
      database = WKDBHelper.shared.getDB();
    }
    if (database == null) {
      throw StateError('Message database is not initialized.');
    }

    final rows = await database.query(
      WKDBConst.tableMessage,
      columns: const <String>[
        'channel_id',
        'channel_type',
        'message_id',
        'message_seq',
        'order_seq',
        'client_msg_no',
        'from_uid',
        'content',
        'timestamp',
        'is_deleted',
      ],
      orderBy: 'message_seq ASC',
    );

    return rows
        .map(
          (row) => BackupRestoreMessageRecord(
            channelId: _readString(row, 'channel_id'),
            channelType: _readInt(row, 'channel_type'),
            messageId: _readString(row, 'message_id'),
            messageSeq: _readInt(row, 'message_seq'),
            orderSeq: _readInt(row, 'order_seq'),
            clientMsgNo: _readString(row, 'client_msg_no'),
            fromUid: _readString(row, 'from_uid'),
            payload: _readString(row, 'content'),
            timestamp: _readInt(row, 'timestamp'),
            isDeleted: _readInt(row, 'is_deleted'),
          ),
        )
        .toList(growable: false);
  }

  static Future<void> _defaultUploadBackupFile(
    String path,
    String filePath,
  ) async {
    await ApiClient.instance.uploadFile<void>(path, filePath);
  }

  static Future<void> _defaultDownloadRecoveryFile(
    String path,
    String savePath,
  ) async {
    await ApiClient.instance.dio.download(path, savePath);
  }

  static Future<BackupRestoreImportResult> _defaultImportBackupArchive(
    String filePath,
  ) async {
    final raw = await File(filePath).readAsString();
    final result = await MessageDB.shared.importBackupArchive(raw);
    return BackupRestoreImportResult(
      importedCount: result.importedCount,
      skippedCount: result.skippedCount,
      conversationCount: result.conversationCount,
    );
  }

  static String _readString(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  static int _readInt(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class BackupRestoreMessageRecord {
  const BackupRestoreMessageRecord({
    required this.channelId,
    required this.channelType,
    required this.messageId,
    required this.messageSeq,
    required this.orderSeq,
    required this.clientMsgNo,
    required this.fromUid,
    required this.payload,
    required this.timestamp,
    required this.isDeleted,
  });

  final String channelId;
  final int channelType;
  final String messageId;
  final int messageSeq;
  final int orderSeq;
  final String clientMsgNo;
  final String fromUid;
  final String payload;
  final int timestamp;
  final int isDeleted;

  Map<String, Object?> toBackupJson() {
    return <String, Object?>{
      'channel_id': channelId,
      'channel_type': channelType,
      'message_id': messageId,
      'message_seq': messageSeq,
      'client_msg_no': clientMsgNo,
      'from_uid': fromUid,
      'payload': payload,
      'timestamp': timestamp,
    };
  }
}

class BackupRestoreArchive {
  const BackupRestoreArchive({
    required this.schemaVersion,
    required this.uid,
    required this.createdAt,
    required this.messages,
  });

  final int schemaVersion;
  final String uid;
  final int createdAt;
  final List<BackupRestoreMessageRecord> messages;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schema_version': schemaVersion,
      'uid': uid,
      'created_at': createdAt,
      'messages': messages
          .map((message) => message.toBackupJson())
          .toList(growable: false),
    };
  }
}

class BackupRestoreImportResult {
  const BackupRestoreImportResult({
    this.importedCount = 0,
    this.skippedCount = 0,
    this.conversationCount = 0,
  });

  final int importedCount;
  final int skippedCount;
  final int conversationCount;
}

class BackupRestoreMessageResult {
  const BackupRestoreMessageResult({
    required this.localPath,
    this.exportedCount = 0,
    this.importedCount = 0,
    this.skippedCount = 0,
    this.conversationCount = 0,
  });

  final String localPath;
  final int exportedCount;
  final int importedCount;
  final int skippedCount;
  final int conversationCount;
}
