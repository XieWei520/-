import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/conversation_draft_api.dart';
import 'package:wukong_im_app/service/api/im_sync_api.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukong_im_app/service/api/reminder_api.dart';
import 'package:wukong_im_app/service/im/attachment_upload_pipeline.dart';
import 'package:wukong_im_app/service/im/im_connection_service.dart';
import 'package:wukong_im_app/service/im/im_masked_message_refresh_service.dart';
import 'package:wukong_im_app/service/im/im_notification_bridge.dart';
import 'package:wukong_im_app/service/im/im_service.dart';
import 'package:wukong_im_app/service/im/im_service_providers.dart';
import 'package:wukong_im_app/service/im/im_sync_orchestrator.dart';
import 'package:wukong_im_app/service/im/im_word_runtime_filter_service.dart';
import 'package:wukong_im_app/service/im/message_delivery_service.dart';
import 'package:wukong_im_app/wukong_push/notification/android_message_alert_manager.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_manager.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_policy.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_presenter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('IM runtime provider graph composes the five extracted services', () {
    final androidManager = AndroidMessageAlertManager(
      presenter: const _NoopAndroidMessageAlertPresenter(),
      isWeb: () => false,
      targetPlatform: () => TargetPlatform.android,
    );
    final desktopManager = DesktopMessageAlertManager(
      presenter: const _NoopDesktopMessageAlertPresenter(),
      isWeb: () => false,
      targetPlatform: () => TargetPlatform.windows,
    );
    final container = ProviderContainer(
      overrides: <Override>[
        androidMessageAlertManagerProvider.overrideWithValue(androidManager),
        desktopMessageAlertManagerProvider.overrideWithValue(desktopManager),
      ],
    );
    addTearDown(container.dispose);

    final runtime = container.read(imRuntimeServicesProvider);

    expect(runtime.connection, isA<ImConnectionService>());
    expect(runtime.sync, isA<ImSyncOrchestrator>());
    expect(runtime.attachments, isA<AttachmentUploadPipeline>());
    expect(runtime.delivery, isA<MessageDeliveryService>());
    expect(runtime.notifications, isA<ImNotificationBridge>());
    expect(runtime.wordRuntimeFilters, isA<ImWordRuntimeFilterService>());
    expect(runtime.maskedMessageRefresh, isA<ImMaskedMessageRefreshService>());
    expect(
      runtime.connection,
      same(container.read(imConnectionServiceProvider)),
    );
    expect(runtime.sync, same(container.read(imSyncOrchestratorProvider)));
    expect(
      runtime.attachments,
      same(container.read(attachmentUploadPipelineProvider)),
    );
    expect(
      runtime.delivery,
      same(container.read(messageDeliveryServiceProvider)),
    );
    expect(
      runtime.notifications,
      same(container.read(imNotificationBridgeProvider)),
    );
    expect(
      runtime.wordRuntimeFilters,
      same(container.read(imWordRuntimeFilterServiceProvider)),
    );
    expect(
      runtime.maskedMessageRefresh,
      same(container.read(imMaskedMessageRefreshServiceProvider)),
    );
  });

  test(
    'imServiceProvider owns the connection service from the provider graph',
    () {
      final androidManager = AndroidMessageAlertManager(
        presenter: const _NoopAndroidMessageAlertPresenter(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.android,
      );
      final desktopManager = DesktopMessageAlertManager(
        presenter: const _NoopDesktopMessageAlertPresenter(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.windows,
      );
      final sync = ImSyncOrchestrator(
        syncApi: IMSyncApi.instance,
        messageApi: MessageApi.instance,
        reminderApi: ReminderApi.instance,
        conversationDraftApi: ConversationDraftApi.instance,
      );
      final attachments = AttachmentUploadPipeline();
      final sdk = _FakeImSdkConnectionPort();
      final container = ProviderContainer(
        overrides: <Override>[
          androidMessageAlertManagerProvider.overrideWithValue(androidManager),
          desktopMessageAlertManagerProvider.overrideWithValue(desktopManager),
          imSdkConnectionPortProvider.overrideWithValue(sdk),
          imRealtimeRuntimePortProvider.overrideWithValue(
            const _NoopImRealtimeRuntimePort(),
          ),
          imConnectionRouteResolverProvider.overrideWithValue(
            (_) async => 'wss://route.example/ws',
          ),
          imSyncOrchestratorProvider.overrideWithValue(sync),
          attachmentUploadPipelineProvider.overrideWithValue(attachments),
        ],
      );

      expect(container.read(imServiceProvider.notifier), isA<IMService>());
      container.dispose();
      expect(sdk.unboundKeys, <String>['im_connection_service_listener']);
    },
  );
}

class _NoopAndroidMessageAlertPresenter
    implements AndroidMessageAlertPresenter {
  const _NoopAndroidMessageAlertPresenter();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playForegroundTick() async {}

  @override
  Future<void> showNotification(
    AndroidMessageNotification notification,
  ) async {}
}

class _NoopDesktopMessageAlertPresenter
    implements DesktopMessageAlertPresenter {
  const _NoopDesktopMessageAlertPresenter();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playForegroundTick() async {}

  @override
  Future<void> playMessageSound() async {}

  @override
  Future<void> showNotification(
    DesktopMessageNotification notification,
  ) async {}
}

class _FakeImSdkConnectionPort implements ImSdkConnectionPort {
  final List<String> unboundKeys = <String>[];

  @override
  Future<bool> setup(ImSdkSetupOptions options) async => true;

  @override
  void connect() {}

  @override
  void disconnect({required bool isLogout}) {}

  @override
  void bindStatusListener({
    required String key,
    required ImConnectionStatusHandler onStatus,
  }) {}

  @override
  void unbindStatusListener(String key) {
    unboundKeys.add(key);
  }
}

class _NoopImRealtimeRuntimePort implements ImRealtimeRuntimePort {
  const _NoopImRealtimeRuntimePort();

  @override
  bool get isRunning => false;

  @override
  Future<void> start({
    required String apiToken,
    required String deviceSessionId,
    required int lastAckedSeq,
  }) async {}

  @override
  Future<void> stop() async {}
}
