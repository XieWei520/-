class PairAgentRequest {
  const PairAgentRequest({
    required this.pairingCode,
    required this.deviceName,
    required this.platform,
    required this.agentVersion,
  });

  final String pairingCode;
  final String deviceName;
  final String platform;
  final String agentVersion;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pairing_code': pairingCode.trim(),
    'device_name': deviceName.trim(),
    'platform': platform.trim(),
    'agent_version': agentVersion.trim(),
  };
}

class PairAgentResponse {
  const PairAgentResponse({
    required this.agentId,
    required this.agentToken,
    required this.heartbeatIntervalSeconds,
    required this.serverTime,
  });

  final String agentId;
  final String agentToken;
  final int heartbeatIntervalSeconds;
  final String serverTime;

  factory PairAgentResponse.fromJson(Map<String, dynamic> json) {
    return PairAgentResponse(
      agentId: _string(json['agent_id']),
      agentToken: _string(json['agent_token']),
      heartbeatIntervalSeconds: _int(
        json['heartbeat_interval_seconds'],
        fallback: 20,
      ),
      serverTime: _string(json['server_time']),
    );
  }

  @override
  String toString() {
    return 'PairAgentResponse(agentId: $agentId, heartbeatIntervalSeconds: $heartbeatIntervalSeconds, serverTime: $serverTime)';
  }
}

class HeartbeatRequest {
  const HeartbeatRequest({
    required this.agentId,
    required this.status,
    required this.deviceName,
    required this.platform,
    required this.agentVersion,
    required this.capabilities,
    required this.observedAt,
  });

  final String agentId;
  final String status;
  final String deviceName;
  final String platform;
  final String agentVersion;
  final List<String> capabilities;
  final String observedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'agent_id': agentId.trim(),
    'status': status.trim(),
    'device_name': deviceName.trim(),
    'platform': platform.trim(),
    'agent_version': agentVersion.trim(),
    'capabilities': capabilities,
    'observed_at': observedAt.trim(),
  };
}

class HeartbeatResponse {
  const HeartbeatResponse({
    required this.agentId,
    required this.status,
    required this.nextHeartbeatAfterSeconds,
    required this.serverTime,
  });

  final String agentId;
  final String status;
  final int nextHeartbeatAfterSeconds;
  final String serverTime;

  factory HeartbeatResponse.fromJson(Map<String, dynamic> json) {
    return HeartbeatResponse(
      agentId: _string(json['agent_id']),
      status: _string(json['status'], fallback: 'online'),
      nextHeartbeatAfterSeconds: _int(
        json['next_heartbeat_after_seconds'],
        fallback: 20,
      ),
      serverTime: _string(json['server_time']),
    );
  }
}

class AgentConfig {
  const AgentConfig({
    required this.serverUrl,
    required this.agentId,
    required this.agentToken,
    required this.deviceName,
    required this.agentVersion,
    required this.pairedAt,
    required this.heartbeatIntervalSeconds,
  });

  final String serverUrl;
  final String agentId;
  final String agentToken;
  final String deviceName;
  final String agentVersion;
  final String pairedAt;
  final int heartbeatIntervalSeconds;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'server_url': serverUrl.trim(),
    'agent_id': agentId.trim(),
    'agent_token': agentToken.trim(),
    'device_name': deviceName.trim(),
    'agent_version': agentVersion.trim(),
    'paired_at': pairedAt.trim(),
    'heartbeat_interval_seconds': heartbeatIntervalSeconds,
  };

  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    return AgentConfig(
      serverUrl: _string(json['server_url']),
      agentId: _string(json['agent_id']),
      agentToken: _string(json['agent_token']),
      deviceName: _string(json['device_name']),
      agentVersion: _string(json['agent_version']),
      pairedAt: _string(json['paired_at']),
      heartbeatIntervalSeconds: _int(
        json['heartbeat_interval_seconds'],
        fallback: 20,
      ),
    );
  }

  @override
  String toString() {
    return 'AgentConfig(serverUrl: $serverUrl, agentId: $agentId, deviceName: $deviceName, agentVersion: $agentVersion, pairedAt: $pairedAt, heartbeatIntervalSeconds: $heartbeatIntervalSeconds)';
  }
}

enum BrowserLoginStatus {
  loggedIn('logged_in'),
  loginRequired('login_required'),
  browserError('browser_error'),
  unknown('unknown');

  const BrowserLoginStatus(this.apiValue);

  final String apiValue;

