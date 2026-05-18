class FeishuMonitorWorkerConfig {
  const FeishuMonitorWorkerConfig({
    required this.workerId,
    required this.baseUrl,
    required this.port,
    required this.profileSuffix,
    required this.visible,
    this.maxRoutes = 20,
  });

  final String workerId;
  final String baseUrl;
  final int port;
  final String profileSuffix;
  final bool visible;
  final int maxRoutes;

  static List<FeishuMonitorWorkerConfig> recommendedForRouteCount(
    int routeCount, {
    int shardSize = 20,
    int firstPort = 18766,
  }) {
    if (shardSize <= 0) {
      throw ArgumentError.value(shardSize, 'shardSize', 'must be greater than 0');
    }
    final normalizedRouteCount = routeCount <= 0 ? 1 : routeCount;
    final count = ((normalizedRouteCount + shardSize - 1) ~/ shardSize).clamp(
      1,
      6,
    );
    final lastPort = firstPort + count - 1;
    if (firstPort < 1024 || lastPort > 65535) {
      throw ArgumentError.value(
        firstPort,
        'firstPort',
        'must leave all worker ports in 1024..65535',
      );
    }
    return List<FeishuMonitorWorkerConfig>.generate(count, (index) {
      final id = 'worker-${index + 1}';
      final port = firstPort + index;
      return FeishuMonitorWorkerConfig(
        workerId: id,
        baseUrl: 'http://127.0.0.1:$port',
        port: port,
        profileSuffix: id,
        visible: true,
        maxRoutes: shardSize,
      );
    });
  }
}

String workerIdForRouteIndex(
  int routeIndex,
  List<FeishuMonitorWorkerConfig> workers,
) {
  if (workers.isEmpty) {
    return 'worker-1';
  }
  final safeIndex = routeIndex < 0 ? 0 : routeIndex;
  var start = 0;
  for (final worker in workers) {
    final end = start + worker.maxRoutes;
    if (safeIndex < end) {
      return worker.workerId;
    }
    start = end;
  }
  return workers.last.workerId;
}
