import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../data/models/group.dart';
import '../../core/platform/local_image_picker.dart';
import '../../service/api/file_api.dart';
import '../../service/api/group_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'feishu_monitor_forwarding_service.dart';
import 'feishu_monitor_shell_client.dart';
import 'feishu_monitor_shell_models.dart';
import 'feishu_monitor_worker_config.dart';

enum _ConsoleTab { logs, rules, groups, images, settings }

typedef FeishuMonitorTargetGroupLoader = Future<List<GroupInfo>> Function();
typedef FeishuMonitorRelayAvatarPicker = Future<String?> Function();
typedef FeishuMonitorRelayAvatarUploader =
    Future<String> Function(String filePath);

Future<String?> _pickDefaultRelayAvatarImage() {
  return pickSingleLocalImagePath(
    imageQuality: 85,
    maxWidth: 512,
    maxHeight: 512,
  );
}

Future<String> _uploadDefaultRelayAvatarImage(String filePath) {
  final extension = path.extension(filePath.trim()).toLowerCase();
  final safeExtension = RegExp(r'^\.[a-z0-9]{1,16}$').hasMatch(extension)
      ? extension
      : '.png';
  final uploadPath =
      '/feishu-relay-avatar/${DateTime.now().millisecondsSinceEpoch}$safeExtension';
  return FileApi.instance.uploadCommonImage(
    filePath: filePath,
    uploadPath: uploadPath,
  );
}

class FeishuMonitorCenterPage extends StatefulWidget {
  FeishuMonitorCenterPage({
    super.key,
    FeishuMonitorShellClient? client,
    FeishuMonitorForwardingService? forwardingService,
    FeishuMonitorForwardingSettingsStore? forwardingSettingsStore,
    FeishuMonitorTargetGroupLoader? loadTargetGroups,
    FeishuMonitorRelayAvatarPicker? pickRelayAvatarImage,
    FeishuMonitorRelayAvatarUploader? uploadRelayAvatarImage,
  }) : client = client ?? _DefaultFeishuMonitorShellClient(),
       forwardingService =
           forwardingService ?? FeishuMonitorForwardingService(),
       forwardingSettingsStore =
           forwardingSettingsStore ??
           const SharedPreferencesFeishuMonitorForwardingSettingsStore(),
       loadTargetGroups = loadTargetGroups ?? GroupApi.instance.getMyGroups,
       pickRelayAvatarImage =
           pickRelayAvatarImage ?? _pickDefaultRelayAvatarImage,
       uploadRelayAvatarImage =
           uploadRelayAvatarImage ?? _uploadDefaultRelayAvatarImage;

  final FeishuMonitorShellClient client;
  final FeishuMonitorForwardingService forwardingService;
  final FeishuMonitorForwardingSettingsStore forwardingSettingsStore;
  final FeishuMonitorTargetGroupLoader loadTargetGroups;
  final FeishuMonitorRelayAvatarPicker pickRelayAvatarImage;
  final FeishuMonitorRelayAvatarUploader uploadRelayAvatarImage;

  @override
  State<FeishuMonitorCenterPage> createState() =>
      _FeishuMonitorCenterPageState();
}

class _FeishuMonitorCenterPageState extends State<FeishuMonitorCenterPage> {
  FeishuMonitorShellStatus? _status;
  _ConsoleTab _selectedTab = _ConsoleTab.logs;
  bool _loading = true;
  bool _forwarding = false;
  FeishuMonitorForwardingSettings _forwardingSettings =
      const FeishuMonitorForwardingSettings(
        enabled: false,
        routes: <FeishuMonitorForwardingRoute>[],
        legacyTargetGroupId: '',
      );
  String _error = '';
  String _forwardingResult = '';

