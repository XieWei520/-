import '../../data/models/group.dart';

enum GroupMemberModerationAction {
  mute,
  unmute,
  addToBlacklist,
  removeFromBlacklist,
}

class GroupModerationPolicy {
  const GroupModerationPolicy._();

  static bool canModerateTarget({
    required GroupMember actor,
    required GroupMember target,
  }) {
    if (actor.uid == target.uid) {
      return false;
    }

    if (actor.isOwner) {
      return !target.isOwner;
    }

    if (actor.isAdmin) {
      return target.isNormal;
    }

    return false;
  }

  static List<GroupMemberModerationAction> actionsFor({
    required GroupMember actor,
    required GroupMember target,
    required DateTime now,
  }) {
    if (!canModerateTarget(actor: actor, target: target)) {
      return const <GroupMemberModerationAction>[];
    }

    return <GroupMemberModerationAction>[
      target.isMutedAt(now)
          ? GroupMemberModerationAction.unmute
          : GroupMemberModerationAction.mute,
      target.isBlacklisted
          ? GroupMemberModerationAction.removeFromBlacklist
          : GroupMemberModerationAction.addToBlacklist,
    ];
  }

  static List<GroupMember> blacklistMembers(List<GroupMember> members) {
    return members
        .where((member) => member.isBlacklisted)
        .toList(growable: false);
  }

  static List<GroupMember> blacklistAddCandidates({
    required GroupMember actor,
    required List<GroupMember> members,
  }) {
    return members
        .where((member) {
          if (member.isBlacklisted) {
            return false;
          }
          return canModerateTarget(actor: actor, target: member);
        })
        .toList(growable: false);
  }
}
