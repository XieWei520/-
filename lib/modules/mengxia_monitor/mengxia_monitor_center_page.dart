import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/group.dart';
import '../../service/api/group_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'mengxia_monitor_error_message.dart';
import 'mengxia_monitor_forwarding_service.dart';
import 'mengxia_monitor_launch_service.dart';
import 'mengxia_monitor_shell_client.dart';
import 'mengxia_monitor_shell_models.dart';

typedef MengxiaMonitorTargetGroupLoader = Future<List<GroupInfo>> Function();

enum _MengxiaConsoleTab { logs, rules, sources, settings }

class MengxiaMonitorCenterPage extends StatefulWidget {
  MengxiaMonitorCenterPage({
    super.key,
    MengxiaMonitorShellClient? client,
    MengxiaMonitorLaunchService? launchService,
    MengxiaMonitorForwardingService? forwardingService,
    MengxiaMonitorForwardingSettingsStore? forwardingSettingsStore,
    MengxiaMonitorTargetGroupLoader? loadTargetGroups,
    this.statusPollInterval = const Duration(seconds: 2),
  }) : client = client ?? MengxiaMonitorShellClient(),
       launchService =
           launchService ??
           (client == null
               ? MengxiaMonitorLaunchService()
               : MengxiaMonitorLaunchService.noop()),
       forwardingService =
           forwardingService ?? MengxiaMonitorForwardingService(),
       forwardingSettingsStore =
           forwardingSettingsStore ??
           const SharedPreferencesMengxiaMonitorForwardingSettingsStore(),
       loadTargetGroups = loadTargetGroups ?? GroupApi.instance.getMyGroups;

  final MengxiaMonitorShellClient client;
  final MengxiaMonitorLaunchService launchService;
  final MengxiaMonitorForwardingService forwardingService;
  final MengxiaMonitorForwardingSettingsStore forwardingSettingsStore;
  final MengxiaMonitorTargetGroupLoader loadTargetGroups;
  final Duration statusPollInterval;

  @override
  State<MengxiaMonitorCenterPage> createState() =>
      _MengxiaMonitorCenterPageState();
}