  @override
  void initState() {
    super.initState();
    _loadForwardingSettings();
    _refresh();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadForwardingSettings() async {
    final settings = await widget.forwardingSettingsStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _forwardingSettings = settings;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final status = await widget.client.fetchStatus();
      if (!mounted) {
        return;
      }
      setState(() {
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

  Future<void> _runQuickAction({
    required String runningMessage,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    if (mounted) {
      setState(() {
        _forwardingResult = runningMessage;
      });
    }
    try {
      await action();
      await _refresh();
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardingResult = successMessage;
      });
      _showInfo(successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = '操作失败：$error';
      setState(() {
        _forwardingResult = message;
      });
      _showInfo(message);
    }
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

  Future<void> _saveForwardingSettings(
    FeishuMonitorForwardingSettings settings,
  ) async {
    if (mounted) {
      setState(() {
        _forwardingSettings = settings;
      });
    } else {
      _forwardingSettings = settings;
    }
    await widget.forwardingSettingsStore.save(settings);
  }

  Future<void> _configureRouteForConversation(
    FeishuMonitorObservedConversation conversation,
  ) async {
    final sourceConversationId = conversation.id.trim();
    final existing = _existingRouteForSource(sourceConversationId);
    final selected = await showModalBottomSheet<_RouteConfigurationDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: WKColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(WKRadius.lg)),
      ),
      builder: (context) {
        return _TargetGroupPicker(
          loadGroups: widget.loadTargetGroups,
          pickRelayAvatarImage: widget.pickRelayAvatarImage,
          uploadRelayAvatarImage: widget.uploadRelayAvatarImage,
          initialRelayDisplayName: existing?.relayDisplayName ?? '',
          initialRelayAvatar: existing?.relayAvatar ?? '',
        );
      },
    );
    if (selected == null || !mounted) {
      return;
    }

    final now = DateTime.now().toUtc();
    final group = selected.group;
    final targetGroupName = await _resolveTargetGroupTitle(group);
    if (!mounted) {
      return;
    }
    final route = FeishuMonitorForwardingRoute(
      id: existing?.id ?? _routeIdForConversation(conversation),
      enabled: existing?.enabled ?? true,
      sourceConversationId: sourceConversationId,
      sourceConversationName: conversation.name.trim(),
      sourceConversationType: conversation.type.trim(),
      targetGroupId: group.groupNo,
      targetGroupName: targetGroupName,
      workerId: existing?.workerId.trim().isNotEmpty == true
          ? existing!.workerId
          : _workerIdForNewRoute(),
      relayDisplayName: selected.relayDisplayName,
      relayAvatar: selected.relayAvatar,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final routes =
        _forwardingSettings.routes
            .where(
              (item) =>
                  item.sourceConversationId.trim() != sourceConversationId,
            )
            .toList(growable: true)
          ..add(route);
    final next = _forwardingSettings.copyWith(routes: routes);
    await _saveForwardingSettings(next);
    _showInfo('已保存 ${route.sourceConversationName} 的转发目标');
  }

  Future<void> _addForwardingRoute() async {
    final candidate = _firstUnconfiguredConversation();
    final route = await _showRouteEditor(
      title: '新增转发规则',
      conversation: candidate,
    );
    if (route == null || !mounted) {
      return;
    }
    final routes = _replaceRoute(_forwardingSettings.routes, route);
    await _saveForwardingSettings(_forwardingSettings.copyWith(routes: routes));
    _showInfo('已新增规则 ${_routeDisplayName(route)}');
  }

  Future<void> _editForwardingRoute(FeishuMonitorForwardingRoute route) async {
    final updated = await _showRouteEditor(title: '编辑转发规则', route: route);
    if (updated == null || !mounted) {
      return;
    }
    final routes = _replaceRoute(_forwardingSettings.routes, updated);
    await _saveForwardingSettings(_forwardingSettings.copyWith(routes: routes));
    _showInfo('已更新规则 ${_routeDisplayName(updated)}');
  }

  Future<void> _deleteForwardingRoute(
    FeishuMonitorForwardingRoute route,
  ) async {
    final routes = _forwardingSettings.routes
        .where((item) => item.id != route.id)
        .toList(growable: false);
    await _saveForwardingSettings(_forwardingSettings.copyWith(routes: routes));
    _showInfo('已删除规则 ${_routeDisplayName(route)}');
  }

  Future<void> _testForwardingRoute(FeishuMonitorForwardingRoute route) async {
    final status = _status;
    if (status == null) {
      _showInfo('当前没有可测试的飞书事件');
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
        settings: _forwardingSettings.copyWith(
          enabled: true,
          routes: <FeishuMonitorForwardingRoute>[
            route.copyWith(enabled: true, updatedAt: DateTime.now().toUtc()),
          ],
        ),
        events: events,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardingResult =
            '测试完成：已转发 ${result.sent} 条，重复跳过 ${result.skippedDuplicate} 条，失败 ${result.failed} 条';
      });
      _showInfo(_forwardingResult);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardingResult = '测试失败：$error';
      });
      _showInfo(_forwardingResult);
    }
  }

  Future<void> _copyRouteImportTemplate() async {
    final template = [
      'source_conversation_id,source_conversation_name,target_group_id,target_group_name,enabled',
      'feed:example,飞书来源群,wk_target,悟空目标群,true',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: template));
    _showInfo('导入模板已复制到剪贴板');
  }

  Future<void> _showBatchImportDialog() async {
    final imported = await showDialog<List<FeishuMonitorForwardingRoute>>(
      context: context,
      builder: (context) => const _BatchImportDialog(),
    );
    if (imported == null || imported.isEmpty || !mounted) {
      return;
    }
    var routes = List<FeishuMonitorForwardingRoute>.from(
      _forwardingSettings.routes,
    );
    for (final route in imported) {
      routes = _replaceRoute(routes, route);
    }
    await _saveForwardingSettings(_forwardingSettings.copyWith(routes: routes));
    _showInfo('已导入 ${imported.length} 条转发规则');
  }

  Future<FeishuMonitorForwardingRoute?> _showRouteEditor({
    required String title,
    FeishuMonitorForwardingRoute? route,
    FeishuMonitorObservedConversation? conversation,
  }) {
    return showDialog<FeishuMonitorForwardingRoute>(
      context: context,
      builder: (context) {
        return _RouteEditorDialog(
          title: title,
          route: route,
          conversation: conversation,
          sourceConversations:
              _status?.observedConversations ??
              const <FeishuMonitorObservedConversation>[],
          loadTargetGroups: widget.loadTargetGroups,
          workerId: route?.workerId.trim().isNotEmpty == true
              ? route!.workerId
              : _workerIdForNewRoute(),
        );
      },
    );
  }

  FeishuMonitorObservedConversation? _firstUnconfiguredConversation() {
    final conversations =
        _status?.observedConversations ??
        const <FeishuMonitorObservedConversation>[];
    for (final conversation in conversations) {
      if (_existingRouteForSource(conversation.id.trim()) == null) {
        return conversation;
      }
    }
    return conversations.isEmpty ? null : conversations.first;
  }

  List<FeishuMonitorForwardingRoute> _replaceRoute(
    List<FeishuMonitorForwardingRoute> routes,
    FeishuMonitorForwardingRoute route,
  ) {
    final next = <FeishuMonitorForwardingRoute>[];
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

  FeishuMonitorForwardingRoute? _existingRouteForSource(String sourceId) {
    for (final route in _forwardingSettings.routes) {
      if (route.sourceConversationId.trim() == sourceId) {
        return route;
      }
    }
    return null;
  }

  String _workerIdForNewRoute() {
    final workers = FeishuMonitorWorkerConfig.recommendedForRouteCount(
      _forwardingSettings.routes.length + 1,
    );
    return workerIdForRouteIndex(_forwardingSettings.routes.length, workers);
  }

  Future<void> _forwardRecentEvents() async {
    final status = _status;
    if (status == null || _forwarding) {
      return;
    }
    setState(() {
      _forwarding = true;
      _forwardingResult = '';
    });
    try {
      final manualForwardingSettings = _forwardingSettings.copyWith(
        enabled: true,
      );
      final result = await widget.forwardingService.forwardRoutedRecentEvents(
        settings: manualForwardingSettings,
        events: status.recentEvents,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardingResult =
            '已转发 ${result.sent} 条，重复跳过 ${result.skippedDuplicate} 条，未匹配 ${result.skippedUnmatched} 条，停用跳过 ${result.skippedDisabled} 条，失败 ${result.failed} 条';
      });
      await _saveForwardingSettings(_forwardingSettings);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardingResult = '转发失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _forwarding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return WKSubPageScaffold(
      title: '飞书信息转发中心',
      trailing: IconButton(
        key: const ValueKey('feishu-monitor-refresh-button'),
        onPressed: _loading ? null : _refresh,
        icon: const Icon(Icons.refresh_rounded, color: WKColors.colorDark),
        tooltip: '刷新',
      ),
      trailingWidth: 48,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusOverview(
              status: status,
              loading: _loading,
              error: _error,
              routes: _forwardingSettings.routes,
            ),
            _WorkerDiagnostics(
              status: status,
              routeCount: _forwardingSettings.routes.length,
            ),
            const SizedBox(height: WKSpace.sm),
            _QuickActions(
              loading: _loading,
              forwarding: _forwarding,
              autoForwarding: _forwardingSettings.enabled,
              forwardingResult: _forwardingResult,
              routeCount: _forwardingSettings.routes.length,
              onStartCapture: _loading
                  ? null
                  : () => _runQuickAction(
                      runningMessage: '正在启动飞书转发...',
                      successMessage: '已启动飞书转发',
                      action: widget.client.startCapture,
                    ),
              onStopCapture: _loading
                  ? null
                  : () => _runQuickAction(
                      runningMessage: '正在停止飞书转发...',
                      successMessage: '已停止飞书转发',
                      action: widget.client.stopCapture,
                    ),
              onReloadRuntime: _loading
                  ? null
                  : () => _runQuickAction(
                      runningMessage: '正在重新加载飞书...',
                      successMessage: '已重新加载飞书',
                      action: widget.client.reloadRuntime,
                    ),
              onForwardRecentEvents: _forwarding ? null : _forwardRecentEvents,
              onAutoForwardingChanged: (value) async {
                final nextSettings = _forwardingSettings.copyWith(
                  enabled: value,
                );
                await _saveForwardingSettings(nextSettings);
              },
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
              forwardingSettings: _forwardingSettings,
              onConfigureRoute: _configureRouteForConversation,
              onRefreshGroups: _loading ? null : _refresh,
              onAddRoute: _addForwardingRoute,
              onEditRoute: _editForwardingRoute,
              onDeleteRoute: _deleteForwardingRoute,
              onTestRoute: _testForwardingRoute,
              onDownloadTemplate: _copyRouteImportTemplate,
              onBatchImport: _showBatchImportDialog,
              onSaveImageSettings: () => _showInfo('图片处理设置已保存'),
              onSaveSystemSettings: _saveForwardingSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultFeishuMonitorShellClient extends FeishuMonitorShellClient {
  _DefaultFeishuMonitorShellClient() : super();
}

class _StatusOverview extends StatelessWidget {
  const _StatusOverview({
    required this.status,
    required this.loading,
    required this.error,
    required this.routes,
  });

  final FeishuMonitorShellStatus? status;
  final bool loading;
  final String error;
  final List<FeishuMonitorForwardingRoute> routes;

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
          return GridView.count(
            crossAxisCount: narrow ? 2 : 3,
            mainAxisSpacing: WKSpace.sm,
            crossAxisSpacing: WKSpace.sm,
            childAspectRatio: narrow ? 1.2 : 2.25,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _MetricTile(
                label: 'Shell 程序',
                value: loading
                    ? '连接中'
                    : online
                    ? '在线'
                    : '离线',
                tone: online ? _Tone.ok : _Tone.warn,
                caption: status?.shellMode ?? 'service',
              ),
              _MetricTile(
                label: '飞书账号',
                value: loggedIn ? '已登录' : '需扫码',
                tone: loggedIn ? _Tone.ok : _Tone.warn,
                caption: status?.pageTitle.trim().isNotEmpty == true
                    ? status!.pageTitle
                    : '等待页面信息',
              ),
              _MetricTile(
                label: '监听状态',
                value: running ? '运行中' : status?.captureState ?? '未知',
                tone: running ? _Tone.ok : _Tone.warn,
                caption: status?.pageKind.trim().isNotEmpty == true
                    ? status!.pageKind
                    : 'unknown',
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
                tone: _Tone.ok,
                caption: matchedForwardable > 0
                    ? '匹配可转发 $matchedForwardable'
                    : '投递成功',
              ),
              _MetricTile(
                label: '今日失败',
                value: '$failed',
                tone: failed > 0 ? _Tone.bad : _Tone.ok,
                caption: error.isNotEmpty
                    ? error
                    : (status?.lastError.trim().isNotEmpty == true
                          ? status!.lastError
                          : '无错误'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WorkerDiagnostics extends StatelessWidget {
  const _WorkerDiagnostics({required this.status, required this.routeCount});

  final FeishuMonitorShellStatus? status;
  final int routeCount;

  @override
  Widget build(BuildContext context) {
    final currentStatus = status;
    final warning = _workerCapacityWarning(routeCount);
    if (currentStatus == null && warning.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: WKSpace.sm),
      child: _ConsoleCard(
        title: 'Worker diagnostics',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (warning.isNotEmpty) ...[
              _StatusWarning(message: warning),
              const SizedBox(height: WKSpace.sm),
            ],
            Wrap(
              spacing: WKSpace.sm,
              runSpacing: WKSpace.sm,
              children: [
                _DiagnosticPill(
                  label: 'Worker',
                  value: currentStatus?.workerId ?? 'worker-1',
                ),
                _DiagnosticPill(
                  label: 'Media queue',
                  value: '${currentStatus?.mediaQueueDepth ?? 0}',
                ),
                _DiagnosticPill(
                  label: 'Oldest wait',
                  value: '${currentStatus?.mediaQueueOldestWaitSeconds ?? 0}s',
                ),
                _DiagnosticPill(
                  label: 'Next delay',
                  value:
                      '${currentStatus?.mediaQueueEstimatedNextDelaySeconds ?? 0}s',
                ),
                if (currentStatus?.mediaQueueLastSkipReason.trim().isNotEmpty ==
                    true)
                  _DiagnosticPill(
                    label: 'Last skip',
                    value: currentStatus!.mediaQueueLastSkipReason,
                    warn: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusWarning extends StatelessWidget {
  const _StatusWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: WKSpace.sm,
        vertical: WKSpace.xs,
      ),
      decoration: BoxDecoration(
        color: WKColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WKRadius.sm),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: WKColors.warning,
        ),
      ),
    );
  }
}

class _DiagnosticPill extends StatelessWidget {
  const _DiagnosticPill({
    required this.label,
    required this.value,
    this.warn = false,
  });

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: warn
            ? WKColors.warning.withValues(alpha: 0.08)
            : WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.sm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 11,
              color: WKColors.color999,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: warn ? WKColors.warning : WKColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

int _effectiveCapturedCount(FeishuMonitorShellStatus? status) {
  if (status == null) {
    return 0;
  }
  final observed = status.observedMessages.length;
  final recent = status.recentEvents.length;
  final reported = status.messagesToday;
  return [reported, observed, recent].reduce((a, b) => a > b ? a : b);
}

int _effectiveSucceededCount(
  FeishuMonitorShellStatus? status,
  List<FeishuMonitorForwardingRoute> routes,
) {
  final reported = status?.deliveriesSucceededToday ?? 0;
  final matched = _matchedRecentEventCount(status, routes);
  return reported > matched ? reported : matched;
}

int _matchedRecentEventCount(
  FeishuMonitorShellStatus? status,
  List<FeishuMonitorForwardingRoute> routes,
) {
  if (status == null || routes.isEmpty) {
    return 0;
  }
  return status.recentEvents
      .where(
        (event) => routes.any(
          (route) => route.enabled && _routeMatchesEvent(route, event),
        ),
      )
      .length;
}

int _routeMatchedRecentEventCount(
  FeishuMonitorShellStatus? status,
  FeishuMonitorForwardingRoute route,
) {
  if (status == null) {
    return 0;
  }
  return status.recentEvents
      .where((event) => _routeMatchesEvent(route, event))
      .length;
}

bool _routeMatchesEvent(
  FeishuMonitorForwardingRoute route,
  FeishuMonitorMessageEvent event,
) {
  final routeId = route.sourceConversationId.trim();
  final eventId = event.conversationId.trim();
  if (routeId.isNotEmpty && routeId == eventId) {
    return true;
  }
  final routeName = route.sourceConversationName.trim();
  final eventName = event.conversationName.trim();
  return routeName.isNotEmpty && routeName == eventName;
}

String _routeDisplayName(FeishuMonitorForwardingRoute route) {
  final name = route.sourceConversationName.trim();
  if (name.isNotEmpty) {
    return name;
  }
  final source = route.sourceConversationId.trim();
  return source.isNotEmpty ? source : route.id;
}

String _logFilterLabel(_LogFilter filter) {
  return switch (filter) {
    _LogFilter.all => '全部',
    _LogFilter.success => '成功',
    _LogFilter.error => '错误',
    _LogFilter.capture => '捕获',
    _LogFilter.forward => '转发',
  };
}

String _workerCapacityWarning(int routeCount) {
  const workerCapacity = 20;
  if (routeCount <= workerCapacity) {
    return '';
  }
  return 'worker capacity 20 exceeded: configured $routeCount routes';
}

class _QuickActions extends StatefulWidget {
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
  State<_QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends State<_QuickActions> {
  @override
  Widget build(BuildContext context) {
    return _ConsoleCard(
      title: '快捷操作',
      trailing: Text(
        widget.forwardingResult.trim().isEmpty
            ? '等待操作'
            : widget.forwardingResult,
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 12,
          color: WKColors.color999,
        ),
      ),
      child: Wrap(
        spacing: WKSpace.sm,
        runSpacing: WKSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ActionButton(
            key: const ValueKey('feishu-monitor-start-capture-button'),
            label: '启动转发',
            onTap: widget.onStartCapture,
          ),
          _ActionButton(
            key: const ValueKey('feishu-monitor-stop-capture-button'),
            label: '停止转发',
            onTap: widget.onStopCapture,
            danger: true,
          ),
          _ActionButton(
            key: const ValueKey('feishu-monitor-reload-runtime-button'),
            label: '重新加载飞书',
            onTap: widget.onReloadRuntime,
          ),
          Text(
            '已配置 ${widget.routeCount} 条转发规则，未配置来源默认跳过',
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 13,
              color: WKColors.color999,
            ),
          ),
          _ActionButton(
            key: const ValueKey('feishu-monitor-forward-recent-button'),
            label: widget.forwarding ? '转发中' : '转发最近事件',
            onTap: widget.onForwardRecentEvents,
            primary: true,
          ),
          SizedBox(
            width: 180,
            child: SwitchListTile(
              key: const ValueKey('feishu-monitor-auto-forward-switch'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: widget.autoForwarding,
              onChanged: widget.onAutoForwardingChanged,
              title: const Text(
                '自动转发',
                style: TextStyle(
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

class _ConsoleTabs extends StatelessWidget {
  const _ConsoleTabs({required this.selected, required this.onChanged});

  final _ConsoleTab selected;
  final ValueChanged<_ConsoleTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.md),
        border: Border.all(color: WKColors.borderColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TabButton(
              label: '运行日志',
              active: selected == _ConsoleTab.logs,
              onTap: () => onChanged(_ConsoleTab.logs),
            ),
            _TabButton(
              label: '转发规则',
              active: selected == _ConsoleTab.rules,
              onTap: () => onChanged(_ConsoleTab.rules),
            ),
            _TabButton(
              label: '飞书群组',
              active: selected == _ConsoleTab.groups,
              onTap: () => onChanged(_ConsoleTab.groups),
            ),
            _TabButton(
              label: '图片处理',
              active: selected == _ConsoleTab.images,
              onTap: () => onChanged(_ConsoleTab.images),
            ),
            _TabButton(
              label: '系统设置',
              active: selected == _ConsoleTab.settings,
              onTap: () => onChanged(_ConsoleTab.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetGroupPicker extends StatefulWidget {
  const _TargetGroupPicker({
    required this.loadGroups,
    required this.pickRelayAvatarImage,
    required this.uploadRelayAvatarImage,
    required this.initialRelayDisplayName,
    required this.initialRelayAvatar,
  });

  final FeishuMonitorTargetGroupLoader loadGroups;
  final FeishuMonitorRelayAvatarPicker pickRelayAvatarImage;
  final FeishuMonitorRelayAvatarUploader uploadRelayAvatarImage;
  final String initialRelayDisplayName;
  final String initialRelayAvatar;

  @override
  State<_TargetGroupPicker> createState() => _TargetGroupPickerState();
}

class _TargetGroupPickerState extends State<_TargetGroupPicker> {
  late final Future<List<_TargetGroupOption>> _groupsFuture;
  late final TextEditingController _relayNameController;
  late final TextEditingController _relayAvatarController;
  bool _uploadingAvatar = false;
  String _avatarUploadError = '';

  @override
  void initState() {
    super.initState();
    _groupsFuture = _loadGroupOptions();
    _relayNameController = TextEditingController(
      text: widget.initialRelayDisplayName.trim().isEmpty
          ? '飞书转发助手'
          : widget.initialRelayDisplayName.trim(),
    );
    _relayAvatarController = TextEditingController(
      text: widget.initialRelayAvatar.trim(),
    );
  }

  @override
  void dispose() {
    _relayNameController.dispose();
    _relayAvatarController.dispose();
    super.dispose();
  }

  Future<List<_TargetGroupOption>> _loadGroupOptions() async {
    final groups = await widget.loadGroups();
    final activeGroups = groups.where(_isSelectableTargetGroup);
    return Future.wait(activeGroups.map(_TargetGroupOption.resolve));
  }

  Future<void> _uploadRelayAvatar() async {
    if (_uploadingAvatar) {
      return;
    }
    setState(() {
      _uploadingAvatar = true;
      _avatarUploadError = '';
    });
    try {
      final filePath = (await widget.pickRelayAvatarImage())?.trim() ?? '';
      if (filePath.isEmpty) {
        return;
      }
      final avatarUrl = (await widget.uploadRelayAvatarImage(filePath)).trim();
      if (avatarUrl.isEmpty) {
        throw StateError('Avatar upload returned an empty url.');
      }
      _relayAvatarController.text = avatarUrl;
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _avatarUploadError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 680),
          padding: const EdgeInsets.fromLTRB(
            WKSpace.xl,
            WKSpace.lg,
            WKSpace.xl,
            WKSpace.xl,
          ),
          child: FutureBuilder<List<_TargetGroupOption>>(
            future: _groupsFuture,
            builder: (context, snapshot) {
              final groups = snapshot.data ?? const <_TargetGroupOption>[];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0EA),
                          borderRadius: BorderRadius.circular(WKRadius.sm),
                        ),
                        child: const Text(
                          'IM',
                          style: TextStyle(
                            fontFamily: WKFontFamily.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: WKColors.brand500,
                          ),
                        ),
                      ),
                      const SizedBox(width: WKSpace.sm),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '选择目标悟空 IM 群',
                              style: TextStyle(
                                fontFamily: WKFontFamily.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: WKColors.colorDark,
                              ),
                            ),
                            SizedBox(height: WKSpace.xxs),
                            Text(
                              '转发助手名称和头像会用于目标群里的消息展示',
                              style: TextStyle(
                                fontFamily: WKFontFamily.primary,
                                fontSize: 12,
                                color: WKColors.color999,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: WKSpace.md),
                  _RelayIdentityCard(
                    nameController: _relayNameController,
                    avatarController: _relayAvatarController,
                    uploadingAvatar: _uploadingAvatar,
                    avatarUploadError: _avatarUploadError,
                    onUploadAvatar: _uploadRelayAvatar,
                  ),
                  const SizedBox(height: WKSpace.md),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: WKSpace.lg),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    _PickerMessage(
                      text: '加载群聊失败',
                      detail: snapshot.error.toString(),
                    )
                  else if (groups.isEmpty)
                    const _PickerMessage(
                      text: '暂无可选群聊',
                      detail: '当前账号没有返回可选群组，请先创建或加入一个悟空 IM 群聊。',
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: groups.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: WKSpace.xs),
                        itemBuilder: (context, index) {
                          final option = groups[index];
                          return _RouteOptionTile(
                            title: option.title,
                            subtitle: option.group.groupNo,
                            meta: _targetGroupMeta(option.group),
                            selected: false,
                            onTap: () => Navigator.of(context).pop(
                              _RouteConfigurationDraft(
                                group: option.group,
                                relayDisplayName: _relayNameController.text,
                                relayAvatar: _relayAvatarController.text,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RelayIdentityCard extends StatelessWidget {
  const _RelayIdentityCard({
    required this.nameController,
    required this.avatarController,
    required this.uploadingAvatar,
    required this.avatarUploadError,
    required this.onUploadAvatar,
  });

  final TextEditingController nameController;
  final TextEditingController avatarController;
  final bool uploadingAvatar;
  final String avatarUploadError;
  final VoidCallback onUploadAvatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(WKSpace.md),
      decoration: BoxDecoration(
        color: WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.md),
        border: Border.all(color: WKColors.borderColor),
      ),
      child: Column(
        children: [
          TextField(
            key: const ValueKey('feishu-route-relay-name-field'),
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '本群显示名称',
              hintText: '飞书转发助手',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: WKSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('feishu-route-relay-avatar-field'),
                  controller: avatarController,
                  decoration: const InputDecoration(
                    labelText: '本群显示头像',
                    hintText: '头像 URL 或媒体地址',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: WKSpace.sm),
              SizedBox(
                height: 42,
                child: TextButton(
                  key: const ValueKey('feishu-route-relay-avatar-upload-button'),
                  onPressed: uploadingAvatar ? null : onUploadAvatar,
                  style: TextButton.styleFrom(
                    backgroundColor: WKColors.surface,
                    foregroundColor: WKColors.brand500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(WKRadius.sm),
                      side: const BorderSide(color: WKColors.borderColor),
                    ),
                  ),
                  child: Text(uploadingAvatar ? '上传中...' : '上传头像'),
                ),
              ),
            ],
          ),
          if (uploadingAvatar || avatarUploadError.isNotEmpty) ...[
            const SizedBox(height: WKSpace.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                uploadingAvatar ? '正在上传头像...' : avatarUploadError,
                style: TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 12,
                  color: uploadingAvatar
                      ? WKColors.textSecondary
                      : WKColors.danger,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteConfigurationDraft {
  const _RouteConfigurationDraft({
    required this.group,
    required this.relayDisplayName,
    required this.relayAvatar,
  });

  final GroupInfo group;
  final String relayDisplayName;
  final String relayAvatar;
}

class _RouteEditorDialog extends StatefulWidget {
  const _RouteEditorDialog({
    required this.title,
    required this.workerId,
    required this.sourceConversations,
    required this.loadTargetGroups,
    this.route,
    this.conversation,
  });

  final String title;
  final String workerId;
  final List<FeishuMonitorObservedConversation> sourceConversations;
  final FeishuMonitorTargetGroupLoader loadTargetGroups;
  final FeishuMonitorForwardingRoute? route;
  final FeishuMonitorObservedConversation? conversation;

  @override
  State<_RouteEditorDialog> createState() => _RouteEditorDialogState();
}

class _RouteEditorDialogState extends State<_RouteEditorDialog> {
  late final Future<List<_TargetGroupOption>> _targetGroupsFuture;
  late List<FeishuMonitorObservedConversation> _sourceOptions;
  FeishuMonitorObservedConversation? _selectedSource;
  _TargetGroupOption? _selectedTarget;
  bool _enabled = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    final conversation = widget.conversation;
    _enabled = route?.enabled ?? true;
    _sourceOptions = _buildSourceOptions(route: route, conversation: conversation);
    _selectedSource = _initialSource(route: route, conversation: conversation);
    _targetGroupsFuture = _loadTargetOptions(route);
  }

  void _submit() {
    final selectedSource = _selectedSource;
    final selectedTarget = _selectedTarget;
    final sourceId = selectedSource?.id.trim() ?? '';
    final targetId = selectedTarget?.group.groupNo.trim() ?? '';
    if (sourceId.isEmpty || targetId.isEmpty) {
      setState(() {
        _error = '请选择来源飞书群和目标悟空 IM 群';
      });
      return;
    }
    final now = DateTime.now().toUtc();
    final route = widget.route;
    Navigator.of(context).pop(
      FeishuMonitorForwardingRoute(
        id: route?.id ?? _routeIdForSource(sourceId),
        enabled: _enabled,
        sourceConversationId: sourceId,
        sourceConversationName: _sourceTitle(selectedSource!),
        sourceConversationType:
            route?.sourceConversationType ?? selectedSource.type.trim(),
        targetGroupId: targetId,
        targetGroupName: selectedTarget!.title.trim(),
        workerId: route?.workerId.trim().isNotEmpty == true
            ? route!.workerId
            : widget.workerId,
        relayDisplayName: route?.relayDisplayName ?? '',
        relayAvatar: route?.relayAvatar ?? '',
        createdAt: route?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  List<FeishuMonitorObservedConversation> _buildSourceOptions({
    required FeishuMonitorForwardingRoute? route,
    required FeishuMonitorObservedConversation? conversation,
  }) {
    final byId = <String, FeishuMonitorObservedConversation>{};
    for (final item in widget.sourceConversations) {
      final id = item.id.trim();
      if (id.isNotEmpty) {
        byId[id] = item;
      }
    }
    if (conversation != null && conversation.id.trim().isNotEmpty) {
      byId[conversation.id.trim()] = conversation;
    }
    if (route != null && route.sourceConversationId.trim().isNotEmpty) {
      final id = route.sourceConversationId.trim();
      byId.putIfAbsent(
        id,
        () => FeishuMonitorObservedConversation(
          id: id,
          name: route.sourceConversationName.trim(),
          type: route.sourceConversationType.trim().isEmpty
              ? 'group'
              : route.sourceConversationType.trim(),
          lastMessagePreview: '当前已配置规则',
          observedAt: route.updatedAt,
        ),
      );
    }
    return byId.values.toList(growable: false)
      ..sort((left, right) => _sourceTitle(left).compareTo(_sourceTitle(right)));
  }

  FeishuMonitorObservedConversation? _initialSource({
    required FeishuMonitorForwardingRoute? route,
    required FeishuMonitorObservedConversation? conversation,
  }) {
    final id = route?.sourceConversationId.trim().isNotEmpty == true
        ? route!.sourceConversationId.trim()
        : conversation?.id.trim();
    if (id == null || id.isEmpty) {
      return _sourceOptions.isEmpty ? null : _sourceOptions.first;
    }
    for (final source in _sourceOptions) {
      if (source.id.trim() == id) {
        return source;
      }
    }
    return _sourceOptions.isEmpty ? null : _sourceOptions.first;
  }

  Future<List<_TargetGroupOption>> _loadTargetOptions(
    FeishuMonitorForwardingRoute? route,
  ) async {
    final groups = await widget.loadTargetGroups();
    final options = await Future.wait(
      groups.where(_isSelectableTargetGroup).map(_TargetGroupOption.resolve),
    );
    final byId = <String, _TargetGroupOption>{
      for (final option in options) option.group.groupNo.trim(): option,
    };
    if (route != null && route.targetGroupId.trim().isNotEmpty) {
      final id = route.targetGroupId.trim();
      byId.putIfAbsent(
        id,
        () => _TargetGroupOption(
          group: GroupInfo(groupNo: id, name: route.targetGroupName.trim()),
          title: route.targetGroupName.trim().isEmpty
              ? id
              : route.targetGroupName.trim(),
        ),
      );
    }
    final result = byId.values.toList(growable: false)
      ..sort((left, right) => left.title.compareTo(right.title));
    if (mounted) {
      final targetId = route?.targetGroupId.trim() ?? '';
      _TargetGroupOption? selected;
      for (final option in result) {
        if (option.group.groupNo.trim() == targetId) {
          selected = option;
          break;
        }
      }
      setState(() {
        _selectedTarget = targetId.isEmpty
            ? (result.isEmpty ? null : result.first)
            : selected ?? (result.isEmpty ? null : result.first);
      });
    }
    return result;
  }

  void _selectSource(FeishuMonitorObservedConversation source) {
    setState(() {
      _selectedSource = source;
      _error = '';
    });
  }

  void _selectTarget(_TargetGroupOption target) {
    setState(() {
      _selectedTarget = target;
      _error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: WKSpace.xl,
        vertical: WKSpace.xl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WKRadius.lg),
      ),
      backgroundColor: WKColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RouteEditorHeader(title: widget.title),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  WKSpace.xl,
                  WKSpace.lg,
                  WKSpace.xl,
                  WKSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final sourcePanel = _RouteOptionPanel<
                          FeishuMonitorObservedConversation
                        >(
                          title: '来源飞书群',
                          subtitle: '选择要监听的飞书会话，规则名称会自动使用群名',
                          emptyText: '暂无可选飞书群，请先刷新飞书群组列表',
                          items: _sourceOptions,
                          selected: _selectedSource,
                          itemKey: (item) =>
                              ValueKey('feishu-route-editor-source-${item.id}'),
                          titleFor: _sourceTitle,
                          subtitleFor: (item) => item.id.trim(),
                          metaFor: (item) =>
                              item.lastMessagePreview.trim().isEmpty
                              ? _conversationTypeLabel(item.type)
                              : item.lastMessagePreview.trim(),
                          selectedFor: (item, selected) =>
                              selected?.id.trim() == item.id.trim(),
                          onSelect: _selectSource,
                        );
                        final targetPanel = FutureBuilder<List<_TargetGroupOption>>(
                          future: _targetGroupsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const _RouteLoadingPanel(
                                title: '目标悟空 IM 群',
                                subtitle: '正在读取当前账号可用群聊',
                              );
                            }
                            if (snapshot.hasError) {
                              return _PickerMessage(
                                text: '加载目标群失败',
                                detail: snapshot.error.toString(),
                              );
                            }
                            final targets =
                                snapshot.data ?? const <_TargetGroupOption>[];
                            return _RouteOptionPanel<_TargetGroupOption>(
                              title: '目标悟空 IM 群',
                              subtitle: '选择转发到哪个悟空 IM 群，ID 和群名会自动写入',
                              emptyText: '暂无可选悟空 IM 群',
                              items: targets,
                              selected: _selectedTarget,
                              itemKey: (item) => ValueKey(
                                'feishu-route-editor-target-${item.group.groupNo}',
                              ),
                              titleFor: (item) => item.title,
                              subtitleFor: (item) => item.group.groupNo,
                              metaFor: (item) => _targetGroupMeta(item.group),
                              selectedFor: (item, selected) =>
                                  selected?.group.groupNo.trim() ==
                                  item.group.groupNo.trim(),
                              onSelect: _selectTarget,
                            );
                          },
                        );
                        if (constraints.maxWidth < 700) {
                          return Column(
                            children: [
                              sourcePanel,
                              const SizedBox(height: WKSpace.md),
                              targetPanel,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: sourcePanel),
                            const SizedBox(width: WKSpace.md),
                            Expanded(child: targetPanel),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: WKSpace.md),
                    _RouteSummaryCard(
                      source: _selectedSource,
                      target: _selectedTarget,
                      enabled: _enabled,
                      onEnabledChanged: (value) {
                        setState(() {
                          _enabled = value;
                        });
                      },
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: WKSpace.sm),
                      Text(
                        _error,
                        style: const TextStyle(
                          fontFamily: WKFontFamily.primary,
                          fontSize: 12,
                          color: WKColors.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                WKSpace.xl,
                WKSpace.sm,
                WKSpace.xl,
                WKSpace.xl,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: WKSpace.sm),
                  FilledButton(
                    key: const ValueKey('feishu-route-editor-save-button'),
                    onPressed: _submit,
                    child: const Text('保存规则'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteEditorHeader extends StatelessWidget {
  const _RouteEditorHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        WKSpace.xl,
        WKSpace.lg,
        WKSpace.xl,
        WKSpace.md,
      ),
      decoration: const BoxDecoration(
        color: WKColors.surfaceSoft,
        borderRadius: BorderRadius.vertical(top: Radius.circular(WKRadius.lg)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: WKSpace.xs),
          const Text(
            '选择来源和目标即可完成配置，无需手动复制群 ID。',
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 13,
              color: WKColors.color999,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteOptionPanel<T> extends StatelessWidget {
  const _RouteOptionPanel({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.items,
    required this.selected,
    required this.itemKey,
    required this.titleFor,
    required this.subtitleFor,
    required this.metaFor,
    required this.selectedFor,
    required this.onSelect,
  });

  final String title;
  final String subtitle;
  final String emptyText;
  final List<T> items;
  final T? selected;
  final Key Function(T item) itemKey;
  final String Function(T item) titleFor;
  final String Function(T item) subtitleFor;
  final String Function(T item) metaFor;
  final bool Function(T item, T? selected) selectedFor;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(WKSpace.md),
      decoration: BoxDecoration(
        color: WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.md),
        border: Border.all(color: WKColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: WKSpace.xxs),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 12,
              color: WKColors.color999,
            ),
          ),
          const SizedBox(height: WKSpace.md),
          if (items.isEmpty)
            _PickerMessage(text: emptyText, detail: '请确认列表已刷新，并且当前账号有可选群。')
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: WKSpace.xs),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = selectedFor(item, selected);
                  return _RouteOptionTile(
                    key: itemKey(item),
                    title: titleFor(item),
                    subtitle: subtitleFor(item),
                    meta: metaFor(item),
                    selected: isSelected,
                    onTap: () => onSelect(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteOptionTile extends StatelessWidget {
  const _RouteOptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String meta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFFFF0EA) : WKColors.surface,
      borderRadius: BorderRadius.circular(WKRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WKRadius.sm),
        child: Container(
          padding: const EdgeInsets.all(WKSpace.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WKRadius.sm),
            border: Border.all(
              color: selected ? WKColors.brand500 : WKColors.borderColor,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? WKColors.brand500 : WKColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(WKRadius.sm),
                ),
                child: Text(
                  selected ? '✓' : _initialForTitle(title),
                  style: TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: selected ? WKColors.white : WKColors.color999,
                  ),
                ),
              ),
              const SizedBox(width: WKSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.trim().isEmpty ? subtitle : title.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: WKFontFamily.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: WKColors.colorDark,
                      ),
                    ),
                    const SizedBox(height: WKSpace.xxs),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: WKFontFamily.primary,
                        fontSize: 12,
                        color: WKColors.color999,
                      ),
                    ),
                    if (meta.trim().isNotEmpty) ...[
                      const SizedBox(height: WKSpace.xxs),
                      Text(
                        meta.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: WKFontFamily.primary,
                          fontSize: 12,
                          color: WKColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteLoadingPanel extends StatelessWidget {
  const _RouteLoadingPanel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(WKSpace.md),
      decoration: BoxDecoration(
        color: WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.md),
        border: Border.all(color: WKColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: WKSpace.xxs),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 12,
              color: WKColors.color999,
            ),
          ),
          const SizedBox(height: WKSpace.xxl),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: WKSpace.xxl),
        ],
      ),
    );
  }
}

class _RouteSummaryCard extends StatelessWidget {
  const _RouteSummaryCard({
    required this.source,
    required this.target,
    required this.enabled,
    required this.onEnabledChanged,
  });

  final FeishuMonitorObservedConversation? source;
  final _TargetGroupOption? target;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final sourceTitle = source == null ? '未选择来源飞书群' : _sourceTitle(source!);
    final targetTitle = target == null ? '未选择目标悟空 IM 群' : target!.title;
    return Container(
      padding: const EdgeInsets.all(WKSpace.md),
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.md),
        border: Border.all(color: WKColors.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '规则预览',
                  style: TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: WKColors.colorDark,
                  ),
                ),
                const SizedBox(height: WKSpace.xs),
                Text(
                  '$sourceTitle  →  $targetTitle',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 13,
                    color: WKColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: WKSpace.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '启用',
                style: TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: WKColors.colorDark,
                ),
              ),
              Switch(value: enabled, onChanged: onEnabledChanged),
            ],
          ),
        ],
      ),
    );
  }
}

String _sourceTitle(FeishuMonitorObservedConversation source) {
  final name = source.name.trim();
  return name.isEmpty ? source.id.trim() : name;
}

String _targetGroupMeta(GroupInfo group) {
  final parts = <String>[];
  final memberCount = group.memberCount;
  if (memberCount != null && memberCount > 0) {
    parts.add('$memberCount 人');
  }
  final status = group.status;
  if (status != null) {
    parts.add(status == 0 || status == 1 ? '可用' : '不可用');
  }
  return parts.join(' · ');
}

String _initialForTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) {
    return '#';
  }
  return trimmed.characters.first;
}

class _BatchImportDialog extends StatefulWidget {
  const _BatchImportDialog();

  @override
  State<_BatchImportDialog> createState() => _BatchImportDialogState();
}

class _BatchImportDialogState extends State<_BatchImportDialog> {
  final TextEditingController _controller = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final routes = _parseImportedRoutes(_controller.text);
      if (routes.isEmpty) {
        setState(() {
          _error = '没有解析到可导入的规则';
        });
        return;
      }
      Navigator.of(context).pop(routes);
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('批量导入转发规则'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('粘贴 CSV 内容：来源ID, 来源名称, 目标群ID, 目标群名称, enabled'),
            const SizedBox(height: WKSpace.sm),
            TextField(
              key: const ValueKey('feishu-route-import-text-field'),
              controller: _controller,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'feed:example,飞书来源群,wk_target,悟空目标群,true',
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: WKSpace.xs),
              Text(_error, style: const TextStyle(color: WKColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('导入')),
      ],
    );
  }
}

bool _isSelectableTargetGroup(GroupInfo group) {
  final groupNo = group.groupNo.trim();
  if (groupNo.isEmpty) {
    return false;
  }
  final save = group.save;
  if (save != null && save != 1) {
    return false;
  }
  final status = group.status;
  if (status != null && status != 0 && status != 1) {
    return false;
  }
  return true;
}

class _TargetGroupOption {
  const _TargetGroupOption({required this.group, required this.title});

  final GroupInfo group;
  final String title;

  static Future<_TargetGroupOption> resolve(GroupInfo group) async {
    final explicitName = _targetGroupDisplayName(group);
    if (explicitName.isNotEmpty) {
      return _TargetGroupOption(group: group, title: explicitName);
    }

    final cachedName = await _cachedTargetGroupDisplayName(group.groupNo);
    return _TargetGroupOption(
      group: group,
      title: cachedName.isEmpty ? group.groupNo : cachedName,
    );
  }
}

String _targetGroupDisplayName(GroupInfo group) {
  for (final value in <String?>[group.remark, group.name]) {
    final text = value?.trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

Future<String> _cachedTargetGroupDisplayName(String groupNo) async {
  final normalizedGroupNo = groupNo.trim();
  if (normalizedGroupNo.isEmpty) {
    return '';
  }
  final channel = await WKIM.shared.channelManager.getChannel(
    normalizedGroupNo,
    WKChannelType.group,
  );
  if (channel == null) {
    return '';
  }
  for (final value in <String>[channel.channelRemark, channel.channelName]) {
    final text = value.trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

String _routeIdForConversation(FeishuMonitorObservedConversation conversation) {
  final id = conversation.id.trim();
  if (id.isNotEmpty) {
    return _routeIdForSource(id);
  }
  return 'route_${normalizeFeishuMonitorRouteName(conversation.name).replaceAll(' ', '_')}';
}

String _routeIdForSource(String sourceId) {
  return 'route_${sourceId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')}';
}

List<FeishuMonitorForwardingRoute> _parseImportedRoutes(String text) {
  final routes = <FeishuMonitorForwardingRoute>[];
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);
  for (final line in lines) {
    if (line.toLowerCase().startsWith('source_conversation_id')) {
      continue;
    }
    final cells = line
        .split(RegExp(r'[\t,]'))
        .map((cell) => cell.trim())
        .toList(growable: false);
    if (cells.length < 3) {
      throw FormatException('规则格式不完整：$line');
    }
    final sourceId = cells[0];
    final targetId = cells[2];
    if (sourceId.isEmpty || targetId.isEmpty) {
      throw FormatException('来源 ID 和目标群 ID 不能为空：$line');
    }
    final enabledText = cells.length > 4 ? cells[4].toLowerCase() : 'true';
    final enabled = !<String>{
      'false',
      '0',
      'no',
      'off',
      '关闭',
    }.contains(enabledText);
    final now = DateTime.now().toUtc();
    routes.add(
      FeishuMonitorForwardingRoute(
        id: _routeIdForSource(sourceId),
        enabled: enabled,
        sourceConversationId: sourceId,
        sourceConversationName: cells.length > 1 ? cells[1] : sourceId,
        sourceConversationType: 'group',
        targetGroupId: targetId,
        targetGroupName: cells.length > 3 ? cells[3] : targetId,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
  return routes;
}

Future<String> _resolveTargetGroupTitle(GroupInfo group) async {
  final explicitName = _targetGroupDisplayName(group);
  if (explicitName.isNotEmpty) {
    return explicitName;
  }
  final cachedName = await _cachedTargetGroupDisplayName(group.groupNo);
  return cachedName.isEmpty ? group.groupNo : cachedName;
}

class _PickerMessage extends StatelessWidget {
  const _PickerMessage({required this.text, required this.detail});

  final String text;
  final String detail;

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
            text,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: WKSpace.xs),
          Text(
            detail,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 12,
              color: WKColors.color999,
            ),
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
    required this.forwardingSettings,
    required this.onConfigureRoute,
    required this.onRefreshGroups,
    required this.onAddRoute,
    required this.onEditRoute,
    required this.onDeleteRoute,
    required this.onTestRoute,
    required this.onDownloadTemplate,
    required this.onBatchImport,
    required this.onSaveImageSettings,
    required this.onSaveSystemSettings,
  });

  final _ConsoleTab selected;
  final FeishuMonitorShellStatus? status;
  final FeishuMonitorForwardingSettings forwardingSettings;
  final ValueChanged<FeishuMonitorObservedConversation> onConfigureRoute;
  final VoidCallback? onRefreshGroups;
  final VoidCallback onAddRoute;
  final ValueChanged<FeishuMonitorForwardingRoute> onEditRoute;
  final ValueChanged<FeishuMonitorForwardingRoute> onDeleteRoute;
  final ValueChanged<FeishuMonitorForwardingRoute> onTestRoute;
  final VoidCallback onDownloadTemplate;
  final VoidCallback onBatchImport;
  final VoidCallback onSaveImageSettings;
  final Future<void> Function(FeishuMonitorForwardingSettings)
  onSaveSystemSettings;

  @override
  Widget build(BuildContext context) {
    return switch (selected) {
      _ConsoleTab.logs => _RuntimeLogsTab(
        status: status,
        routes: forwardingSettings.routes,
      ),
      _ConsoleTab.rules => _ForwardingRulesTab(
        status: status,
        routes: forwardingSettings.routes,
        onAddRoute: onAddRoute,
        onEditRoute: onEditRoute,
        onDeleteRoute: onDeleteRoute,
        onTestRoute: onTestRoute,
        onDownloadTemplate: onDownloadTemplate,
        onBatchImport: onBatchImport,
      ),
      _ConsoleTab.groups => _FeishuGroupsTab(
        status: status,
        routes: forwardingSettings.routes,
        onConfigureRoute: onConfigureRoute,
        onRefresh: onRefreshGroups,
      ),
      _ConsoleTab.images => _ImageProcessingTab(onSave: onSaveImageSettings),
      _ConsoleTab.settings => _SystemSettingsTab(
        status: status,
        forwardingSettings: forwardingSettings,
        onSave: onSaveSystemSettings,
      ),
    };
  }
}

enum _LogFilter { all, success, error, capture, forward }

class _RuntimeLogsTab extends StatefulWidget {
  const _RuntimeLogsTab({required this.status, required this.routes});

  final FeishuMonitorShellStatus? status;
  final List<FeishuMonitorForwardingRoute> routes;

  @override
  State<_RuntimeLogsTab> createState() => _RuntimeLogsTabState();
}

class _RuntimeLogsTabState extends State<_RuntimeLogsTab> {
  _LogFilter _filter = _LogFilter.all;
  bool _cleared = false;

  @override
  void didUpdateWidget(covariant _RuntimeLogsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _cleared = false;
    }
  }

  void _selectFilter(_LogFilter filter) {
    setState(() {
      _filter = filter;
    });
  }

  void _clearLogs() {
    setState(() {
      _cleared = true;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('日志已清空，刷新后会重新加载最新事件')));
  }

  Future<void> _exportLogs(List<_RuntimeLogEntry> entries) async {
    final lines = entries.isEmpty
        ? '暂无日志'
        : entries
              .map(
                (entry) =>
                    '${entry.time}\t${entry.level}\t${entry.source}\t${entry.message}',
              )
              .join('\n');
    await Clipboard.setData(ClipboardData(text: lines));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已复制 ${entries.length} 条日志到剪贴板')));
  }

  List<_RuntimeLogEntry> _entries() {
    if (_cleared) {
      return const <_RuntimeLogEntry>[];
    }
    final status = widget.status;
    final entries = <_RuntimeLogEntry>[];
    if (status?.lastError.trim().isNotEmpty == true) {
      entries.add(
        _RuntimeLogEntry(
          time: _formatTime(status!.lastUpdatedAt ?? status.probeObservedAt),
          level: '错误',
          source: 'shell',
          message: status.lastError.trim(),
          filter: _LogFilter.error,
        ),
      );
    }
    final events = status?.recentEvents ?? const <FeishuMonitorMessageEvent>[];
    for (final event in events) {
      final matchesRoute = widget.routes.any(
        (route) => route.enabled && _routeMatchesEvent(route, event),
      );
      entries.add(
        _RuntimeLogEntry(
          time: _formatTime(event.observedAt),
          level: matchesRoute ? '转发' : '捕获',
          source: event.captureSource.isEmpty ? 'probe' : event.captureSource,
          message:
              '${event.conversationName} / ${event.senderName}: ${event.text}',
          filter: matchesRoute ? _LogFilter.forward : _LogFilter.capture,
        ),
      );
    }
    return entries;
  }

  List<_RuntimeLogEntry> _visibleEntries(List<_RuntimeLogEntry> entries) {
    return switch (_filter) {
      _LogFilter.all => entries,
      _LogFilter.success =>
        entries
            .where((entry) => entry.filter != _LogFilter.error)
            .toList(growable: false),
      _LogFilter.error =>
        entries
            .where((entry) => entry.filter == _LogFilter.error)
            .toList(growable: false),
      _LogFilter.capture =>
        entries
            .where((entry) => entry.filter == _LogFilter.capture)
            .toList(growable: false),
      _LogFilter.forward =>
        entries
            .where((entry) => entry.filter == _LogFilter.forward)
            .toList(growable: false),
    };
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = _entries();
    final visibleEntries = _visibleEntries(
      allEntries,
    ).take(12).toList(growable: false);
    return _ConsoleCard(
      title: '运行日志',
      trailing: Wrap(
        spacing: 6,
        children: [
          _FilterChip(
            key: const ValueKey('feishu-log-filter-all'),
            label: '全部',
            active: _filter == _LogFilter.all,
            onTap: () => _selectFilter(_LogFilter.all),
          ),
          _FilterChip(
            key: const ValueKey('feishu-log-filter-success'),
            label: '成功',
            active: _filter == _LogFilter.success,
            onTap: () => _selectFilter(_LogFilter.success),
          ),
          _FilterChip(
            key: const ValueKey('feishu-log-filter-error'),
            label: '错误',
            active: _filter == _LogFilter.error,
            onTap: () => _selectFilter(_LogFilter.error),
          ),
          _FilterChip(
            key: const ValueKey('feishu-log-filter-capture'),
            label: '捕获',
            active: _filter == _LogFilter.capture,
            onTap: () => _selectFilter(_LogFilter.capture),
          ),
          _FilterChip(
            key: const ValueKey('feishu-log-filter-forward'),
            label: '转发',
            active: _filter == _LogFilter.forward,
            onTap: () => _selectFilter(_LogFilter.forward),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: WKSpace.sm,
            runSpacing: WKSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SmallButton(
                key: const ValueKey('feishu-log-clear-button'),
                label: '清空日志',
                onTap: _clearLogs,
              ),
              _SmallButton(
                key: const ValueKey('feishu-log-export-button'),
                label: '导出日志',
                primary: true,
                onTap: () => _exportLogs(allEntries),
              ),
              Text(
                '当前筛选：${_logFilterLabel(_filter)}',
                style: const TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 12,
                  color: WKColors.color999,
                ),
              ),
            ],
          ),
          const SizedBox(height: WKSpace.sm),
          Container(
            height: 380,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF121722),
              borderRadius: BorderRadius.circular(WKRadius.md),
            ),
            padding: const EdgeInsets.symmetric(vertical: WKSpace.sm),
            child: visibleEntries.isEmpty
                ? _TerminalLine(
                    time: '--:--:--',
                    level: '等待',
                    source: 'shell',
                    message: _cleared
                        ? '日志已清空，刷新列表后继续显示最新事件'
                        : '暂无标准化事件，等待飞书页面探针返回数据',
                  )
                : ListView.builder(
                    itemCount: visibleEntries.length,
                    itemBuilder: (context, index) {
                      final entry = visibleEntries[index];
                      return _TerminalLine(
                        time: entry.time,
                        level: entry.level,
                        source: entry.source,
                        message: entry.message,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RuntimeLogEntry {
  const _RuntimeLogEntry({
    required this.time,
    required this.level,
    required this.source,
    required this.message,
    required this.filter,
  });

  final String time;
  final String level;
  final String source;
  final String message;
  final _LogFilter filter;
}

class _ForwardingRulesTab extends StatelessWidget {
  const _ForwardingRulesTab({
    required this.status,
    required this.routes,
    required this.onAddRoute,
    required this.onEditRoute,
    required this.onDeleteRoute,
    required this.onTestRoute,
    required this.onDownloadTemplate,
    required this.onBatchImport,
  });

  final FeishuMonitorShellStatus? status;
  final List<FeishuMonitorForwardingRoute> routes;
  final VoidCallback onAddRoute;
  final ValueChanged<FeishuMonitorForwardingRoute> onEditRoute;
  final ValueChanged<FeishuMonitorForwardingRoute> onDeleteRoute;
  final ValueChanged<FeishuMonitorForwardingRoute> onTestRoute;
  final VoidCallback onDownloadTemplate;
  final VoidCallback onBatchImport;

  @override
  Widget build(BuildContext context) {
    return _ConsoleCard(
      title: '\u8f6c\u53d1\u89c4\u5219',
      trailing: Wrap(
        spacing: WKSpace.xs,
        children: [
          _SmallButton(
            key: const ValueKey('feishu-route-import-button'),
            label: '\u6279\u91cf\u5bfc\u5165',
            onTap: onBatchImport,
          ),
          _SmallButton(
            key: const ValueKey('feishu-route-template-button'),
            label: '\u4e0b\u8f7d\u6a21\u677f',
            onTap: onDownloadTemplate,
          ),
          _SmallButton(
            key: const ValueKey('feishu-route-add-button'),
            label: '\u65b0\u589e\u89c4\u5219',
            primary: true,
            onTap: onAddRoute,
          ),
        ],
      ),
      child: routes.isEmpty
          ? const Text(
              '\u8fd8\u6ca1\u6709\u8f6c\u53d1\u89c4\u5219\uff0c\u8bf7\u5148\u5230\u98de\u4e66\u7fa4\u7ec4\u9875\u4e3a\u6765\u6e90\u7fa4\u8bbe\u7f6e\u76ee\u6807\u7fa4\u3002',
              style: TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 13,
                color: WKColors.color999,
              ),
            )
          : _WidgetDataTable(
              columns: const [
                '\u64cd\u4f5c',
                '\u542f\u7528',
                '\u89c4\u5219\u540d\u79f0',
                '\u6765\u6e90\u98de\u4e66\u7fa4',
                '\u76ee\u6807\u609f\u7a7aIM\u7fa4',
                '\u76ee\u6807\u65b9\u5f0f',
                '\u4eca\u65e5\u6210\u529f',
                '\u4eca\u65e5\u5931\u8d25',
              ],
              rows: [
                for (final route in routes)
                  [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TableActionButton(
                          key: ValueKey('feishu-route-edit-${route.id}'),
                          label: '\u7f16\u8f91',
                          onTap: () => onEditRoute(route),
                        ),
                        _TableActionButton(
                          key: ValueKey('feishu-route-test-${route.id}'),
                          label: '\u6d4b\u8bd5',
                          onTap: () => onTestRoute(route),
                        ),
                        _TableActionButton(
                          key: ValueKey('feishu-route-delete-${route.id}'),
                          label: '\u5220\u9664',
                          onTap: () => onDeleteRoute(route),
                          danger: true,
                        ),
                      ],
                    ),
                    _tableText(route.enabled ? '\u542f\u7528' : '\u5173\u95ed'),
                    _tableText(_routeDisplayName(route)),
                    _tableText(route.sourceConversationId.trim()),
                    _tableText(
                      route.targetGroupName.trim().isEmpty
                          ? route.targetGroupId.trim()
                          : route.targetGroupName.trim(),
                    ),
                    _tableText('\u672c\u5730 SDK'),
                    _tableText(
                      '${_routeMatchedRecentEventCount(status, route)}',
                    ),
                    _tableText('${status?.deliveriesFailedToday ?? 0}'),
                  ],
              ],
            ),
    );
  }
}

class _FeishuGroupsTab extends StatelessWidget {
  const _FeishuGroupsTab({
    required this.status,
    required this.routes,
    required this.onConfigureRoute,
    required this.onRefresh,
  });

  final FeishuMonitorShellStatus? status;
  final List<FeishuMonitorForwardingRoute> routes;
  final ValueChanged<FeishuMonitorObservedConversation> onConfigureRoute;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final conversations =
        status?.observedConversations ??
        const <FeishuMonitorObservedConversation>[];
    return _ConsoleCard(
      title: '\u98de\u4e66\u7fa4\u7ec4',
      trailing: _SmallButton(
        key: const ValueKey('feishu-groups-refresh-button'),
        label: '\u5237\u65b0\u5217\u8868',
        primary: true,
        onTap: onRefresh,
      ),
      child: _WidgetDataTable(
        scrollbarKey: const ValueKey(
          'feishu-groups-table-horizontal-scrollbar',
        ),
        columns: const [
          '\u64cd\u4f5c',
          '\u5e8f\u53f7',
          '\u804a\u5929\u7c7b\u578b',
          '\u7fa4\u540d\u79f0',
          '\u98de\u4e66\u7fa4 ID',
          '\u6210\u5458\u6570',
          '\u6700\u8fd1\u6d88\u606f',
          '\u6700\u8fd1\u89c2\u5bdf',
          '\u8f6c\u53d1\u72b6\u6001',
        ],
        rows: conversations.isEmpty
            ? <List<Widget>>[
                [
                  _tableText('-'),
                  _tableText('-'),
                  _tableText('\u7b49\u5f85'),
                  _tableText('\u6682\u65e0\u7fa4\u7ec4\u6570\u636e'),
                  _tableText('-'),
                  _tableText('-'),
                  _tableText('-'),
                  _tableText('-'),
                  _tableText('\u672a\u914d\u7f6e'),
                ],
              ]
            : List<List<Widget>>.generate(conversations.length, (index) {
                final item = conversations[index];
                final route = _routeForConversation(item);
                return [
                  TextButton(
                    key: ValueKey('feishu-route-configure-${item.id}'),
                    onPressed: () => onConfigureRoute(item),
                    child: Text(
                      route == null
                          ? '\u8bbe\u7f6e\u8f6c\u53d1'
                          : '\u4fee\u6539\u76ee\u6807',
                    ),
                  ),
                  _tableText('${index + 1}'),
                  _tableText(_conversationTypeLabel(item.type)),
                  _tableText(item.name.isEmpty ? item.id : item.name),
                  _tableText(item.id),
                  _tableText('-'),
                  _tableText(item.lastMessagePreview),
                  _tableText(_formatObservedAt(item.observedAt)),
                  _tableText(_routeStatusLabel(route)),
                ];
              }),
      ),
    );
  }

  FeishuMonitorForwardingRoute? _routeForConversation(
    FeishuMonitorObservedConversation conversation,
  ) {
    final sourceConversationId = conversation.id.trim();
    for (final route in routes) {
      if (route.sourceConversationId.trim() == sourceConversationId) {
        return route;
      }
    }
    return null;
  }

  String _routeStatusLabel(FeishuMonitorForwardingRoute? route) {
    if (route == null) {
      return '\u672a\u914d\u7f6e';
    }
    if (!route.enabled) {
      return '\u5df2\u505c\u7528';
    }
    final target = route.targetGroupName.trim().isNotEmpty
        ? route.targetGroupName.trim()
        : route.targetGroupId.trim();
    return '\u5df2\u8f6c\u53d1\u5230 ${target.isEmpty ? '\u672a\u914d\u7f6e' : target}';
  }
}

class _ImageProcessingTab extends StatelessWidget {
  const _ImageProcessingTab({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _ConsoleCard(
      title: '\u56fe\u7247\u5904\u7406',
      trailing: _SmallButton(
        key: const ValueKey('feishu-image-settings-save-button'),
        label: '\u4fdd\u5b58\u8bbe\u7f6e',
        primary: true,
        onTap: onSave,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 760;
          const textToImage = _SettingsPanel(
            title: '\u6587\u5b57\u8f6c\u56fe\u7247',
            rows: [
              _FormLine('\u542f\u7528\u529f\u80fd', '\u5173\u95ed'),
              _FormLine('\u89e6\u53d1\u51e0\u7387', '30%'),
              _FormLine('\u56fe\u7247\u5bbd\u5ea6', '800 px'),
              _FormLine('\u5b57\u4f53\u5927\u5c0f', '28 px'),
            ],
          );
          const watermark = _SettingsPanel(
            title: '\u56fe\u7247\u6c34\u5370',
            rows: [
              _FormLine('\u542f\u7528\u529f\u80fd', '\u5173\u95ed'),
              _FormLine('\u89e6\u53d1\u51e0\u7387', '50%'),
              _FormLine('\u6c34\u5370\u6587\u5b57', '\u8fd9\u662f\u6c34\u5370'),
              _FormLine('\u6c34\u5370\u4f4d\u7f6e', '\u968f\u673a\u4f4d\u7f6e'),
              _FormLine('\u900f\u660e\u5ea6', '128'),
            ],
          );
          if (narrow) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                textToImage,
                SizedBox(height: WKSpace.sm),
                watermark,
              ],
            );
          }
          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: textToImage),
              SizedBox(width: WKSpace.sm),
              Expanded(child: watermark),
            ],
          );
        },
      ),
    );
  }
}

class _SystemSettingsTab extends StatefulWidget {
  const _SystemSettingsTab({
    required this.status,
    required this.forwardingSettings,
    required this.onSave,
  });

  final FeishuMonitorShellStatus? status;
  final FeishuMonitorForwardingSettings forwardingSettings;
  final Future<void> Function(FeishuMonitorForwardingSettings) onSave;

  @override
  State<_SystemSettingsTab> createState() => _SystemSettingsTabState();
}

class _SystemSettingsTabState extends State<_SystemSettingsTab> {
  late bool _autoForwarding;
  late final TextEditingController _legacyTargetController;

  @override
  void initState() {
    super.initState();
    _autoForwarding = widget.forwardingSettings.enabled;
    _legacyTargetController = TextEditingController(
      text: widget.forwardingSettings.legacyTargetGroupId,
    );
  }

  @override
  void didUpdateWidget(covariant _SystemSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forwardingSettings != widget.forwardingSettings) {
      _autoForwarding = widget.forwardingSettings.enabled;
      if (_legacyTargetController.text !=
          widget.forwardingSettings.legacyTargetGroupId) {
        _legacyTargetController.text =
            widget.forwardingSettings.legacyTargetGroupId;
      }
    }
  }

  @override
  void dispose() {
    _legacyTargetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.onSave(
      widget.forwardingSettings.copyWith(
        enabled: _autoForwarding,
        legacyTargetGroupId: _legacyTargetController.text.trim(),
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('系统设置已保存')));
  }

  @override
  Widget build(BuildContext context) {
    return _ConsoleCard(
      title: '\u7cfb\u7edf\u8bbe\u7f6e',
      trailing: _SmallButton(
        key: const ValueKey('feishu-settings-save-button'),
        label: '\u4fdd\u5b58\u8bbe\u7f6e',
        primary: true,
        onTap: _save,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 760;
          final shellSettings = _SettingsPanel(
            title: '\u672c\u5730 Shell \u7a0b\u5e8f',
            rows: [
              const _FormLine('Shell \u5730\u5740', 'http://127.0.0.1:18766'),
              const _FormLine('Token', 'wukong-feishu-shell-dev'),
              const _FormLine('\u5237\u65b0\u95f4\u9694', '8 \u79d2'),
              _FormLine(
                '\u5f53\u524d\u5730\u5740',
                widget.status?.runtimeUrl ?? '\u672a\u52a0\u8f7d',
              ),
            ],
          );
          final forwardingSettings = _SettingsPanel(
            title: '\u8f6c\u53d1\u7b56\u7565',
            rows: [
              _FormLine.custom(
                '\u81ea\u52a8\u8f6c\u53d1',
                Switch(
                  key: const ValueKey('feishu-settings-auto-forward-switch'),
                  value: _autoForwarding,
                  onChanged: (value) {
                    setState(() {
                      _autoForwarding = value;
                    });
                  },
                ),
              ),
              _FormLine.custom(
                '\u9ed8\u8ba4\u76ee\u6807',
                TextField(
                  key: const ValueKey('feishu-settings-legacy-target-field'),
                  controller: _legacyTargetController,
                  decoration: const InputDecoration(
                    hintText: '可选，旧版单目标群 ID',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 13,
                    color: WKColors.colorDark,
                  ),
                ),
              ),
              const _FormLine(
                '\u53bb\u91cd\u7a97\u53e3',
                '\u5f53\u524d\u8fd0\u884c\u671f',
              ),
              const _FormLine(
                '\u5931\u8d25\u91cd\u8bd5',
                '\u4e0b\u4e00\u9636\u6bb5\u63a5\u5165',
              ),
              const _FormLine('\u6295\u9012\u901a\u9053', '\u672c\u5730 SDK'),
              _FormLine(
                '\u8f6c\u53d1\u89c4\u5219',
                '\u5df2\u914d\u7f6e ${widget.forwardingSettings.routes.length} \u6761\uff0c\u672a\u914d\u7f6e\u6765\u6e90\u9ed8\u8ba4\u8df3\u8fc7',
              ),
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
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: trailingWidget,
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final background = primary
        ? WKColors.brand500
        : danger
        ? WKColors.danger.withValues(alpha: 0.08)
        : WKColors.surfaceSoft;
    final foreground = primary
        ? WKColors.white
        : danger
        ? WKColors.danger
        : WKColors.colorDark;
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
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: active
              ? const Color(0xFFEAF2FF)
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
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        backgroundColor: active
            ? const Color(0xFFEAF2FF)
            : WKColors.surfaceSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? WKColors.brand500 : WKColors.color999,
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

TextStyle _terminalStyle(Color color) {
  return TextStyle(
    fontFamily: 'Consolas',
    fontSize: 12,
    color: color,
    height: 1.2,
  );
}

class _WidgetDataTable extends StatelessWidget {
  const _WidgetDataTable({
    this.scrollbarKey,
    required this.columns,
    required this.rows,
  });

  final Key? scrollbarKey;
  final List<String> columns;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    return _HorizontalTableScroll(
      scrollbarKey: scrollbarKey,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 58,
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
  const _HorizontalTableScroll({required this.child, this.scrollbarKey});

  final Widget child;
  final Key? scrollbarKey;

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
      key: widget.scrollbarKey,
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

Widget _tableText(String text) {
  return Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontFamily: WKFontFamily.primary,
      fontSize: 13,
      color: WKColors.colorDark,
    ),
  );
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
            width: 92,
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
              height: 34,
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
                    maxLines: 1,
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

String _formatObservedAt(DateTime? value) {
  if (value == null) {
    return '\u672a\u89c2\u5bdf';
  }
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
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
  if (normalized.contains('bot') || normalized.contains('robot')) {
    return '\u673a\u5668\u4eba';
  }
  if (normalized.contains('dm') || normalized.contains('single')) {
    return '\u5355\u804a';
  }
  return '\u7fa4\u804a';
}
