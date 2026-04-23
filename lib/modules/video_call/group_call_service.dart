import 'dart:math' as math;

import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../service/api/group_api.dart';
import '../../wukong_base/endpoint/endpoint_manager.dart';
import '../../wukong_base/endpoint/menu/endpoint_menu.dart';

typedef GroupCallMembersLoader =
    Future<List<WKChannelMember>> Function({
      required String channelId,
      required int channelType,
    });
typedef GroupCallMembersPageLoader =
    Future<GroupCallMemberPage> Function({
      required String channelId,
      required int channelType,
      required String keyword,
      required int page,
      required int pageSize,
    });
typedef GroupCallCreator =
    Future<GroupCallCreateResult> Function({
      required String channelId,
      required int channelType,
      required List<GroupCallMemberCandidate> selectedMembers,
    });

class GroupCallService {
  GroupCallService({
    GroupCallMembersLoader? loadGroupMembers,
    String? Function()? currentUidReader,
    bool Function(String uid)? isSystemAccount,
    int Function()? maxSelectableCountReader,
    this.loadMembersPage,
    this.createGroupCallRunner,
  }) : _loadGroupMembers = loadGroupMembers ?? _defaultLoadGroupMembers,
       _currentUidReader = currentUidReader ?? _defaultCurrentUidReader,
       _isSystemAccount = isSystemAccount ?? _defaultIsSystemAccount,
       _maxSelectableCountReader =
           maxSelectableCountReader ?? _defaultMaxSelectableCountReader;

  static const int _fallbackMaxSelectableCount = 9;
  static const String _systemTeamId = 'u_10000';
  static const String _fileHelperId = 'fileHelper';

  final GroupCallMembersLoader _loadGroupMembers;
  final String? Function() _currentUidReader;
  final bool Function(String uid) _isSystemAccount;
  final int Function() _maxSelectableCountReader;
  final GroupCallMembersPageLoader? loadMembersPage;
  final GroupCallCreator? createGroupCallRunner;

  Future<GroupCallMemberPage> loadMembers({
    required String channelId,
    required int channelType,
    String keyword = '',
    int page = 1,
    int pageSize = 100,
  }) async {
    if (loadMembersPage != null) {
      return loadMembersPage!(
        channelId: channelId,
        channelType: channelType,
        keyword: keyword,
        page: page,
        pageSize: pageSize,
      );
    }

    final safePage = page < 1 ? 1 : page;
    final safePageSize = pageSize < 1 ? 100 : pageSize;
    final normalizedKeyword = keyword.trim().toLowerCase();
    final currentUid = _currentUidReader()?.trim() ?? '';
    final members = await _loadGroupMembers(
      channelId: channelId,
      channelType: channelType,
    );

    final filteredMembers = members
        .where((member) => !_shouldSkipMember(member, currentUid))
        .map(_toCandidate)
        .where(
          (candidate) => _matchesKeyword(
            candidate: candidate,
            normalizedKeyword: normalizedKeyword,
          ),
        )
        .toList(growable: false);

    final start = (safePage - 1) * safePageSize;
    if (start >= filteredMembers.length) {
      return GroupCallMemberPage(
        items: const <GroupCallMemberCandidate>[],
        page: safePage,
        hasMore: false,
        maxSelectableCount: _maxSelectableCountReader(),
      );
    }

    final end = math.min(start + safePageSize, filteredMembers.length);
    return GroupCallMemberPage(
      items: filteredMembers.sublist(start, end),
      page: safePage,
      hasMore: end < filteredMembers.length,
      maxSelectableCount: _maxSelectableCountReader(),
    );
  }