class _MengxiaMonitorCenterPageState extends State<MengxiaMonitorCenterPage> {
  MengxiaMonitorShellStatus? _status;
  _MengxiaConsoleTab _selectedTab = _MengxiaConsoleTab.sources;
  MengxiaMonitorForwardingSettings _settings =
      const MengxiaMonitorForwardingSettings(enabled: false);
  bool _loading = true;
  bool _forwarding = false;
  String _error = '';
  String _operationResult = '';
  Timer? _statusPollTimer;
  bool _refreshingStatus = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    if (widget.statusPollInterval > Duration.zero) {
      _statusPollTimer = Timer.periodic(widget.statusPollInterval, (_) {
        unawaited(_refreshStatus());
      });
    }
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await widget.launchService.startShell();
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
        _error = describeMengxiaMonitorShellError(error);
      });
    }
  }

  Future<void> _refreshStatus() async {
    if (_refreshingStatus || _loading || _forwarding) {
      return;
    }
    _refreshingStatus = true;
    try {
      final status = await widget.client.fetchStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _error = '';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = describeMengxiaMonitorShellError(error);
      });
    } finally {
      _refreshingStatus = false;
    }
  }

  Future<void> _startCapture() async {
    await _runQuickAction(
      runningMessage: '正在启动萌侠捕获...',
      successMessage: '已启动萌侠捕获',
      action: widget.client.startCapture,
    );
  }

  Future<void> _stopCapture() async {
    await _runQuickAction(
      runningMessage: '正在停止萌侠捕获...',
      successMessage: '已停止萌侠捕获',
      action: widget.client.stopCapture,
    );
  }

  Future<void> _reloadRuntime() async {
    await _runQuickAction(
      runningMessage: '正在重载萌侠无痕窗口...',
      successMessage: '已重载萌侠无痕窗口',
      action: widget.client.reloadRuntime,
    );
  }

  Future<void> _runQuickAction({
    required String runningMessage,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    if (mounted) {
      setState(() {
        _operationResult = runningMessage;
      });
    }
    try {
      await action();
      await _load();
      if (!mounted) {
        return;
      }
      setState(() {
        _operationResult = successMessage;
      });
      _showInfo(successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = '操作失败：${describeMengxiaMonitorShellError(error)}';
      setState(() {
        _operationResult = message;
      });
      _showInfo(message);
    }
  }

  Future<void> _forwardRecentEvents() async {
    final status = _status;
    if (status == null || _forwarding) {
      return;
    }
    setState(() {
      _forwarding = true;
      _operationResult = '正在按当前规则转发近期萌侠事件...';
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
        _operationResult =
            '转发完成：已转发 ${result.sent} 条，重复跳过 ${result.skippedDuplicate} 条，未匹配 ${result.skippedUnmatched} 条，停用跳过 ${result.skippedDisabled} 条，失败 ${result.failed} 条';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _operationResult = '转发失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _forwarding = false;
        });
      }
    }
  }

  Future<void> _configureRouteForConversation(
    MengxiaMonitorObservedConversation conversation,
  ) async {
    final sourceConversationId = conversation.id.trim();
    if (sourceConversationId.isEmpty) {
      _showInfo('无法配置空的萌侠来源会话');
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
        return _MengxiaTargetGroupPicker(loadGroups: widget.loadTargetGroups);
      },
    );
    if (selected == null || !mounted) {
      return;
    }

    final existing = _existingRouteForSource(sourceConversationId);
    final now = DateTime.now().toUtc();
    final targetGroupName = _groupDisplayName(selected);
    final route = MengxiaMonitorForwardingRoute(
      id: existing?.id ?? _routeIdForConversation(conversation),
      enabled: existing?.enabled ?? true,
      sourceConversationId: sourceConversationId,
      sourceConversationName: conversation.name.trim(),
      sourceConversationType: conversation.type.trim(),
      targetGroupId: selected.groupNo.trim(),
      targetGroupName: targetGroupName,
      relayDisplayName: existing?.relayDisplayName ?? '',
      relayAvatar: existing?.relayAvatar ?? '',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final routes = _replaceRoute(_settings.routes, route);
    await _saveSettings(_settings.copyWith(enabled: true, routes: routes));
    _showInfo('已保存 ${_conversationDisplayName(conversation)} 的转发目标');
  }

  Future<void> _saveSettings(MengxiaMonitorForwardingSettings settings) async {
    if (mounted) {
      setState(() {
        _settings = settings;
      });
    } else {
      _settings = settings;
    }
    await widget.forwardingSettingsStore.save(settings);
  }

  Future<void> _toggleAutoForwarding(bool enabled) async {
    await _saveSettings(_settings.copyWith(enabled: enabled));
  }

  Future<void> _toggleRoute(MengxiaMonitorForwardingRoute route) async {
    final updated = route.copyWith(
      enabled: !route.enabled,
      updatedAt: DateTime.now().toUtc(),
    );
    await _saveSettings(
      _settings.copyWith(routes: _replaceRoute(_settings.routes, updated)),
    );
  }

  Future<void> _deleteRoute(MengxiaMonitorForwardingRoute route) async {
    await _saveSettings(
      _settings.copyWith(
        routes: _settings.routes
            .where((item) => item.id != route.id)
            .toList(growable: false),
      ),
    );
    _showInfo('已删除规则 ${_routeDisplayName(route)}');
  }

  Future<void> _testRoute(MengxiaMonitorForwardingRoute route) async {
    final status = _status;
    if (status == null) {
      _showInfo('当前没有可测试的萌侠事件');
      return;
    }
    final events = status.recentEvents
        .where((event) => _routeMatchesEvent(route, event))
        .toList(growable: false);
    if (events.isEmpty) {
      _showInfo('没有找到匹配 ${_routeDisplayName(route)} 的近期事件');
      return;
    }
    try {
      final result = await widget.forwardingService.forwardRoutedRecentEvents(
        settings: MengxiaMonitorForwardingSettings(
          enabled: true,
          routes: <MengxiaMonitorForwardingRoute>[
            route.copyWith(enabled: true, updatedAt: DateTime.now().toUtc()),
          ],
        ),
        events: events,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _operationResult =
            '测试完成：已转发 ${result.sent} 条，重复跳过 ${result.skippedDuplicate} 条，失败 ${result.failed} 条';
      });
      _showInfo(_operationResult);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _operationResult = '测试失败：$error';
      });
      _showInfo(_operationResult);
    }
  }

  List<MengxiaMonitorForwardingRoute> _replaceRoute(
    List<MengxiaMonitorForwardingRoute> routes,
    MengxiaMonitorForwardingRoute route,
  ) {
    final next = <MengxiaMonitorForwardingRoute>[];
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

  MengxiaMonitorForwardingRoute? _existingRouteForSource(String sourceId) {
    for (final route in _settings.routes) {
      if (route.sourceConversationId.trim() == sourceId) {
        return route;
      }
    }
    return null;
  }

  void _showInfo(String message) {
    if (!mounted) {
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
      title: '萌侠信息转发中心',
      trailing: IconButton(
        key: const ValueKey('mengxia-monitor-refresh-button'),
        onPressed: _loading ? null : _load,
        icon: const Icon(Icons.refresh_rounded, color: WKColors.colorDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusOverview(
              status: status,
              loading: _loading,
              error: _error,
              routes: _settings.routes,
            ),
            const SizedBox(height: WKSpace.sm),
            _QuickActions(
              loading: _loading,
              forwarding: _forwarding,
              autoForwarding: _settings.enabled,
              forwardingResult: _operationResult,
              routeCount: _settings.routes.length,
              onStartCapture: _loading ? null : _startCapture,
              onStopCapture: _loading ? null : _stopCapture,
              onReloadRuntime: _loading ? null : _reloadRuntime,
              onForwardRecentEvents: _forwarding ? null : _forwardRecentEvents,
              onAutoForwardingChanged: _toggleAutoForwarding,
            ),
            const SizedBox(height: WKSpace.sm),
            _ConsoleTabs(
              selected: _selectedTab,
              onChanged: (tab) {
                setState(() {
                  _selectedTab = tab;
                });
              },
            ),
            const SizedBox(height: WKSpace.sm),
            _ConsoleTabBody(
              selected: _selectedTab,
              status: status,
              settings: _settings,
              onConfigureRoute: _configureRouteForConversation,
              onToggleRoute: _toggleRoute,
              onDeleteRoute: _deleteRoute,
              onTestRoute: _testRoute,
              onAutoForwardingChanged: _toggleAutoForwarding,
            ),
          ],
        ),
      ),
    );
  }

  String _routeDisplayName(MengxiaMonitorForwardingRoute route) {
    final source = route.sourceConversationName.trim().isNotEmpty
        ? route.sourceConversationName.trim()
        : route.sourceConversationId.trim();
    final target = route.targetGroupName.trim().isNotEmpty
        ? route.targetGroupName.trim()
        : route.targetGroupId.trim();
    return '$source -> $target';
  }

  String _conversationDisplayName(MengxiaMonitorObservedConversation item) {
    return item.name.trim().isNotEmpty ? item.name.trim() : item.id.trim();
  }

  bool _routeMatchesEvent(
    MengxiaMonitorForwardingRoute route,
    MengxiaMonitorMessageEvent event,
  ) {
    final routeSourceId = route.sourceConversationId.trim();
    if (routeSourceId.isNotEmpty &&
        routeSourceId == event.conversationId.trim()) {
      return true;
    }
    final routeSourceName = route.sourceConversationName.trim();
    return routeSourceName.isNotEmpty &&
        routeSourceName == event.conversationName.trim();
  }

  String _routeIdForConversation(MengxiaMonitorObservedConversation item) {
    final source = item.id.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    return 'route_${source.isEmpty ? DateTime.now().microsecondsSinceEpoch : source}';
  }
}

