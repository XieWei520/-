import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/group.dart';
import '../../service/api/group_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'dingtalk_monitor_forwarding_service.dart';
import 'dingtalk_monitor_shell_client.dart';
import 'dingtalk_monitor_shell_models.dart';

typedef DingTalkMonitorTargetGroupLoader = Future<List<GroupInfo>> Function();

class DingTalkMonitorCenterPage extends StatefulWidget {
  DingTalkMonitorCenterPage({
    super.key,
    DingTalkMonitorShellClient? client,
    DingTalkMonitorForwardingService? forwardingService,
    DingTalkMonitorForwardingSettingsStore? forwardingSettingsStore,
    DingTalkMonitorTargetGroupLoader? loadTargetGroups,
  }) : client = client ?? DingTalkMonitorShellClient(),
       forwardingService =
           forwardingService ?? DingTalkMonitorForwardingService(),
       forwardingSettingsStore =
           forwardingSettingsStore ??
           const SharedPreferencesDingTalkMonitorForwardingSettingsStore(),
       loadTargetGroups = loadTargetGroups ?? GroupApi.instance.getMyGroups;

  final DingTalkMonitorShellClient client;
  final DingTalkMonitorForwardingService forwardingService;
  final DingTalkMonitorForwardingSettingsStore forwardingSettingsStore;
  final DingTalkMonitorTargetGroupLoader loadTargetGroups;

  @override
  State<DingTalkMonitorCenterPage> createState() =>
      _DingTalkMonitorCenterPageState();
}

