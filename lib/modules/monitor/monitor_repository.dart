import '../../data/models/group.dart';
import '../../service/api/group_api.dart';
import '../../service/api/monitor_api.dart';
import 'monitor_models.dart';

class MonitorRepository {
  MonitorRepository({MonitorApi? api, GroupApi? groupApi})
    : _api = api ?? MonitorApi.instance,
      _groupApi = groupApi ?? GroupApi.instance;

  final MonitorApi _api;
  final GroupApi _groupApi;

  Future<FeishuMonitorSnapshot> loadFeishuSnapshot() async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _api.fetchStats(platform: MonitorPlatform.feishu),
      _api.fetchAgents(platform: MonitorPlatform.feishu),
      _api.fetchRoutes(platform: MonitorPlatform.feishu),
      _api.fetchLogs(platform: MonitorPlatform.feishu, limit: 20),
      _api.fetchBrowserStatus(platform: MonitorPlatform.feishu),
    ]);

    return FeishuMonitorSnapshot(
      stats: results[0] as MonitorStats,
      agents: List<MonitorAgent>.unmodifiable(
        _deduplicateAgents(results[1] as List<MonitorAgent>),
      ),
      routes: List<MonitorRoute>.unmodifiable(results[2] as List<MonitorRoute>),
      logs: List<MonitorLogEntry>.unmodifiable(
        results[3] as List<MonitorLogEntry>,
      ),
      browserStatus: results[4] as MonitorBrowserStatus,
    );
  }

  List<MonitorAgent> _deduplicateAgents(List<MonitorAgent> agents) {
    final byDevice = <String, MonitorAgent>{};
    final order = <String>[];
    for (final agent in agents) {
      final key =
          '${agent.platform.trim().toLowerCase()}|${agent.deviceName.trim().toLowerCase()}';
      if (key == '|') {
        order.add(agent.id);
        byDevice[agent.id] = agent;
        continue;
      }
      final existing = byDevice[key];
      if (existing == null) {
        order.add(key);
        byDevice[key] = agent;
        continue;
      }
      if (_isPreferredAgent(agent, existing)) {
        byDevice[key] = agent;
      }
    }
    return order.map((key) => byDevice[key]!).toList(growable: false);
  }

  bool _isPreferredAgent(MonitorAgent candidate, MonitorAgent existing) {
    final candidateOnline = candidate.status == MonitorAgentStatus.online;
    final existingOnline = existing.status == MonitorAgentStatus.online;
    if (candidateOnline != existingOnline) {
      return candidateOnline;
    }
    final candidateHeartbeat = DateTime.tryParse(candidate.lastHeartbeatAt);
    final existingHeartbeat = DateTime.tryParse(existing.lastHeartbeatAt);
    if (candidateHeartbeat != null && existingHeartbeat != null) {
      return candidateHeartbeat.isAfter(existingHeartbeat);
    }
    if (candidateHeartbeat != null) {
      return true;
    }
    if (existingHeartbeat != null) {
      return false;
    }
    return false;
  }

  Future<List<MonitorSelectableGroup>> loadDestinationGroups() async {
    final groups = await _groupApi.getMyGroups();
    final activeGroups = groups
        .where(_isSelectableGroup)
        .toList(growable: false);
    final nameCounts = <String, int>{};
    for (final group in groups) {
      final name = (group.name ?? '').trim();
      if (name.isEmpty) {
        continue;
      }
      nameCounts[name] = (nameCounts[name] ?? 0) + 1;
    }
    return activeGroups
        .map(
          (group) =>
              _mapGroup(group, nameCounts[(group.name ?? '').trim()] ?? 0),
        )
        .toList(growable: false);
  }

  Future<MonitorPairingCode> createPairingCode(String deviceName) {
    return _api.createPairingCode(deviceName);
  }

  Future<MonitorRoute> createFeishuRoute(
    CreateFeishuMonitorRouteRequest request,
  ) {
    return _api.createFeishuRoute(request);
  }

  Future<void> pauseRoute(String routeId) {
    return _api.updateRouteStatus(
      routeId: routeId,
      status: MonitorRouteStatus.paused,
    );
  }

  Future<void> resumeRoute(String routeId) {
    return _api.updateRouteStatus(
      routeId: routeId,
      status: MonitorRouteStatus.running,
    );
  }

  bool _isSelectableGroup(GroupInfo group) {
    if (group.groupNo.trim().isEmpty) {
      return false;
    }
    final status = group.status;
    return status == null || status == 1;
  }

  MonitorSelectableGroup _mapGroup(GroupInfo group, int duplicateNameCount) {
    final name = (group.name ?? '').trim();
    final displayName = duplicateNameCount > 1
        ? '${name.isEmpty ? group.groupNo : name}（${_shortGroupNo(group.groupNo)}）'
        : null;
    return MonitorSelectableGroup(
      groupNo: group.groupNo,
      name: name,
      displayName: displayName,
    );
  }

  String _shortGroupNo(String groupNo) {
    final normalized = groupNo.trim();
    if (normalized.length <= 8) {
      return normalized;
    }
    return '${normalized.substring(0, 7)}…';
  }
}