class _StatusOverview extends StatelessWidget {
  const _StatusOverview({
    required this.status,
    required this.loading,
    required this.error,
    required this.routes,
  });

  final MengxiaMonitorShellStatus? status;
  final bool loading;
  final String error;
  final List<MengxiaMonitorForwardingRoute> routes;

  @override
  Widget build(BuildContext context) {
    final online = status?.isOnline ?? false;
    final loggedIn = status?.loginState == 'logged_in';
    final running = status?.isCapturing ?? false;
    final captured = _effectiveCapturedCount(status);
    final matchedForwardable = _matchedRecentEventCount(status, routes);
    final succeeded = _effectiveSucceededCount(status, routes);
    final failed = status?.deliveriesFailedToday ?? 0;
    return _ConsoleCard(
      title: '状态总览',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 640;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                crossAxisCount: narrow ? 2 : 3,
                mainAxisSpacing: WKSpace.sm,
                crossAxisSpacing: WKSpace.sm,
                childAspectRatio: narrow ? 1.18 : 2.3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MetricTile(
                    label: 'Shell 程序',
                    value: loading
                        ? '加载中'
                        : online
                        ? '在线'
                        : '离线',
                    caption: status?.shellMode ?? 'desktop_shell',
                    tone: online ? _Tone.ok : _Tone.bad,
                  ),
                  _MetricTile(
                    label: '萌侠账号',
                    value: loggedIn ? '已登录' : '需人工登录',
                    caption: loggedIn ? '当前会话有效' : '每次启动重新登录',
                    tone: loggedIn ? _Tone.ok : _Tone.warn,
                  ),
                  _MetricTile(
                    label: '监听状态',
                    value: running ? '监听中' : '已停止',
                    caption: status?.captureState ?? 'stopped',
                    tone: running ? _Tone.ok : _Tone.warn,
                  ),
                  _MetricTile(
                    label: '今日捕获',
                    value: '$captured',
                    caption:
                        '消息 ${status?.observedMessages.length ?? 0}，事件 ${status?.recentEvents.length ?? 0}',
                  ),
                  _MetricTile(
                    label: '今日成功',
                    value: '$succeeded',
                    caption: '匹配可转发 $matchedForwardable',
                    tone: succeeded > 0 ? _Tone.ok : _Tone.neutral,
                  ),
                  _MetricTile(
                    label: '今日失败',
                    value: '$failed',
                    caption: status?.lastError.trim().isNotEmpty == true
                        ? status!.lastError
                        : error.trim().isNotEmpty
                        ? error
                        : '暂无错误',
                    tone: failed > 0 || error.trim().isNotEmpty
                        ? _Tone.bad
                        : _Tone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: WKSpace.sm),
              _NoticeStrip(
                text: '萌侠每次启动都必须人工登录；关闭后不会复用 Cookie、本地存储、历史记录或会话目录。',
              ),
              if (error.trim().isNotEmpty) ...[
                const SizedBox(height: WKSpace.xs),
                _NoticeStrip(text: error, danger: true),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.loading,
    required this.forwarding,
    required this.autoForwarding,
    required this.forwardingResult,
    required this.routeCount,
    required this.onStartCapture,
    required this.onStopCapture,
    required this.onReloadRuntime,
    required this.onForwardRecentEvents,
    required this.onAutoForwardingChanged,
  });

  final bool loading;
  final bool forwarding;
  final bool autoForwarding;
  final String forwardingResult;
  final int routeCount;
  final VoidCallback? onStartCapture;
  final VoidCallback? onStopCapture;
  final VoidCallback? onReloadRuntime;
  final VoidCallback? onForwardRecentEvents;
  final ValueChanged<bool> onAutoForwardingChanged;

  @override
  Widget build(BuildContext context) {
    return _ConsoleCard(
      title: '快捷操作',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '自动转发',
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 13,
              color: WKColors.color999,
            ),
          ),
          const SizedBox(width: WKSpace.xs),
          Switch(
            key: const ValueKey('mengxia-monitor-auto-forward-switch'),
            value: autoForwarding,
            onChanged: loading ? null : onAutoForwardingChanged,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: WKSpace.sm,
            runSpacing: WKSpace.xs,
            children: [
              _ActionButton(
                key: const ValueKey('mengxia-monitor-start-capture-button'),
                label: '启动捕获',
                primary: true,
                onTap: onStartCapture,
              ),
              _ActionButton(
                key: const ValueKey('mengxia-monitor-stop-capture-button'),
                label: '停止捕获',
                onTap: onStopCapture,
              ),
              _ActionButton(
                key: const ValueKey('mengxia-monitor-reload-runtime-button'),
                label: '重载无痕窗口',
                onTap: onReloadRuntime,
              ),
              _ActionButton(
                key: const ValueKey('mengxia-monitor-forward-recent-button'),
                label: forwarding ? '转发中...' : '转发近期事件',
                onTap: onForwardRecentEvents,
              ),
            ],
          ),
          const SizedBox(height: WKSpace.sm),
          _NoticeStrip(text: '只会转发已配置规则的萌侠来源；当前已配置 $routeCount 条规则。'),
          if (forwardingResult.trim().isNotEmpty) ...[
            const SizedBox(height: WKSpace.xs),
            Text(
              forwardingResult,
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 13,
                color: WKColors.colorDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConsoleTabs extends StatelessWidget {
  const _ConsoleTabs({required this.selected, required this.onChanged});

  final _MengxiaConsoleTab selected;
  final ValueChanged<_MengxiaConsoleTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ConsoleCard(
      title: '监控控制台',
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _TabButton(
            label: '运行日志',
            active: selected == _MengxiaConsoleTab.logs,
            onTap: () => onChanged(_MengxiaConsoleTab.logs),
          ),
          _TabButton(
            label: '转发规则',
            active: selected == _MengxiaConsoleTab.rules,
            onTap: () => onChanged(_MengxiaConsoleTab.rules),
          ),
          _TabButton(
            label: '萌侠来源',
            active: selected == _MengxiaConsoleTab.sources,
            onTap: () => onChanged(_MengxiaConsoleTab.sources),
          ),
          _TabButton(
            label: '系统设置',
            active: selected == _MengxiaConsoleTab.settings,
            onTap: () => onChanged(_MengxiaConsoleTab.settings),
          ),
        ],
      ),
    );
  }
}

class _ConsoleTabBody extends StatelessWidget {
  const _ConsoleTabBody({
    required this.selected,
    required this.status,
    required this.settings,
    required this.onConfigureRoute,
    required this.onToggleRoute,
    required this.onDeleteRoute,
    required this.onTestRoute,
    required this.onAutoForwardingChanged,
  });

