import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/group.dart';
import '../../service/api/group_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'juliang_monitor_forwarding_service.dart';
import 'juliang_monitor_shell_client.dart';
import 'juliang_monitor_shell_models.dart';

typedef JuliangMonitorTargetGroupLoader = Future<List<GroupInfo>> Function();

class JuliangMonitorCenterPage extends StatefulWidget {
  JuliangMonitorCenterPage({
    super.key,
    JuliangMonitorShellClient? client,
    JuliangMonitorForwardingService? forwardingService,
    JuliangMonitorForwardingSettingsStore? forwardingSettingsStore,
    JuliangMonitorTargetGroupLoader? loadTargetGroups,
  }) : client = client ?? JuliangMonitorShellClient(),
       forwardingService =
           forwardingService ?? JuliangMonitorForwardingService(),
       forwardingSettingsStore =
           forwardingSettingsStore ??
           const SharedPreferencesJuliangMonitorForwardingSettingsStore(),
       loadTargetGroups = loadTargetGroups ?? GroupApi.instance.getMyGroups;

  final JuliangMonitorShellClient client;
  final JuliangMonitorForwardingService forwardingService;
  final JuliangMonitorForwardingSettingsStore forwardingSettingsStore;
  final JuliangMonitorTargetGroupLoader loadTargetGroups;

  @override
  State<JuliangMonitorCenterPage> createState() =>
      _JuliangMonitorCenterPageState();
}

class _JuliangMonitorCenterPageState extends State<JuliangMonitorCenterPage> {
  JuliangMonitorShellStatus? _status;
  JuliangMonitorForwardingSettings _settings =
      const JuliangMonitorForwardingSettings(enabled: false);
  bool _loading = true;
  bool _forwarding = false;
  String _error = '';
  String _result = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
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

  Future<void> _saveSettings(
    JuliangMonitorForwardingSettings settings,
  ) async {
    await widget.forwardingSettingsStore.save(settings);
    if (!mounted) {
      return;
    }
    setState(() => _settings = settings);
  }

  Future<void> _configureRoute(JuliangMonitorMessageEvent event) async {
    return _configureRouteFromSource(
      sourceConversationId: event.conversationId,
      sourceConversationName: event.conversationName,
      sourceConversationType: event.conversationType,
    );
  }

  Future<void> _configureRouteFromConversation(
    JuliangMonitorObservedConversation conversation,
  ) async {
    return _configureRouteFromSource(
      sourceConversationId: conversation.id,
      sourceConversationName: conversation.name,
      sourceConversationType: conversation.type,
    );
  }

  Future<void> _configureRouteFromSource({
    required String sourceConversationId,
    required String sourceConversationName,
    required String sourceConversationType,
  }) async {
    final groups = await widget.loadTargetGroups();
    if (!mounted) {
      return;
    }
    final selected = await showModalBottomSheet<GroupInfo>(
      context: context,
      backgroundColor: WKColors.surface,
      builder: (context) => _TargetGroupSheet(groups: groups),
    );
    if (selected == null || !mounted) {
      return;
    }
    final now = DateTime.now().toUtc();
    final route = JuliangMonitorForwardingRoute(
      id: _routeIdForSource(sourceConversationId),
      enabled: true,
      sourceConversationId: sourceConversationId.trim(),
      sourceConversationName: sourceConversationName.trim(),
      sourceConversationType: sourceConversationType.trim(),
      targetGroupId: selected.groupNo,
      targetGroupName: _groupDisplayName(selected),
      createdAt:
          _existingRouteForSource(sourceConversationId)?.createdAt ?? now,
      updatedAt: now,
    );
    await _saveSettings(
      _settings.copyWith(
        enabled: true,
        routes: _replaceRoute(_settings.routes, route),
      ),
    );
    _showMessage('已保存聚合转发规则');
  }

