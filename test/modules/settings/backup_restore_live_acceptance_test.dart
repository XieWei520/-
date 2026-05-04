import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/live_backup_restore_acceptance_harness.dart';

const bool _runLiveBackupAcceptance = bool.fromEnvironment(
  'WK_RUN_LIVE_BACKUP_ACCEPTANCE',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  test(
    'live backup and restore round-trips against production with a disposable account',
    () async {
      final harness = LiveBackupRestoreAcceptanceHarness();
      addTearDown(harness.dispose);

      final result = await harness.run();

      expect(result.exportedCount, 2);
      expect(result.importedCount, 2);
      expect(result.skippedCount, 0);
      expect(result.conversationCount, 2);
      expect(result.serverArchiveMessageIds, unorderedEquals(result.messageIds));
      expect(
        result.restoredMessagesById.keys.toSet(),
        unorderedEquals(result.messageIds),
      );
      for (final messageId in result.messageIds) {
        expect(
          result.restoredMessagesById[messageId],
          result.expectedPayloadsById[messageId],
        );
      }
    },
    skip: _runLiveBackupAcceptance
        ? false
        : 'Set --dart-define=WK_RUN_LIVE_BACKUP_ACCEPTANCE=true to run the live production acceptance harness.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
