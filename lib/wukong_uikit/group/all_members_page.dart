import 'package:flutter/material.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/group.dart';
import '../../data/models/group_forbidden_time_option.dart';
import '../../modules/search/domain/search_models.dart';
import '../../modules/search/search_with_member_page.dart';
import '../../service/api/group_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import '../user/user_detail_page.dart';
import 'group_moderation_policy.dart';

class AllMembersPage extends StatefulWidget {
  final String channelId;
  final int channelType;
  final String? channelName;
  final bool searchMessage;
  final bool autoLoad;
  final List<GroupMember>? initialMembers;

  const AllMembersPage({
    super.key,
    required this.channelId,
    this.channelType = 1,
    this.channelName,
    this.searchMessage = false,
    this.autoLoad = true,
    this.initialMembers,
  });

  @override
  State<AllMembersPage> createState() => _AllMembersPageState();
}

class _AllMembersPageState extends State<AllMembersPage> {
  List<GroupMember> _members = <GroupMember>[];
  List<GroupMember> _filteredMembers = <GroupMember>[];
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _hasChanges = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String get _currentUid => StorageUtils.getUid()?.trim() ?? '';

  GroupMember? get _currentMember {
    for (final member in _members) {
      if (member.uid == _currentUid) {
        return member;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _members = List<GroupMember>.from(
      widget.initialMembers ?? const <GroupMember>[],
    );
    _filteredMembers = List<GroupMember>.from(_members);
    if (widget.autoLoad) {
      _loadMembers();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);

    try {
      final members = await GroupApi.instance.getGroupMembers(widget.channelId);
      if (!mounted) {
        return;
      }
      setState(() {
        _members = members;
        _filteredMembers = _applySearch(_searchQuery, members);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载群成员失败：$error')));
    }
  }

  List<GroupMember> _applySearch(String query, List<GroupMember> source) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return List<GroupMember>.from(source);
    }

    return source
        .where((member) {
          final values = <String>[
            member.uid,
            member.name ?? '',
            member.remark ?? '',
          ];
          return values.any(
            (value) => value.toLowerCase().contains(normalized),
          );
        })
        .toList(growable: false);
  }

  void _filterMembers(String query) {
    setState(() {
      _searchQuery = query;
      _filteredMembers = _applySearch(query, _members);
    });
  }

  bool _canModerate(GroupMember member) {
    final actor = _currentMember;
    if (widget.searchMessage || actor == null) {
      return false;
    }
    return GroupModerationPolicy.canModerateTarget(
      actor: actor,
      target: member,
    );
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    setState(() => _isUpdating = true);
    try {
      await action();
      _hasChanges = true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('群成员操作失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  String _actionLabel(GroupMemberModerationAction action) {
    switch (action) {
      case GroupMemberModerationAction.mute:
        return '禁言成员';
      case GroupMemberModerationAction.unmute:
        return '解除禁言';
      case GroupMemberModerationAction.addToBlacklist:
        return '加入黑名单';
      case GroupMemberModerationAction.removeFromBlacklist:
        return '移出黑名单';
    }
  }

  Future<void> _showModerationActions(GroupMember member) async {
    final actor = _currentMember;
    if (actor == null) {
      return;
    }

    final actions = GroupModerationPolicy.actionsFor(
      actor: actor,
      target: member,
      now: DateTime.now(),
    );
    if (actions.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in actions)
                ListTile(
                  key: ValueKey<String>(
                    'member-moderation-action-${action.name}-${member.uid}',
                  ),
                  title: Text(_actionLabel(action)),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _handleModerationAction(member, action);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleModerationAction(
    GroupMember member,
    GroupMemberModerationAction action,
  ) async {
    switch (action) {
      case GroupMemberModerationAction.mute:
        final options = await GroupApi.instance.getForbiddenTimes();
        if (!mounted) {
          return;
        }
        final selected = await showModalBottomSheet<GroupForbiddenTimeOption>(
          context: context,
          builder: (_) => _ForbiddenTimePicker(options: options),
        );
        if (selected == null) {
          return;
        }
        await _runMutation(() async {
          await GroupApi.instance.updateMemberForbidden(
            widget.channelId,
            memberUid: member.uid,
            action: GroupMemberForbiddenAction.mute,
            key: selected.key,
          );
          await _loadMembers();
        });
      case GroupMemberModerationAction.unmute:
        await _runMutation(() async {
          await GroupApi.instance.updateMemberForbidden(
            widget.channelId,
            memberUid: member.uid,
            action: GroupMemberForbiddenAction.unmute,
          );
          await _loadMembers();
        });
      case GroupMemberModerationAction.addToBlacklist:
        await _runMutation(() async {
          await GroupApi.instance.updateBlacklist(
            widget.channelId,
            uids: <String>[member.uid],
            action: GroupBlacklistAction.add,
          );
          await _loadMembers();
        });
      case GroupMemberModerationAction.removeFromBlacklist:
        await _runMutation(() async {
          await GroupApi.instance.updateBlacklist(
            widget.channelId,
            uids: <String>[member.uid],
            action: GroupBlacklistAction.remove,
          );
          await _loadMembers();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_hasChanges);
      },
      child: WKSubPageScaffold(
        title: widget.searchMessage
            ? 'Search by group members'
            : '群成员(${_members.length})',
        body: Stack(
          children: [
            Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredMembers.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isNotEmpty ? '未找到匹配的成员' : '暂无成员',
                            style: const TextStyle(
                              fontSize: 14,
                              color: WKColors.color999,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: _filteredMembers.length,
                          itemBuilder: (context, index) {
                            return _buildMemberTile(_filteredMembers[index]);
                          },
                        ),
                ),
              ],
            ),
            if (_isUpdating)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: WKColors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 5, 0),
              child: WKReferenceAssets.image(
                WKReferenceAssets.search,
                width: 16,
                height: 16,
                tint: WKColors.color999,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _filterMembers,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '鎼滅储',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: WKColors.color999,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _filterMembers('');
                          },
                          icon: const Icon(
                            Icons.cancel_rounded,
                            size: 16,
                            color: WKColors.color999,
                          ),
                        ),
                ),
                style: const TextStyle(fontSize: 14, color: WKColors.colorDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(GroupMember member) {
    final displayName = _memberDisplayName(member);
    final roleLabel = _memberRoleLabel(member);
    final roleColor = _memberRoleColor(member);
    final canModerate = _canModerate(member);

    return Material(
      color: WKColors.white,
      child: InkWell(
        onTap: () => _onMemberTap(member),
        highlightColor: WKColors.screenBgSelected,
        splashColor: WKColors.screenBgSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              WKAvatar(url: member.avatar, name: displayName, size: 45),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (roleLabel != null) ...[
                          _buildRoleChip(roleLabel, roleColor),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              color: WKColors.colorDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.uid,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: WKColors.color999,
                      ),
                    ),
                  ],
                ),
              ),
              if (canModerate)
                IconButton(
                  key: ValueKey<String>(
                    'member-moderation-trigger-${member.uid}',
                  ),
                  onPressed: _isUpdating
                      ? null
                      : () => _showModerationActions(member),
                  icon: const Icon(Icons.more_horiz),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: WKColors.white),
      ),
    );
  }

  String _memberDisplayName(GroupMember member) {
    final remark = (member.remark ?? '').trim();
    if (remark.isNotEmpty) {
      return remark;
    }
    final name = (member.name ?? '').trim();
    if (name.isNotEmpty) {
      return name;
    }
    return member.uid;
  }

  String? _memberRoleLabel(GroupMember member) {
    if (member.isOwner) {
      return '群主';
    }
    if (member.isAdmin) {
      return '管理员';
    }
    return null;
  }

  Color _memberRoleColor(GroupMember member) {
    if (member.isOwner) {
      return const Color(0xFFFFC107);
    }
    return WKColors.brand500;
  }

  void _onMemberTap(GroupMember member) {
    if (widget.searchMessage) {
      final memberHit = SearchMemberHit(
        uid: member.uid,
        displayName: _memberDisplayName(member),
        avatarUrl: member.avatar,
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SearchWithMemberPage(
            channelId: widget.channelId,
            channelType: widget.channelType,
            channelName: widget.channelName,
            member: memberHit,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            UserDetailPage(uid: member.uid, groupId: widget.channelId),
      ),
    );
  }
}

class _ForbiddenTimePicker extends StatefulWidget {
  const _ForbiddenTimePicker({required this.options});

  final List<GroupForbiddenTimeOption> options;

  @override
  State<_ForbiddenTimePicker> createState() => _ForbiddenTimePickerState();
}

class _ForbiddenTimePickerState extends State<_ForbiddenTimePicker> {
  GroupForbiddenTimeOption? _selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioGroup<int>(
            groupValue: _selected?.key,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              final selected = widget.options.firstWhere(
                (option) => option.key == value,
              );
              setState(() => _selected = selected);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in widget.options)
                  RadioListTile<int>(
                    key: ValueKey<String>(
                      'group-forbidden-time-option-${option.key}',
                    ),
                    value: option.key,
                    title: Text(option.text),
                  ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey<String>('group-forbidden-time-confirm'),
            onPressed: _selected == null
                ? null
                : () => Navigator.of(context).pop(_selected),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}