  static BrowserLoginStatus parse(dynamic value) {
    switch (_string(value).trim()) {
      case 'logged_in':
        return BrowserLoginStatus.loggedIn;
      case 'login_required':
        return BrowserLoginStatus.loginRequired;
      case 'browser_error':
        return BrowserLoginStatus.browserError;
      default:
        return BrowserLoginStatus.unknown;
    }
  }
}

class BrowserStatusReportRequest {
  const BrowserStatusReportRequest({
    required this.agentId,
    required this.platform,
    required this.browser,
    required this.profileMode,
    required this.loginStatus,
    required this.observedAt,
    required this.errorMessage,
  });

  final String agentId;
  final String platform;
  final String browser;
  final String profileMode;
  final BrowserLoginStatus loginStatus;
  final String observedAt;
  final String errorMessage;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'agent_id': agentId.trim(),
    'platform': platform.trim(),
    'browser': browser.trim(),
    'profile_mode': profileMode.trim(),
    'login_status': loginStatus.apiValue,
    'observed_at': observedAt.trim(),
    'error_message': errorMessage.trim(),
  };

  @override
  String toString() {
    return 'BrowserStatusReportRequest(agentId: $agentId, platform: $platform, browser: $browser, profileMode: $profileMode, loginStatus: ${loginStatus.apiValue}, observedAt: $observedAt, errorMessage: $errorMessage)';
  }
}

class AgentMonitorRoute {
  const AgentMonitorRoute({
    required this.routeId,
    required this.platform,
    required this.connectorType,
    required this.routeType,
    required this.sourceChatName,
    required this.destinationType,
    required this.destinationGroupNo,
    required this.destinationGroupName,
    required this.includeText,
    required this.includeLinks,
    required this.includeImages,
    required this.includeFiles,
  });

  final String routeId;
  final String platform;
  final String connectorType;
  final String routeType;
  final String sourceChatName;
  final String destinationType;
  final String destinationGroupNo;
  final String destinationGroupName;
  final bool includeText;
  final bool includeLinks;
  final bool includeImages;
  final bool includeFiles;

  factory AgentMonitorRoute.fromJson(Map<String, dynamic> json) {
    final source = _map(json['source']);
    final destination = _map(json['destination']);
    final policy = _map(json['message_policy']);
    return AgentMonitorRoute(
      routeId: _string(json['route_id'] ?? json['id']),
      platform: _string(json['platform'], fallback: 'feishu'),
      connectorType: _string(json['connector_type']),
      routeType: _string(json['route_type']),
      sourceChatName: _string(source['chat_name'] ?? json['source_name']),
      destinationType: _string(
        destination['type'],
        fallback: 'wukong_im_group',
      ),
      destinationGroupNo: _string(destination['group_no']),
      destinationGroupName: _string(destination['group_name']),
      includeText: _bool(policy['include_text'], fallback: true),
      includeLinks: _bool(policy['include_links'], fallback: true),
      includeImages: _bool(policy['include_images']),
      includeFiles: _bool(policy['include_files']),
    );
  }
}

class ObservedMessageRequest {
  const ObservedMessageRequest({
    required this.agentId,
    required this.routeId,
    required this.sourcePlatform,
    required this.sourceChatName,
    required this.sourceMessageId,
    required this.messageType,
    required this.content,
    required this.sourceCreatedAt,
    required this.observedAt,
  });

  final String agentId;
  final String routeId;
  final String sourcePlatform;
  final String sourceChatName;
  final String sourceMessageId;
  final String messageType;
  final String content;
  final String sourceCreatedAt;
  final String observedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'agent_id': agentId.trim(),
    'route_id': routeId.trim(),
    'source_platform': sourcePlatform.trim(),
    'source_chat_name': sourceChatName.trim(),
    'source_message_id': sourceMessageId.trim(),
    'message_type': messageType.trim(),
    'content': content.trim(),
    'source_created_at': sourceCreatedAt.trim(),
    'observed_at': observedAt.trim(),
  };
}

class ObservedMessageResponse {
  const ObservedMessageResponse({
    required this.accepted,
    required this.duplicate,
    required this.forwardStatus,
    required this.messageId,
  });

  final bool accepted;
  final bool duplicate;
  final String forwardStatus;
  final String messageId;

  factory ObservedMessageResponse.fromJson(Map<String, dynamic> json) {
    return ObservedMessageResponse(
      accepted: _bool(json['accepted']),
      duplicate: _bool(json['duplicate']),
      forwardStatus: _string(json['forward_status']),
      messageId: _string(json['message_id']),
    );
  }
}

String _string(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

bool _bool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text == 'true' || text == '1') {
    return true;
  }
  if (text == 'false' || text == '0') {
    return false;
  }
  return fallback;
}
