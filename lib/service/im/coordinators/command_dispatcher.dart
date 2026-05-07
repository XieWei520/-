import 'package:wukongimfluttersdk/entity/cmd.dart';

const String imSyncRemindersCommand = 'wk_sync_reminders';
const String imSyncMessageExtraCommand = 'wk_sync_message_extra';
const String imSyncConversationExtraCommand = 'wk_sync_conversation_extra';
const String imSyncPinnedMessageCommand = 'syncPinnedMessage';

enum IMCommandSideEffect {
  refreshFriendList,
  refreshFriendRequests,
  syncReminders,
  syncMessageExtra,
  syncConversationExtra,
}

class CommandChannelTarget {
  const CommandChannelTarget({
    required this.channelId,
    required this.channelType,
  });

  final String channelId;
  final int channelType;
}

class CommandDispatchPlan {
  const CommandDispatchPlan({
    required this.normalizedCommand,
    required this.effects,
    required this.shouldNotifyVipExpired,
    this.messageExtraTarget,
  });

  final String normalizedCommand;
  final Set<IMCommandSideEffect> effects;
  final bool shouldNotifyVipExpired;
  final CommandChannelTarget? messageExtraTarget;
}

class CommandDispatcher {
  const CommandDispatcher();

  CommandDispatchPlan plan(WKCMD cmd) {
    final normalizedCommand = cmd.cmd.trim();
    final effects = resolveSideEffects(normalizedCommand);
    return CommandDispatchPlan(
      normalizedCommand: normalizedCommand,
      effects: effects,
      shouldNotifyVipExpired: normalizedCommand == 'vip_expired',
      messageExtraTarget: effects.contains(IMCommandSideEffect.syncMessageExtra)
          ? resolveChannelTarget(cmd)
          : null,
    );
  }

  Set<IMCommandSideEffect> resolveSideEffects(String rawCommand) {
    switch (rawCommand.trim()) {
      case 'friendAccept':
        return const <IMCommandSideEffect>{
          IMCommandSideEffect.refreshFriendList,
          IMCommandSideEffect.refreshFriendRequests,
        };
      case 'friendRequest':
        return const <IMCommandSideEffect>{
          IMCommandSideEffect.refreshFriendRequests,
        };
      case imSyncRemindersCommand:
        return const <IMCommandSideEffect>{IMCommandSideEffect.syncReminders};
      case imSyncMessageExtraCommand:
      case 'syncMessageExtra':
      case imSyncPinnedMessageCommand:
      case 'messageRevoke':
        return const <IMCommandSideEffect>{
          IMCommandSideEffect.syncMessageExtra,
        };
      case imSyncConversationExtraCommand:
        return const <IMCommandSideEffect>{
          IMCommandSideEffect.syncConversationExtra,
        };
      default:
        return const <IMCommandSideEffect>{};
    }
  }

  CommandChannelTarget? resolveChannelTarget(WKCMD cmd) {
    final param = cmd.param;
    if (param is! Map) {
      return null;
    }
    return _targetFromMap(param) ?? _targetFromNestedPayload(param);
  }

  CommandChannelTarget? _targetFromNestedPayload(Map<dynamic, dynamic> param) {
    for (final key in const <String>['payload', 'data', 'extra']) {
      final nested = param[key];
      if (nested is Map) {
        final target = _targetFromMap(nested);
        if (target != null) {
          return target;
        }
      }
    }
    return null;
  }

  CommandChannelTarget? _targetFromMap(Map<dynamic, dynamic> raw) {
    final channelId = _readString(raw['channel_id']);
    final channelType = _readInt(raw['channel_type']);
    if (channelId.isEmpty || channelType <= 0) {
      return null;
    }
    return CommandChannelTarget(channelId: channelId, channelType: channelType);
  }

  static String _readString(dynamic value) => value?.toString().trim() ?? '';

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }
}

Set<IMCommandSideEffect> resolveImCommandSideEffects(String rawCommand) {
  return const CommandDispatcher().resolveSideEffects(rawCommand);
}
