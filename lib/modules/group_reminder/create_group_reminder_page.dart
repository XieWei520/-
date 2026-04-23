import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/group.dart';
import '../../service/api/group_api.dart';

class CreateGroupReminderPage extends StatefulWidget {
  final String groupId;
  final String? groupName;
  final int? reminderId;
  final String? initialTitle;
  final String? initialContent;
  final Set<String>? initialAssigneeUids;
  final DateTime? initialRemindAt;

  const CreateGroupReminderPage({
    super.key,
    required this.groupId,
    this.groupName,
    this.reminderId,
    this.initialTitle,
    this.initialContent,
    this.initialAssigneeUids,
    this.initialRemindAt,
  });

  @override
  State<CreateGroupReminderPage> createState() =>
      _CreateGroupReminderPageState();
}

class _CreateGroupReminderPageState extends State<CreateGroupReminderPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  List<GroupMember> _members = const <GroupMember>[];
  Set<String> _selectedUids = <String>{};
  DateTime _remindAt = _defaultRemindAt();
  bool _isLoadingMembers = true;
  bool _isSubmitting = false;

  String get _currentUid => StorageUtils.getUid()?.trim() ?? '';
  bool get _isEditing => widget.reminderId != null && widget.reminderId! > 0;
  String get _submitLabel => _isEditing ? '保存' : '创建';
  String get _submittingLabel => _isEditing ? '保存中...' : '创建中...';
  String get _pageTitle => _isEditing ? '编辑群提醒' : '创建群提醒';

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle?.trim() ?? '';
    _contentController.text = widget.initialContent?.trim() ?? '';
    _remindAt = widget.initialRemindAt ?? _defaultRemindAt();
    if (widget.initialAssigneeUids != null &&
        widget.initialAssigneeUids!.isNotEmpty) {
      _selectedUids = widget.initialAssigneeUids!
          .map((uid) => uid.trim())
          .where((uid) => uid.isNotEmpty)
          .toSet();
    }
    _loadMembers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  static DateTime _defaultRemindAt() {
    final now = DateTime.now().add(const Duration(hours: 1));
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final members = await GroupApi.instance.getGroupMembers(widget.groupId);
      if (!mounted) {
        return;
      }
      final currentUid = _currentUid;
      final initialSelection = <String>{};
      if (currentUid.isNotEmpty &&
          members.any((member) => member.uid.trim() == currentUid)) {
        initialSelection.add(currentUid);
      } else if (members.isNotEmpty) {
        initialSelection.add(members.first.uid);
      }

      final memberUids = members.map((member) => member.uid).toSet();
      Set<String> resolvedSelection;
      if (_selectedUids.isNotEmpty) {
        final intersection = _selectedUids
            .where((uid) => memberUids.contains(uid))
            .toSet();
        resolvedSelection = intersection.isNotEmpty
            ? intersection
            : initialSelection;
      } else {
        resolvedSelection = initialSelection;
      }

      setState(() {
        _members = members;
        _selectedUids = resolvedSelection;
        _isLoadingMembers = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      final currentUid = _currentUid;
      setState(() {
        _members = currentUid.isEmpty
            ? const <GroupMember>[]
            : <GroupMember>[
                GroupMember(
                  groupNo: widget.groupId,
                  uid: currentUid,
                  name: '我',
                ),
              ];
        if (_selectedUids.isEmpty) {
          _selectedUids = currentUid.isEmpty
              ? <String>{}
              : <String>{currentUid};
        }
        _isLoadingMembers = false;
      });
      _showMessage('加载群成员失败，已回退为仅提醒自己: $e');
    }
  }

  Future<void> _pickReminderTime() async {
    final now = DateTime.now();
    final initialDate = _remindAt.isAfter(now) ? _remindAt : now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_remindAt),
    );
    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _remindAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickAssignees() async {
    if (_members.isEmpty) {
      _showMessage('当前暂无可选成员');
      return;
    }

    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => _ReminderAssigneePickerPage(
          members: _members,
          initialSelected: _selectedUids,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }
    setState(() => _selectedUids = result);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty) {
      _showMessage('请输入提醒标题');
      return;
    }
    if (_selectedUids.isEmpty) {
      _showMessage('请至少选择一位提醒成员');
      return;
    }
    final now = DateTime.now();
    if (!_remindAt.isAfter(now.subtract(const Duration(seconds: 30)))) {
      _showMessage('提醒时间需要晚于当前时间');
      return;
    }
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_isEditing) {
        await GroupApi.instance.updateGroupReminder(
          widget.groupId,
          widget.reminderId!,
          title: title,
          content: content,
          remindAt: _remindAt.millisecondsSinceEpoch ~/ 1000,
          assigneeUids: _selectedUids.toList(),
        );
      } else {
        await GroupApi.instance.createGroupReminder(
          widget.groupId,
          title: title,
          content: content,
          remindAt: _remindAt.millisecondsSinceEpoch ~/ 1000,
          assigneeUids: _selectedUids.toList(),
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage('${_isEditing ? '保存' : '创建'}群提醒失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    final selectedMembers = _members
        .where((member) => _selectedUids.contains(member.uid))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isSubmitting ? _submittingLabel : _submitLabel),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.groupName?.trim().isNotEmpty == true
                      ? widget.groupName!.trim()
                      : widget.groupId,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '群提醒会在到点后进入现有提醒同步流，成员在任一设备完成后，其他设备的提醒状态也会一起更新。',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: '提醒标题',
              hintText: '例如：周会纪要、版本上线检查',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: '提醒说明',
              hintText: '可补充待办细节、验收标准或备注',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('提醒时间'),
            subtitle: Text(formatter.format(_remindAt)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickReminderTime,
          ),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.people_outline),
            title: const Text('提醒成员'),
            subtitle: _isLoadingMembers
                ? const Text('正在加载群成员...')
                : Text(
                    selectedMembers.isEmpty
                        ? '尚未选择成员'
                        : selectedMembers
                              .map((member) => _memberDisplayName(member))
                              .join('、'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _isLoadingMembers ? null : _pickAssignees,
          ),
          if (selectedMembers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedMembers
                  .map(
                    (member) => Chip(
                      label: Text(_memberDisplayName(member)),
                      avatar: CircleAvatar(
                        radius: 10,
                        child: Text(
                          _avatarLetter(_memberDisplayName(member)),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: Icon(
              _isEditing
                  ? Icons.edit_calendar_outlined
                  : Icons.alarm_add_outlined,
            ),
            label: Text(_isSubmitting ? _submittingLabel : '$_submitLabel群提醒'),
          ),
        ],
      ),
    );
  }

  String _memberDisplayName(GroupMember member) {
    final value = (member.remark ?? member.name ?? member.uid).trim();
    return value.isEmpty ? member.uid : value;
  }

  String _avatarLetter(String value) {
    if (value.isEmpty) {
      return '?';
    }
    return value.substring(0, 1).toUpperCase();
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

class _ReminderAssigneePickerPage extends StatefulWidget {
  final List<GroupMember> members;
  final Set<String> initialSelected;

  const _ReminderAssigneePickerPage({
    required this.members,
    required this.initialSelected,
  });

  @override
  State<_ReminderAssigneePickerPage> createState() =>
      _ReminderAssigneePickerPageState();
}

class _ReminderAssigneePickerPageState
    extends State<_ReminderAssigneePickerPage> {
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelected};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GroupMember> get _filteredMembers {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.members;
    }
    return widget.members.where((member) {
      final values = [member.uid, member.name ?? '', member.remark ?? ''];
      return values.any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final members = _filteredMembers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择提醒成员'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: Text('确定(${_selected.length})'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索成员 UID、昵称、备注',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: members.isEmpty
                ? const Center(child: Text('没有符合条件的成员'))
                : ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final displayName = _memberDisplayName(member);
                      final isSelected = _selected.contains(member.uid);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (_) {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(member.uid);
                            } else {
                              _selected.add(member.uid);
                            }
                          });
                        },
                        secondary: CircleAvatar(
                          child: Text(
                            _avatarLetter(displayName),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(displayName),
                        subtitle: Text(member.uid),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _memberDisplayName(GroupMember member) {
    final value = (member.remark ?? member.name ?? member.uid).trim();
    return value.isEmpty ? member.uid : value;
  }

  String _avatarLetter(String value) {
    if (value.isEmpty) {
      return '?';
    }
    return value.substring(0, 1).toUpperCase();
  }
}
