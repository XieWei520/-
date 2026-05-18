import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/cmd.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'attachment_upload_pipeline.dart';
import 'im_connection_service.dart';
import 'im_sync_orchestrator.dart';

typedef ImConversationCmdVersionReader = int Function();
typedef ImConversationCmdVersionWriter = void Function(int version);
typedef ImRecoveredCallingStatesApplier =
    void Function(Iterable<WKChannelState> channelStates);

class ImSdkCallbackBinder {
  ImSdkCallbackBinder({
    required this.connectionService,
    required this.syncOrchestrator,
    required this.attachmentUploadPipeline,
    this.commandListenerKey = 'im_service_cmd_listener',
    this.newMessageListenerKey = 'im_service_new_msg_listener',
  });

  final ImConnectionService connectionService;
  final ImSyncOrchestrator syncOrchestrator;
  final AttachmentUploadPipeline attachmentUploadPipeline;
  final String commandListenerKey;
  final String newMessageListenerKey;

  bool _isBound = false;

  void bind({
    required ImConnectionStatusHandler onConnectionStatus,
    required ImDeviceUuidLoader deviceUuidLoader,
    required ImConversationCmdVersionReader readConversationCmdVersion,
    required ImConversationCmdVersionWriter writeConversationCmdVersion,
    required ImRecoveredCallingStatesApplier applyRecoveredCallingStates,
    required ValueChanged<List<WKMsg>> onNewMessages,
    required ValueChanged<WKCMD> onCommand,
  }) {
    if (_isBound) {
      return;
    }

    connectionService.bindConnectionStatusListener(
      onStatus: onConnectionStatus,
    );
    WKIM.shared.cmdManager.removeCmdListener(commandListenerKey);
    WKIM.shared.messageManager.removeNewMsgListener(newMessageListenerKey);

    WKIM.shared.conversationManager.addOnSyncConversationListener((
      lastMsgSeqs,
      msgCount,
      version,
      back,
    ) async {
      try {
        final deviceUuid = await deviceUuidLoader();
        final result = await syncOrchestrator.syncConversation(
          version: version,
          lastMsgSeqs: lastMsgSeqs,
          msgCount: msgCount,
          deviceUuid: deviceUuid,
        );
        writeConversationCmdVersion(result.cmdVersion);
        applyRecoveredCallingStates(
          result.channelStatus ?? const <WKChannelState>[],
        );
        back(result);
        unawaited(
          syncOrchestrator.acknowledgeConversationSync(
            cmdVersion: result.cmdVersion,
            deviceUuid: deviceUuid,
          ),
        );
        unawaited(syncOrchestrator.handleConversationSyncCompleted());
      } catch (error, stackTrace) {
        debugPrint('Conversation sync failed: $error');
        debugPrint('$stackTrace');
        back(WKSyncConversation()..conversations = []);
      }
    });

    WKIM.shared.messageManager.addOnSyncChannelMsgListener((
      channelId,
      channelType,
      startMessageSeq,
      endMessageSeq,
      limit,
      pullMode,
      back,
    ) async {
      try {
        final deviceUuid = await deviceUuidLoader();
        final result = await syncOrchestrator.syncChannelMessages(
          channelId: channelId,
          channelType: channelType,
          startMessageSeq: startMessageSeq,
          endMessageSeq: endMessageSeq,
          limit: limit,
          pullMode: pullMode,
          deviceUuid: deviceUuid,
        );
        back(result);
        unawaited(
          syncOrchestrator.acknowledgeConversationSync(
            cmdVersion: readConversationCmdVersion(),
            deviceUuid: deviceUuid,
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('Channel sync failed: $error');
        debugPrint('$stackTrace');
        back(null);
      }
    });

    WKIM.shared.messageManager.addOnUploadAttachmentListener((wkMsg, back) {
      attachmentUploadPipeline
          .uploadMessageAttachments(wkMsg)
          .then(
            (success) => back(success, wkMsg),
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Attachment upload failed: $error');
              debugPrint('$stackTrace');
              back(false, wkMsg);
            },
          );
    });

    WKIM.shared.messageManager.addOnMsgInsertedListener((wkMsg) {
      WKIM.shared.messageManager.pushNewMsg([wkMsg]);
    });
    WKIM.shared.messageManager.addOnNewMsgListener(
      newMessageListenerKey,
      onNewMessages,
    );
    WKIM.shared.cmdManager.addOnCmdListener(commandListenerKey, onCommand);
    _isBound = true;
  }

  void unbind() {
    WKIM.shared.messageManager.removeNewMsgListener(newMessageListenerKey);
    WKIM.shared.cmdManager.removeCmdListener(commandListenerKey);
    connectionService.unbindConnectionStatusListener();
    _isBound = false;
  }
}
