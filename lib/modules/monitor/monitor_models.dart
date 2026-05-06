enum MonitorPlatform {
  feishu,
  dingtalk,
  xiaoe,
  unknown;

  String get apiValue {
    switch (this) {
      case MonitorPlatform.feishu:
        return 'feishu';
      case MonitorPlatform.dingtalk:
        return 'dingtalk';
      case MonitorPlatform.xiaoe:
        return 'xiaoe';
      case MonitorPlatform.unknown:
        return 'unknown';
    }
  }

  String get label {
    switch (this) {
      case MonitorPlatform.feishu:
        return '飞书';
      case MonitorPlatform.dingtalk:
        return '钉钉';
      case MonitorPlatform.xiaoe:
        return '小鹅通';
      case MonitorPlatform.unknown:
        return '未知平台';
    }
  }

  static MonitorPlatform parse(dynamic value) {
    switch (_toString(value)) {
      case 'feishu':
        return MonitorPlatform.feishu;
      case 'dingtalk':
        return MonitorPlatform.dingtalk;
      case 'xiaoe':
      case 'xiaoetong':
        return MonitorPlatform.xiaoe;
      default:
        return MonitorPlatform.unknown;
    }
  }
}

enum MonitorConnectorType {
  feishuWebGroup,
  dingtalkWebGroup,
  xiaoeWeb,
  unknown;

  String get apiValue {
    switch (this) {
      case MonitorConnectorType.feishuWebGroup:
        return 'feishu_web_group';
      case MonitorConnectorType.dingtalkWebGroup:
        return 'dingtalk_web_group';
      case MonitorConnectorType.xiaoeWeb:
        return 'xiaoe_web';
      case MonitorConnectorType.unknown:
        return 'unknown';
    }
  }

  String get label {
    switch (this) {
      case MonitorConnectorType.feishuWebGroup:
        return '飞书 Web 群';
      case MonitorConnectorType.dingtalkWebGroup:
        return '钉钉 Web 群';
      case MonitorConnectorType.xiaoeWeb:
        return '小鹅通 Web';
      case MonitorConnectorType.unknown:
        return '未知来源';
    }
  }

  static MonitorConnectorType parse(dynamic value) {
    switch (_toString(value)) {
      case 'feishu_web_group':
        return MonitorConnectorType.feishuWebGroup;
      case 'dingtalk_web_group':
        return MonitorConnectorType.dingtalkWebGroup;
      case 'xiaoe_web':
      case 'xiaoetong_web':
        return MonitorConnectorType.xiaoeWeb;
      default:
        return MonitorConnectorType.unknown;
    }
  }
}

enum MonitorRouteStatus {
  running,
  paused,
  loginRequired,
  agentOffline,
  destinationError,
  selectorError,
  unknown;

  String get apiValue {
    switch (this) {
      case MonitorRouteStatus.running:
        return 'running';
      case MonitorRouteStatus.paused:
        return 'paused';
      case MonitorRouteStatus.loginRequired:
        return 'login_required';
      case MonitorRouteStatus.agentOffline:
        return 'agent_offline';
      case MonitorRouteStatus.destinationError:
        return 'destination_error';
      case MonitorRouteStatus.selectorError:
        return 'selector_error';
      case MonitorRouteStatus.unknown:
        return 'unknown';
    }
  }

  String get label {
    switch (this) {
      case MonitorRouteStatus.running:
        return '运行中';
      case MonitorRouteStatus.paused:
        return '已暂停';
      case MonitorRouteStatus.loginRequired:
        return '需要登录';
      case MonitorRouteStatus.agentOffline:
        return 'Agent 离线';
      case MonitorRouteStatus.destinationError:
        return '目标 IM 异常';
      case MonitorRouteStatus.selectorError:
        return '页面结构异常';
      case MonitorRouteStatus.unknown:
        return '未知状态';
    }
  }

