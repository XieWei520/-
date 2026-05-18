import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/group.dart';
import '../../service/api/group_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'xiaoe_monitor_forwarding_service.dart';
import 'xiaoe_monitor_launch_service.dart';
import 'xiaoe_monitor_shell_client.dart';
import 'xiaoe_monitor_shell_models.dart';

typedef XiaoeMonitorTargetGroupLoader = Future<List<GroupInfo>> Function();

class XiaoeMonitorCenterPage extends StatefulWidget {
  XiaoeMonitorCenterPage({
    super.key,
    XiaoeMonitorShellClient? client,
    XiaoeMonitorLaunchService? launchService,
    XiaoeMonitorForwardingService? forwardingService,
    XiaoeMonitorForwardingSettingsStore? forwardingSettingsStore,
    XiaoeMonitorTargetGroupLoader? loadTargetGroups,
  }) : client = client ?? XiaoeMonitorShellClient(),
       launchService =
           launchService ??
           (client == null
               ? XiaoeMonitorLaunchService()
               : const XiaoeMonitorLaunchService.noop()),
       forwardingService = forwardingService ?? XiaoeMonitorForwardingService(),
       forwardingSettingsStore =
           forwardingSettingsStore ??
           const SharedPreferencesXiaoeMonitorForwardingSettingsStore(),
       loadTargetGroups = loadTargetGroups ?? GroupApi.instance.getMyGroups;

  final XiaoeMonitorShellClient client;
  final XiaoeMonitorLaunchService launchService;
  final XiaoeMonitorForwardingService forwardingService;
  final XiaoeMonitorForwardingSettingsStore forwardingSettingsStore;
  final XiaoeMonitorTargetGroupLoader loadTargetGroups;

  @override
  State<XiaoeMonitorCenterPage> createState() => _XiaoeMonitorCenterPageState();
}

