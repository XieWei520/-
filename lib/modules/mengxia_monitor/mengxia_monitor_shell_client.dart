import 'package:dio/dio.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_client.dart';

import 'mengxia_monitor_shell_models.dart';

const int mengxiaMonitorDefaultShellPort = 18786;
const String mengxiaMonitorDefaultShellBaseUrl =
    'http://127.0.0.1:$mengxiaMonitorDefaultShellPort';
const String mengxiaMonitorDefaultShellToken = 'wukong-mengxia-shell-dev';

class MengxiaMonitorRoutingSource {
  const MengxiaMonitorRoutingSource({
    required this.conversationId,
    required this.conversationName,
  });

  final String conversationId;
  final String conversationName;

  LocalMonitorRoutingSource toLocal() {
    return LocalMonitorRoutingSource(
      conversationId: conversationId,
      conversationName: conversationName,
    );
  }
}

class MengxiaMonitorShellClient {
  MengxiaMonitorShellClient({
    Dio? dio,
    String baseUrl = mengxiaMonitorDefaultShellBaseUrl,
    String token = mengxiaMonitorDefaultShellToken,
  }) : _client = LocalMonitorShellClient(
         dio: dio,
         baseUrl: baseUrl,
         token: token,
       );

  final LocalMonitorShellClient _client;

  Future<MengxiaMonitorShellStatus> fetchStatus() async {
    return MengxiaMonitorShellStatus.fromLocal(await _client.fetchStatus());
  }

  Future<void> startCapture() => _client.startCapture();

  Future<void> stopCapture() => _client.stopCapture();

  Future<void> reloadRuntime() => _client.reloadRuntime();

  Future<void> syncConfiguredSources(
    Iterable<MengxiaMonitorRoutingSource> sources,
  ) {
    return _client.syncConfiguredSources(
      sources.map((source) => source.toLocal()),
    );
  }

  Stream<MengxiaMonitorShellEvent> watchEvents() {
    return _client.watchEvents().map(MengxiaMonitorShellEvent.fromLocal);
  }
}
