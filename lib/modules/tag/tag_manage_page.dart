import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/friend.dart';
import '../../service/api/collection_api.dart';
import '../../service/api/friend_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_button.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_status_view.dart';

class TagManagePage extends ConsumerStatefulWidget {
  const TagManagePage({super.key});

  @override
  ConsumerState<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends ConsumerState<TagManagePage> {
  List<Map<String, dynamic>> _tags = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final tags = await TagApi.instance.getTags();
      if (!mounted) return;
      setState(() => _tags = tags);
    } catch (_) {
      if (!mounted) return;
      setState(() => _tags = []);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createTag() async {
    final name = await _showTagNameDialog('新建标签');
    if (name == null || name.isEmpty) return;
    try {
      await TagApi.instance.create(name: name);
      await _loadTags();
      _showSnackBar('标签创建成功');
    } catch (error) {
      _showSnackBar('创建失败：$error', isError: true);
    }
  }

  Future<void> _editTag(Map<String, dynamic> tag) async {
    final name = await _showTagNameDialog('编辑标签', initialValue: _tagName(tag));
    if (name == null || name.isEmpty) return;
    try {
      await TagApi.instance.update(id: tag['id'].toString(), name: name);
      await _loadTags();
      _showSnackBar('标签已更新');
    } catch (error) {
      _showSnackBar('更新失败：$error', isError: true);
    }
  }

  Future<void> _deleteTag(Map<String, dynamic> tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确认删除“${_tagName(tag)}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: WKColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await TagApi.instance.delete(tag['id'].toString());
      await _loadTags();
      _showSnackBar('标签已删除');
    } catch (error) {
      _showSnackBar('删除失败：$error', isError: true);
    }
  }