  static MonitorRouteStatus parse(dynamic value) {
    switch (_toString(value)) {
      case 'running':
        return MonitorRouteStatus.running;
      case 'paused':
        return MonitorRouteStatus.paused;
      case 'login_required':
        return MonitorRouteStatus.loginRequired;
      case 'agent_offline':
        return MonitorRouteStatus.agentOffline;
      case 'destination_error':
        return MonitorRouteStatus.destinationError;
      case 'selector_error':
        return MonitorRouteStatus.selectorError;
      default:
        return MonitorRouteStatus.unknown;
    }
  }
}

enum MonitorAgentStatus {
  online,
  offline,
  loginRequired,
  unknown;

  String get label {
    switch (this) {
      case MonitorAgentStatus.online:
        return '在线';
      case MonitorAgentStatus.offline:
        return '离线';
      case MonitorAgentStatus.loginRequired:
        return '需要登录';
      case MonitorAgentStatus.unknown:
        return '未知状态';
    }
  }

  static MonitorAgentStatus parse(dynamic value) {
    switch (_toString(value)) {
      case 'online':
        return MonitorAgentStatus.online;
      case 'offline':
        return MonitorAgentStatus.offline;
      case 'login_required':
        return MonitorAgentStatus.loginRequired;
      default:
        return MonitorAgentStatus.unknown;
    }
  }
}

class MonitorStats {
  const MonitorStats({
    required this.runningRoutes,
    required this.todayForwarded,
    required this.alerts,
  });

  final int runningRoutes;
  final int todayForwarded;
  final int alerts;

  factory MonitorStats.fromJson(Map<String, dynamic> json) {
    return MonitorStats(
      runningRoutes: _toInt(json['running_routes']),
      todayForwarded: _toInt(json['today_forwarded']),
      alerts: _toInt(json['alerts']),
    );
  }

  static const empty = MonitorStats(
    runningRoutes: 0,
    todayForwarded: 0,
    alerts: 0,
  );
}

class MonitorAgent {
  const MonitorAgent({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.version,
    required this.status,
    required this.lastHeartbeatAt,
  });

  final String id;
  final String deviceName;
  final String platform;
  final String version;
  final MonitorAgentStatus status;
  final String lastHeartbeatAt;

  String get statusLabel => status.label;

  String get platformLabel {
    switch (platform.toLowerCase()) {
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      case 'linux':
        return 'Linux';
      default:
        return platform.isEmpty ? '未知平台' : platform;
    }
  }

  factory MonitorAgent.fromJson(Map<String, dynamic> json) {
    return MonitorAgent(
      id: _toString(json['id'] ?? json['agent_id']),
      deviceName: _toString(json['device_name'], fallback: '未命名设备'),
      platform: _toString(json['platform'], fallback: 'unknown'),
      version: _toString(json['version'] ?? json['agent_version']),
      status: MonitorAgentStatus.parse(json['status']),
      lastHeartbeatAt: _toString(json['last_heartbeat_at']),
    );
  }
}

class MonitorRoute {
  const MonitorRoute({
    required this.id,
    required this.platform,
    required this.connectorType,
    required this.routeType,
    required this.sourceName,
    required this.destinationName,
    required this.status,
    required this.todayForwardedCount,
    required this.lastForwardedAt,
    required this.agentId,
    required this.includeText,
    required this.includeLinks,
    required this.includeImages,
    required this.includeFiles,
  });

  final String id;
  final MonitorPlatform platform;
  final MonitorConnectorType connectorType;
  final String routeType;
  final String sourceName;
  final String destinationName;
  final MonitorRouteStatus status;
  final int todayForwardedCount;
  final String lastForwardedAt;
  final String agentId;
  final bool includeText;
  final bool includeLinks;
  final bool includeImages;
  final bool includeFiles;

  String get title => '$sourceName → $destinationName';
  String get statusLabel => status.label;
  String get sourceTypeLabel => connectorType.label;

