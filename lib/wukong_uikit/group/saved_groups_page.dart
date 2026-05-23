import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../core/utils/avatar_utils.dart';
import '../../data/models/group.dart';
import '../../modules/chat/chat_page.dart';
import '../../modules/contacts/create_group_page.dart';
import '../../modules/vip/vip_guard.dart';
import '../../service/api/group_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

enum _SavedGroupMenuAction { delete }

class SavedGroupsPage extends StatefulWidget {
  final bool autoLoad;
  final List<GroupInfo>? initialGroups;

  const SavedGroupsPage({super.key, this.autoLoad = true, this.initialGroups});

  @override
  State<SavedGroupsPage> createState() => _SavedGroupsPageState();
}

class _SavedGroupsPageState extends State<SavedGroupsPage> {
  late List<GroupInfo> _groups;
  bool _isLoading = false;
  final Set<String> _updatingGroups = <String>{};

  @override
  void initState() {
    super.initState();
    _groups = List<GroupInfo>.from(widget.initialGroups ?? const <GroupInfo>[]);
    _isLoading = widget.autoLoad && _groups.isEmpty;
    if (widget.autoLoad) {
      _loadGroups(showLoading: _groups.isEmpty);
    }
  }

  Future<void> _loadGroups({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final groups = await GroupApi.instance.getMyGroups();
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage('加载群聊失败: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '保存的群聊',
      trailing: WKSubPageAction(text: '新建', onTap: _openCreateGroupPage),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _groups.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                indent: 71,
                color: WKColors.homeBg,
              ),
              itemBuilder: (context, index) => _buildGroupRow(_groups[index]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Text(
          '你可以通过群聊中的"保存到通讯录"选项，将其保存到这里',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5, color: WKColors.color999),
        ),
      ),
    );
  }

  Widget _buildGroupRow(GroupInfo group) {
    final groupNo = group.groupNo.trim();
    final title = _resolveGroupTitle(group);
    final isUpdating = _updatingGroups.contains(groupNo);

    return Builder(
      builder: (itemContext) => Material(
        color: WKColors.surface,
        child: InkWell(
          onTap: isUpdating ? null : () => _openChat(group),
          onLongPress: isUpdating
              ? null
              : () => _showGroupMenu(itemContext, group),
          child: Opacity(
            opacity: isUpdating ? 0.45 : 1,
            child: SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    WKAvatar(
                      url: resolveGroupAvatarUrl(group.avatar, groupNo),
                      name: title,
                      size: 40,
                      isGroup: true,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          color: WKColors.colorDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showGroupMenu(
    BuildContext anchorContext,
    GroupInfo group,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final anchor = anchorContext.findRenderObject() as RenderBox?;
    if (anchor == null) {
      return;
    }

    final offset = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final action = await showMenu<_SavedGroupMenuAction>(
      context: context,
      color: WKColors.surface,
      elevation: 8,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      position: RelativeRect.fromLTRB(
        offset.dx + 24,
        offset.dy + 10,
        overlay.size.width - offset.dx - anchor.size.width + 24,
        overlay.size.height - offset.dy,
      ),
      items: const [
        PopupMenuItem<_SavedGroupMenuAction>(
          value: _SavedGroupMenuAction.delete,
          height: 42,
          child: Text(
            '删除',
            style: TextStyle(fontSize: 14, color: WKColors.colorDark),
          ),
        ),
      ],
    );

    if (action == _SavedGroupMenuAction.delete) {
      await _removeSavedGroup(group);
    }
  }

  Future<void> _removeSavedGroup(GroupInfo group) async {
    final groupNo = group.groupNo.trim();
    if (groupNo.isEmpty || _updatingGroups.contains(groupNo)) {
      return;
    }

    setState(() {
      _updatingGroups.add(groupNo);
    });

    try {
      await GroupApi.instance.updateGroupSetting(groupNo, 'save', 0);
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = _groups
            .where((item) => item.groupNo.trim() != groupNo)
            .toList(growable: false);
      });
    } catch (error) {
      _showMessage('取消保存失败: $error');
    } finally {
      if (mounted) {
        setState(() {
          _updatingGroups.remove(groupNo);
        });
      }
    }
  }

  Future<void> _openCreateGroupPage() async {
    if (!await guardVipFeature(
      context,
      entitlement: VipEntitlement.createGroup,
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<GroupInfo>(
      MaterialPageRoute(builder: (_) => const CreateGroupPage()),
    );
    if (!mounted) {
      return;
    }
    await _loadGroups(showLoading: false);
  }

  void _openChat(GroupInfo group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          channelId: group.groupNo,
          channelType: WKChannelType.group,
          channelName: _resolveGroupTitle(group),
        ),
      ),
    );
  }

  String _resolveGroupTitle(GroupInfo group) {
    final remark = (group.remark ?? '').trim();
    if (remark.isNotEmpty) {
      return remark;
    }
    final name = (group.name ?? '').trim();
    if (name.isNotEmpty) {
      return name;
    }
    return group.groupNo;
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
