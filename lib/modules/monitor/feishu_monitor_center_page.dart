import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'monitor_models.dart';
import 'monitor_local_agent_binder.dart';
import 'monitor_repository.dart';

typedef FeishuSnapshotLoader = Future<FeishuMonitorSnapshot> Function();
typedef MonitorGroupsLoader = Future<List<MonitorSelectableGroup>> Function();
typedef FeishuChatsLoader = Future<List<String>> Function();
typedef PairingCodeCreator =
    Future<MonitorPairingCode> Function(String deviceName);
typedef LocalAgentBinder =
    Future<LocalAgentBindResult> Function(LocalAgentBindRequest request);
typedef LocalAgentAction = Future<LocalAgentActionResult> Function();
typedef FeishuRouteCreator =
    Future<MonitorRoute> Function(CreateFeishuMonitorRouteRequest request);
typedef MonitorRouteAction = Future<void> Function(String routeId);
typedef MonitorRouteCallback = void Function(String routeId);

const Size _monitorActionButtonSize = Size(220, 48);

final ButtonStyle _monitorFilledActionButtonStyle = FilledButton.styleFrom(
  fixedSize: _monitorActionButtonSize,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(WKRadius.lg),
  ),
);

final ButtonStyle _monitorOutlinedActionButtonStyle = OutlinedButton.styleFrom(
  fixedSize: _monitorActionButtonSize,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(WKRadius.lg),
  ),
);

class FeishuMonitorCenterPage extends StatefulWidget {
  FeishuMonitorCenterPage({
    super.key,
    MonitorRepository? repository,
    this.loadSnapshot,
    this.loadDestinationGroups,
    this.loadFeishuChats,
    this.onCreatePairingCode,
    this.onCreateRoute,
    this.onBindLocalAgent,
    this.onOpenBrowserLogin,
    this.onCheckBrowserStatus,
    this.onClearBrowserProfile,
    this.onListenOnce,
    this.onRefreshAgentStatus,
    this.onPauseRoute,
    this.onResumeRoute,
    this.onViewRouteLogs,
    this.onDownloadAgent,
  }) : _repository = repository ?? MonitorRepository();

  final MonitorRepository _repository;
  final FeishuSnapshotLoader? loadSnapshot;
  final MonitorGroupsLoader? loadDestinationGroups;
  final FeishuChatsLoader? loadFeishuChats;
  final PairingCodeCreator? onCreatePairingCode;
  final FeishuRouteCreator? onCreateRoute;
  final LocalAgentBinder? onBindLocalAgent;
  final LocalAgentAction? onOpenBrowserLogin;
  final LocalAgentAction? onCheckBrowserStatus;
  final LocalAgentAction? onClearBrowserProfile;
  final LocalAgentAction? onListenOnce;
  final LocalAgentAction? onRefreshAgentStatus;
  final MonitorRouteAction? onPauseRoute;
  final MonitorRouteAction? onResumeRoute;
  final MonitorRouteCallback? onViewRouteLogs;
  final VoidCallback? onDownloadAgent;

  @override
  State<FeishuMonitorCenterPage> createState() =>
      _FeishuMonitorCenterPageState();
}

class _FeishuMonitorCenterPageState extends State<FeishuMonitorCenterPage> {
  late Future<FeishuMonitorSnapshot> _snapshotFuture;
  MonitorPairingCode? _pairingCode;
  bool _isCreatingPairingCode = false;
  bool _isBindingLocalAgent = false;
  bool _isRepairingAgent = false;
  bool _isRunningBrowserAction = false;
  bool _isRefreshingAgentStatus = false;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<FeishuMonitorSnapshot> _loadSnapshot() {
    return widget.loadSnapshot?.call() ??
        widget._repository.loadFeishuSnapshot();
  }

  Future<List<MonitorSelectableGroup>> _loadDestinationGroups() {
    return widget.loadDestinationGroups?.call() ??
        widget._repository.loadDestinationGroups();
  }