  factory MonitorRoute.fromJson(Map<String, dynamic> json) {
    return MonitorRoute(
      id: _toString(json['id'] ?? json['route_id']),
      platform: MonitorPlatform.parse(json['platform']),
      connectorType: MonitorConnectorType.parse(json['connector_type']),
      routeType: _toString(json['route_type']),
      sourceName: _toString(json['source_name'], fallback: '未命名来源'),
      destinationName: _toString(
        json['destination_name'],
        fallback: '未命名目标',
      ),
      status: MonitorRouteStatus.parse(json['status']),
      todayForwardedCount: _toInt(json['today_forwarded_count']),
      lastForwardedAt: _toString(json['last_forwarded_at']),
      agentId: _toString(json['agent_id']),
      includeText: _toBool(json['include_text'], fallback: true),
      includeLinks: _toBool(json['include_links'], fallback: true),
      includeImages: _toBool(json['include_images']),
      includeFiles: _toBool(json['include_files']),
    );
  }
}

class MonitorLogEntry {
  const MonitorLogEntry({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.message,
    this.routeId = '',
  });

  final String id;
  final String type;
  final String occurredAt;
  final String message;
  final String routeId;

  factory MonitorLogEntry.fromJson(Map<String, dynamic> json) {
    return MonitorLogEntry(
      id: _toString(json['id'] ?? json['event_id']),
      type: _toString(json['type']),
      occurredAt: _toString(json['occurred_at'] ?? json['created_at']),
      message: _toString(json['message'], fallback: '暂无详情'),
      routeId: _toString(json['route_id']),
    );
  }
}

class MonitorPairingCode {
  const MonitorPairingCode({required this.code, required this.expiresAt});

  final String code;
  final String expiresAt;

  factory MonitorPairingCode.fromJson(Map<String, dynamic> json) {
    return MonitorPairingCode(
      code: _toString(json['pairing_code'] ?? json['pairingCode']),
      expiresAt: _toString(json['expires_at'] ?? json['expiresAt']),
    );
  }
}

class MonitorSelectableGroup {
  const MonitorSelectableGroup({required this.groupNo, required this.name});

  final String groupNo;
  final String name;

  String get label => name.isEmpty ? groupNo : name;
}

class FeishuMonitorSnapshot {
  const FeishuMonitorSnapshot({
    required this.stats,
    required this.agents,
    required this.routes,
    required this.logs,
  });

  final MonitorStats stats;
  final List<MonitorAgent> agents;
  final List<MonitorRoute> routes;
  final List<MonitorLogEntry> logs;

  bool get hasAgent => agents.isNotEmpty;

  static const empty = FeishuMonitorSnapshot(
    stats: MonitorStats.empty,
    agents: <MonitorAgent>[],
    routes: <MonitorRoute>[],
    logs: <MonitorLogEntry>[],
  );
}

class CreateFeishuMonitorRouteRequest {
  const CreateFeishuMonitorRouteRequest({
    required this.sourceChatName,
    required this.destinationGroupNo,
    required this.destinationGroupName,
    this.includeText = true,
    this.includeLinks = true,
    this.includeImages = false,
    this.includeFiles = false,
  });

  final String sourceChatName;
  final String destinationGroupNo;
  final String destinationGroupName;
  final bool includeText;
  final bool includeLinks;
  final bool includeImages;
  final bool includeFiles;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'platform': MonitorPlatform.feishu.apiValue,
      'connector_type': MonitorConnectorType.feishuWebGroup.apiValue,
      'route_type': 'feishu_web_group_to_wukong_im_group',
      'source': <String, dynamic>{'chat_name': sourceChatName.trim()},
      'destination': <String, dynamic>{
        'type': 'wukong_im_group',
        'group_no': destinationGroupNo.trim(),
        'group_name': destinationGroupName.trim(),
      },
      'message_policy': <String, dynamic>{
        'include_text': includeText,
        'include_links': includeLinks,
        'include_images': includeImages,
        'include_files': includeFiles,
      },
    };
  }
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _toBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  if (normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'false' || normalized == '0') {
    return false;
  }
  return fallback;
}

String _toString(dynamic value, {String fallback = ''}) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}
