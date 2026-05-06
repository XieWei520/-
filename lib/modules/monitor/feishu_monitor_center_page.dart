import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'monitor_models.dart';
import 'monitor_repository.dart';

typedef FeishuSnapshotLoader = Future<FeishuMonitorSnapshot> Function();
typedef MonitorGroupsLoader = Future<List<MonitorSelectableGroup>> Function();
typedef PairingCodeCreator =
    Future<MonitorPairingCode> Function(String deviceName);
typedef FeishuRouteCreator =
    Future<MonitorRoute> Function(CreateFeishuMonitorRouteRequest request);
typedef MonitorRouteAction = Future<void> Function(String routeId);
typedef MonitorRouteCallback = void Function(String routeId);

class FeishuMonitorCenterPage extends StatefulWidget {
  FeishuMonitorCenterPage({
    super.key,
    MonitorRepository? repository,
    this.loadSnapshot,
    this.loadDestinationGroups,
    this.onCreatePairingCode,
    this.onCreateRoute,
    this.onPauseRoute,
    this.onResumeRoute,
    this.onViewRouteLogs,
    this.onDownloadAgent,
  }) : _repository = repository ?? MonitorRepository();

  final MonitorRepository _repository;
  final FeishuSnapshotLoader? loadSnapshot;
  final MonitorGroupsLoader? loadDestinationGroups;
  final PairingCodeCreator? onCreatePairingCode;
  final FeishuRouteCreator? onCreateRoute;
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

  Future<void> _refresh() async {
    final nextSnapshot = _loadSnapshot();
    setState(() {
      _snapshotFuture = nextSnapshot;
    });
    await _snapshotFuture;
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

  Future<void> _openCreateRouteDialog() async {
    final groups = await _loadDestinationGroups();
    if (!mounted) {
      return;
    }
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _CreateFeishuRouteDialog(
        groups: groups,
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
                    onNewRoute: data.hasAgent ? _openCreateRouteDialog : null,
                    onDownloadAgent: widget.onDownloadAgent,
                  ),
                  const SizedBox(height: WKSpace.md),
                  if (!data.hasAgent)
                    _AgentOnboardingCard(
                      pairingCode: _pairingCode,
                      isCreating: _isCreatingPairingCode,
                      onCreatePairingCode: _createPairingCode,
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
                    for (final agent in data.agents) _AgentCard(agent: agent),
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
          icon: const Icon(Icons.add_rounded),
          label: const Text('新建飞书监控规则'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('feishu-monitor-download-agent'),
          onPressed: onDownloadAgent,
          icon: const Icon(Icons.download_rounded),
          label: const Text('下载 Windows Agent'),
        ),
      ],
    );
  }
}

class _AgentOnboardingCard extends StatelessWidget {
  const _AgentOnboardingCard({
    required this.pairingCode,
    required this.isCreating,
    required this.onCreatePairingCode,
    required this.onDownloadAgent,
  });

  final MonitorPairingCode? pairingCode;
  final bool isCreating;
  final VoidCallback onCreatePairingCode;
  final VoidCallback? onDownloadAgent;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '还没有绑定 Windows Agent',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
                child: Text(isCreating ? '生成中...' : '生成配对码'),
              ),
              OutlinedButton(
                onPressed: onDownloadAgent,
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
  const _AgentCard({required this.agent});

  final MonitorAgent agent;

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
              TextButton(onPressed: () {}, child: const Text('重新配对')),
              TextButton(onPressed: () {}, child: const Text('查看日志')),
              TextButton(onPressed: () {}, child: const Text('更新 Agent')),
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
    required this.onSubmit,
  });

  final List<MonitorSelectableGroup> groups;
  final FeishuRouteCreator onSubmit;

  @override
  State<_CreateFeishuRouteDialog> createState() =>
      _CreateFeishuRouteDialogState();
}

class _CreateFeishuRouteDialogState extends State<_CreateFeishuRouteDialog> {
  final _chatController = TextEditingController();
  MonitorSelectableGroup? _selectedGroup;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.groups.isEmpty ? null : widget.groups.first;
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final chatName = _chatController.text.trim();
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
    return AlertDialog(
      title: const Text('新建飞书监控规则'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('feishu-route-source-chat-input'),
              controller: _chatController,
              decoration: const InputDecoration(
                labelText: '飞书群名称',
                hintText: '例如：新闻群',
              ),
            ),
            const SizedBox(height: WKSpace.md),
            DropdownButtonFormField<MonitorSelectableGroup>(
              value: _selectedGroup,
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
