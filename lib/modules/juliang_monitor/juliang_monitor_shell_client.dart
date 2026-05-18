import 'package:dio/dio.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_client.dart';

import 'juliang_monitor_shell_models.dart';

const String juliangMonitorDefaultShellBaseUrl = 'http://127.0.0.1:18796';
const String juliangMonitorDefaultShellToken = 'wukong-juliang-shell-dev';

typedef JuliangMonitorRoutingSource = LocalMonitorRoutingSource;

class JuliangMonitorShellClient {
  JuliangMonitorShellClient({
    LocalMonitorShellClient? client,
    Dio? dio,
    String baseUrl = juliangMonitorDefaultShellBaseUrl,
    String token = juliangMonitorDefaultShellToken,
  }) : _client =
           client ??
           LocalMonitorShellClient(dio: dio, baseUrl: baseUrl, token: token);

  final LocalMonitorShellClient _client;

  Future<JuliangMonitorShellStatus> fetchStatus() async {
    final status = await _client.fetchStatus();
    return JuliangMonitorShellStatus.fromLocal(status);
  }

  Future<void> startCapture() => _client.startCapture();

  Future<void> stopCapture() => _client.stopCapture();

  Future<void> reloadRuntime() => _client.reloadRuntime();

  Future<void> syncConfiguredSources(
    Iterable<JuliangMonitorRoutingSource> sources,
  ) {
    return _client.syncConfiguredSources(sources);
  }

  Stream<JuliangMonitorShellEvent> watchEvents() {
    return _client.watchEvents().map(JuliangMonitorShellEvent.fromLocal);
  }
}
