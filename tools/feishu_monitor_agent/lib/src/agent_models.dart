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
