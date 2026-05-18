import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import '../api/conversation_draft_api.dart';
import '../api/im_sync_api.dart';
import '../api/message_api.dart';
import '../api/reminder_api.dart';
import 'coordinators/message_sync_coordinator.dart';
import 'im_word_sync_models.dart';

typedef ImSyncTaskHandler = Future<void> Function({String? reason});
typedef ImMessageExtraSyncTask =
    Future<void> Function({
      required String channelId,
      required int channelType,
      String? reason,
    });

enum ImSyncTaskSlot {
  reminders,
  sensitiveWords,
  prohibitWords,
  conversationExtras,
  offlineCommands,
}

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

@immutable
class ImSyncFanOutPlan {
  const ImSyncFanOutPlan({
    required this.reason,
    this.syncReminders = false,
    this.syncSensitiveWords = false,
    this.syncProhibitWords = false,
    this.syncConversationExtras = false,
    this.syncOfflineCommandMessages = false,
  });

  final String reason;
  final bool syncReminders;
  final bool syncSensitiveWords;
  final bool syncProhibitWords;
  final bool syncConversationExtras;
  final bool syncOfflineCommandMessages;
}

@immutable
class ImSyncTaskHandlers {
  const ImSyncTaskHandlers({
    required this.syncReminders,
    required this.syncSensitiveWords,
    required this.syncProhibitWords,
    required this.syncConversationExtras,
    required this.syncOfflineCommandMessages,
  });

  final ImSyncTaskHandler syncReminders;
  final ImSyncTaskHandler syncSensitiveWords;
  final ImSyncTaskHandler syncProhibitWords;
  final ImSyncTaskHandler syncConversationExtras;
  final ImSyncTaskHandler syncOfflineCommandMessages;
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
  final Set<ImSyncTaskSlot> _activeTaskSlots = <ImSyncTaskSlot>{};
  final Map<ImSyncTaskSlot, String?> _pendingTaskReasons =
      <ImSyncTaskSlot, String?>{};
  final Set<String> _activeMessageExtraKeys = <String>{};
  final Map<String, String?> _pendingMessageExtraReasons = <String, String?>{};

  ImSyncStatus get status {
    return ImSyncStatus(
      isSyncingReminders: _activeTaskSlots.contains(ImSyncTaskSlot.reminders),
      isSyncingSensitiveWords: _activeTaskSlots.contains(
        ImSyncTaskSlot.sensitiveWords,
      ),
      isSyncingProhibitWords: _activeTaskSlots.contains(
        ImSyncTaskSlot.prohibitWords,
      ),
      isSyncingConversationExtras: _activeTaskSlots.contains(
        ImSyncTaskSlot.conversationExtras,
      ),
      isSyncingOfflineCommands: _activeTaskSlots.contains(
        ImSyncTaskSlot.offlineCommands,
      ),
      activeMessageExtraKeys: Set<String>.unmodifiable(_activeMessageExtraKeys),
    );
  }

  Future<void> handleSyncCompleted() {
    throw UnimplementedError(
      'Skeleton only: fan out sync-completed tasks here.',
    );
  }

  void runFanOutPlan(ImSyncFanOutPlan plan, ImSyncTaskHandlers handlers) {
    if (plan.syncReminders) {
      handlers.syncReminders(reason: plan.reason);
    }
    if (plan.syncSensitiveWords) {
      handlers.syncSensitiveWords(reason: plan.reason);
    }
    if (plan.syncProhibitWords) {
      handlers.syncProhibitWords(reason: plan.reason);
    }
    if (plan.syncConversationExtras) {
      handlers.syncConversationExtras(reason: plan.reason);
    }
    if (plan.syncOfflineCommandMessages) {
      handlers.syncOfflineCommandMessages(reason: plan.reason);
    }
  }

  Future<void> runExclusiveSyncTask(
    ImSyncTaskSlot slot, {
    String? reason,
    required ImSyncTaskHandler task,
  }) async {
    if (_activeTaskSlots.contains(slot)) {
      _pendingTaskReasons[slot] = reason;
      return;
    }

    _activeTaskSlots.add(slot);
    var currentReason = reason;
    try {
      while (true) {
        _pendingTaskReasons.remove(slot);
        await task(reason: currentReason);
        if (!_pendingTaskReasons.containsKey(slot)) {
          break;
        }
        currentReason = _pendingTaskReasons.remove(slot);
      }
    } finally {
      _activeTaskSlots.remove(slot);
    }
  }

  Future<void> runExclusiveMessageExtraTask({
    required String channelId,
    required int channelType,
    String? reason,
    required ImMessageExtraSyncTask task,
  }) async {
    final normalizedChannelId = channelId.trim();
    if (normalizedChannelId.isEmpty) {
      return;
    }

    final syncKey = coordinator.messageExtraSyncKey(
      normalizedChannelId,
      channelType,
    );
    if (_activeMessageExtraKeys.contains(syncKey)) {
      _pendingMessageExtraReasons[syncKey] = reason;
      return;
    }

    _activeMessageExtraKeys.add(syncKey);
    var currentReason = reason;
    try {
      while (true) {
        _pendingMessageExtraReasons.remove(syncKey);
        await task(
          channelId: normalizedChannelId,
          channelType: channelType,
          reason: currentReason,
        );
        if (!_pendingMessageExtraReasons.containsKey(syncKey)) {
          break;
        }
        currentReason = _pendingMessageExtraReasons.remove(syncKey);
      }
    } finally {
      _activeMessageExtraKeys.remove(syncKey);
    }
  }

  static ImSyncFanOutPlan planForSyncCompleted() {
    return const ImSyncFanOutPlan(
      reason: 'sync_completed',
      syncReminders: true,
      syncSensitiveWords: true,
      syncProhibitWords: true,
      syncConversationExtras: true,
      syncOfflineCommandMessages: true,
    );
  }

  static ImSyncFanOutPlan planForConversationSync() {
    return const ImSyncFanOutPlan(
      reason: 'conversation_sync',
      syncConversationExtras: true,
      syncOfflineCommandMessages: true,
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
