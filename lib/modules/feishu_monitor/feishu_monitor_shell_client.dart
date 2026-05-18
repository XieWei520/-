import 'package:dio/dio.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_client.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_models.dart';

import 'feishu_monitor_forwarding_service.dart';
import 'feishu_monitor_shell_models.dart';
import 'feishu_monitor_worker_config.dart';

class FeishuMonitorShellClientGroup {
  FeishuMonitorShellClientGroup._(List<FeishuMonitorShellClient> clients)
    : clients = List<FeishuMonitorShellClient>.unmodifiable(clients);

  factory FeishuMonitorShellClientGroup.single(
    FeishuMonitorShellClient client,
  ) {
    return FeishuMonitorShellClientGroup._(<FeishuMonitorShellClient>[client]);
  }

  factory FeishuMonitorShellClientGroup.forTesting(
    List<FeishuMonitorShellClient> clients,
  ) {
    return FeishuMonitorShellClientGroup._(clients);
  }

  factory FeishuMonitorShellClientGroup.recommendedForRouteCount(
    int routeCount, {
    Dio? dio,
    String? token,
  }) {
    final workers = FeishuMonitorWorkerConfig.recommendedForRouteCount(
      routeCount,
    );
    return FeishuMonitorShellClientGroup._(
      workers
          .map(
            (worker) => FeishuMonitorShellClient(
              dio: dio,
              baseUrl: worker.baseUrl,
              token: token,
              workerId: worker.workerId,
            ),
          )
          .toList(growable: false),
    );
  }

  final List<FeishuMonitorShellClient> clients;

  Future<List<FeishuMonitorShellStatus>> fetchStatuses({
    Set<String>? workerIds,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    final selectedClients = _clientsForWorkerIds(workerIds);
    final statuses = await Future.wait<FeishuMonitorShellStatus?>(
      selectedClients.map((client) async {
        try {
          return await client.fetchStatus();
        } catch (error, stackTrace) {
          onError?.call(error, stackTrace);
          return null;
        }
      }),
    );
    return statuses.nonNulls.toList(growable: false);
  }

  Future<void> syncConfiguredMediaSources(
    List<FeishuMonitorForwardingRoute> routes,
  ) async {
    final assignedWorkerIds = _workerIdsForRoutes(routes);
    await Future.wait(
      _clientsForWorkerIds(assignedWorkerIds).map((client) {
        return client.syncConfiguredMediaSources(
          _routesForClient(client, routes),
        );
      }),
    );
  }

  Set<String> workerIdsForRoutes(List<FeishuMonitorForwardingRoute> routes) {
    return _workerIdsForRoutes(routes);
  }

  List<FeishuMonitorShellClient> _clientsForWorkerIds(Set<String>? workerIds) {
    final normalizedWorkerIds = workerIds
        ?.map((workerId) => workerId.trim())
        .where((workerId) => workerId.isNotEmpty)
        .toSet();
    if (normalizedWorkerIds == null || normalizedWorkerIds.isEmpty) {
      return clients;
    }
    return clients
        .where((client) => normalizedWorkerIds.contains(client.workerId.trim()))
        .toList(growable: false);
  }

  Set<String> _workerIdsForRoutes(List<FeishuMonitorForwardingRoute> routes) {
    if (clients.length == 1) {
      return <String>{clients.first.workerId.trim()};
    }
    final workerIds = <String>{};
    for (final route in routes) {
      if (!route.enabled || route.targetGroupId.trim().isEmpty) {
        continue;
      }
      final routeWorkerId = route.workerId.trim();
      if (routeWorkerId.isNotEmpty) {
        workerIds.add(routeWorkerId);
        continue;
      }
      workerIds.add(clients.first.workerId.trim());
    }
    workerIds.remove('');
    return workerIds;
  }

  List<FeishuMonitorForwardingRoute> _routesForClient(
    FeishuMonitorShellClient client,
    List<FeishuMonitorForwardingRoute> routes,
  ) {
    final clientWorkerId = client.workerId.trim();
    if (clients.length == 1 || clientWorkerId.isEmpty) {
      return routes;
    }
    return routes
        .where((route) {
          final routeWorkerId = route.workerId.trim();
          if (routeWorkerId.isEmpty) {
            return identical(client, clients.first);
          }
          return routeWorkerId == clientWorkerId;
        })
        .toList(growable: false);
  }
}

class FeishuMonitorShellClient {
  FeishuMonitorShellClient({
    Dio? dio,
    String? baseUrl,
    String? token,
    String workerId = 'worker-1',
  }) : workerId = workerId.trim(),
       _client = LocalMonitorShellClient(
         dio: dio,
         baseUrl: baseUrl ?? 'http://127.0.0.1:18766',
         token: token ?? 'wukong-feishu-shell-dev',
       );

  final String workerId;
  final LocalMonitorShellClient _client;

  Future<FeishuMonitorShellStatus> fetchStatus() async {
    final status = await _client.fetchStatus();
    final diagnostics = status.probeDiagnostics;
    return FeishuMonitorShellStatus.fromLocal(
      status,
      mediaQueueDepth: localMonitorInt(diagnostics['media_queue_depth']),
      mediaQueueOldestWaitSeconds: localMonitorInt(
        diagnostics['media_queue_oldest_wait_seconds'],
      ),
      mediaQueueEstimatedNextDelaySeconds: localMonitorInt(
        diagnostics['media_queue_estimated_next_delay_seconds'],
      ),
      mediaQueueLastSkipReason:
          (diagnostics['media_queue_last_skip_reason'] ?? '').toString(),
    );
  }

  Future<FeishuMonitorShellHealth> fetchHealth() async {
    return FeishuMonitorShellHealth.fromLocal(await _client.fetchHealth());
  }

  Future<void> startCapture() => _client.startCapture();

  Future<void> stopCapture() => _client.stopCapture();

  Future<void> reloadRuntime() => _client.reloadRuntime();

  Future<void> syncConfiguredMediaSources(
    List<FeishuMonitorForwardingRoute> routes,
  ) async {
    await _client.syncConfiguredSources(
      routes.where(_isEnabledRoute).map((route) {
        return LocalMonitorRoutingSource(
          conversationId: route.sourceConversationId,
          conversationName: route.sourceConversationName,
        );
      }),
    );
  }

  Stream<FeishuMonitorShellEvent> watchEvents() async* {
    yield* _client.watchEvents().map(FeishuMonitorShellEvent.fromLocal);
  }

  bool _isEnabledRoute(FeishuMonitorForwardingRoute route) =>
      route.enabled && route.targetGroupId.trim().isNotEmpty;
}