  final _MengxiaConsoleTab selected;
  final MengxiaMonitorShellStatus? status;
  final MengxiaMonitorForwardingSettings settings;
  final ValueChanged<MengxiaMonitorObservedConversation> onConfigureRoute;
  final ValueChanged<MengxiaMonitorForwardingRoute> onToggleRoute;
  final ValueChanged<MengxiaMonitorForwardingRoute> onDeleteRoute;
  final ValueChanged<MengxiaMonitorForwardingRoute> onTestRoute;
  final ValueChanged<bool> onAutoForwardingChanged;

  @override
  Widget build(BuildContext context) {
    return switch (selected) {
      _MengxiaConsoleTab.logs => _LogsTab(status: status),
      _MengxiaConsoleTab.rules => _RulesTab(
        routes: settings.routes,
        onToggleRoute: onToggleRoute,
        onDeleteRoute: onDeleteRoute,
        onTestRoute: onTestRoute,
      ),
      _MengxiaConsoleTab.sources => _SourcesTab(
        status: status,
        routes: settings.routes,
        onConfigureRoute: onConfigureRoute,
      ),
      _MengxiaConsoleTab.settings => _SettingsTab(
        status: status,
        settings: settings,
        onAutoForwardingChanged: onAutoForwardingChanged,
      ),
    };
  }
}

class _LogsTab extends StatelessWidget {
  const _LogsTab({required this.status});

