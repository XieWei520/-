class UnsupportedBackupDirectory {
  const UnsupportedBackupDirectory(this.path);

  final String path;

  Future<void> create({bool recursive = false}) async {}
}

typedef BackupRestoreDirectoryResolver =
    Future<UnsupportedBackupDirectory> Function();
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
  }) : uidReader = uidReader ?? (() => ''),
       resolveBackupDirectory =
           resolveBackupDirectory ??
           (() async => const UnsupportedBackupDirectory('')),
       loadMessages = loadMessages ?? (() async => const []),
       uploadBackupFile = uploadBackupFile ?? ((_, _) async {}),
       downloadRecoveryFile = downloadRecoveryFile ?? ((_, _) async {}),
       importBackupArchive =
           importBackupArchive ??
           ((_) async => const BackupRestoreImportResult());

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
    throw UnsupportedError('当前平台不支持本地消息备份');
  }

  Future<BackupRestoreMessageResult> restore() async {
    if (restoreRunner != null) {
      return restoreRunner!();
    }
    throw UnsupportedError('当前平台不支持本地消息恢复');
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