  Future<List<String>> _loadFeishuChats() {
    return widget.loadFeishuChats?.call() ??
        MonitorLocalAgentBinder().listChats();
  }

  Future<void> _refresh() async {
    final nextSnapshot = _loadSnapshot();
    setState(() {
      _snapshotFuture = nextSnapshot;
    });
    await _snapshotFuture;
  }

  Future<void> _runBrowserAction(LocalAgentAction action) async {
    if (_isRunningBrowserAction) {
      return;
    }
    setState(() => _isRunningBrowserAction = true);
    try {
      final result = await action();
      _showSnackBar(result.message);
      await _refresh();
    } catch (error) {
      if (mounted) {
        _showSnackBar('椋炰功娴忚鍣ㄦ搷浣滃け璐ワ細$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isRunningBrowserAction = false);
      }
    }
  }

  Future<void> _refreshAgentStatus() async {
    if (_isRefreshingAgentStatus) {
      return;
    }
    setState(() => _isRefreshingAgentStatus = true);
    try {
      final binder =
          widget.onRefreshAgentStatus ??
          MonitorLocalAgentBinder().heartbeatOnce;
      final result = await binder();
      _showSnackBar(result.message);
      await _refresh();
    } catch (error) {
      if (mounted) {
        _showSnackBar('更新 Agent 状态失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingAgentStatus = false);
      }
    }
  }

  Future<void> _createPairingCode() async {
    if (_isCreatingPairingCode) {
      return;
    }
    setState(() => _isCreatingPairingCode = true);
    try {
      final creator =
          widget.onCreatePairingCode ?? widget._repository.createPairingCode;
      final code = await creator('Windows Agent');
      if (mounted) {
        setState(() => _pairingCode = code);
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('生成配对码失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingPairingCode = false);
      }
    }
  }

  Future<MonitorPairingCode?> _createFreshPairingCode() async {
    final creator =
        widget.onCreatePairingCode ?? widget._repository.createPairingCode;
    final code = await creator('Windows Agent');
    if (mounted) {
      setState(() => _pairingCode = code);
    }
    return code;
  }

  Future<void> _bindLocalAgent() async {
    if (_isBindingLocalAgent || _isCreatingPairingCode) {
      return;
    }
    setState(() => _isBindingLocalAgent = true);
    try {
      final code = await _createFreshPairingCode();
      if (code == null) {
        return;
      }
      final binder =
          widget.onBindLocalAgent ?? MonitorLocalAgentBinder().bindAndHeartbeat;
      final result = await binder(
        LocalAgentBindRequest(
          serverUrl: 'https://infoequity.qingyunshe.top',
          pairingCode: code.code,
          forcePair: _isRepairingAgent,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isRepairingAgent = false;
        _pairingCode = null;
      });
      _showSnackBar(result.message);
      await _refresh();
    } catch (error) {
      if (mounted) {
        _showSnackBar('一键绑定失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isBindingLocalAgent = false);
      }
    }
  }

  void _startRepairAgent() {
    setState(() {
      _isRepairingAgent = true;
      _pairingCode = null;
    });
    _showSnackBar('已进入重新配对模式，请重新生成配对码或一键绑定并上线');
  }

  Future<void> _openCreateRouteDialog() async {
    final groups = await _loadDestinationGroups();
    if (!mounted) {
      return;
    }
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _CreateFeishuRouteDialog(
        groups: groups,
        loadFeishuChats: _loadFeishuChats,
        onSubmit: (request) async {
          final creator =
              widget.onCreateRoute ?? widget._repository.createFeishuRoute;
          final route = await creator(request);
          if (mounted) {
            final nextSnapshot = _loadSnapshot();
            setState(() {
              _snapshotFuture = nextSnapshot;
            });
          }
          return route;
        },
      ),
    );
    if (created == true && mounted) {
      _showSnackBar('飞书监控规则已创建');
    }
  }

  Future<void> _pauseRoute(String routeId) async {
    final action = widget.onPauseRoute ?? widget._repository.pauseRoute;
    await action(routeId);
    if (mounted) {
      final nextSnapshot = _loadSnapshot();
      setState(() {
        _snapshotFuture = nextSnapshot;
      });
    }
  }

  Future<void> _resumeRoute(String routeId) async {
    final action = widget.onResumeRoute ?? widget._repository.resumeRoute;
    await action(routeId);
    if (mounted) {
      final nextSnapshot = _loadSnapshot();
      setState(() {
        _snapshotFuture = nextSnapshot;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '飞书信息监控中心',
      trailingWidth: 64,
      trailing: WKSubPageAction(text: '刷新', onTap: _refresh),
      body: FutureBuilder<FeishuMonitorSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: '加载失败：${snapshot.error}',
              onRetry: _refresh,
            );
          }
          final data = snapshot.data ?? FeishuMonitorSnapshot.empty;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeroCard(),
                  const SizedBox(height: WKSpace.md),
                  _StatsRow(stats: data.stats),
                  const SizedBox(height: WKSpace.md),
                  _ActionRow(
                    onNewRoute: data.hasAgent && !_isRepairingAgent
                        ? _openCreateRouteDialog
                        : null,
                    onDownloadAgent: widget.onDownloadAgent,
                  ),
                  const SizedBox(height: WKSpace.md),
                  if (data.hasAgent)
                    _BrowserStatusCard(
                      status: data.browserStatus,
                      isBusy: _isRunningBrowserAction,
                      onOpenBrowserLogin: widget.onOpenBrowserLogin != null
                          ? () => _runBrowserAction(widget.onOpenBrowserLogin!)
                          : null,
                      onCheckBrowserStatus: widget.onCheckBrowserStatus != null
                          ? () =>
                                _runBrowserAction(widget.onCheckBrowserStatus!)
                          : null,
                      onListenOnce: widget.onListenOnce != null
                          ? () => _runBrowserAction(widget.onListenOnce!)
                          : null,
                      onClearBrowserProfile:
                          widget.onClearBrowserProfile != null
                          ? () =>
                                _runBrowserAction(widget.onClearBrowserProfile!)
                          : null,
                    ),
                  const SizedBox(height: WKSpace.md),
                  if (!data.hasAgent || _isRepairingAgent)
                    _AgentOnboardingCard(
                      title: _isRepairingAgent
                          ? '\u91cd\u65b0\u914d\u5bf9 Windows Agent'
                          : '\u8fd8\u6ca1\u6709\u7ed1\u5b9a Windows Agent',
                      pairingCode: _pairingCode,
                      isCreating: _isCreatingPairingCode,
                      isBinding: _isBindingLocalAgent,
                      onCreatePairingCode: _createPairingCode,
                      onBindLocalAgent: _bindLocalAgent,
                      onDownloadAgent: widget.onDownloadAgent,
                    )
                  else ...[
                    const _SectionTitle(title: '监控规则'),
                    if (data.routes.isEmpty)
                      _EmptyCard(
                        title: '还没有飞书监控规则',
                        description: '创建一条飞书 Web 群 → 悟空 IM 群规则后，Agent 会开始监听。',
                        actionText: '新建飞书监控规则',
                        onAction: _openCreateRouteDialog,
                      )
                    else
                      for (final route in data.routes)
                        _RouteCard(
                          route: route,
                          onPause: () => _pauseRoute(route.id),
                          onResume: () => _resumeRoute(route.id),
                          onLogs: () => widget.onViewRouteLogs?.call(route.id),
                        ),
                    const SizedBox(height: WKSpace.md),
                    const _SectionTitle(title: 'Windows Agent'),
                    for (final agent in data.agents)
                      _AgentCard(
                        agent: agent,
                        isRefreshing: _isRefreshingAgentStatus,
                        onRepair: _startRepairAgent,
                        onRefresh: _refreshAgentStatus,
                      ),
                  ],
                  const SizedBox(height: WKSpace.md),
                  const _SectionTitle(title: '最近日志'),
                  if (data.logs.isEmpty)
                    const _MutedCard(text: '暂无运行日志')
                  else
                    _LogsCard(logs: data.logs),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '飞书信息监控中心',
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
          SizedBox(height: WKSpace.xs),
          Text(
            '实时监听你已登录飞书账号可见的群消息，并自动转发到悟空 IM 群。',
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 14,
              height: 1.45,
              color: WKColors.color999,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final MonitorStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(label: '运行中规则', value: '${stats.runningRoutes}'),
        ),
        const SizedBox(width: WKSpace.sm),
        Expanded(
          child: _StatCard(label: '今日转发', value: '${stats.todayForwarded}'),
        ),
        const SizedBox(width: WKSpace.sm),
        Expanded(
          child: _StatCard(label: '异常提醒', value: '${stats.alerts}'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(WKSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: WKColors.color999, fontSize: 12),
          ),
          const SizedBox(height: WKSpace.xs),
          Text(
            value,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.onNewRoute, required this.onDownloadAgent});

  final VoidCallback? onNewRoute;
  final VoidCallback? onDownloadAgent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: WKSpace.sm,
      runSpacing: WKSpace.sm,
      children: [
        FilledButton.icon(
          key: const ValueKey('feishu-monitor-new-route'),
          onPressed: onNewRoute,
          style: _monitorFilledActionButtonStyle,
          icon: const Icon(Icons.add_rounded),
          label: const Text('新建飞书监控规则'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('feishu-monitor-download-agent'),
          onPressed: onDownloadAgent,
          style: _monitorOutlinedActionButtonStyle,
          icon: const Icon(Icons.download_rounded),
          label: const Text('下载 Windows Agent'),
        ),
      ],
    );
  }
}

class _BrowserStatusCard extends StatelessWidget {
  const _BrowserStatusCard({
    required this.status,
    required this.isBusy,
    required this.onOpenBrowserLogin,
    required this.onCheckBrowserStatus,
    required this.onListenOnce,
    required this.onClearBrowserProfile,
  });

  final MonitorBrowserStatus status;
  final bool isBusy;
  final VoidCallback? onOpenBrowserLogin;
  final VoidCallback? onCheckBrowserStatus;
  final VoidCallback? onListenOnce;
  final VoidCallback? onClearBrowserProfile;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '飞书信息监控中心 · 浏览器状态',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: WKSpace.xs),
          const Text('Browser: Chromium'),
          const Text('Environment: 专属隔离环境'),
          Text('登录状态：${status.loginStatusLabel}'),
          Text('最后检测：${status.observedAt.isEmpty ? '暂无' : status.observedAt}'),
          Text(
            '最后错误：${status.errorMessage.isEmpty ? '暂无' : status.errorMessage}',
          ),
          const SizedBox(height: WKSpace.md),
          Wrap(
            spacing: WKSpace.sm,
            runSpacing: WKSpace.sm,
            children: [
              FilledButton(
                key: const ValueKey('feishu-monitor-open-browser-login'),
                onPressed: isBusy ? null : onOpenBrowserLogin,
                style: _monitorFilledActionButtonStyle,
                child: const Text('打开飞书登录'),
              ),
              FilledButton(
                key: const ValueKey('feishu-monitor-check-browser-status'),
                onPressed: isBusy ? null : onCheckBrowserStatus,
                style: _monitorFilledActionButtonStyle,
                child: const Text('检查登录状态'),
              ),
              FilledButton(
                key: const ValueKey('feishu-monitor-listen-once'),
                onPressed: isBusy ? null : onListenOnce,
                style: _monitorFilledActionButtonStyle,
                child: const Text('测试监听一次'),
              ),
              OutlinedButton(
                key: const ValueKey('feishu-monitor-clear-browser-profile'),
                onPressed: isBusy ? null : onClearBrowserProfile,
                style: _monitorOutlinedActionButtonStyle,
                child: const Text('清除飞书登录'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgentOnboardingCard extends StatelessWidget {
  const _AgentOnboardingCard({
    required this.title,
    required this.pairingCode,
    required this.isCreating,
    required this.isBinding,
    required this.onCreatePairingCode,
    required this.onBindLocalAgent,
    required this.onDownloadAgent,
  });

  final String title;
  final MonitorPairingCode? pairingCode;
  final bool isCreating;
  final bool isBinding;
  final VoidCallback onCreatePairingCode;
  final VoidCallback onBindLocalAgent;
  final VoidCallback? onDownloadAgent;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: WKSpace.sm),
          const Text('1. 下载 Windows Agent'),
          const Text('2. 使用配对码绑定设备'),
          const Text('3. 扫码登录飞书 Web'),
          const Text('4. 创建飞书群转发规则'),
          const SizedBox(height: WKSpace.md),
          Wrap(
            spacing: WKSpace.sm,
            runSpacing: WKSpace.sm,
            children: [
              FilledButton(
                key: const ValueKey('feishu-monitor-create-pairing'),
                onPressed: isCreating ? null : onCreatePairingCode,
                style: _monitorFilledActionButtonStyle,
                child: Text(isCreating ? '生成中...' : '生成配对码'),
              ),
              FilledButton(
                key: const ValueKey('feishu-monitor-one-click-bind'),
                onPressed: (isCreating || isBinding) ? null : onBindLocalAgent,
                style: _monitorFilledActionButtonStyle,
                child: Text(isBinding ? '绑定中...' : '一键绑定并上线'),
              ),
              OutlinedButton(
                key: const ValueKey('feishu-monitor-onboarding-download-agent'),
                onPressed: onDownloadAgent,
                style: _monitorOutlinedActionButtonStyle,
                child: const Text('下载 Windows Agent'),
              ),
            ],
          ),
          if (pairingCode != null) ...[
            const SizedBox(height: WKSpace.md),
            Text(
              '配对码：${pairingCode!.code}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('有效期至：${pairingCode!.expiresAt}'),
          ],
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.onPause,
    required this.onResume,
    required this.onLogs,
  });

  final MonitorRoute route;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onLogs;

  @override
  Widget build(BuildContext context) {
    final isRunning = route.status == MonitorRouteStatus.running;
    return _Panel(
      margin: const EdgeInsets.only(bottom: WKSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: WKSpace.xs),
          Text('来源：${route.sourceTypeLabel}'),
          Text('状态：${route.statusLabel}'),
          Text(
            '最近转发：${route.lastForwardedAt.isEmpty ? '暂无' : route.lastForwardedAt}',
          ),
          Text('今日转发：${route.todayForwardedCount} 条'),
          const SizedBox(height: WKSpace.sm),
          Wrap(
            spacing: WKSpace.xs,
            children: [
              TextButton(
                key: ValueKey(
                  'monitor-route-${isRunning ? 'pause' : 'resume'}-${route.id}',
                ),
                onPressed: isRunning ? onPause : onResume,
                child: Text(isRunning ? '暂停' : '恢复'),
              ),
              TextButton(
                key: ValueKey('monitor-route-logs-${route.id}'),
                onPressed: onLogs,
                child: const Text('查看日志'),
              ),
              TextButton(onPressed: () {}, child: const Text('编辑')),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.isRefreshing,
    required this.onRepair,
    required this.onRefresh,
  });

  final MonitorAgent agent;
  final bool isRefreshing;
  final VoidCallback onRepair;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      margin: const EdgeInsets.only(bottom: WKSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            agent.deviceName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: WKSpace.xs),
          Text('平台：${agent.platformLabel}'),
          Text('版本：${agent.version.isEmpty ? '未知' : agent.version}'),
          Text('状态：${agent.statusLabel}'),
          Text(
            '最近心跳：${agent.lastHeartbeatAt.isEmpty ? '暂无' : agent.lastHeartbeatAt}',
          ),
          const SizedBox(height: WKSpace.sm),
          Wrap(
            spacing: WKSpace.xs,
            children: [
              TextButton(
                key: const ValueKey('feishu-monitor-repair-agent'),
                onPressed: isRefreshing ? null : onRepair,
                child: const Text('重新配对'),
              ),
              TextButton(onPressed: () {}, child: const Text('查看日志')),
              TextButton(
                key: const ValueKey('feishu-monitor-refresh-agent-status'),
                onPressed: isRefreshing ? null : onRefresh,
                child: Text(isRefreshing ? '更新中...' : '更新 Agent 状态'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogsCard extends StatelessWidget {
  const _LogsCard({required this.logs});

  final List<MonitorLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final log in logs)
            Padding(
              padding: const EdgeInsets.only(bottom: WKSpace.xs),
              child: Text('${log.occurredAt} ${log.message}'),
            ),
        ],
      ),
    );
  }
}

class _CreateFeishuRouteDialog extends StatefulWidget {
  const _CreateFeishuRouteDialog({
    required this.groups,
    required this.loadFeishuChats,
    required this.onSubmit,
  });

  final List<MonitorSelectableGroup> groups;
  final FeishuChatsLoader loadFeishuChats;
  final FeishuRouteCreator onSubmit;

  @override
  State<_CreateFeishuRouteDialog> createState() =>
      _CreateFeishuRouteDialogState();
}

class _CreateFeishuRouteDialogState extends State<_CreateFeishuRouteDialog> {
  final _chatController = TextEditingController();
  final _chatSearchController = TextEditingController();
  List<String> _chatOptions = const <String>[];
  String? _selectedChat;
  MonitorSelectableGroup? _selectedGroup;
  bool _submitting = false;
  bool _loadingChats = true;
  String _chatLoadError = '';

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.groups.isEmpty ? null : widget.groups.first;
    _loadChats();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() {
      _loadingChats = true;
      _chatLoadError = '';
    });
    try {
      final chats = await widget.loadFeishuChats();
      final unique = <String>[];
      final seen = <String>{};
      for (final chat in chats) {
        final name = chat.trim();
        if (name.isEmpty || seen.contains(name)) {
          continue;
        }
        seen.add(name);
        unique.add(name);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _chatOptions = unique;
        _selectedChat = unique.isEmpty ? null : unique.first;
        _chatSearchController.clear();
        if (_selectedChat != null) {
          _chatController.text = _selectedChat!;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _chatLoadError = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingChats = false);
      }
    }
  }

  Future<void> _submit() async {
    final chatName = (_selectedChat ?? _chatController.text).trim();
    final group = _selectedGroup;
    if (chatName.isEmpty || group == null || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        CreateFeishuMonitorRouteRequest(
          sourceChatName: chatName,
          destinationGroupNo: group.groupNo,
          destinationGroupName: group.label,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredChatOptions = _filteredChatOptions();
    return AlertDialog(
      title: const Text('新建飞书监控规则'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loadingChats)
                const Padding(
                  padding: EdgeInsets.only(bottom: WKSpace.sm),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: WKSpace.sm),
                      Text('正在识别飞书群...'),
                    ],
                  ),
                )
              else if (_chatOptions.isNotEmpty)
                _DetectedFeishuChatPicker(
                  allChatsCount: _chatOptions.length,
                  filteredChats: filteredChatOptions,
                  selectedChat: _selectedChat,
                  searchController: _chatSearchController,
                  onSearchChanged: (_) => setState(() {}),
                  onSelected: (value) {
                    setState(() {
                      _selectedChat = value;
                      _chatController.text = value;
                    });
                  },
                )
              else
                TextField(
                  key: const ValueKey('feishu-route-source-chat-input'),
                  controller: _chatController,
                  decoration: InputDecoration(
                    labelText: '飞书群名称',
                    hintText: '例如：新闻群',
                    helperText: _chatLoadError.isEmpty
                        ? '未识别到飞书群，可手动输入'
                        : '自动识别失败，可手动输入',
                  ),
                ),
              const SizedBox(height: WKSpace.xs),
              TextButton.icon(
                key: const ValueKey('feishu-route-reload-chats'),
                onPressed: _loadingChats ? null : _loadChats,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新识别飞书群'),
              ),
              const SizedBox(height: WKSpace.md),
              DropdownButtonFormField<MonitorSelectableGroup>(
                initialValue: _selectedGroup,
                decoration: const InputDecoration(labelText: '悟空 IM 群'),
                items: [
                  for (final group in widget.groups)
                    DropdownMenuItem(value: group, child: Text(group.label)),
                ],
                onChanged: (value) => setState(() => _selectedGroup = value),
              ),
              const SizedBox(height: WKSpace.md),
              const Text('转发内容：文本、链接'),
              const Text('图片、文件：暂不支持，后续支持'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('feishu-route-submit'),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '创建中...' : '确认并启动'),
        ),
      ],
    );
  }

  List<String> _filteredChatOptions() {
    final keyword = _chatSearchController.text.trim().toLowerCase();
    if (keyword.isEmpty) {
      return _chatOptions;
    }
    return _chatOptions
        .where((chat) => chat.toLowerCase().contains(keyword))
        .toList(growable: false);
  }
}

class _DetectedFeishuChatPicker extends StatelessWidget {
  const _DetectedFeishuChatPicker({
    required this.allChatsCount,
    required this.filteredChats,
    required this.selectedChat,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSelected,
  });

  final int allChatsCount;
  final List<String> filteredChats;
  final String? selectedChat;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('feishu-route-source-chat-picker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '飞书群',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: WKSpace.xxs),
        Text(
          '已自动识别 $allChatsCount 个会话，可搜索或滚动选择',
          style: const TextStyle(fontSize: 12, color: WKColors.color999),
        ),
        const SizedBox(height: WKSpace.xxs),
        const Text(
          '如果群很多：请在 Chromium 飞书窗口手动滚动群列表，然后回到这里点“重新识别飞书群”，系统会增量合并。',
          style: TextStyle(fontSize: 12, color: WKColors.color999),
        ),
        const SizedBox(height: WKSpace.sm),
        TextField(
          key: const ValueKey('feishu-route-source-chat-search'),
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: '搜索飞书群名称',
            isDense: true,
          ),
        ),
        const SizedBox(height: WKSpace.sm),
        Container(
          key: const ValueKey('feishu-route-source-chat-list'),
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: WKColors.colorLine),
            borderRadius: BorderRadius.circular(WKRadius.md),
          ),
          child: filteredChats.isEmpty
              ? const Center(
                  child: Text(
                    '没有匹配的飞书群',
                    style: TextStyle(color: WKColors.color999),
                  ),
                )
              : Scrollbar(
                  child: ListView.separated(
                    itemCount: filteredChats.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: WKColors.colorLine),
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      final selected = chat == selectedChat;
                      return ListTile(
                        key: ValueKey('feishu-route-source-chat-$chat'),
                        dense: true,
                        selected: selected,
                        title: Text(
                          chat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: selected
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () => onSelected(chat),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: WKSpace.sm),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.description,
    required this.actionText,
    required this.onAction,
  });

  final String title;
  final String description;
  final String actionText;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: WKSpace.xs),
          Text(description, style: const TextStyle(color: WKColors.color999)),
          const SizedBox(height: WKSpace.sm),
          FilledButton(onPressed: onAction, child: Text(actionText)),
        ],
      ),
    );
  }
}

class _MutedCard extends StatelessWidget {
  const _MutedCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Text(text, style: const TextStyle(color: WKColors.color999)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: WKSpace.md),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(WKSpace.lg),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.lg),
        boxShadow: WKShadows.soft,
      ),
      child: child,
    );
  }
}
