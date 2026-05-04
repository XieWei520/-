import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/group.dart';
import '../../service/api/group_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

class DeleteGroupMembersPage extends StatefulWidget {
  final String groupId;
  final List<GroupMember> members;
  final Future<void> Function(List<String> memberIds)? onDelete;

  const DeleteGroupMembersPage({
    super.key,
    required this.groupId,
    required this.members,
    this.onDelete,
  });

  @override
  State<DeleteGroupMembersPage> createState() => _DeleteGroupMembersPageState();
}

class _DeleteGroupMembersPageState extends State<DeleteGroupMembersPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Set<String> _selectedIds = <String>{};
  String _query = '';
  bool _isDeleting = false;
  String? _pendingRemovalUid;

  List<GroupMember> get _filteredMembers {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return widget.members;
    }

    return widget.members.where((member) {
      final values = [member.uid, member.name ?? '', member.remark ?? ''];
      return values.any(
        (value) => value.toLowerCase().contains(normalizedQuery),
      );
    }).toList();
  }

  List<GroupMember> get _selectedMembers => widget.members
      .where((member) => _selectedIds.contains(member.uid))
      .toList(growable: false);

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleMember(GroupMember member) {
    setState(() {
      _pendingRemovalUid = null;
      if (_selectedIds.contains(member.uid)) {
        _selectedIds.remove(member.uid);
      } else {
        _selectedIds.add(member.uid);
      }
    });
  }

  void _handleSelectedAvatarTap(GroupMember member) {
    setState(() {
      if (_pendingRemovalUid == member.uid) {
        _selectedIds.remove(member.uid);
        _pendingRemovalUid = null;
      } else {
        _pendingRemovalUid = member.uid;
      }
    });
  }

  void _handleBackspaceDelete() {
    if (_selectedMembers.isEmpty) {
      return;
    }

    final lastMember = _selectedMembers.last;
    if (_pendingRemovalUid == lastMember.uid) {
      setState(() {
        _selectedIds.remove(lastMember.uid);
        _pendingRemovalUid = null;
      });
      return;
    }

    setState(() => _pendingRemovalUid = lastMember.uid);
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty || _isDeleting) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      final selectedIds = _selectedIds.toList(growable: false);
      if (widget.onDelete != null) {
        await widget.onDelete!(selectedIds);
      } else {
        await GroupApi.instance.removeGroupMembers(widget.groupId, selectedIds);
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除群成员失败: $error')));
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = _filteredMembers;

    return WKSubPageScaffold(
      title: '删除群成员',
      trailing: _selectedIds.isEmpty
          ? null
          : _isDeleting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(WKColors.brand500),
              ),
            )
          : WKSubPageAction(
              text: '删除(${_selectedIds.length})',
              color: WKColors.brand500,
              onTap: _deleteSelected,
            ),
      body: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _searchFocusNode.requestFocus(),
            child: Container(
              height: 40,
              color: WKColors.homeBg,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                children: [
                  ..._selectedMembers.map(_buildSelectedAvatar),
                  _buildSearchField(),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) =>
                  _buildMemberRow(filteredMembers[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedAvatar(GroupMember member) {
    final isPendingRemoval = _pendingRemovalUid == member.uid;

    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 5),
      child: Center(
        child: GestureDetector(
          onTap: () => _handleSelectedAvatarTap(member),
          child: SizedBox(
            width: 30,
            height: 30,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isPendingRemoval
                        ? WKColors.danger
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: isPendingRemoval
                      ? const Icon(Icons.close, size: 16, color: WKColors.white)
                      : WKAvatar(
                          url: member.avatar,
                          name: _displayName(member),
                          size: 25,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 5),
      child: Center(
        child: SizedBox(
          width: 100,
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.backspace &&
                  _searchController.text.isEmpty) {
                _handleBackspaceDelete();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              maxLines: 1,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14, color: WKColors.colorDark),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '搜索',
                hintStyle: TextStyle(fontSize: 14, color: WKColors.color999),
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value;
                  _pendingRemovalUid = null;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberRow(GroupMember member) {
    final isSelected = _selectedIds.contains(member.uid);

    return Material(
      color: WKColors.surface,
      child: InkWell(
        onTap: _isDeleting ? null : () => _toggleMember(member),
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: [
                SizedBox(
                  width: 45,
                  height: 45,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: WKAvatar(
                          url: member.avatar,
                          name: _displayName(member),
                          size: 40,
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? WKColors.brand500
                                : WKColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: WKColors.layoutColor),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: WKColors.white,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _displayName(member),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: WKColors.colorDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
}
