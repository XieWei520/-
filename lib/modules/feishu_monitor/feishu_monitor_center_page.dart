import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../data/models/group.dart';
import '../../service/api/group_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'feishu_monitor_forwarding_service.dart';
import 'feishu_monitor_shell_client.dart';
import 'feishu_monitor_shell_models.dart';

enum _ConsoleTab { logs, rules, groups, images, settings }

typedef FeishuMonitorTargetGroupLoader = Future<List<GroupInfo>> Function();

class FeishuMonitorCenterPage extends StatefulWidget {
  FeishuMonitorCenterPage({
    super.key,
    FeishuMonitorShellClient? client,
    FeishuMonitorForwardingService? forwardingService,
    FeishuMonitorForwardingSettingsStore? forwardingSettingsStore,
    FeishuMonitorTargetGroupLoader? loadTargetGroups,
  }) : client = client ?? _DefaultFeishuMonitorShellClient(),
       forwardingService =
           forwardingService ?? FeishuMonitorForwardingService(),
       forwardingSettingsStore =
           forwardingSettingsStore ??
           const SharedPreferencesFeishuMonitorForwardingSettingsStore(),
       loadTargetGroups = loadTargetGroups ?? GroupApi.instance.getMyGroups;

  final FeishuMonitorShellClient client;
  final FeishuMonitorForwardingService forwardingService;
  final FeishuMonitorForwardingSettingsStore forwardingSettingsStore;
  final FeishuMonitorTargetGroupLoader loadTargetGroups;

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

  Future<void> _runAction(Future<void> Function() action) async {
    await action();
    await _refresh();
  }

  Future<void> _saveForwardingSettings(
    FeishuMonitorForwardingSettings settings,
  ) {
    _forwardingSettings = settings;
    return widget.forwardingSettingsStore.save(settings);
  }