  final MengxiaMonitorShellStatus? status;

  @override
  Widget build(BuildContext context) {
    final events =
        status?.recentEvents.take(30).toList(growable: false) ??
        const <MengxiaMonitorMessageEvent>[];
    final emptyText = status?.needsManualLogin ?? true
        ? '等待人工登录并进入萌侠会话后开始观察事件。'
        : '已登录萌侠，暂无可转发事件。请保持 MX 信息监控窗口打开，系统会继续监听已配置来源。';
    return _ConsoleCard(
      title: '运行日志',
      trailing: Text(
        '最近 ${events.length} 条',
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 12,
          color: WKColors.color999,
        ),
      ),
      child: events.isEmpty
          ? _EmptyState(text: emptyText)
          : _TerminalPanel(
              children: [
                for (final event in events)
                  _TerminalLine(
                    time: _formatTime(event.observedAt),
                    level: event.isForwardable ? '捕获' : '跳过',
                    source: _eventConversationName(event),
                    message: _eventPreview(event),
                  ),
              ],
            ),
    );
  }
}

class _RulesTab extends StatelessWidget {
  const _RulesTab({
    required this.routes,
    required this.onToggleRoute,
    required this.onDeleteRoute,
    required this.onTestRoute,
  });

  final List<MengxiaMonitorForwardingRoute> routes;
  final ValueChanged<MengxiaMonitorForwardingRoute> onToggleRoute;
  final ValueChanged<MengxiaMonitorForwardingRoute> onDeleteRoute;
  final ValueChanged<MengxiaMonitorForwardingRoute> onTestRoute;

  @override
  Widget build(BuildContext context) {
    return _ConsoleCard(
      title: '转发规则',
      trailing: Text(
        '已配置 ${routes.length} 条',
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 12,
          color: WKColors.color999,
        ),
      ),
      child: routes.isEmpty
          ? const _EmptyState(text: '暂无转发规则。请到“萌侠来源”里为来源会话配置悟空目标群。')
          : _WidgetDataTable(
              columns: const ['规则名称', '来源萌侠会话', '目标悟空IM群', '状态', '操作'],
              rows: [
                for (final route in routes)
                  [
                    _tableText(_routeDisplayName(route)),
                    _tableText(
                      route.sourceConversationName.trim().isNotEmpty
                          ? route.sourceConversationName.trim()
                          : route.sourceConversationId.trim(),
                    ),
                    _tableText(
                      route.targetGroupName.trim().isNotEmpty
                          ? route.targetGroupName.trim()
                          : route.targetGroupId.trim(),
                    ),
                    _StatusPill(
                      text: route.enabled ? '启用' : '停用',
                      tone: route.enabled ? _Tone.ok : _Tone.warn,
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        _TableActionButton(
                          key: ValueKey('mengxia-route-toggle-${route.id}'),
                          label: route.enabled ? '停用' : '启用',
                          onTap: () => onToggleRoute(route),
                        ),
                        _TableActionButton(
                          key: ValueKey('mengxia-route-test-${route.id}'),
                          label: '测试',
                          onTap: () => onTestRoute(route),
                        ),
                        _TableActionButton(
                          key: ValueKey('mengxia-route-delete-${route.id}'),
                          label: '删除',
                          danger: true,
                          onTap: () => onDeleteRoute(route),
                        ),
                      ],
                    ),
                  ],
              ],
            ),
    );
  }
}

