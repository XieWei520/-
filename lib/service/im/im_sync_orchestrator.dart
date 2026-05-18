import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/entity/reminder.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../api/conversation_draft_api.dart';
import '../api/im_sync_api.dart';
import '../api/message_api.dart';
import '../api/reminder_api.dart';
import 'coordinators/message_sync_coordinator.dart';
import 'im_connection_service.dart';
import 'im_word_sync_models.dart';
import 'im_word_sync_store.dart';

typedef ImSyncTaskHandler = Future<void> Function({String? reason});
typedef ImMessageExtraSyncTask =
    Future<void> Function({
      required String channelId,
      required int channelType,
      String? reason,
    });
typedef ImReminderChannelIdsLoader = Future<List<String>> Function();
typedef ImRefreshMaskedMessagesTask = Future<void> Function();
typedef ImDeviceUuidLoader = Future<String> Function();
typedef ImMessageExtraRefreshPublisher =
    void Function(
      String channelId,
      int channelType,
      Iterable<WKMsgExtra> extras,
    );
typedef ImSyncDelay = Future<void> Function(Duration duration);

abstract interface class ImMessageExtraStore {
  Future<int> getMaxExtraVersionWithChannel(String channelId, int channelType);

  WKMsgExtra toMessageExtra(
    String channelId,
    int channelType,
    WKSyncExtraMsg extra,
  );

  Future<void> saveRemoteExtraMsg(List<WKMsgExtra> extras);

  bool get usesLocalPersistence;
}

class WkImMessageExtraStore implements ImMessageExtraStore {
  const WkImMessageExtraStore();

  @override
  Future<int> getMaxExtraVersionWithChannel(String channelId, int channelType) {
    return WKIM.shared.messageManager.getMaxExtraVersionWithChannel(
      channelId,
      channelType,
    );
  }

  @override
  WKMsgExtra toMessageExtra(
    String channelId,
    int channelType,
    WKSyncExtraMsg extra,
  ) {
    return WKIM.shared.messageManager.wkSyncExtraMsg2WKMsgExtra(
      channelId,
      channelType,
      extra,
    );
  }

  @override
  Future<void> saveRemoteExtraMsg(List<WKMsgExtra> extras) {
    return WKIM.shared.messageManager.saveRemoteExtraMsg(extras);
  }

  @override
  bool get usesLocalPersistence {
    return ImConnectionService.shouldUseLocalPersistence(
      isWeb: kIsWeb,
      sdkAppMode: WKIM.shared.isApp(),
    );
  }
}

abstract interface class ImConversationExtraStore {
  Future<int> getMaxVersion();

  Future<void> saveSyncExtras(List<WKSyncConvMsgExtra> extras);
}

class WkImConversationExtraStore implements ImConversationExtraStore {
  const WkImConversationExtraStore();

  @override
  Future<int> getMaxVersion() {
    return WKIM.shared.conversationManager.getMsgExtraMaxVersion();
  }

  @override
  Future<void> saveSyncExtras(List<WKSyncConvMsgExtra> extras) {
    return WKIM.shared.conversationManager.saveSyncMsgExtras(extras);
  }
}

abstract interface class ImReminderStore {
  Future<int> getMaxVersion();

  Future<void> saveOrUpdateReminders(List<WKReminder> reminders);
}

class WkImReminderStore implements ImReminderStore {
  const WkImReminderStore();

  @override
  Future<int> getMaxVersion() {
    return WKIM.shared.reminderManager.getMaxVersion();
  }