  Future<void> _configureRouteForConversation(
    FeishuMonitorObservedConversation conversation,
  ) async {
    final selected = await showModalBottomSheet<GroupInfo>(
      context: context,
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

    final now = DateTime.now().toUtc();
    final sourceConversationId = conversation.id.trim();
    final targetGroupName = await _resolveTargetGroupTitle(selected);
    if (!mounted) {
      return;
    }
    FeishuMonitorForwardingRoute? existing;
    for (final route in _forwardingSettings.routes) {
      if (route.sourceConversationId.trim() == sourceConversationId) {
        existing = route;
        break;
      }
    }
    final route = FeishuMonitorForwardingRoute(
      id: existing?.id ?? _routeIdForConversation(conversation),
      enabled: existing?.enabled ?? true,
      sourceConversationId: sourceConversationId,
      sourceConversationName: conversation.name.trim(),
      sourceConversationType: conversation.type.trim(),
      targetGroupId: selected.groupNo,
      targetGroupName: targetGroupName,
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
    setState(() {
      _forwardingSettings = next;
    });
    await _saveForwardingSettings(next);
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
      title: '飞书信息监控中心',
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
            _StatusOverview(status: status, loading: _loading, error: _error),
            const SizedBox(height: WKSpace.sm),
            _QuickActions(
              loading: _loading,
              forwarding: _forwarding,
              autoForwarding: _forwardingSettings.enabled,
              forwardingResult: _forwardingResult,
              routeCount: _forwardingSettings.routes.length,
              onStartCapture: _loading
                  ? null
                  : () => _runAction(widget.client.startCapture),
              onStopCapture: _loading
                  ? null
                  : () => _runAction(widget.client.stopCapture),
              onReloadRuntime: _loading
                  ? null
                  : () => _runAction(widget.client.reloadRuntime),
              onForwardRecentEvents: _forwarding ? null : _forwardRecentEvents,
              onAutoForwardingChanged: (value) async {
                final nextSettings = _forwardingSettings.copyWith(
                  enabled: value,
                );
                setState(() {
                  _forwardingSettings = nextSettings;
                });
                await widget.forwardingSettingsStore.save(nextSettings);
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
  });

  final FeishuMonitorShellStatus? status;
  final bool loading;
  final String error;

  @override
  Widget build(BuildContext context) {
    final online = status?.isOnline ?? false;
    final loggedIn = status?.loginState == 'logged_in';
    final running = status?.isCapturing ?? false;
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
                value: '${status?.messagesToday ?? 0}',
                caption: '消息 ${status?.observedMessages.length ?? 0}',
              ),
              _MetricTile(
                label: '今日成功',
                value: '${status?.deliveriesSucceededToday ?? 0}',
                tone: _Tone.ok,
                caption: '投递成功',
              ),
              _MetricTile(
                label: '今日失败',
                value: '${status?.deliveriesFailedToday ?? 0}',
                tone: (status?.deliveriesFailedToday ?? 0) > 0
                    ? _Tone.bad
                    : _Tone.ok,
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
            label: '启动监控',
            onTap: widget.onStartCapture,
          ),
          _ActionButton(
            key: const ValueKey('feishu-monitor-stop-capture-button'),
            label: '停止监控',
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
  const _TargetGroupPicker({required this.loadGroups});

  final FeishuMonitorTargetGroupLoader loadGroups;

  @override
  State<_TargetGroupPicker> createState() => _TargetGroupPickerState();
}

class _TargetGroupPickerState extends State<_TargetGroupPicker> {
  late final Future<List<_TargetGroupOption>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _loadGroupOptions();
  }

  Future<List<_TargetGroupOption>> _loadGroupOptions() async {
    final groups = await widget.loadGroups();
    final activeGroups = groups.where(_isSelectableTargetGroup);
    return Future.wait(activeGroups.map(_TargetGroupOption.resolve));
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
        child: FutureBuilder<List<_TargetGroupOption>>(
          future: _groupsFuture,
          builder: (context, snapshot) {
            final groups = snapshot.data ?? const <_TargetGroupOption>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择目标悟空IM群',
                  style: TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: WKColors.colorDark,
                  ),
                ),
                const SizedBox(height: WKSpace.sm),
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
                    detail: '当前账号没有返回可选群组，请先创建或加入一个悟空IM群聊。',
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: WKColors.borderColor),
                      itemBuilder: (context, index) {
                        final option = groups[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            option.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: WKFontFamily.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: WKColors.colorDark,
                            ),
                          ),
                          subtitle: Text(
                            option.group.groupNo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: WKFontFamily.primary,
                              fontSize: 12,
                              color: WKColors.color999,
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(option.group),
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
    return 'route_${id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')}';
  }
  return 'route_${normalizeFeishuMonitorRouteName(conversation.name).replaceAll(' ', '_')}';
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
  });

  final _ConsoleTab selected;
  final FeishuMonitorShellStatus? status;
  final FeishuMonitorForwardingSettings forwardingSettings;
  final ValueChanged<FeishuMonitorObservedConversation> onConfigureRoute;

  @override
  Widget build(BuildContext context) {
    return switch (selected) {
      _ConsoleTab.logs => _RuntimeLogsTab(status: status),
      _ConsoleTab.rules => _ForwardingRulesTab(
        status: status,
        routes: forwardingSettings.routes,
      ),
      _ConsoleTab.groups => _FeishuGroupsTab(
        status: status,
        routes: forwardingSettings.routes,
        onConfigureRoute: onConfigureRoute,
      ),
      _ConsoleTab.images => const _ImageProcessingTab(),
      _ConsoleTab.settings => _SystemSettingsTab(
        status: status,
        routeCount: forwardingSettings.routes.length,
        autoForwarding: forwardingSettings.enabled,
      ),
    };
  }
}

class _RuntimeLogsTab extends StatelessWidget {
  const _RuntimeLogsTab({required this.status});

  final FeishuMonitorShellStatus? status;