class _SourcesTab extends StatelessWidget {
  const _SourcesTab({
    required this.status,
    required this.routes,
    required this.onConfigureRoute,
  });

  final MengxiaMonitorShellStatus? status;
  final List<MengxiaMonitorForwardingRoute> routes;
  final ValueChanged<MengxiaMonitorObservedConversation> onConfigureRoute;

  @override
  Widget build(BuildContext context) {
    final conversations =
        status?.observedConversations ??
        const <MengxiaMonitorObservedConversation>[];
    return _ConsoleCard(
      title: '萌侠来源',
      trailing: Text(
        '已观察 ${conversations.length} 个',
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 12,
          color: WKColors.color999,
        ),
      ),
      child: conversations.isEmpty
          ? const _EmptyState(text: '登录萌侠后，系统会在这里列出当前可见的群和会话。')
          : _WidgetDataTable(
              columns: const ['聊天类型', '来源名称', '萌侠来源 ID', '最近消息', '转发状态', '操作'],
              rows: [
                for (final conversation in conversations)
                  [
                    _tableText(_conversationTypeLabel(conversation.type)),
                    _tableText(_conversationDisplayName(conversation)),
                    _tableText(conversation.id),
                    _tableText(
                      conversation.lastMessagePreview.trim().isEmpty
                          ? '暂无预览'
                          : conversation.lastMessagePreview.trim(),
                    ),
                    _StatusPill(
                      text:
                          _existingRouteForConversation(routes, conversation) ==
                              null
                          ? '未配置'
                          : '已配置',
                      tone:
                          _existingRouteForConversation(routes, conversation) ==
                              null
                          ? _Tone.warn
                          : _Tone.ok,
                    ),
                    _SmallButton(
                      key: ValueKey(
                        'mengxia-route-configure-${conversation.id}',
                      ),
                      label:
                          _existingRouteForConversation(routes, conversation) ==
                              null
                          ? '配置转发'
                          : '修改目标',
                      primary: true,
                      onTap: () => onConfigureRoute(conversation),
                    ),
                  ],
              ],
            ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.status,
    required this.settings,
    required this.onAutoForwardingChanged,
  });

  final MengxiaMonitorShellStatus? status;
  final MengxiaMonitorForwardingSettings settings;
  final ValueChanged<bool> onAutoForwardingChanged;

  @override
  Widget build(BuildContext context) {
    return _ConsoleCard(
      title: '系统设置',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;
          final shellSettings = _SettingsPanel(
            title: '本地 Shell 程序',
            rows: [
              _FormLine('端口', '18786'),
              _FormLine('Token', 'wukong-mengxia-shell-dev'),
              _FormLine('登录策略', '每次人工登录'),
              _FormLine('无痕策略', '不复用 Cookie / LocalStorage / 会话目录'),
              _FormLine('页面状态', status?.pageKind ?? '未知'),
            ],
          );
          final forwardingSettings = _SettingsPanel(
            title: '转发策略',
            rows: [
              _FormLine.custom(
                '自动转发',
                Switch(
                  key: const ValueKey('mengxia-settings-auto-forward-switch'),
                  value: settings.enabled,
                  onChanged: onAutoForwardingChanged,
                ),
              ),
              const _FormLine('转发范围', '仅已配置来源会话'),
              const _FormLine('投递通道', '悟空内部群'),
              const _FormLine('图片转发', '支持可解析图片源'),
              _FormLine('转发规则', '已配置 ${settings.routes.length} 条'),
            ],
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shellSettings,
                const SizedBox(height: WKSpace.sm),
                forwardingSettings,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: shellSettings),
              const SizedBox(width: WKSpace.sm),
              Expanded(child: forwardingSettings),
            ],
          );
        },
      ),
    );
  }
}

class _ConsoleCard extends StatelessWidget {
  const _ConsoleCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.lg),
        boxShadow: WKShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WKSpace.lg,
              WKSpace.md,
              WKSpace.lg,
              WKSpace.sm,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final titleWidget = Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: WKColors.colorDark,
                  ),
                );
                final trailingWidget = trailing;
                if (trailingWidget == null) {
                  return titleWidget;
                }
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      const SizedBox(height: WKSpace.xs),
                      trailingWidget,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: WKSpace.sm),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: trailingWidget,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: WKColors.borderColor),
          Padding(padding: const EdgeInsets.all(WKSpace.lg), child: child),
        ],
      ),
    );
  }
}