  Future<GroupCallCreateResult> createGroupCall({
    required String channelId,
    required int channelType,
    required List<GroupCallMemberCandidate> selectedMembers,
  }) async {
    if (createGroupCallRunner != null) {
      return createGroupCallRunner!(
        channelId: channelId,
        channelType: channelType,
        selectedMembers: selectedMembers,
      );
    }

    final maxSelectableCount = _maxSelectableCountReader();
    if (selectedMembers.isEmpty) {
      return const GroupCallCreateResult(shouldClose: false);
    }
    if (selectedMembers.length > maxSelectableCount) {
      return GroupCallCreateResult(
        shouldClose: false,
        feedbackMessage: '最多选择 $maxSelectableCount 人',
      );
    }

    return const GroupCallCreateResult(shouldClose: true);
  }

  bool _shouldSkipMember(WKChannelMember member, String currentUid) {
    final memberUid = member.memberUID.trim();
    if (memberUid.isEmpty) {
      return true;
    }
    if (memberUid == currentUid) {
      return true;
    }
    if (_isSystemAccount(memberUid)) {
      return true;
    }
    return member.isDeleted == 1;
  }

  static GroupCallMemberCandidate _toCandidate(WKChannelMember member) {
    final displayName = member.memberRemark.trim().isNotEmpty
        ? member.memberRemark.trim()
        : member.memberName.trim();
    final remark = member.memberRemark.trim();
    return GroupCallMemberCandidate(
      uid: member.memberUID.trim(),
      displayName: displayName.isNotEmpty
          ? displayName
          : member.memberUID.trim(),
      avatarUrl: member.memberAvatar.trim().isEmpty
          ? null
          : member.memberAvatar.trim(),
      remark: remark.isEmpty ? null : remark,
    );
  }

  static bool _matchesKeyword({
    required GroupCallMemberCandidate candidate,
    required String normalizedKeyword,
  }) {
    if (normalizedKeyword.isEmpty) {
      return true;
    }
    return <String>[
      candidate.uid,
      candidate.displayName,
      candidate.remark ?? '',
    ].any((value) => value.toLowerCase().contains(normalizedKeyword));
  }

  static Future<List<WKChannelMember>> _defaultLoadGroupMembers({
    required String channelId,
    required int channelType,
  }) async {
    final localMembers =
        await WKIM.shared.channelMemberManager.getMembers(
          channelId,
          channelType,
        ) ??
        <WKChannelMember>[];
    if (localMembers.isNotEmpty || channelType != WKChannelType.group) {
      return localMembers;
    }

    final remoteMembers = await GroupApi.instance.getGroupMembers(channelId);
    return remoteMembers
        .map(
          (member) => WKChannelMember()
            ..channelID = channelId
            ..channelType = channelType
            ..memberUID = member.uid
            ..memberName = member.name ?? ''
            ..memberRemark = member.remark ?? ''
            ..memberAvatar = member.avatar ?? ''
            ..role = member.role ?? 0
            ..status = member.status ?? 0
            ..version = member.version ?? 0
            ..memberInviteUID = member.inviteUid ?? ''
            ..forbiddenExpirationTime = member.forbiddenExpirTime ?? 0,
        )
        .toList(growable: false);
  }

  static String? _defaultCurrentUidReader() => WKIM.shared.options.uid;

  static bool _defaultIsSystemAccount(String uid) {
    return uid == _systemTeamId || uid == _fileHelperId;
  }

  static int _defaultMaxSelectableCountReader() {
    final result = EndpointManager.getInstance().invoke(
      CallMenuIDs.rtcMaxNumber,
    );
    if (result is int && result > 0) {
      return result;
    }
    if (result is num && result > 0) {
      return result.toInt();
    }
    return _fallbackMaxSelectableCount;
  }
}

class GroupCallMemberCandidate {
  const GroupCallMemberCandidate({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
    this.remark,
  });

  final String uid;
  final String displayName;
  final String? avatarUrl;
  final String? remark;
}

class GroupCallMemberPage {
  const GroupCallMemberPage({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.maxSelectableCount,
  });

  final List<GroupCallMemberCandidate> items;
  final int page;
  final bool hasMore;
  final int maxSelectableCount;
}

class GroupCallCreateResult {
  const GroupCallCreateResult({
    required this.shouldClose,
    this.feedbackMessage,
  });

  final bool shouldClose;
  final String? feedbackMessage;
}
