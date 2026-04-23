import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/call.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_status_view.dart';
import 'call_history_service.dart';
import 'video_call_page.dart';

class CallHistoryPage extends StatefulWidget {
  const CallHistoryPage({super.key});

  @override
  State<CallHistoryPage> createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends State<CallHistoryPage> {
  final CallHistoryService _historyService = CallHistoryService.instance;
  StreamSubscription<void>? _historySubscription;
  List<CallHistoryEntry> _entries = const <CallHistoryEntry>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _historySubscription = _historyService.updates.listen((_) {
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final entries = await _historyService.getEntries();
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清空通话记录'),
          content: const Text('清空后将无法恢复，确定继续吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                '清空',
                style: TextStyle(color: WKColors.danger),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await _historyService.clear();
  }

  Future<void> _deleteEntry(CallHistoryEntry entry) async {
    await _historyService.deleteEntry(entry.roomId);
  }

  Future<void> _redial(CallHistoryEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallPage(
          channelId: entry.channelId,
          channelName: entry.channelName,
          callType: entry.callType,
        ),
      ),
    );
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通话记录'),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              tooltip: '清空记录',
              onPressed: _confirmClearHistory,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? const WKEmptyView(
              icon: Icons.history_toggle_off_rounded,
              message: '暂无通话记录',
              subMessage: '发起一次语音或视频通话后，会在这里保留最近记录。',
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  WKSpace.md,
                  WKSpace.md,
                  WKSpace.md,
                  WKSpace.xl,
                ),
                itemCount: _entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: WKSpace.sm),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return Dismissible(
                    key: ValueKey(entry.roomId),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: WKSpace.lg),
                      decoration: BoxDecoration(
                        color: WKColors.danger,
                        borderRadius: BorderRadius.circular(WKRadius.xl),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    onDismissed: (_) => _deleteEntry(entry),
                    child: _HistoryTile(
                      entry: entry,
                      onTap: () => _redial(entry),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.onTap,
  });

  final CallHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = entry.channelName.trim().isEmpty
        ? entry.channelId
        : entry.channelName.trim();
    final subtitle = _buildSubtitle(entry);
    final timeText = _formatTimestamp(entry.startedAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(WKRadius.xl),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(WKSpace.md),
          decoration: BoxDecoration(
            color: WKColors.surface,
            borderRadius: BorderRadius.circular(WKRadius.xl),
            border: Border.all(color: WKColors.outline),
            boxShadow: WKShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _iconBackground(entry),
                  borderRadius: BorderRadius.circular(WKRadius.lg),
                ),
                child: Icon(
                  entry.callType == CallType.video
                      ? Icons.videocam_outlined
                      : Icons.call_outlined,
                  color: _iconColor(entry),
                ),
              ),
              const SizedBox(width: WKSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: WKSpace.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WKColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: WKSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WKColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: WKSpace.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: WKColors.textTertiary.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _buildSubtitle(CallHistoryEntry entry) {
    final directionText = entry.direction == CallDirection.incoming
        ? '来电'
        : '去电';
    final typeText = entry.callType == CallType.video ? '视频' : '语音';
    final statusText = switch (entry.status) {
      CallHistoryStatus.ringing => '响铃中',
      CallHistoryStatus.connected => '通话中',
      CallHistoryStatus.completed => '已完成',
      CallHistoryStatus.missed => '未接听',
      CallHistoryStatus.rejected => '已拒绝',
      CallHistoryStatus.canceled => '已取消',
    };
    final durationSeconds = entry.durationSeconds;
    final durationText = durationSeconds == null
        ? null
        : '时长 ${_formatDuration(durationSeconds)}';
    return [
      '$directionText · $typeText',
      statusText,
      ?durationText,
    ].join(' · ');
  }

  static String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes == 0) {
      return '${seconds}s';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  static String _formatTimestamp(int millisecondsSinceEpoch) {
    final date = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  static Color _iconBackground(CallHistoryEntry entry) {
    return switch (entry.status) {
      CallHistoryStatus.completed || CallHistoryStatus.connected =>
        WKColors.brand50,
      CallHistoryStatus.ringing => WKColors.warning.withValues(alpha: 0.14),
      CallHistoryStatus.missed ||
      CallHistoryStatus.rejected ||
      CallHistoryStatus.canceled => WKColors.danger.withValues(alpha: 0.12),
    };
  }

  static Color _iconColor(CallHistoryEntry entry) {
    return switch (entry.status) {
      CallHistoryStatus.completed || CallHistoryStatus.connected =>
        WKColors.brand500,
      CallHistoryStatus.ringing => WKColors.warning,
      CallHistoryStatus.missed ||
      CallHistoryStatus.rejected ||
      CallHistoryStatus.canceled => WKColors.danger,
    };
  }
}
