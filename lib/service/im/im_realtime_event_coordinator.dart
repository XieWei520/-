import 'package:wukongimfluttersdk/entity/conversation.dart';

import '../../modules/conversation/conversation_activity_registry.dart';
import '../../modules/conversation/conversation_projection.dart';
import '../../realtime/control/control_event.dart';
import '../../realtime/session/session_event_frame.dart';

typedef ImRealtimeConversationPatchApplier =
    void Function(ConversationPatch patch);
typedef ImRealtimeCallFrameHandler =
    Future<void> Function(SessionEventFrame frame);
typedef ImCallingStateSetter =
    void Function(String channelId, int channelType, bool isCalling);
typedef ImActiveCallingKeysLoader = Set<String> Function();

class ImRealtimeEventCoordinator {
  ImRealtimeEventCoordinator({
    required ImRealtimeConversationPatchApplier applyConversationPatch,
    required ImRealtimeCallFrameHandler handleCallSessionFrame,
    ImCallingStateSetter? setCallingState,
    ImActiveCallingKeysLoader? activeCallingKeysLoader,
  }) : _applyConversationPatch = applyConversationPatch,
       _handleCallSessionFrame = handleCallSessionFrame,
       _setCallingState =
           setCallingState ??
           ((channelId, channelType, isCalling) {
             ConversationActivityRegistry.instance.setCallingState(
               channelId,
               channelType,
               isCalling,
             );
           }),
       _activeCallingKeysLoader =
           activeCallingKeysLoader ??
           ConversationActivityRegistry
               .instance
               .getActiveCallingConversationKeys;

  final ImRealtimeConversationPatchApplier _applyConversationPatch;
  final ImRealtimeCallFrameHandler _handleCallSessionFrame;
  final ImCallingStateSetter _setCallingState;
  final ImActiveCallingKeysLoader _activeCallingKeysLoader;

  Future<void> handleSessionFrame(SessionEventFrame frame) async {
    final controlEvent = mapSessionControlEvent(frame);
    if (controlEvent is ConversationUpdatedEvent) {
      _applyConversationUpdatedEvent(controlEvent);
    }
    await _handleCallSessionFrame(frame);
  }

  Set<String> applyRecoveredCallingStates(
    Iterable<WKChannelState> channelStates,
  ) {
    final nextKeys = <String>{};
    for (final channelState in channelStates) {
      final channelId = channelState.channelID.trim();
      if (channelId.isEmpty) {
        continue;
      }
      final channelKey = ConversationActivityRegistry.conversationKey(
        channelId,
        channelState.channelType,
      );
      final isCalling = channelState.calling > 0;
      _setCallingState(channelId, channelState.channelType, isCalling);
      if (isCalling) {
        nextKeys.add(channelKey);
      }
    }

    final previousCallingKeys = _activeCallingKeysLoader();
    for (final staleKey in previousCallingKeys.difference(nextKeys)) {
      final target = _parseRecoveredCallingKey(staleKey);
      if (target == null) {
        continue;
      }
      _setCallingState(target.channelId, target.channelType, false);
    }

    return Set<String>.from(nextKeys);
  }

  void _applyConversationUpdatedEvent(ConversationUpdatedEvent event) {
    _applyConversationPatch(
      ConversationPatch.unreadAndDigest(
        channelId: event.channelId,
        channelType: event.channelType,
        unreadCount: event.unreadCount,
        lastMessageDigest: event.lastMessageDigest,
        sortTimestamp: event.sortTimestamp,
      ),
    );
  }

  _RecoveredCallingKey? _parseRecoveredCallingKey(String key) {
    final separatorIndex = key.indexOf('_');
    if (separatorIndex <= 0 || separatorIndex >= key.length - 1) {
      return null;
    }

    final channelType = int.tryParse(key.substring(0, separatorIndex));
    final channelId = key.substring(separatorIndex + 1).trim();
    if (channelType == null || channelId.isEmpty) {
      return null;
    }

    return _RecoveredCallingKey(channelId: channelId, channelType: channelType);
  }
}

class _RecoveredCallingKey {
  const _RecoveredCallingKey({
    required this.channelId,
    required this.channelType,
  });

  final String channelId;
  final int channelType;
}
