import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/entity/reminder.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../home/home_surface_contract.dart';
import '../home/home_surface_invalidation_bus.dart';
import '../../wukong_base/msg/draft_manager.dart';
import 'conversation_activity_registry.dart';

final conversationListRefreshProvider = StateNotifierProvider.autoDispose<
  ConversationListRefreshController,
  ConversationListRefreshState
>((ref) {
  return ConversationListRefreshController();
});

@immutable
class ConversationListRefreshState {
  const ConversationListRefreshState({
    this.globalVersion = 0,
    this.keyVersions = const <String, int>{},
  });

  final int globalVersion;
  final Map<String, int> keyVersions;

  int versionFor(String channelId, int channelType) {
    final key = ConversationActivityRegistry.conversationKey(
      channelId,
      channelType,
    );
    return Object.hash(globalVersion, keyVersions[key] ?? 0);
  }

  ConversationListRefreshState markConversation(
    String channelId,
    int channelType,
  ) {
    return markKey(
      ConversationActivityRegistry.conversationKey(channelId, channelType),
    );
  }

  ConversationListRefreshState markKey(String key) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return this;
    }
    final nextVersions = <String, int>{...keyVersions};
    nextVersions[normalizedKey] = (nextVersions[normalizedKey] ?? 0) + 1;
    return ConversationListRefreshState(
      globalVersion: globalVersion,
      keyVersions: nextVersions,
    );
  }

  ConversationListRefreshState markAll() {
    return ConversationListRefreshState(
      globalVersion: globalVersion + 1,
      keyVersions: keyVersions,
    );
  }
}

class ConversationListRefreshController
    extends StateNotifier<ConversationListRefreshState> {
  ConversationListRefreshController({bool attachSources = true})
    : super(const ConversationListRefreshState()) {
    if (attachSources) {
      _attachSources();
    }
  }

  static const String _channelRefreshListenerKey =
      'conversation_list_refresh_controller';
  static const String _messageRefreshListenerKey =
      'conversation_list_refresh_controller';
  static const String _reminderRefreshListenerKey =
      'conversation_list_refresh_controller';

  StreamSubscription<DraftUpdate>? _draftSubscription;

  void _attachSources() {
    _draftSubscription = DraftManager().draftUpdates.listen(_handleDraftUpdate);
    WKIM.shared.channelManager.addOnRefreshListener(
      _channelRefreshListenerKey,
      _handleChannelRefresh,
    );
    WKIM.shared.messageManager.addOnRefreshMsgListener(
      _messageRefreshListenerKey,
      _handleMessageRefresh,
    );
    WKIM.shared.reminderManager.addOnNewReminderListener(
      _reminderRefreshListenerKey,
      _handleReminderRefresh,
    );
    ConversationActivityRegistry.instance.addGlobalListener(
      _handleActivityRefresh,
    );
  }

  @visibleForTesting
  void markConversationChanged(String channelId, int channelType) {
    state = state.markConversation(channelId, channelType);
  }

  void markConversationDirty(String requestKey) {
    state = state.markKey(requestKey);
  }

  @visibleForTesting
  void markAllChanged() {
    state = state.markAll();
  }

  void _handleDraftUpdate(DraftUpdate update) {
    if (update.type == DraftUpdateType.clearAll) {
      markAllChanged();
      return;
    }

    final channelId = update.channelId?.trim() ?? '';
    final channelType = update.channelType;
    if (channelId.isEmpty || channelType == null) {
      return;
    }
    markConversationChanged(channelId, channelType);
  }

  void _handleChannelRefresh(WKChannel channel) {
    final channelId = channel.channelID.trim();
    if (channelId.isEmpty) {
      return;
    }
    markConversationChanged(channelId, channel.channelType);
  }

  void _handleMessageRefresh(WKMsg message) {
    final channelId = message.channelID.trim();
    if (channelId.isEmpty) {
      return;
    }
    markConversationChanged(channelId, message.channelType);
  }

  void _handleReminderRefresh(List<WKReminder> reminders) {
    if (reminders.isEmpty) {
      return;
    }

    var nextState = state;
    final touchedKeys = <String>{};
    for (final reminder in reminders) {
      final channelId = reminder.channelID.trim();
      if (channelId.isEmpty) {
        continue;
      }
      final key = ConversationActivityRegistry.conversationKey(
        channelId,
        reminder.channelType,
      );
      if (!touchedKeys.add(key)) {
        continue;
      }
      nextState = nextState.markKey(key);
    }

    if (!identical(nextState, state)) {
      state = nextState;
    }
  }

  void _handleActivityRefresh(String conversationKey) {
    state = state.markKey(conversationKey);
  }

  @override
  void dispose() {
    _draftSubscription?.cancel();
    WKIM.shared.channelManager.removeOnRefreshListener(
      _channelRefreshListenerKey,
    );
    WKIM.shared.messageManager.removeOnRefreshMsgListener(
      _messageRefreshListenerKey,
    );
    WKIM.shared.reminderManager.removeOnNewReminderListener(
      _reminderRefreshListenerKey,
    );
    ConversationActivityRegistry.instance.removeGlobalListener(
      _handleActivityRefresh,
    );
    super.dispose();
  }
}

class ConversationSurfaceBridge {
  ConversationSurfaceBridge({
    required this.refreshController,
    required this.invalidationBus,
  });

  final ConversationListRefreshController refreshController;
  final HomeSurfaceInvalidationBus invalidationBus;

  void onConversationChanged(String requestKey) {
    refreshController.markConversationDirty(requestKey);
    invalidationBus.emit(
      const HomeSurfaceInvalidation(
        surfaceId: HomeSurfaceId.conversations,
        kind: HomeInvalidationKind.structural,
      ),
    );
  }
}
