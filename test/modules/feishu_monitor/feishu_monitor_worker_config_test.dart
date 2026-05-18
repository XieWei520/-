import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_worker_config.dart';

void main() {
  test('builds six visible workers for 120 groups by default', () {
    final workers = FeishuMonitorWorkerConfig.recommendedForRouteCount(120);

    expect(workers, hasLength(6));
    expect(workers.first.workerId, 'worker-1');
    expect(workers.first.baseUrl, 'http://127.0.0.1:18766');
    expect(workers.last.workerId, 'worker-6');
    expect(workers.last.baseUrl, 'http://127.0.0.1:18771');
    expect(workers.every((worker) => worker.visible), isTrue);
  });

  test('assigns route index to deterministic worker shard', () {
    final workers = FeishuMonitorWorkerConfig.recommendedForRouteCount(120);

    expect(workerIdForRouteIndex(0, workers), 'worker-1');
    expect(workerIdForRouteIndex(19, workers), 'worker-1');
    expect(workerIdForRouteIndex(20, workers), 'worker-2');
    expect(workerIdForRouteIndex(119, workers), 'worker-6');
  });

  test('rejects invalid shard size', () {
    expect(
      () => FeishuMonitorWorkerConfig.recommendedForRouteCount(
        120,
        shardSize: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => FeishuMonitorWorkerConfig.recommendedForRouteCount(
        120,
        shardSize: -1,
      ),
      throwsArgumentError,
    );
  });

  test('rejects invalid worker port ranges', () {
    expect(
      () => FeishuMonitorWorkerConfig.recommendedForRouteCount(
        120,
        firstPort: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => FeishuMonitorWorkerConfig.recommendedForRouteCount(
        120,
        firstPort: 65531,
      ),
      throwsArgumentError,
    );
    expect(
      FeishuMonitorWorkerConfig.recommendedForRouteCount(
        120,
        firstPort: 65530,
      ).last.port,
      65535,
    );
  });

  test('routes beyond six worker capacity overflow to last worker', () {
    final workers = FeishuMonitorWorkerConfig.recommendedForRouteCount(121);

    expect(workers, hasLength(6));
    expect(workerIdForRouteIndex(120, workers), 'worker-6');
  });
}
