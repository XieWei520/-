import 'agent_models.dart';

abstract class AgentApiLike {
  Future<PairAgentResponse> pair(PairAgentRequest request);

  Future<HeartbeatResponse> heartbeat({
    required String agentToken,
    required HeartbeatRequest request,
  });

  void close();
}

class HeartbeatRunner {
  HeartbeatRunner({required this.api, required this.now});

  final AgentApiLike api;
  final DateTime Function() now;

  Future<HeartbeatResponse> sendOnce(AgentConfig config) {
    return api.heartbeat(
      agentToken: config.agentToken,
      request: HeartbeatRequest(
        agentId: config.agentId,
        status: 'online',
        deviceName: config.deviceName,
        platform: 'windows',
        agentVersion: config.agentVersion,
        capabilities: const <String>['feishu_web_group'],
        observedAt: now().toUtc().toIso8601String(),
      ),
    );
  }
}