class _XiaoeMonitorCenterPageState extends State<XiaoeMonitorCenterPage> {
  XiaoeMonitorShellStatus? _status;
  XiaoeMonitorForwardingSettings _settings =
      const XiaoeMonitorForwardingSettings(enabled: false);
  bool _loading = true;
  bool _forwarding = false;
  String _error = '';
  String _result = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load(startShell: false));
  }

  Future<void> _load({bool startShell = false}) async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      if (startShell) {
        await widget.launchService.startShell();
      }
      final settings = await widget.forwardingSettingsStore.load();
      final status = await widget.client.fetchStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _status = status;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _saveSettings(XiaoeMonitorForwardingSettings settings) async {
    await widget.forwardingSettingsStore.save(settings);
    if (!mounted) {
      return;
    }
    setState(() => _settings = settings);
  }

  Future<void> _startCapture() async {
    await _runQuickAction(
      runningMessage: '正在启动小鹅通监控...',
      successMessage: '小鹅通监控已启动',
      action: () async {
        await widget.launchService.startShell();
        await widget.client.startCapture();
      },
    );
  }

  Future<void> _stopCapture() async {
    await _runQuickAction(
      runningMessage: '正在停止小鹅通监控...',
      successMessage: '小鹅通监控已停止',
      action: widget.client.stopCapture,
    );
  }

  Future<void> _reloadRuntime() async {
    await _runQuickAction(
      runningMessage: '正在重新打开小鹅通 muti_index...',
      successMessage: '已重新打开小鹅通 muti_index',
      action: widget.client.reloadRuntime,
    );
  }

  Future<void> _runQuickAction({
    required String runningMessage,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    if (mounted) {
      setState(() => _result = runningMessage);
    }
    try {
      await action();
      await _load(startShell: false);
      if (!mounted) {
        return;
      }
      setState(() => _result = successMessage);
      _showMessage(successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = '操作失败：$error';
      setState(() => _result = message);
      _showMessage(message);
    }
  }

  Future<void> _forwardRecentEvents() async {
    final status = _status;
    if (status == null || _forwarding) {
      return;
    }
    setState(() {
      _forwarding = true;
      _result = '正在按当前规则转发小鹅通近期事件...';
    });
    try {
      final result = await widget.forwardingService.forwardRoutedRecentEvents(
        settings: _settings.copyWith(enabled: true),
        events: status.recentEvents,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result =
            '已转发 ${result.sent} 条，重复 ${result.skippedDuplicate} 条，'
            '未匹配 ${result.skippedUnmatched} 条，停用 ${result.skippedDisabled} 条，'
            '超限文件 ${result.skippedOversizedFile} 个，不支持文件 ${result.skippedUnsupportedFile} 个，'
            '失败 ${result.failed} 条';
      });
      _showMessage(_result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _result = '转发失败：$error');
    } finally {
      if (mounted) {
        setState(() => _forwarding = false);
      }
    }
  }

  Future<void> _configureRouteForConversation(
    XiaoeMonitorObservedConversation conversation,
  ) async {
    final sourceConversationId = conversation.id.trim();
    if (sourceConversationId.isEmpty) {
      _showMessage('无法配置空的小鹅通来源');
      return;
    }
    final selected = await showModalBottomSheet<GroupInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: WKColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(WKRadius.lg)),
      ),
      builder: (context) {
        return _TargetGroupPicker(loadGroups: widget.loadTargetGroups);
      },
    );
    if (selected == null || !mounted) {
      return;
    }

    final existing = _existingRouteForSource(sourceConversationId);
    final now = DateTime.now().toUtc();
    final route = XiaoeMonitorForwardingRoute(
      id: existing?.id ?? _routeIdForConversation(conversation),
      enabled: existing?.enabled ?? true,
      sourceConversationId: sourceConversationId,
      sourceConversationName: conversation.name.trim(),
      sourceConversationType: conversation.type.trim(),
      targetGroupId: selected.groupNo.trim(),
      targetGroupName: _groupDisplayName(selected),
      relayDisplayName: existing?.relayDisplayName ?? '',
      relayAvatar: existing?.relayAvatar ?? '',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _saveSettings(
      _settings.copyWith(
        enabled: true,
        routes: _replaceRoute(_settings.routes, route),
      ),
    );
    _showMessage('已保存 ${_conversationDisplayName(conversation)} 的转发目标');
  }

  List<XiaoeMonitorForwardingRoute> _replaceRoute(
    List<XiaoeMonitorForwardingRoute> routes,
    XiaoeMonitorForwardingRoute route,
  ) {
    final next = <XiaoeMonitorForwardingRoute>[];
    var replaced = false;
    for (final item in routes) {
      if (item.id == route.id ||
          item.sourceConversationId.trim() ==
              route.sourceConversationId.trim()) {
        next.add(route);
        replaced = true;
      } else {
        next.add(item);
      }
    }
    if (!replaced) {
      next.add(route);
    }
    return next;
  }

  XiaoeMonitorForwardingRoute? _existingRouteForSource(String sourceId) {
    for (final route in _settings.routes) {
      if (route.sourceConversationId.trim() == sourceId) {
        return route;
      }
    }
    return null;
  }

  String _routeIdForConversation(XiaoeMonitorObservedConversation item) {
    final source = item.id.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    return 'route_${source.isEmpty ? DateTime.now().microsecondsSinceEpoch : source}';
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return WKSubPageScaffold(
      title: '小鹅通信息转发中心',
      trailing: IconButton(
        key: const ValueKey('xiaoe-monitor-refresh-button'),
        onPressed: _loading ? null : () => _load(startShell: true),
        icon: const Icon(Icons.refresh_rounded, color: WKColors.colorDark),
        tooltip: '刷新',
      ),
      trailingWidth: 48,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusCard(
              status: status,
              loading: _loading,
              error: _error,
              routes: _settings.routes,
            ),
            const SizedBox(height: WKSpace.sm),
            _ActionCard(
              loading: _loading,
              forwarding: _forwarding,
              routeCount: _settings.routes.length,
              result: _result,
              onStartCapture: _loading ? null : _startCapture,
              onStopCapture: _loading ? null : _stopCapture,
              onReloadRuntime: _loading ? null : _reloadRuntime,
              onForwardRecent:
                  status == null || status.recentEvents.isEmpty || _forwarding
                  ? null
                  : _forwardRecentEvents,
            ),
            const SizedBox(height: WKSpace.sm),
            _RoutesCard(routes: _settings.routes),
            const SizedBox(height: WKSpace.sm),
            _SourcesCard(
              conversations:
                  status?.observedConversations ??
                  const <XiaoeMonitorObservedConversation>[],
              onConfigureRoute: _configureRouteForConversation,
            ),
            const SizedBox(height: WKSpace.sm),
            _RecentEventsCard(
              events:
                  status?.recentEvents ?? const <XiaoeMonitorMessageEvent>[],
            ),
            const SizedBox(height: WKSpace.sm),
            _DiagnosticsCard(status: status),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.loading,
    required this.error,
    required this.routes,
  });

  final XiaoeMonitorShellStatus? status;
  final bool loading;
  final String error;
  final List<XiaoeMonitorForwardingRoute> routes;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    final online = status?.isOnline ?? false;
    final running = status?.isCapturing ?? false;
    final loginState = status?.loginState ?? 'unknown';
    return _SectionCard(
      title: '运行总览',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error.trim().isNotEmpty)
            Text(error, style: const TextStyle(color: WKColors.danger)),
          _Line('Shell', online ? 'online' : (status?.shellState ?? 'unknown')),
          _Line('登录', loginState),
          _Line(
            '监听',
            running ? 'running' : (status?.captureState ?? 'stopped'),
          ),
          _Line('页面', status?.pageTitle ?? '-'),
          _Line('地址', status?.runtimeUrl ?? xiaoeMonitorDefaultShellBaseUrl),
          _Line('路由', '${routes.length} 条'),
          const SizedBox(height: WKSpace.xs),
          const Text(
            '从 muti_index 打开后，请手动停留在目标圈子/课程互动/直播评论页面；'
            '直播评论逐条文本转发，圈子/课程互动图片和 20 MB 内文件会一起转发。',
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 13,
              height: 1.45,
              color: WKColors.color999,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.loading,
    required this.forwarding,
    required this.routeCount,
    required this.result,
    required this.onStartCapture,
    required this.onStopCapture,
    required this.onReloadRuntime,
    required this.onForwardRecent,
  });

  final bool loading;
  final bool forwarding;
  final int routeCount;
  final String result;
  final VoidCallback? onStartCapture;
  final VoidCallback? onStopCapture;
  final VoidCallback? onReloadRuntime;
  final VoidCallback? onForwardRecent;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '快捷操作',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('已配置 $routeCount 条转发规则'),
          const SizedBox(height: WKSpace.sm),
          Wrap(
            spacing: WKSpace.sm,
            runSpacing: WKSpace.xs,
            children: [
              FilledButton.icon(
                key: const ValueKey('xiaoe-monitor-start-button'),
                onPressed: onStartCapture,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('启动监控'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('xiaoe-monitor-stop-button'),
                onPressed: onStopCapture,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('停止'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('xiaoe-monitor-reload-button'),
                onPressed: onReloadRuntime,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重开 muti_index'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('xiaoe-monitor-forward-recent-button'),
                onPressed: forwarding ? null : onForwardRecent,
                icon: const Icon(Icons.send_rounded),
                label: Text(forwarding ? '转发中...' : '手动转发最近事件'),
              ),
            ],
          ),
          if (result.trim().isNotEmpty) ...[
            const SizedBox(height: WKSpace.sm),
            Text(result),
          ],
        ],
      ),
    );
  }
}

