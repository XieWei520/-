import 'package:dio/dio.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_client.dart';

import 'xiaoe_monitor_shell_models.dart';

const String xiaoeMonitorDefaultShellBaseUrl = 'http://127.0.0.1:18806';
const String xiaoeMonitorDefaultShellToken = 'wukong-xiaoe-shell-dev';

typedef XiaoeMonitorRoutingSource = LocalMonitorRoutingSource;

class XiaoeMonitorShellClient {
  XiaoeMonitorShellClient({
    LocalMonitorShellClient? client,
    Dio? dio,
    String baseUrl = xiaoeMonitorDefaultShellBaseUrl,
    String token = xiaoeMonitorDefaultShellToken,
  }) : _client =
           client ??
           LocalMonitorShellClient(dio: dio, baseUrl: baseUrl, token: token);

  final LocalMonitorShellClient _client;

  Future<XiaoeMonitorShellStatus> fetchStatus() async {
    final status = await _client.fetchStatus();
    return XiaoeMonitorShellStatus.fromLocal(status);
  }

  Future<void> startCapture() => _client.startCapture();

  Future<void> stopCapture() => _client.stopCapture();

  Future<void> reloadRuntime() => _client.reloadRuntime();

  Future<void> syncConfiguredSources(
    Iterable<XiaoeMonitorRoutingSource> sources,
  ) {
    return _client.syncConfiguredSources(sources);
  }

  Stream<XiaoeMonitorShellEvent> watchEvents() {
    return _client.watchEvents().map(XiaoeMonitorShellEvent.fromLocal);
  }
}
