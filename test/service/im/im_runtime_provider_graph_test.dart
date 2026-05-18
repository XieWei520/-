import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/im/attachment_upload_pipeline.dart';
import 'package:wukong_im_app/service/im/im_connection_service.dart';
import 'package:wukong_im_app/service/im/im_notification_bridge.dart';
import 'package:wukong_im_app/service/im/im_service_providers.dart';
import 'package:wukong_im_app/service/im/im_sync_orchestrator.dart';
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
  });
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
