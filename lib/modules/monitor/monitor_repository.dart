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
    ]);

    return FeishuMonitorSnapshot(
      stats: results[0] as MonitorStats,
      agents: List<MonitorAgent>.unmodifiable(results[1] as List<MonitorAgent>),
      routes: List<MonitorRoute>.unmodifiable(results[2] as List<MonitorRoute>),
      logs: List<MonitorLogEntry>.unmodifiable(
        results[3] as List<MonitorLogEntry>,
      ),
    );
  }

  Future<List<MonitorSelectableGroup>> loadDestinationGroups() async {
    final groups = await _groupApi.getMyGroups();
    return groups.map(_mapGroup).toList(growable: false);
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

  MonitorSelectableGroup _mapGroup(GroupInfo group) {
    return MonitorSelectableGroup(
      groupNo: group.groupNo,
      name: (group.name ?? '').trim(),
    );
  }
}
