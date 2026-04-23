import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/settings/message_backup/backup_restore_message_service.dart';

void main() {
  test(
    'backup payload matches TangSeng Android row schema exactly',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'wk_message_backup_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      String? uploadedPath;
      String? uploadedFilePath;
      final service = BackupRestoreMessageService(
        uidReader: () => 'u_backup',
        resolveBackupDirectory: () async => tempDir,
        loadMessages: () async => <BackupRestoreMessageRecord>[
          const BackupRestoreMessageRecord(
            channelId: 'g1',
            channelType: 2,
            messageId: 'm1',
            messageSeq: 11,
            orderSeq: 11000,
            clientMsgNo: 'c1',
            fromUid: 'u1',
            payload: '{"type":1,"content":"hello"}',
            timestamp: 1712000001,
            isDeleted: 0,
          ),
          const BackupRestoreMessageRecord(
            channelId: 'g1',
            channelType: 2,
            messageId: 'm2',
            messageSeq: 12,
            orderSeq: 12000,
            clientMsgNo: 'c2',
            fromUid: 'u2',
            payload: '{"type":1,"content":"deleted"}',
            timestamp: 1712000002,
            isDeleted: 1,
          ),
        ],
        uploadBackupFile: (path, filePath) async {
          uploadedPath = path;
          uploadedFilePath = filePath;
        },
      );

      final result = await service.backup();

      expect(uploadedPath, '/v1/message/backup');
      expect(uploadedFilePath, result.localPath);
      expect(result.exportedCount, 1);

      final raw = await File(result.localPath).readAsString();
      final messages = jsonDecode(raw) as List<dynamic>;
      expect(messages, hasLength(1));
      expect(
        (messages.single as Map).keys.toSet(),
        <String>{
          'channel_id',
          'channel_type',
          'message_id',
          'message_seq',
          'client_msg_no',
          'from_uid',
          'payload',
          'timestamp',
        },
      );
      expect(messages.single, <String, dynamic>{
        'channel_id': 'g1',
        'channel_type': 2,
        'message_id': 'm1',
        'message_seq': 11,
        'client_msg_no': 'c1',
        'from_uid': 'u1',
        'payload': '{"type":1,"content":"hello"}',
        'timestamp': 1712000001,
      });
    },
  );

  test(
    'restore downloads recovery json and imports archive into local sqlite',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'wk_message_recovery_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      String? downloadedPath;
      String? downloadedSavePath;
      String? importedFilePath;
      final service = BackupRestoreMessageService(
        uidReader: () => 'u_restore',
        resolveBackupDirectory: () async => tempDir,
        downloadRecoveryFile: (path, savePath) async {
          downloadedPath = path;
          downloadedSavePath = savePath;
          await File(savePath).writeAsString(
            jsonEncode(<String, dynamic>{
              'schema_version': 2,
              'uid': 'u_restore',
              'created_at': 1712001000,
              'messages': <Map<String, dynamic>>[],
            }),
          );
        },
        importBackupArchive: (filePath) async {
          importedFilePath = filePath;
          return const BackupRestoreImportResult(
            importedCount: 3,
            skippedCount: 1,
            conversationCount: 2,
          );
        },
      );

      final result = await service.restore();

      expect(downloadedPath, '/v1/message/recovery');
      expect(downloadedSavePath, result.localPath);
      expect(result.localPath, endsWith('u_restore_recovery.json'));
      expect(await File(result.localPath).exists(), isTrue);
      expect(importedFilePath, result.localPath);
      expect(result.importedCount, 3);
      expect(result.skippedCount, 1);
      expect(result.conversationCount, 2);
    },
  );
}