  Future<void> _forwardRecent() async {
    final status = _status;
    if (_forwarding || status == null) {
      return;
    }
    setState(() {
      _forwarding = true;
      _result = '';
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
            '已转发 ${result.sent} 条，重复 ${result.skippedDuplicate} 条，未匹配 ${result.skippedUnmatched} 条，停用 ${result.skippedDisabled} 条，失败 ${result.failed} 条';
      });
      _showMessage(_result);
    } finally {
      if (mounted) {
        setState(() => _forwarding = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<JuliangMonitorForwardingRoute> _replaceRoute(
    List<JuliangMonitorForwardingRoute> routes,
    JuliangMonitorForwardingRoute route,
  ) {
    final next = <JuliangMonitorForwardingRoute>[];
    var replaced = false;
    for (final item in routes) {
      if (item.sourceConversationId.trim() == route.sourceConversationId) {
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

  JuliangMonitorForwardingRoute? _existingRouteForSource(String sourceId) {
    for (final route in _settings.routes) {
      if (route.sourceConversationId.trim() == sourceId.trim()) {
        return route;
      }
    }
    return null;
  }

  String _routeIdForSource(String sourceId) {
    final safe = sourceId
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceFirst(RegExp(r'^_+'), '')
        .replaceFirst(RegExp(r'_+$'), '');
    return safe.isEmpty ? 'route_juliang' : 'route_$safe';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return WKSubPageScaffold(
      title: '聚合信息转发中心',
      trailing: IconButton(
        onPressed: _loading ? null : _load,
        icon: const Icon(Icons.refresh_rounded, color: WKColors.colorDark),
      ),
      trailingWidth: 48,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _StatusCard(status: status, loading: _loading, error: _error),
          const SizedBox(height: WKSpace.sm),
          _ActionCard(
            forwarding: _forwarding,
            routeCount: _settings.routes.length,
            result: _result,
            onForwardRecent: status == null || status.recentEvents.isEmpty
                ? null
                : _forwardRecent,
          ),
          const SizedBox(height: WKSpace.sm),
          _RoutesCard(routes: _settings.routes),
          const SizedBox(height: WKSpace.sm),
          _RecentEventsCard(
            events: status?.recentEvents ?? const <JuliangMonitorMessageEvent>[],
            onConfigureRoute: _configureRoute,
          ),
          const SizedBox(height: WKSpace.sm),
          _ObservedSourcesCard(
            conversations:
                status?.observedConversations ??
                const <JuliangMonitorObservedConversation>[],
            onConfigureRoute: _configureRouteFromConversation,
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.loading,
    required this.error,
  });

  final JuliangMonitorShellStatus? status;
  final bool loading;
  final String error;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    return _SectionCard(
      title: '运行状态',
      children: [
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (error.trim().isNotEmpty)
          Text(error, style: const TextStyle(color: WKColors.danger)),
        Text('Shell: ${status?.shellState ?? 'unknown'}'),
        Text('登录: ${status?.loginState ?? 'unknown'}'),
        Text('监听: ${status?.captureState ?? 'unknown'}'),
        Text('页面: ${status?.pageTitle ?? '-'}'),
        const Text('每次启动都需要手动登录，聚合网页会话不会复用。'),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.forwarding,
    required this.routeCount,
    required this.result,
    required this.onForwardRecent,
  });

  final bool forwarding;
  final int routeCount;
  final String result;
  final VoidCallback? onForwardRecent;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '快捷操作',
      children: [
        Text('已配置 $routeCount 条路由'),
        FilledButton(
          key: const ValueKey('juliang-forward-recent-button'),
          onPressed: forwarding ? null : onForwardRecent,
          child: Text(forwarding ? '转发中...' : '转发最近文本'),
        ),
        if (result.trim().isNotEmpty) Text(result),
      ],
    );
  }
}

class _RoutesCard extends StatelessWidget {
  const _RoutesCard({required this.routes});

  final List<JuliangMonitorForwardingRoute> routes;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '转发规则',
      children: [
        if (routes.isEmpty) const Text('暂无转发规则'),
        for (final route in routes)
          Text(
            '${route.enabled ? '启用' : '停用'} ${route.sourceConversationName} -> ${route.targetGroupName}',
          ),
      ],
    );
  }
}

class _ObservedSourcesCard extends StatelessWidget {
  const _ObservedSourcesCard({
    required this.conversations,
    required this.onConfigureRoute,
  });

  final List<JuliangMonitorObservedConversation> conversations;
  final ValueChanged<JuliangMonitorObservedConversation> onConfigureRoute;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '已观察来源',
      children: [
        if (conversations.isEmpty) const Text('暂无来源'),
        for (final conversation in conversations)
          ListTile(
            key: ValueKey('juliang-observed-source:${conversation.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(conversation.name),
            subtitle: Text(conversation.lastMessagePreview),
            onTap: () => onConfigureRoute(conversation),
            trailing: TextButton(
              onPressed: () => onConfigureRoute(conversation),
              child: const Text('配置'),
            ),
          ),
      ],
    );
  }
}

class _RecentEventsCard extends StatelessWidget {
  const _RecentEventsCard({
    required this.events,
    required this.onConfigureRoute,
  });

  final List<JuliangMonitorMessageEvent> events;
  final ValueChanged<JuliangMonitorMessageEvent> onConfigureRoute;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '最近文本事件',
      children: [
        if (events.isEmpty) const Text('暂无文本事件'),
        for (final event in events)
          ListTile(
            key: ValueKey('juliang-route-source:${event.conversationId}'),
            contentPadding: EdgeInsets.zero,
            title: Text(event.conversationName),
            subtitle: Text('${event.senderName}: ${event.text}'),
            onTap: () => onConfigureRoute(event),
            trailing: TextButton(
              onPressed: () => onConfigureRoute(event),
              child: const Text('配置'),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WKSpace.md),
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.md),
        boxShadow: WKShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: WKSpace.sm),
          ...children,
        ],
      ),
    );
  }
}

class _TargetGroupSheet extends StatelessWidget {
  const _TargetGroupSheet({required this.groups});

  final List<GroupInfo> groups;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final group in groups)
            ListTile(
              title: Text(_groupDisplayName(group)),
              subtitle: Text(group.groupNo),
              onTap: () => Navigator.of(context).pop(group),
            ),
        ],
      ),
    );
  }
}

String _groupDisplayName(GroupInfo group) {
  final name = group.name?.trim();
  if (name != null && name.isNotEmpty) {
    return name;
  }
  final remark = group.remark?.trim();
  if (remark != null && remark.isNotEmpty) {
    return remark;
  }
  return group.groupNo;
}