enum _Tone { neutral, ok, warn, bad }

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.caption = '',
    this.tone = _Tone.neutral,
  });

  final String label;
  final String value;
  final String caption;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _Tone.ok => WKColors.success,
      _Tone.warn => WKColors.warning,
      _Tone.bad => WKColors.danger,
      _Tone.neutral => WKColors.colorDark,
    };
    return Container(
      padding: const EdgeInsets.all(WKSpace.sm),
      decoration: BoxDecoration(
        color: WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 12,
              color: WKColors.color999,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 12,
                color: WKColors.color999,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoticeStrip extends StatelessWidget {
  const _NoticeStrip({required this.text, this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: WKSpace.sm,
        vertical: WKSpace.xs,
      ),
      decoration: BoxDecoration(
        color: danger
            ? WKColors.danger.withValues(alpha: 0.08)
            : WKColors.brand500.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WKRadius.md),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 13,
          height: 1.35,
          color: danger ? WKColors.danger : WKColors.colorDark,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final background = primary ? WKColors.brand500 : WKColors.surfaceSoft;
    final foreground = primary ? WKColors.white : WKColors.colorDark;
    return SizedBox(
      height: 40,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WKRadius.md),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: WKFontFamily.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: active
            ? WKColors.brand500.withValues(alpha: 0.10)
            : Colors.transparent,
        foregroundColor: active ? WKColors.brand500 : WKColors.textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WKRadius.md),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WKSpace.lg),
      decoration: BoxDecoration(
        color: WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.md),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 13,
          color: WKColors.color999,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.tone});

  final String text;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _Tone.ok => WKColors.success,
      _Tone.warn => WKColors.warning,
      _Tone.bad => WKColors.danger,
      _Tone.neutral => WKColors.color999,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(WKRadius.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    super.key,
    required this.label,
    this.primary = false,
    this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: primary ? WKColors.brand500 : WKColors.surfaceSoft,
          foregroundColor: primary ? WKColors.white : WKColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WKRadius.sm),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: WKFontFamily.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: primary ? WKColors.white : WKColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TableActionButton extends StatelessWidget {
  const _TableActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        foregroundColor: danger ? WKColors.danger : WKColors.brand500,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 160),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(WKRadius.md),
      ),
      padding: const EdgeInsets.symmetric(vertical: WKSpace.xs),
      child: Column(children: children),
    );
  }
}

class _TerminalLine extends StatelessWidget {
  const _TerminalLine({
    required this.time,
    required this.level,
    required this.source,
    required this.message,
  });

  final String time;
  final String level;
  final String source;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(time, style: _terminalStyle(const Color(0xFF9AA6B8))),
          ),
          SizedBox(
            width: 46,
            child: Text(level, style: _terminalStyle(WKColors.success)),
          ),
          SizedBox(
            width: 112,
            child: Text(
              source,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _terminalStyle(const Color(0xFF7EB6FF)),
            ),
          ),
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _terminalStyle(const Color(0xFFE4ECF7)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetDataTable extends StatelessWidget {
  const _WidgetDataTable({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    return _HorizontalTableScroll(
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 64,
        columns: [
          for (final column in columns)
            DataColumn(
              label: Text(
                column,
                style: const TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: WKColors.color999,
                ),
              ),
            ),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                for (final cell in row)
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: cell,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HorizontalTableScroll extends StatefulWidget {
  const _HorizontalTableScroll({required this.child});

  final Widget child;

  @override
  State<_HorizontalTableScroll> createState() => _HorizontalTableScrollState();
}

class _HorizontalTableScrollState extends State<_HorizontalTableScroll> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      interactive: true,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        primary: false,
        padding: const EdgeInsets.only(bottom: 12),
        child: widget.child,
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.title, required this.rows});

  final String title;
  final List<_FormLine> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WKSpace.md),
      decoration: BoxDecoration(
        color: WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: WKSpace.sm),
          for (final row in rows) _SettingsRow(row: row),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.row});

  final _FormLine row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: WKSpace.sm),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              row.label,
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 13,
                color: WKColors.color999,
              ),
            ),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 34),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: WKColors.surface,
                borderRadius: BorderRadius.circular(WKRadius.sm),
              ),
              child:
                  row.child ??
                  Text(
                    row.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: WKFontFamily.primary,
                      fontSize: 13,
                      color: WKColors.colorDark,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormLine {
  const _FormLine(this.label, this.value) : child = null;
  const _FormLine.custom(this.label, this.child) : value = '';

  final String label;
  final String value;
  final Widget? child;
}

Widget _tableText(String text) {
  return Text(
    text.trim().isEmpty ? '-' : text.trim(),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontFamily: WKFontFamily.primary,
      fontSize: 13,
      color: WKColors.colorDark,
    ),
  );
}

