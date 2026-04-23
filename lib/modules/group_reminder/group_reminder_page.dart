import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/group_reminder.dart';
import '../../service/api/group_api.dart';
import 'create_group_reminder_page.dart';

class GroupReminderPage extends StatefulWidget {
  final String groupId;
  final String? groupName;
  final int? initialReminderId;

  const GroupReminderPage({
    super.key,
    required this.groupId,
    this.groupName,
    this.initialReminderId,
  });

  @override
  State<GroupReminderPage> createState() => _GroupReminderPageState();
}

class _GroupReminderPageState extends State<GroupReminderPage> {
  List<GroupReminder> _reminders = const <GroupReminder>[];
  bool _isLoading = true;
  final Set<int> _completingReminderIds = <int>{};
  final Set<int> _cancellingReminderIds = <int>{};

  String get _currentUid => StorageUtils.getUid()?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final reminders = await GroupApi.instance.getGroupReminders(
        widget.groupId,
      );
      if (!mounted) {
        return;
      }
      reminders.sort((left, right) {
        if (widget.initialReminderId != null) {
          if (left.id == widget.initialReminderId &&
              right.id != widget.initialReminderId) {
            return -1;
          }
          if (right.id == widget.initialReminderId &&
              left.id != widget.initialReminderId) {
            return 1;
          }
        }
        return right.remindAt.compareTo(left.remindAt);
      });
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage('加载群提醒失败: $e');
    }
  }

  Future<void> _createReminder() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateGroupReminderPage(
          groupId: widget.groupId,
          groupName: widget.groupName,
        ),
      ),
    );
    if (created == true && mounted) {
      _showMessage('群提醒已创建');
      await _loadReminders();
    }
  }

  Future<void> _editReminder(GroupReminder reminder) async {
    if (!reminder.canManage(_currentUid)) {
      _showMessage('该提醒已进入执行阶段，暂不支持编辑');
      return;
    }
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateGroupReminderPage(
          groupId: widget.groupId,
          groupName: widget.groupName,
          reminderId: reminder.id,
          initialTitle: reminder.title,
          initialContent: reminder.content,
          initialAssigneeUids: reminder.assigneeUids,
          initialRemindAt: DateTime.fromMillisecondsSinceEpoch(
            reminder.remindAt * 1000,
          ),
        ),
      ),
    );
    if (updated == true && mounted) {
      _showMessage('群提醒已更新');
      await _loadReminders();
    }
  }

  Future<void> _cancelReminder(GroupReminder reminder) async {
    if (_cancellingReminderIds.contains(reminder.id)) {
      return;
    }
    if (!reminder.canManage(_currentUid)) {
      _showMessage('该提醒已进入执行阶段，暂不支持取消');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消群提醒'),
        content: Text(
          reminder.title.trim().isEmpty
              ? '确认取消这条群提醒吗？取消后将不会继续触发。'
              : '确认取消“${reminder.title.trim()}”吗？取消后将不会继续触发。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _cancellingReminderIds.add(reminder.id));
    try {
      await GroupApi.instance.cancelGroupReminder(widget.groupId, reminder.id);
      if (!mounted) {
        return;
      }
      _showMessage('群提醒已取消');
      await _loadReminders();
    } catch (e) {
      _showMessage('取消群提醒失败: $e');
    } finally {
      if (mounted) {
        setState(() => _cancellingReminderIds.remove(reminder.id));
      }
    }
  }

  Future<void> _completeReminder(GroupReminder reminder) async {
    if (_completingReminderIds.contains(reminder.id)) {
      return;
    }
    setState(() => _completingReminderIds.add(reminder.id));
    try {
      await GroupApi.instance.completeGroupReminder(
        widget.groupId,
        reminder.id,
      );
      if (!mounted) {
        return;
      }
      await _loadReminders();
      _showMessage('提醒已标记完成');
    } catch (e) {
      _showMessage('完成提醒失败: $e');
    } finally {
      if (mounted) {
        setState(() => _completingReminderIds.remove(reminder.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _reminders.where((item) => !item.isCompleted).toList();
    final completed = _reminders.where((item) => item.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.groupName?.trim().isNotEmpty == true
              ? '${widget.groupName!.trim()} · 群提醒'
              : '群提醒',
        ),
        actions: [
          IconButton(
            tooltip: '创建提醒',
            onPressed: _createReminder,
            icon: const Icon(Icons.add_alert_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReminders,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(pendingCount: pending.length),
                  const SizedBox(height: 16),
                  if (pending.isEmpty && completed.isEmpty)
                    _buildEmptyState()
                  else ...[
                    if (pending.isNotEmpty) ...[
                      _buildSectionTitle('待处理'),
                      const SizedBox(height: 8),
                      ...pending.map(_buildReminderCard),
                    ],
                    if (completed.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('已完成'),
                      const SizedBox(height: 8),
                      ...completed.map(_buildReminderCard),
                    ],
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createReminder,
        icon: const Icon(Icons.alarm_add_outlined),
        label: const Text('新建提醒'),
      ),
    );
  }

  Widget _buildSummaryCard({required int pendingCount}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0F7FF), Color(0xFFF8FBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4E7FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '群待办 / 群提醒',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            pendingCount > 0
                ? '当前还有 $pendingCount 条待处理提醒，创建后会在到点时同步到对应成员的设备。'
                : '当前没有待处理提醒，你可以直接创建新的群待办或定时提醒。',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildReminderCard(GroupReminder reminder) {
    final isCompleting = _completingReminderIds.contains(reminder.id);
    final isCancelling = _cancellingReminderIds.contains(reminder.id);
    final isBusy = isCompleting || isCancelling;
    final canComplete = reminder.assignees.any(
      (assignee) => assignee.uid == _currentUid && !assignee.done,
    );
    final canManage = reminder.canManage(_currentUid);
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    final remindAt = DateTime.fromMillisecondsSinceEpoch(
      reminder.remindAt * 1000,
    );
    final status = _resolveStatus(reminder);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _statusColor(status).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reminder.title.isEmpty ? '未命名提醒' : reminder.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canManage || isCancelling) ...[
                const SizedBox(width: 8),
                isCancelling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : PopupMenuButton<_ReminderAction>(
                        tooltip: '更多操作',
                        onSelected: (_ReminderAction action) {
                          if (action == _ReminderAction.edit) {
                            _editReminder(reminder);
                            return;
                          }
                          _cancelReminder(reminder);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<_ReminderAction>(
                            value: _ReminderAction.edit,
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('编辑提醒'),
                            ),
                          ),
                          PopupMenuItem<_ReminderAction>(
                            value: _ReminderAction.cancel,
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.cancel_outlined),
                              title: Text('取消提醒'),
                            ),
                          ),
                        ],
                      ),
              ],
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(status),
                  ),
                ),
              ),
            ],
          ),
          if (reminder.content.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              reminder.content.trim(),
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.schedule_outlined,
                label: formatter.format(remindAt),
              ),
              _InfoChip(
                icon: Icons.person_outline,
                label: reminder.creatorName.isEmpty
                    ? reminder.creatorUid
                    : reminder.creatorName,
              ),
              _InfoChip(
                icon: Icons.task_alt_outlined,
                label: '${reminder.doneCount}/${reminder.totalCount} 已完成',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '提醒成员',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: reminder.assignees
                .map(
                  (assignee) => Chip(
                    avatar: CircleAvatar(
                      radius: 10,
                      backgroundColor: assignee.done
                          ? Colors.green.withValues(alpha: 0.18)
                          : Colors.blueGrey.withValues(alpha: 0.12),
                      child: Icon(
                        assignee.done ? Icons.check : Icons.person_outline,
                        size: 12,
                        color: assignee.done
                            ? Colors.green.shade700
                            : Colors.blueGrey.shade700,
                      ),
                    ),
                    label: Text(
                      assignee.name.isEmpty ? assignee.uid : assignee.name,
                    ),
                  ),
                )
                .toList(),
          ),
          if (canComplete) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : () => _completeReminder(reminder),
                icon: isCompleting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all_outlined),
                label: Text(isCompleting ? '处理中...' : '标记完成'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.alarm_off_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            '这个群还没有提醒',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            '新建后会在到点时推送给指定成员，成员完成后也会同步回其他设备。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  _ReminderCardStatus _resolveStatus(GroupReminder reminder) {
    if (reminder.isCompleted) {
      return _ReminderCardStatus.completed;
    }
    if (reminder.triggered || reminder.overdue) {
      return _ReminderCardStatus.inProgress;
    }
    return _ReminderCardStatus.scheduled;
  }

  Color _statusColor(_ReminderCardStatus status) {
    switch (status) {
      case _ReminderCardStatus.completed:
        return const Color(0xFF1F8F5F);
      case _ReminderCardStatus.inProgress:
        return const Color(0xFFCC7A00);
      case _ReminderCardStatus.scheduled:
        return const Color(0xFF1368CE);
    }
  }

  String _statusLabel(_ReminderCardStatus status) {
    switch (status) {
      case _ReminderCardStatus.completed:
        return '已完成';
      case _ReminderCardStatus.inProgress:
        return '待处理';
      case _ReminderCardStatus.scheduled:
        return '待提醒';
    }
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

enum _ReminderCardStatus { scheduled, inProgress, completed }

enum _ReminderAction { edit, cancel }

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}