class _DingTalkMonitorCenterPageState extends State<DingTalkMonitorCenterPage> {
  DingTalkMonitorShellStatus? _status;
  List<DingTalkMonitorMessageEvent> _recentEvents =
      const <DingTalkMonitorMessageEvent>[];
  DingTalkMonitorForwardingSettings _settings =
      const DingTalkMonitorForwardingSettings(enabled: false);
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
      final events = await widget.client.fetchForwardableRecentEvents();
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _status = status;
        _recentEvents = events;
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
    DingTalkMonitorForwardingSettings settings,
  ) async {
    await widget.forwardingSettingsStore.save(settings);
    if (!mounted) {
      return;
    }
    setState(() => _settings = settings);
  }

  Future<void> _configureRoute(DingTalkMonitorMessageEvent event) async {
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
    final route = DingTalkMonitorForwardingRoute(
      id: _routeIdForEvent(event),
      enabled: true,
      sourceConversationId: event.sourceConversationId.trim(),
      sourceConversationName: event.sourceConversationName.trim(),
      embeddedSourceName: event.embeddedSourceName.trim(),
      targetGroupId: selected.groupNo,
      targetGroupName: _groupDisplayName(selected),
      createdAt: _existingRouteForEvent(event)?.createdAt ?? now,
      updatedAt: now,
    );
    final routes = _replaceRoute(_settings.routes, route);
    await _saveSettings(
      _settings.copyWith(enabled: true, routes: routes),
    );
    _showMessage('已保存钉钉转发规则');
  }

  Future<void> _forwardRecent() async {
    if (_forwarding) {
      return;
    }
    setState(() {
      _forwarding = true;
      _result = '';
    });
    try {
      final result = await widget.forwardingService.forwardRoutedRecentEvents(
        settings: _settings.copyWith(enabled: true),
        events: _recentEvents,
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

  List<DingTalkMonitorForwardingRoute> _replaceRoute(
    List<DingTalkMonitorForwardingRoute> routes,
    DingTalkMonitorForwardingRoute route,
  ) {
    final next = <DingTalkMonitorForwardingRoute>[];
    var replaced = false;
    for (final item in routes) {
      if (item.id == route.id ||
          (route.sourceConversationId.trim().isNotEmpty &&
              item.sourceConversationId.trim() ==
                  route.sourceConversationId.trim())) {
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

  DingTalkMonitorForwardingRoute? _existingRouteForEvent(
    DingTalkMonitorMessageEvent event,
  ) {
    for (final route in _settings.routes) {
      if (route.sourceConversationId.trim().isNotEmpty &&
          route.sourceConversationId.trim() ==
              event.sourceConversationId.trim()) {
        return route;
      }
      if (normalizeDingTalkMonitorRouteName(route.embeddedSourceName) ==
              normalizeDingTalkMonitorRouteName(event.embeddedSourceName) &&
          event.embeddedSourceName.trim().isNotEmpty) {
        return route;
      }
    }
    return null;
  }

  String _routeIdForEvent(DingTalkMonitorMessageEvent event) {
    final source = event.sourceConversationId.trim().isNotEmpty
        ? event.sourceConversationId.trim()
        : event.embeddedSourceName.trim().isNotEmpty
        ? event.embeddedSourceName.trim()
        : event.sourceConversationName.trim();
    final safe = source
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceFirst(RegExp(r'^_+'), '')
        .replaceFirst(RegExp(r'_+$'), '');
    return safe.isEmpty ? 'route_dingtalk' : 'route_$safe';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return WKSubPageScaffold(
      title: '钉钉信息转发中心',
      trailing: IconButton(
        key: const ValueKey('dingtalk-monitor-refresh-button'),
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
            onForwardRecent: _recentEvents.isEmpty ? null : _forwardRecent,
          ),
          const SizedBox(height: WKSpace.sm),
          _RoutesCard(routes: _settings.routes),
          const SizedBox(height: WKSpace.sm),
          _RecentEventsCard(
            events: _recentEvents,
            onConfigureRoute: _configureRoute,
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

  final DingTalkMonitorShellStatus? status;
  final bool loading;
  final String error;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    return _Card(
      title: 'Native Host 状态',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error.trim().isNotEmpty)
            Text(error, style: const TextStyle(color: WKColors.danger)),
          _Line('窗口状态', status?.shellState ?? 'Unknown'),
          _Line('监听状态', status?.captureRunning == true ? 'Running' : 'Stopped'),
          _Line('会话就绪', status?.conversationReadiness ?? 'Unknown'),
          _Line('OCR', status?.ocrEnabled == true ? 'Enabled' : 'Disabled'),
          _Line('窗口句柄', status?.currentHwnd ?? ''),
          if ((status?.conversationReadinessMessage ?? '').trim().isNotEmpty)
            _Line('说明', status!.conversationReadinessMessage),
        ],
      ),
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
    return _Card(
      title: '转发控制',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('已配置 $routeCount 条规则'),
          const SizedBox(height: WKSpace.sm),
          FilledButton(
            key: const ValueKey('dingtalk-forward-recent-button'),
            onPressed: forwarding ? null : onForwardRecent,
            child: Text(forwarding ? '正在转发...' : '手动转发最近事件'),
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

  final List<DingTalkMonitorForwardingRoute> routes;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: '转发规则',
      child: routes.isEmpty
          ? const Text('暂无规则。请从最近事件中选择来源并绑定悟空 IM 群。')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final route in routes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: WKSpace.xs),
                    child: Text(
                      '${_routeSourceLabel(route)} -> ${route.targetGroupName.trim().isEmpty ? route.targetGroupId : route.targetGroupName}',
                    ),
                  ),
              ],
            ),
    );
  }

  String _routeSourceLabel(DingTalkMonitorForwardingRoute route) {
    if (route.embeddedSourceName.trim().isNotEmpty) {
      return route.embeddedSourceName.trim();
    }
    if (route.sourceConversationName.trim().isNotEmpty) {
      return route.sourceConversationName.trim();
    }
    return route.sourceConversationId.trim();
  }
}

class _RecentEventsCard extends StatelessWidget {
  const _RecentEventsCard({
    required this.events,
    required this.onConfigureRoute,
  });

  final List<DingTalkMonitorMessageEvent> events;
  final Future<void> Function(DingTalkMonitorMessageEvent event)
  onConfigureRoute;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: '最近可转发事件',
      child: events.isEmpty
          ? const Text('暂无事件。请确认 native host 已启动并捕获到消息。')
          : Column(
              children: [
                for (final event in events.take(20))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      event.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${event.sourceConversationName} ${event.senderName} ${dingTalkMonitorCaptureSourceName(event.captureSource)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: TextButton(
                      key: ValueKey(
                        'dingtalk-route-source:${event.sourceConversationId}',
                      ),
                      onPressed: () => onConfigureRoute(event),
                      child: const Text('绑定群'),
                    ),
                  ),
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
          const Padding(
            padding: EdgeInsets.all(WKSpace.lg),
            child: Text(
              '选择目标悟空 IM 群',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(WKSpace.lg),
              child: Text('暂无可选群'),
            ),
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
  final name = group.name?.trim() ?? '';
  return name.isEmpty ? group.groupNo : name;
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

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