TextStyle _terminalStyle(Color color) {
  return TextStyle(
    fontFamily: 'Consolas',
    fontSize: 12,
    color: color,
    height: 1.2,
  );
}

int _effectiveCapturedCount(MengxiaMonitorShellStatus? status) {
  if (status == null) {
    return 0;
  }
  if (status.messagesToday > 0) {
    return status.messagesToday;
  }
  return status.recentEvents.length > status.observedMessages.length
      ? status.recentEvents.length
      : status.observedMessages.length;
}

int _effectiveSucceededCount(
  MengxiaMonitorShellStatus? status,
  List<MengxiaMonitorForwardingRoute> routes,
) {
  if (status == null) {
    return 0;
  }
  if (status.deliveriesSucceededToday > 0) {
    return status.deliveriesSucceededToday;
  }
  return _matchedRecentEventCount(status, routes);
}

int _matchedRecentEventCount(
  MengxiaMonitorShellStatus? status,
  List<MengxiaMonitorForwardingRoute> routes,
) {
  if (status == null || routes.isEmpty) {
    return 0;
  }
  var count = 0;
  for (final event in status.recentEvents) {
    if (!event.isForwardable) {
      continue;
    }
    if (findMengxiaMonitorRouteForEvent(routes: routes, event: event) != null) {
      count += 1;
    }
  }
  return count;
}

String _routeDisplayName(MengxiaMonitorForwardingRoute route) {
  final source = route.sourceConversationName.trim().isNotEmpty
      ? route.sourceConversationName.trim()
      : route.sourceConversationId.trim();
  final target = route.targetGroupName.trim().isNotEmpty
      ? route.targetGroupName.trim()
      : route.targetGroupId.trim();
  return '$source -> $target';
}

String _conversationDisplayName(MengxiaMonitorObservedConversation item) {
  return item.name.trim().isNotEmpty ? item.name.trim() : item.id.trim();
}

String _eventConversationName(MengxiaMonitorMessageEvent event) {
  return event.conversationName.trim().isNotEmpty
      ? event.conversationName.trim()
      : event.conversationId.trim();
}

String _eventPreview(MengxiaMonitorMessageEvent event) {
  if (event.text.trim().isNotEmpty) {
    return event.text.trim();
  }
  if (event.hasForwardableImage) {
    return '[图片]';
  }
  return '(空消息)';
}

String _formatTime(DateTime? value) {
  if (value == null) {
    return '--:--:--';
  }
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _conversationTypeLabel(String type) {
  final normalized = type.trim().toLowerCase();
  if (normalized.contains('dm') || normalized.contains('single')) {
    return '单聊';
  }
  if (normalized.contains('bot') || normalized.contains('robot')) {
    return '机器人';
  }
  return '群聊';
}

MengxiaMonitorForwardingRoute? _existingRouteForConversation(
  List<MengxiaMonitorForwardingRoute> routes,
  MengxiaMonitorObservedConversation conversation,
) {
  for (final route in routes) {
    if (route.sourceConversationId.trim() == conversation.id.trim()) {
      return route;
    }
  }
  return null;
}

class _MengxiaTargetGroupPicker extends StatefulWidget {
  const _MengxiaTargetGroupPicker({required this.loadGroups});

  final MengxiaMonitorTargetGroupLoader loadGroups;

  @override
  State<_MengxiaTargetGroupPicker> createState() =>
      _MengxiaTargetGroupPickerState();
}

class _MengxiaTargetGroupPickerState extends State<_MengxiaTargetGroupPicker> {
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
            final selectableGroups =
                snapshot.data
                    ?.where(_isSelectableTargetGroup)
                    .toList(growable: false) ??
                const <GroupInfo>[];
            final groups = _filterGroups(selectableGroups, _query);
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
                  '萌侠消息只会转发到这里选择的悟空内部群。',
                  style: TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 13,
                    color: WKColors.color999,
                  ),
                ),
                const SizedBox(height: WKSpace.md),
                TextField(
                  key: const ValueKey('mengxia-target-group-search-field'),
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
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
                  Text(
                    selectableGroups.isEmpty ? '暂无可选择的悟空群。' : '没有匹配的悟空群。',
                    style: const TextStyle(color: WKColors.color999),
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
                          key: ValueKey(
                            'mengxia-target-group-${group.groupNo}',
                          ),
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