  @override
  Future<void> saveOrUpdateReminders(List<WKReminder> reminders) {
    return WKIM.shared.reminderManager.saveOrUpdateReminders(reminders);
  }
}

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
    ImReminderStore? reminderStore,
    ImReminderChannelIdsLoader? reminderChannelIdsLoader,
    ImWordSyncStore? wordStore,
    ImConversationExtraStore? conversationExtraStore,
    ImMessageExtraStore? messageExtraStore,
    ImRefreshMaskedMessagesTask? refreshMaskedMessagesAfterProhibitWordSync,
    ImSyncDelay? syncDelay,
    this.coordinator = const MessageSyncCoordinator(),
  }) : reminderStore = reminderStore ?? const WkImReminderStore(),
       reminderChannelIdsLoader =
           reminderChannelIdsLoader ?? loadWkImReminderChannelIds,
       wordStore = wordStore ?? WkImWordSyncStore(),
       conversationExtraStore =
           conversationExtraStore ?? const WkImConversationExtraStore(),
       messageExtraStore = messageExtraStore ?? const WkImMessageExtraStore(),
       refreshMaskedMessagesAfterProhibitWordSync =
           refreshMaskedMessagesAfterProhibitWordSync ??
           _noopRefreshMaskedMessages,
       _syncDelay = syncDelay ?? Future<void>.delayed;

  final IMSyncApi syncApi;
  final MessageApi messageApi;
  final ReminderApi reminderApi;
  final ConversationDraftRemoteStore conversationDraftApi;
  final ImReminderStore reminderStore;
  final ImReminderChannelIdsLoader reminderChannelIdsLoader;
  final ImWordSyncStore wordStore;
  final ImConversationExtraStore conversationExtraStore;
  final ImMessageExtraStore messageExtraStore;
  final ImRefreshMaskedMessagesTask refreshMaskedMessagesAfterProhibitWordSync;
  final MessageSyncCoordinator coordinator;
  final ImSyncDelay _syncDelay;
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
    return syncApi.syncConversation(
      version: version,
      lastMsgSeqs: lastMsgSeqs,
      msgCount: msgCount,
      deviceUuid: deviceUuid,
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
    return syncApi.syncChannelMessages(
      channelId: channelId,
      channelType: channelType,
      startMessageSeq: startMessageSeq,
      endMessageSeq: endMessageSeq,
      limit: limit,
      pullMode: pullMode,
      deviceUuid: deviceUuid,
    );
  }

  Future<void> acknowledgeConversationSync({
    required int cmdVersion,
    required String deviceUuid,
  }) async {
    try {
      await syncApi.ackConversationSync(
        cmdVersion: cmdVersion,
        deviceUuid: deviceUuid,
      );
    } catch (error, stackTrace) {
      debugPrint('Conversation sync ack failed: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> syncReminders({String? reason}) {
    return runExclusiveSyncTask(
      ImSyncTaskSlot.reminders,
      reason: reason,
      task: ({reason}) async {
        try {
          final version = await reminderStore.getMaxVersion();
          final channelIds = await reminderChannelIdsLoader();
          final reminders = await reminderApi.syncReminders(
            version: version,
            channelIds: channelIds,
          );
          if (reminders.isNotEmpty) {
            await reminderStore.saveOrUpdateReminders(reminders);
          }
        } catch (error, stackTrace) {
          debugPrint('Reminder sync failed($reason): $error');
          debugPrint('$stackTrace');
        }
      },
    );
  }

  Future<void> syncSensitiveWords({String? reason}) {
    return runExclusiveSyncTask(
      ImSyncTaskSlot.sensitiveWords,
      reason: reason,
      task: ({reason}) async {
        try {
          final version = wordStore.loadSensitiveWordsSnapshot().version;
          final snapshot = await messageApi.syncSensitiveWords(
            version: version,
          );
          if (snapshot.version > 0 || snapshot.tips.trim().isNotEmpty) {
            await applySensitiveWordsSync(snapshot);
          }
        } catch (error, stackTrace) {
          debugPrint('Sensitive words sync failed($reason): $error');
          debugPrint('$stackTrace');
        }
      },
    );
  }

  Future<void> applySensitiveWordsSync(SensitiveWordsSnapshot snapshot) {
    return wordStore.applySensitiveWordsSync(snapshot);
  }

  Future<void> syncProhibitWords({
    String? reason,
    ImRefreshMaskedMessagesTask? refreshMaskedMessagesAfterProhibitWordSync,
  }) {
    if (!wordStore.usesLocalPersistence) {
      return Future<void>.value();
    }

    final refreshMaskedMessages =
        refreshMaskedMessagesAfterProhibitWordSync ??
        this.refreshMaskedMessagesAfterProhibitWordSync;
    return runExclusiveSyncTask(
      ImSyncTaskSlot.prohibitWords,
      reason: reason,
      task: ({reason}) async {
        try {
          final version = await wordStore.getMaxProhibitWordVersion();
          final words = await messageApi.syncProhibitWords(version: version);
          if (words.isNotEmpty) {
            await applyProhibitWordsSync(words);
            await refreshMaskedMessages();
          }
        } catch (error, stackTrace) {
          debugPrint('Prohibit words sync failed($reason): $error');
          debugPrint('$stackTrace');
        }
      },
    );
  }

  Future<void> applyProhibitWordsSync(List<ProhibitWordEntry> words) {
    return wordStore.applyProhibitWordsSync(words);
  }

  Future<void> syncConversationExtras({String? reason}) {
    return runExclusiveSyncTask(
      ImSyncTaskSlot.conversationExtras,
      reason: reason,
      task: ({reason}) async {
        try {
          final version = await conversationExtraStore.getMaxVersion();
          final extras = await conversationDraftApi.syncExtras(
            version: version,
          );
          if (extras.isNotEmpty) {
            await conversationExtraStore.saveSyncExtras(
              extras.map(toSyncConversationExtra).toList(growable: false),
            );
          }
        } catch (error, stackTrace) {
          debugPrint('Conversation extra sync failed($reason): $error');
          debugPrint('$stackTrace');
        }
      },
    );
  }

  WKSyncConvMsgExtra toSyncConversationExtra(RemoteConversationDraft extra) {
    return WKSyncConvMsgExtra()
      ..channelID = extra.channelId
      ..channelType = extra.channelType
      ..browseTo = extra.browseTo
      ..keepMessageSeq = extra.keepMessageSeq
      ..keepOffsetY = extra.keepOffsetY
      ..draft = extra.draft
      ..version = extra.version;
  }

  Future<void> syncMessageExtras({
    required String channelId,
    required int channelType,
    String? reason,
    required ImDeviceUuidLoader deviceUuidLoader,
    ImMessageExtraRefreshPublisher? publishRealtimeMessageExtraRefresh,
  }) {
    return runExclusiveMessageExtraTask(
      channelId: channelId,
      channelType: channelType,
      reason: reason,
      task: ({required channelId, required channelType, reason}) async {
        try {
          final deviceUuid = await deviceUuidLoader();
          final extraVersion = await messageExtraStore
              .getMaxExtraVersionWithChannel(channelId, channelType);
          final extras = await messageApi.syncMessageExtras(
            channelId: channelId,
            channelType: channelType,
            extraVersion: extraVersion,
            deviceUuid: deviceUuid,
            limit: 100,
          );
          if (extras.isEmpty) {
            return;
          }
          final mappedExtras = extras
              .map(
                (item) => messageExtraStore.toMessageExtra(
                  channelId,
                  channelType,
                  item,
                ),
              )
              .toList(growable: false);
          await messageExtraStore.saveRemoteExtraMsg(mappedExtras);
          if (!messageExtraStore.usesLocalPersistence) {
            publishRealtimeMessageExtraRefresh?.call(
              channelId,
              channelType,
              mappedExtras,
            );
          }
          await _syncDelay(const Duration(milliseconds: 500));
        } catch (error, stackTrace) {
          debugPrint(
            'Message extra sync failed($reason:$channelId/$channelType): $error',
          );
          debugPrint('$stackTrace');
        }
      },
    );
  }

  Future<void> syncOfflineCommandMessages({String? reason}) {
    throw UnimplementedError(
      'Skeleton only: move offline command sync and ack here.',
    );
  }
}

Future<List<String>> loadWkImReminderChannelIds() async {
  try {
    final conversations = await WKIM.shared.conversationManager.getAll();
    final ids = <String>{};
    for (final item in conversations) {
      if (item.channelType == WKChannelType.group &&
          item.channelID.trim().isNotEmpty) {
        ids.add(item.channelID.trim());
      }
    }
    return ids.toList();
  } catch (_) {
    return const <String>[];
  }
}

Future<void> _noopRefreshMaskedMessages() async {}
