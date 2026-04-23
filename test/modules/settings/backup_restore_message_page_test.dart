import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/settings/message_backup/backup_restore_message_page.dart';
import 'package:wukong_im_app/modules/settings/message_backup/backup_restore_message_service.dart';

void main() {
  testWidgets('backup page executes backup flow and shows success path', (
    tester,
  ) async {
    var backupCalls = 0;
    final service = BackupRestoreMessageService(
      uidReader: () => 'u_demo',
      resolveBackupDirectory: () async => throw UnimplementedError(),
      backupRunner: () async {
        backupCalls += 1;
        return const BackupRestoreMessageResult(
          localPath: '/tmp/u_demo.json',
          exportedCount: 2,
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreMessagePage(
          mode: BackupRestoreMessageMode.backup,
          service: service,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('message-backup-start-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(backupCalls, 1);
    expect(find.textContaining('/tmp/u_demo.json'), findsOneWidget);
  });

  testWidgets('restore page executes restore flow and shows success path', (
    tester,
  ) async {
    var restoreCalls = 0;
    final service = BackupRestoreMessageService(
      uidReader: () => 'u_demo',
      resolveBackupDirectory: () async => throw UnimplementedError(),
      restoreRunner: () async {
        restoreCalls += 1;
        return const BackupRestoreMessageResult(
          localPath: '/tmp/u_demo_recovery.json',
          importedCount: 31,
          skippedCount: 17,
          conversationCount: 29,
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreMessagePage(
          mode: BackupRestoreMessageMode.restore,
          service: service,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('message-backup-start-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(restoreCalls, 1);
    expect(find.textContaining('/tmp/u_demo_recovery.json'), findsOneWidget);
    expect(find.textContaining('31'), findsOneWidget);
    expect(find.textContaining('17'), findsOneWidget);
    expect(find.textContaining('29'), findsOneWidget);
  });
}