  @override
  Widget build(BuildContext context) {
    final events = status?.recentEvents ?? const <FeishuMonitorMessageEvent>[];
    final visibleEvents = events.take(12).toList(growable: false);
    return _ConsoleCard(
      title: '运行日志',
      trailing: Wrap(
        spacing: 6,
        children: const [
          _FilterChip(label: '全部', active: true),
          _FilterChip(label: '成功'),
          _FilterChip(label: '错误'),
          _FilterChip(label: '捕获'),
          _FilterChip(label: '转发'),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: WKSpace.sm,
            runSpacing: WKSpace.xs,
            children: const [
              _SmallButton(label: '清空日志'),
              _SmallButton(label: '导出日志', primary: true),
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
            child: visibleEvents.isEmpty
                ? const _TerminalLine(
                    time: '--:--:--',
                    level: '等待',
                    source: 'shell',
                    message: '暂无标准化事件，等待飞书页面探针返回数据',
                  )
                : ListView.builder(
                    itemCount: visibleEvents.length,
                    itemBuilder: (context, index) {
                      final event = visibleEvents[index];
                      return _TerminalLine(
                        time: _formatTime(event.observedAt),
                        level: '成功',
                        source: event.captureSource.isEmpty
                            ? 'probe'
                            : event.captureSource,
                        message:
                            '${event.conversationName} / ${event.senderName}: ${event.text}',
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ForwardingRulesTab extends StatelessWidget {
  const _ForwardingRulesTab({required this.status, required this.routes});

  final FeishuMonitorShellStatus? status;
  final List<FeishuMonitorForwardingRoute> routes;

  @override
  Widget build(BuildContext context) {
    return _ConsoleCard(
      title: '\u8f6c\u53d1\u89c4\u5219',
      trailing: Wrap(
        spacing: WKSpace.xs,
        children: const [
          _SmallButton(label: '\u6279\u91cf\u5bfc\u5165'),
          _SmallButton(label: '\u4e0b\u8f7d\u6a21\u677f'),
          _SmallButton(label: '\u65b0\u589e\u89c4\u5219', primary: true),
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
          : _DataTable(
              columns: const [
                '\u542f\u7528',
                '\u89c4\u5219\u540d\u79f0',
                '\u6765\u6e90\u98de\u4e66\u7fa4',
                '\u76ee\u6807\u609f\u7a7aIM\u7fa4',
                '\u76ee\u6807\u65b9\u5f0f',
                '\u4eca\u65e5\u6210\u529f',
                '\u4eca\u65e5\u5931\u8d25',
                '\u64cd\u4f5c',
              ],
              rows: [
                for (final route in routes)
                  [
                    route.enabled ? '\u542f\u7528' : '\u5173\u95ed',
                    route.sourceConversationName.trim().isEmpty
                        ? route.id
                        : route.sourceConversationName.trim(),
                    route.sourceConversationId.trim(),
                    route.targetGroupName.trim().isEmpty
                        ? route.targetGroupId.trim()
                        : route.targetGroupName.trim(),
                    '\u672c\u5730 SDK',
                    '${status?.deliveriesSucceededToday ?? 0}',
                    '${status?.deliveriesFailedToday ?? 0}',
                    '\u7f16\u8f91  \u6d4b\u8bd5  \u5220\u9664',
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
  });

  final FeishuMonitorShellStatus? status;
  final List<FeishuMonitorForwardingRoute> routes;
  final ValueChanged<FeishuMonitorObservedConversation> onConfigureRoute;

  @override
  Widget build(BuildContext context) {
    final conversations =
        status?.observedConversations ??
        const <FeishuMonitorObservedConversation>[];
    return _ConsoleCard(
      title: '\u98de\u4e66\u7fa4\u7ec4',
      trailing: const _SmallButton(
        label: '\u5237\u65b0\u5217\u8868',
        primary: true,
      ),
      child: _WidgetDataTable(
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
  const _ImageProcessingTab();

  @override
  Widget build(BuildContext context) {
    return _ConsoleCard(
      title: '\u56fe\u7247\u5904\u7406',
      trailing: const _SmallButton(
        label: '\u4fdd\u5b58\u8bbe\u7f6e',
        primary: true,
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

class _SystemSettingsTab extends StatelessWidget {
  const _SystemSettingsTab({
    required this.status,
    required this.routeCount,
    required this.autoForwarding,
  });

  final FeishuMonitorShellStatus? status;
  final int routeCount;
  final bool autoForwarding;

  @override
  Widget build(BuildContext context) {
    return _ConsoleCard(
      title: '\u7cfb\u7edf\u8bbe\u7f6e',
      trailing: const _SmallButton(
        label: '\u4fdd\u5b58\u8bbe\u7f6e',
        primary: true,
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
                status?.runtimeUrl ?? '\u672a\u52a0\u8f7d',
              ),
            ],
          );
          final forwardingSettings = _SettingsPanel(
            title: '\u8f6c\u53d1\u7b56\u7565',
            rows: [
              _FormLine(
                '\u81ea\u52a8\u8f6c\u53d1',
                autoForwarding ? '\u5f00\u542f' : '\u5173\u95ed',
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
                '\u5df2\u914d\u7f6e $routeCount \u6761\uff0c\u672a\u914d\u7f6e\u6765\u6e90\u9ed8\u8ba4\u8df3\u8fc7',
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
  const _FilterChip({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEAF2FF) : WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
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
  const _SmallButton({required this.label, this.primary = false});

  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary ? WKColors.brand500 : WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.sm),
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

class _DataTable extends StatelessWidget {
  const _DataTable({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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
                      child: Text(
                        cell,
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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
              child: Text(
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
  const _FormLine(this.label, this.value);

  final String label;
  final String value;
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
