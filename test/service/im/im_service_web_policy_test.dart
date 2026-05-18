import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/im/im_service.dart';

void main() {
  test('web IM initialization does not require local sqflite persistence', () {
    expect(shouldUseImLocalPersistence(isWeb: true, sdkAppMode: true), isFalse);
  });

  test('native app IM initialization keeps local sqflite persistence', () {
    expect(shouldUseImLocalPersistence(isWeb: false, sdkAppMode: true), isTrue);
  });

  test('web IM initialization does not start native session runtime', () {
    expect(shouldStartNativeSessionRuntime(isWeb: true), isFalse);
  });

  test('web IM keeps websocket alive while page is backgrounded', () {
    expect(
      shouldDisconnectForBackgroundLifecycle(
        isWeb: true,
        hasActiveCallOrPendingSetup: false,
      ),
      isFalse,
    );
  });

  test('native IM may disconnect in background when no call is active', () {
    expect(
      shouldDisconnectForBackgroundLifecycle(
        isWeb: false,
        hasActiveCallOrPendingSetup: false,
      ),
      isTrue,
    );
    expect(
      shouldDisconnectForBackgroundLifecycle(
        isWeb: false,
        hasActiveCallOrPendingSetup: true,
      ),
      isFalse,
    );
  });

  test('IMService source does not import dart io directly', () {
    final source = File('lib/service/im/im_service.dart').readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });

  test('IMService delegates notifications through the bridge only', () {
    final source = File('lib/service/im/im_service.dart').readAsStringSync();

    expect(source, contains('im_notification_bridge.dart'));
    expect(source, contains('_notificationBridge.showMessageAlert'));
    expect(source, isNot(contains('android_message_alert_manager.dart')));
    expect(source, isNot(contains('desktop_message_alert_manager.dart')));
    expect(source, isNot(contains('web_notification_manager.dart')));
    expect(source, isNot(contains('AndroidMessageAlertManager')));
    expect(source, isNot(contains('DesktopMessageAlertManager')));
    expect(source, isNot(contains('WebNotificationManager')));
  });

  test(
    'IMService delegates offline command ack sequencing to sync orchestrator',
    () {
      final source = File('lib/service/im/im_service.dart').readAsStringSync();

      expect(
        source,
        contains('_syncOrchestrator.resolveOfflineCommandAckSequence'),
      );
      expect(source, isNot(contains('message_sync_coordinator.dart')));
      expect(source, isNot(contains('MessageSyncCoordinator')));
      expect(source, isNot(contains('_messageSyncCoordinator')));
    },
  );

  test('IMService delegates word runtime filtering to a dedicated service', () {
    final source = File('lib/service/im/im_service.dart').readAsStringSync();

    expect(source, contains('im_word_runtime_filter_service.dart'));
    expect(source, contains('_wordRuntimeFilterService'));
    expect(
      source,
      contains('_wordRuntimeFilterService.applyProhibitWordsToMessage'),
    );
    expect(
      source,
      contains(
        '_wordRuntimeFilterService.buildSensitiveWordTipMessageIfNeeded',
      ),
    );
    expect(source, isNot(contains('snapshot.list.any(text.contains)')));
    expect(source, isNot(contains("replaceAll(target, '*' * target.length)")));
  });

  test(
    'IMService delegates masked message refresh after prohibit-word sync',
    () {
      final source = File('lib/service/im/im_service.dart').readAsStringSync();

      expect(source, contains('im_masked_message_refresh_service.dart'));
      expect(source, contains('_maskedMessageRefreshService'));
      expect(
        source,
        contains('_maskedMessageRefreshService.refreshAfterProhibitWordSync'),
      );
      expect(source, isNot(contains('MessageDB.shared.queryWithClientMsgNo')));
      expect(source, isNot(contains('WKDBConst.tableMessage')));
    },
  );

  test('IMService delegates local database readiness to a service', () {
    final source = File('lib/service/im/im_service.dart').readAsStringSync();

    expect(source, contains('im_local_database_service.dart'));
    expect(source, contains('_localDatabaseService.ensureReady()'));
    expect(source, isNot(contains("import 'package:sqflite/sqflite.dart'")));
    expect(source, isNot(contains('db/wk_db_helper.dart')));
    expect(source, isNot(contains('ensureMessageOutboxSchema')));
    expect(source, isNot(contains('WKDBHelper.shared.init')));
    expect(source, isNot(contains('WKDBHelper.shared.onUpgrade')));
  });
}