  Future<String?> _showTagNameDialog(String title, {String initialValue = ''}) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(
            labelText: '标签名称',
            hintText: '请输入标签名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _openTagDetail(Map<String, dynamic> tag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TagDetailPage(tag: tag, onRefresh: _loadTags),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? WKColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: WKSpace.sm),
            child: WKIconButton(
              icon: Icons.add_rounded,
              onPressed: _createTag,
              iconColor: WKColors.brand500,
              backgroundColor: WKColors.brand50,
              isCircle: false,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const WKLoadingView(message: '正在同步标签...')
          : RefreshIndicator(
              onRefresh: _loadTags,
              color: WKColors.brand500,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        WKSpace.md,
                        WKSpace.md,
                        WKSpace.md,
                        WKSpace.sm,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(WKSpace.lg),
                        decoration: BoxDecoration(
                          color: WKColors.surface,
                          borderRadius: BorderRadius.circular(WKRadius.xl),
                          border: Border.all(color: WKColors.outline),
                          boxShadow: WKShadows.card,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: WKColors.brand50,
                                borderRadius: BorderRadius.circular(WKRadius.lg),
                              ),
                              child: const Icon(
                                Icons.label_rounded,
                                color: WKColors.brand500,
                              ),
                            ),
                            const SizedBox(width: WKSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('统一标签系统', style: textTheme.titleLarge),
                                  const SizedBox(height: WKSpace.xs),
                                  Text('当前共 ${_tags.length} 个标签，可用于精细化分组管理。', style: textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_tags.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: WKEmptyView(
                        icon: Icons.label_outline_rounded,
                        message: '还没有标签',
                        subMessage: '创建后即可按项目、同事、家人等维度组织联系人。',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(WKSpace.md, WKSpace.sm, WKSpace.md, WKSpace.xl),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final tag = _tags[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: WKSpace.sm),
                              child: _TagItem(
                                tag: tag,
                                onTap: () => _openTagDetail(tag),
                                onEdit: () => _editTag(tag),
                                onDelete: () => _deleteTag(tag),
                              ),
                            );
                          },
                          childCount: _tags.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _TagItem extends StatelessWidget {
  final Map<String, dynamic> tag;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TagItem({
    required this.tag,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.xl),
        border: Border.all(color: WKColors.outline),
        boxShadow: WKShadows.soft,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: WKSpace.md, vertical: WKSpace.sm),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: WKColors.brand50,
            borderRadius: BorderRadius.circular(WKRadius.lg),
          ),
          child: const Icon(Icons.label_rounded, color: WKColors.brand500),
        ),
        title: Text(_tagName(tag)),
        subtitle: Text('已归类 ${_tagMemberCount(tag)} 位联系人'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('编辑')),
            PopupMenuItem(
              value: 'delete',
              child: Text('删除', style: TextStyle(color: WKColors.danger)),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _TagDetailPage extends StatefulWidget {
  final Map<String, dynamic> tag;
  final Future<void> Function() onRefresh;

  const _TagDetailPage({required this.tag, required this.onRefresh});

  @override
  State<_TagDetailPage> createState() => _TagDetailPageState();
}

class _TagDetailPageState extends State<_TagDetailPage> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final members = await TagApi.instance.getMembers(widget.tag['id'].toString());
      if (!mounted) return;
      setState(() => _members = members);
    } catch (_) {
      if (!mounted) return;
      setState(() => _members = []);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addMembers() async {
    try {
      final friends = await FriendApi.instance.getFriends();
      final existingUids = _members.map((e) => e['uid']?.toString() ?? '').toSet();
      final available = friends.where((friend) => !existingUids.contains(friend.uid)).toList();
      if (!mounted) return;
      if (available.isEmpty) {
        _showSnackBar('没有可添加的联系人');
        return;
      }
      final selected = await showDialog<List<String>>(
        context: context,
        builder: (context) => _MemberSelectDialog(members: available),
      );
      if (selected == null || selected.isEmpty) return;
      await TagApi.instance.addMembers(tagId: widget.tag['id'].toString(), uids: selected);
      await _loadMembers();
      await widget.onRefresh();
      _showSnackBar('成员已添加');
    } catch (error) {
      _showSnackBar('添加失败：$error', isError: true);
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final uid = member['uid']?.toString();
    if (uid == null || uid.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确认移除“${_memberName(member)}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: WKColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await TagApi.instance.removeMembers(tagId: widget.tag['id'].toString(), uids: [uid]);
      await _loadMembers();
      await widget.onRefresh();
      _showSnackBar('成员已移除');
    } catch (error) {
      _showSnackBar('移除失败：$error', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? WKColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tagName(widget.tag)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: WKSpace.sm),
            child: WKIconButton(
              icon: Icons.person_add_alt_1_rounded,
              onPressed: _addMembers,
              iconColor: WKColors.brand500,
              backgroundColor: WKColors.brand50,
              isCircle: false,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const WKLoadingView(message: '正在加载成员...')
          : RefreshIndicator(
              onRefresh: _loadMembers,
              color: WKColors.brand500,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(WKSpace.md, WKSpace.md, WKSpace.md, WKSpace.sm),
                      child: Container(
                        padding: const EdgeInsets.all(WKSpace.lg),
                        decoration: BoxDecoration(
                          color: WKColors.surface,
                          borderRadius: BorderRadius.circular(WKRadius.xl),
                          border: Border.all(color: WKColors.outline),
                          boxShadow: WKShadows.card,
                        ),
                        child: Row(
                          children: [
                            WKAvatar(name: _tagName(widget.tag), size: 52, borderRadius: BorderRadius.circular(WKRadius.lg)),
                            const SizedBox(width: WKSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_tagName(widget.tag), style: Theme.of(context).textTheme.titleLarge),
                                  const SizedBox(height: WKSpace.xs),
                                  Text('当前包含 ${_members.length} 位联系人', style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_members.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: WKEmptyView(
                        icon: Icons.group_outlined,
                        message: '这个标签还没有成员',
                        subMessage: '点击右上角按钮，将联系人加入这个标签。',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(WKSpace.md, WKSpace.sm, WKSpace.md, WKSpace.xl),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final member = _members[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: WKSpace.sm),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: WKColors.surface,
                                  borderRadius: BorderRadius.circular(WKRadius.xl),
                                  border: Border.all(color: WKColors.outline),
                                  boxShadow: WKShadows.soft,
                                ),
                                child: ListTile(
                                  leading: WKAvatar(
                                    url: member['avatar']?.toString(),
                                    name: _memberName(member),
                                    size: 44,
                                  ),
                                  title: Text(_memberName(member)),
                                  subtitle: Text(member['uid']?.toString() ?? ''),
                                  trailing: IconButton(
                                    onPressed: () => _removeMember(member),
                                    icon: const Icon(Icons.remove_circle_outline_rounded),
                                    color: WKColors.danger,
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: _members.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _MemberSelectDialog extends StatefulWidget {
  final List<Friend> members;

  const _MemberSelectDialog({required this.members});

  @override
  State<_MemberSelectDialog> createState() => _MemberSelectDialogState();
}

class _MemberSelectDialogState extends State<_MemberSelectDialog> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加成员'),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: ListView.builder(
          itemCount: widget.members.length,
          itemBuilder: (context, index) {
            final member = widget.members[index];
            final selected = _selected.contains(member.uid);
            return CheckboxListTile(
              value: selected,
              activeColor: WKColors.brand500,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selected.add(member.uid);
                  } else {
                    _selected.remove(member.uid);
                  }
                });
              },
              title: Text(_friendName(member)),
              subtitle: Text(member.uid),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected.toList()),
          child: Text('添加 ${_selected.length} 人'),
        ),
      ],
    );
  }
}

String _tagName(Map<String, dynamic> tag) {
  final name = tag['name']?.toString().trim();
  return (name == null || name.isEmpty) ? '未命名标签' : name;
}

int _tagMemberCount(Map<String, dynamic> tag) {
  final members = tag['members'];
  if (members is List) return members.length;
  final count = tag['member_count'] ?? tag['count'] ?? tag['memberCount'];
  return count is num ? count.toInt() : 0;
}

String _memberName(Map<String, dynamic> member) {
  final values = [member['remark'], member['name'], member['nickname'], member['uid']];
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return '未知联系人';
}

String _friendName(Friend friend) {
  final remark = friend.remark?.trim();
  if (remark != null && remark.isNotEmpty) return remark;
  final name = friend.name?.trim();
  if (name != null && name.isNotEmpty) return name;
  return friend.uid;
}
