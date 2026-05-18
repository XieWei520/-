import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/im_config.dart';
import '../../wukong_push/notification/android_message_alert_manager.dart';
import '../../wukong_push/notification/desktop_message_alert_manager.dart';
import '../../wukong_push/notification/web_notification_manager.dart';
import '../api/conversation_draft_api.dart';
import '../api/file_api.dart';
import '../api/im_sync_api.dart';
import '../api/message_api.dart';
import '../api/reminder_api.dart';
import 'attachment_upload_pipeline.dart';
import 'im_connection_service.dart';
import 'im_notification_bridge.dart';
import 'im_sync_orchestrator.dart';
import 'im_word_sync_store.dart';
import 'message_delivery_service.dart';

final imSdkConnectionPortProvider = Provider<ImSdkConnectionPort>((ref) {
  return const WkImSdkConnectionPort();
});

final imRealtimeRuntimePortProvider = Provider<ImRealtimeRuntimePort>((ref) {
  return const SkeletonImRealtimeRuntimePort();
});

final imConnectionRouteResolverProvider = Provider<ImRouteResolver>((ref) {
  return (uid) async {
    final route = await IMSyncApi.instance.fetchUserConnectRoute(uid: uid);
    return ImConnectionService.selectConnectAddr(
      route,
      fallbackAddr: IMConfig.connectAddr,
    );
  };
});

final imConnectionServiceProvider = Provider<ImConnectionService>((ref) {
  return ImConnectionService(
    sdk: ref.watch(imSdkConnectionPortProvider),
    realtimeRuntime: ref.watch(imRealtimeRuntimePortProvider),
    routeResolver: ref.watch(imConnectionRouteResolverProvider),
  );
});

final imSyncOrchestratorProvider = Provider<ImSyncOrchestrator>((ref) {
  return ImSyncOrchestrator(
    syncApi: IMSyncApi.instance,
    messageApi: MessageApi.instance,
    reminderApi: ReminderApi.instance,
    conversationDraftApi: ConversationDraftApi.instance,
    wordStore: ref.watch(imWordSyncStoreProvider),
    conversationExtraStore: ref.watch(imConversationExtraStoreProvider),
    messageExtraStore: ref.watch(imMessageExtraStoreProvider),
  );
});

final imWordSyncStoreProvider = Provider<ImWordSyncStore>((ref) {
  return WkImWordSyncStore();
});

final imConversationExtraStoreProvider = Provider<ImConversationExtraStore>((
  ref,
) {
  return const WkImConversationExtraStore();
});

final imMessageExtraStoreProvider = Provider<ImMessageExtraStore>((ref) {
  return const WkImMessageExtraStore();
});

final attachmentUploadPipelineProvider = Provider<AttachmentUploadPipeline>((
  ref,
) {
  return AttachmentUploadPipeline(fileApi: FileApi.instance);
});

final androidMessageAlertManagerProvider = Provider<AndroidMessageAlertManager>(
  (ref) {
    return AndroidMessageAlertManager.instance;
  },
);

final desktopMessageAlertManagerProvider = Provider<DesktopMessageAlertManager>(
  (ref) {
    return DesktopMessageAlertManager.instance;
  },
);

final webNotificationManagerProvider = Provider<WebNotificationManager>((ref) {
  return WebNotificationManager.instance;
});

final imNotificationBridgeProvider = Provider<ImNotificationBridge>((ref) {
  return ImNotificationBridge(
    androidAlerts: ref.watch(androidMessageAlertManagerProvider),
    desktopAlerts: ref.watch(desktopMessageAlertManagerProvider),
    webNotifications: ref.watch(webNotificationManagerProvider),
  );
});

@immutable
class ImRuntimeServices {
  const ImRuntimeServices({
    required this.connection,
    required this.sync,
    required this.attachments,
    required this.delivery,
    required this.notifications,
  });

  final ImConnectionService connection;
  final ImSyncOrchestrator sync;
  final AttachmentUploadPipeline attachments;
  final MessageDeliveryService delivery;
  final ImNotificationBridge notifications;
}

final imRuntimeServicesProvider = Provider<ImRuntimeServices>((ref) {
  return ImRuntimeServices(
    connection: ref.watch(imConnectionServiceProvider),
    sync: ref.watch(imSyncOrchestratorProvider),
    attachments: ref.watch(attachmentUploadPipelineProvider),
    delivery: ref.watch(messageDeliveryServiceProvider),
    notifications: ref.watch(imNotificationBridgeProvider),
  );
});
