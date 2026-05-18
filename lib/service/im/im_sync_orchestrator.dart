import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import '../api/conversation_draft_api.dart';
import '../api/im_sync_api.dart';
import '../api/message_api.dart';
import '../api/reminder_api.dart';
import 'coordinators/message_sync_coordinator.dart';
import 'im_word_sync_models.dart';

@immutable
class ImSyncStatus {
  const ImSyncStatus({
    this.isSyncingReminders = false,
    this.isSyncingSensitiveWords = false,
    this.isSyncingProhibitWords = false,
    this.isSyncingConversationExtras = false,
    this.isSyncingOfflineCommands = false,
    this.activeMessageExtraKeys = const <String>{},
  });

  final bool isSyncingReminders;
  final bool isSyncingSensitiveWords;
  final bool isSyncingProhibitWords;
  final bool isSyncingConversationExtras;
  final bool isSyncingOfflineCommands;
  final Set<String> activeMessageExtraKeys;
}

class ImSyncOrchestrator {
  ImSyncOrchestrator({
    required this.syncApi,
    required this.messageApi,
    required this.reminderApi,
    required this.conversationDraftApi,
    this.coordinator = const MessageSyncCoordinator(),
  });

  final IMSyncApi syncApi;
  final MessageApi messageApi;
  final ReminderApi reminderApi;
  final ConversationDraftRemoteStore conversationDraftApi;
  final MessageSyncCoordinator coordinator;

  ImSyncStatus get status {
    throw UnimplementedError('Skeleton only: move sync in-flight state here.');
  }

  Future<void> handleSyncCompleted() {
    throw UnimplementedError(
      'Skeleton only: fan out sync-completed tasks here.',
    );
  }

  Future<WKSyncConversation> syncConversation({
    required int version,
    required String lastMsgSeqs,
    required int msgCount,
    required String deviceUuid,
  }) {
    throw UnimplementedError(
      'Skeleton only: move conversation sync callback here.',
    );
  }

  Future<WKSyncChannelMsg?> syncChannelMessages({
    required String channelId,
    required int channelType,
    required int startMessageSeq,
    required int endMessageSeq,
    required int limit,
    required int pullMode,
    required String deviceUuid,
  }) {
    throw UnimplementedError('Skeleton only: move channel sync callback here.');
  }

  Future<void> acknowledgeConversationSync({
    required int cmdVersion,
    required String deviceUuid,
  }) {
    throw UnimplementedError('Skeleton only: move sync ack here.');
  }

  Future<void> syncReminders({String? reason}) {
    throw UnimplementedError('Skeleton only: move reminder sync here.');
  }

  Future<void> syncSensitiveWords({String? reason}) {
    throw UnimplementedError('Skeleton only: move sensitive-word sync here.');
  }

  Future<void> applySensitiveWordsSync(SensitiveWordsSnapshot snapshot) {
    throw UnimplementedError(
      'Skeleton only: move sensitive-word application here.',
    );
  }

  Future<void> syncProhibitWords({String? reason}) {
    throw UnimplementedError('Skeleton only: move prohibit-word sync here.');
  }

  Future<void> applyProhibitWordsSync(List<ProhibitWordEntry> words) {
    throw UnimplementedError(
      'Skeleton only: move prohibit-word application here.',
    );
  }

  Future<void> syncConversationExtras({String? reason}) {
    throw UnimplementedError(
      'Skeleton only: move conversation-extra sync here.',
    );
  }

  Future<void> syncMessageExtras({
    required String channelId,
    required int channelType,
    String? reason,
  }) {
    throw UnimplementedError('Skeleton only: move message-extra sync here.');
  }

  Future<void> syncOfflineCommandMessages({String? reason}) {
    throw UnimplementedError(
      'Skeleton only: move offline command sync and ack here.',
    );
  }
}
