import 'package:flutter/material.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/group.dart';
import '../../service/api/group_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'group_member_picker_page.dart';
import 'group_moderation_policy.dart';

class GroupBlacklistPage extends StatefulWidget {
  final String channelId;

  const GroupBlacklistPage({super.key, required this.channelId});

  @override
  State<GroupBlacklistPage> createState() => _GroupBlacklistPageState();
}

class _GroupBlacklistPageState extends State<GroupBlacklistPage> {
  final String _currentUid = (StorageUtils.getUid() ?? '').trim();
  List<GroupMember> _members = <GroupMember>[];
  bool _isLoading = true;
  bool _isMutating = false;
  String? _pendingRemoveUid;
  bool _hasChanges = false;

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
    _loadMembers();
  }

  Future<void> _loadMembers({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final members = await GroupApi.instance.getGroupMembers(widget.channelId);
      if (!mounted) {
        return;
      }
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage('Failed to load blacklist');
    }
  }

  Future<void> _addToBlacklist() async {
    if (_isMutating || _isLoading) {
      return;
    }

    final actor = _currentMember;
    if (actor == null) {
      _showMessage('Current member not found');
      return;
    }

    final candidates = GroupModerationPolicy.blacklistAddCandidates(
      actor: actor,
      members: _members,
    );
    final pickerCandidates = candidates
        .map(
          (member) => SelectableGroupMember(
            uid: member.uid,
            title: _displayName(member),
            subtitle: member.uid,
            avatar: member.avatar,
            badge: _memberRoleLabel(member),
          ),
        )
        .toList(growable: false);

    final selected = await openGroupMemberPicker(
      context,
      title: '群黑名单',
      submitLabel: '添加',
      emptyText: '暂无可添加成员',
      candidates: pickerCandidates,
    );
    if (selected == null || selected.isEmpty) {
      return;
    }

    setState(() => _isMutating = true);
    try {
      await GroupApi.instance.updateBlacklist(
        widget.channelId,
        uids: selected,
        action: GroupBlacklistAction.add,
      );
      await _loadMembers(showLoading: false);
      if (!mounted) {
        return;
      }
      setState(() => _hasChanges = true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('黑名单更新失败');
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _removeFromBlacklist(String uid) async {
    if (_isMutating || _isLoading) {
      return;
    }

    setState(() {
      _isMutating = true;
      _pendingRemoveUid = uid;
    });
    try {
      await GroupApi.instance.updateBlacklist(
        widget.channelId,
        uids: <String>[uid],
        action: GroupBlacklistAction.remove,
      );
      await _loadMembers(showLoading: false);
      if (!mounted) {
        return;
      }
      setState(() => _hasChanges = true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('黑名单更新失败');
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
          _pendingRemoveUid = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final blacklistMembers = GroupModerationPolicy.blacklistMembers(_members);

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_hasChanges);
      },
      child: WKSubPageScaffold(
        title: '群黑名单',
        trailing: IconButton(
          key: const ValueKey<String>('group-blacklist-add'),
          icon: const Icon(Icons.add, color: WKColors.brand500),
          onPressed: _isLoading || _isMutating || _currentMember == null
              ? null
              : _addToBlacklist,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : blacklistMembers.isEmpty
            ? const Center(
                child: Text(
                  '暂无黑名单成员',
                  style: TextStyle(fontSize: 14, color: WKColors.color999),
                ),
              )
            : ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: blacklistMembers.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: WKColors.colorF5F5F5),
                itemBuilder: (context, index) {
                  final member = blacklistMembers[index];
                  final displayName = _displayName(member);
                  final isRemoving =
                      _isMutating && _pendingRemoveUid == member.uid;
                  return Material(
                    key: ValueKey<String>('group-blacklist-row-${member.uid}'),
                    color: WKColors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 6,
                      ),
                      leading: WKAvatar(
                        url: member.avatar,
                        name: displayName,
                        size: 40,
                      ),
                      title: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          color: WKColors.colorDark,
                        ),
                      ),
                      subtitle: Text(
                        member.uid,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: WKColors.color999,
                        ),
                      ),
                      trailing: isRemoving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              key: ValueKey<String>(
                                'group-blacklist-remove-${member.uid}',
                              ),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: WKColors.danger,
                              ),
                              onPressed: _isMutating
                                  ? null
                                  : () => _removeFromBlacklist(member.uid),
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _displayName(GroupMember member) {
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