class _RoutesCard extends StatelessWidget {
  const _RoutesCard({required this.routes});

  final List<XiaoeMonitorForwardingRoute> routes;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '转发规则',
      child: routes.isEmpty
          ? const Text(
              '暂无规则。请先让壳端停留在目标页面，然后从“小鹅通来源”绑定悟空 IM 目标群。',
              style: TextStyle(color: WKColors.color999),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final route in routes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: WKSpace.xs),
                    child: Text(
                      '${route.enabled ? '启用' : '停用'} '
                      '${_routeSourceName(route)} -> ${_routeTargetName(route)}',
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SourcesCard extends StatelessWidget {
  const _SourcesCard({
    required this.conversations,
    required this.onConfigureRoute,
  });

  final List<XiaoeMonitorObservedConversation> conversations;
  final ValueChanged<XiaoeMonitorObservedConversation> onConfigureRoute;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '小鹅通来源',
      child: conversations.isEmpty
          ? const Text(
              '暂无来源。请在壳端登录小鹅通并停留在圈子/课程互动/直播评论页面。',
              style: TextStyle(color: WKColors.color999),
            )
          : Column(
              children: [
                for (final conversation in conversations)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_conversationDisplayName(conversation)),
                    subtitle: Text(
                      '${conversation.type} ${conversation.lastMessagePreview}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: TextButton(
                      key: ValueKey(
                        'xiaoe-route-configure-${conversation.id.trim()}',
                      ),
                      onPressed: () => onConfigureRoute(conversation),
                      child: const Text('配置'),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RecentEventsCard extends StatelessWidget {
  const _RecentEventsCard({required this.events});

  final List<XiaoeMonitorMessageEvent> events;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '最近事件',
      child: events.isEmpty
          ? const Text(
              '暂无事件。直播评论会按评论逐条出现；图片和文件事件会保留附件。',
              style: TextStyle(color: WKColors.color999),
            )
          : Column(
              children: [
                for (final event in events.take(30))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _eventPreview(event),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_eventSourceName(event)} ${event.senderName} '
                      '${event.messageType}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({required this.status});

  final XiaoeMonitorShellStatus? status;

  @override
  Widget build(BuildContext context) {
    final diagnostics = status?.probeDiagnostics ?? const <String, dynamic>{};
    return _SectionCard(
      title: '诊断',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Line('端口', '18806'),
          _Line('默认页', 'https://study.xiaoe-tech.com/#/muti_index'),
          _Line('文件限制', '20 MB'),
          if ((status?.lastError ?? '').trim().isNotEmpty)
            _Line('错误', status!.lastError),
          for (final entry in diagnostics.entries.take(12))
            _Line(entry.key, entry.value.toString()),
        ],
      ),
    );
  }
}

class _TargetGroupPicker extends StatefulWidget {
  const _TargetGroupPicker({required this.loadGroups});

  final XiaoeMonitorTargetGroupLoader loadGroups;

  @override
  State<_TargetGroupPicker> createState() => _TargetGroupPickerState();
}

class _TargetGroupPickerState extends State<_TargetGroupPicker> {
  late final Future<List<GroupInfo>> _groupsFuture = widget.loadGroups();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          WKSpace.lg,
          WKSpace.md,
          WKSpace.lg,
          WKSpace.lg,
        ),
        child: FutureBuilder<List<GroupInfo>>(
          future: _groupsFuture,
          builder: (context, snapshot) {
            final selectable =
                snapshot.data
                    ?.where(_isSelectableTargetGroup)
                    .toList(growable: false) ??
                const <GroupInfo>[];
            final groups = _filterGroups(selectable, _query);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择悟空目标群',
                  style: TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: WKColors.colorDark,
                  ),
                ),
                const SizedBox(height: WKSpace.xs),
                const Text(
                  '小鹅通来源只会转发到这里选择的悟空 IM 群。',
                  style: TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 13,
                    color: WKColors.color999,
                  ),
                ),
                const SizedBox(height: WKSpace.md),
                TextField(
                  key: const ValueKey('xiaoe-target-group-search-field'),
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _query = value);
                  },
                  decoration: InputDecoration(
                    hintText: '搜索群名称或群 ID',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    filled: true,
                    fillColor: WKColors.surfaceSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(WKRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: WKSpace.sm),
                if (snapshot.connectionState != ConnectionState.done)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  Text(
                    '加载群列表失败：${snapshot.error}',
                    style: const TextStyle(color: WKColors.danger),
                  )
                else if (groups.isEmpty)
                  const Text(
                    '暂无可选择的悟空群。',
                    style: TextStyle(color: WKColors.color999),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: WKColors.borderColor),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return ListTile(
                          key: ValueKey('xiaoe-target-group-${group.groupNo}'),
                          title: Text(_groupDisplayName(group)),
                          subtitle: Text(group.groupNo),
                          onTap: () => Navigator.of(context).pop(group),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WKSpace.lg),
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.lg),
        boxShadow: WKShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: WKSpace.sm),
          child,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: WKSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(color: WKColors.color999),
            ),
          ),
          Expanded(child: Text(value.trim().isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}

String _groupDisplayName(GroupInfo group) {
  final remark = group.remark?.trim() ?? '';
  if (remark.isNotEmpty) {
    return remark;
  }
  final name = group.name?.trim() ?? '';
  return name.isNotEmpty ? name : group.groupNo.trim();
}

bool _isSelectableTargetGroup(GroupInfo group) {
  if (group.groupNo.trim().isEmpty) {
    return false;
  }
  final status = group.status;
  if (status != null && status != 1) {
    return false;
  }
  final save = group.save;
  if (save != null && save != 1) {
    return false;
  }
  return true;
}

List<GroupInfo> _filterGroups(List<GroupInfo> groups, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return groups;
  }
  return groups
      .where((group) {
        final values = <String>[
          group.groupNo,
          group.name ?? '',
          group.remark ?? '',
        ];
        return values.any((value) => value.toLowerCase().contains(normalized));
      })
      .toList(growable: false);
}

String _conversationDisplayName(XiaoeMonitorObservedConversation item) {
  return item.name.trim().isNotEmpty ? item.name.trim() : item.id.trim();
}

String _routeSourceName(XiaoeMonitorForwardingRoute route) {
  if (route.sourceConversationName.trim().isNotEmpty) {
    return route.sourceConversationName.trim();
  }
  return route.sourceConversationId.trim();
}

String _routeTargetName(XiaoeMonitorForwardingRoute route) {
  if (route.targetGroupName.trim().isNotEmpty) {
    return route.targetGroupName.trim();
  }
  return route.targetGroupId.trim();
}

String _eventSourceName(XiaoeMonitorMessageEvent event) {
  return event.conversationName.trim().isNotEmpty
      ? event.conversationName.trim()
      : event.conversationId.trim();
}

String _eventPreview(XiaoeMonitorMessageEvent event) {
  if (event.text.trim().isNotEmpty) {
    return event.text.trim();
  }
  if (event.hasImageAttachments) {
    return '[图片]';
  }
  if (event.hasFileAttachments) {
    final fileName = event.fileAttachments
        .map((file) => file.fileName.trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => '文件');
    return '[文件] $fileName';
  }
  return '(空消息)';
}
