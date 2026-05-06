import 'dart:io';

import 'agent_api.dart';
import 'agent_models.dart';
import 'agent_store.dart';
import 'heartbeat_runner.dart';

const agentVersion = '0.1.0';

typedef AgentApiFactory = AgentApiLike Function(String serverUrl);
typedef WriteLine = void Function(String line);
typedef Now = DateTime Function();
typedef DeviceNameProvider = String Function();

Future<int> runAgentCli(
  List<String> args, {
  AgentApiFactory? apiFactory,
  WriteLine? writeLine,
  Now? now,
  DeviceNameProvider? deviceNameProvider,
}) async {
  final WriteLine out = writeLine ?? (line) => stdout.writeln(line);
  final clock = now ?? DateTime.now;
  final nameProvider = deviceNameProvider ?? _defaultDeviceName;
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage(out);
    return args.isEmpty ? 64 : 0;
  }

  final command = args.first;
  final options = _parseOptions(args.skip(1).toList());
  final store = AgentStore(
    options['store-dir'] ?? defaultAgentStoreDirectory(),
  );

  if (command == 'pair') {
    final server = options['server'];
    final code = options['code'];
    if (server == null || code == null) {
      out('pair 需要 --server 和 --code');
      _printUsage(out);
      return 64;
    }
    final api = apiFactory?.call(server) ?? AgentApi(serverUrl: server);
    try {
      final deviceName = nameProvider();
      final response = await api.pair(
        PairAgentRequest(
          pairingCode: code,
          deviceName: deviceName,
          platform: 'windows',
          agentVersion: agentVersion,
        ),
      );
      await store.save(
        AgentConfig(
          serverUrl: server,
          agentId: response.agentId,
          agentToken: response.agentToken,
          deviceName: deviceName,
          agentVersion: agentVersion,
          pairedAt: clock().toUtc().toIso8601String(),
          heartbeatIntervalSeconds: response.heartbeatIntervalSeconds,
        ),
      );
      out(
        '绑定成功：Agent ${response.agentId}，心跳间隔 ${response.heartbeatIntervalSeconds} 秒',
      );
      return 0;
    } finally {
      api.close();
    }
  }

  if (command == 'run') {
    final config = await store.load();
    if (config == null) {
      out('未找到 Agent 配置，请先执行 pair 命令绑定设备。');
      return 66;
    }
    final api =
        apiFactory?.call(config.serverUrl) ??
        AgentApi(serverUrl: config.serverUrl);
    final runner = HeartbeatRunner(api: api, now: clock);
    try {
      final response = await runner.sendOnce(config);
      out('心跳成功：${response.status}，服务器时间 ${response.serverTime}');
      return 0;
    } finally {
      api.close();
    }
  }

  out('未知命令：$command');
  _printUsage(out);
  return 64;
}

void _printUsage(WriteLine out) {
  out('用法：');
  out(
    '  feishu_monitor_agent pair --server https://infoequity.qingyunshe.top --code A7K9Q2 [--store-dir C:\\Temp\\feishu-agent]',
  );
  out(
    '  feishu_monitor_agent run [--once] [--store-dir C:\\Temp\\feishu-agent]',
  );
}

Map<String, String> _parseOptions(List<String> args) {
  final result = <String, String>{};
  var index = 0;
  while (index < args.length) {
    final item = args[index];
    if (!item.startsWith('--')) {
      index += 1;
      continue;
    }
    final key = item.substring(2);
    if (index + 1 < args.length && !args[index + 1].startsWith('--')) {
      result[key] = args[index + 1];
      index += 2;
    } else {
      result[key] = 'true';
      index += 1;
    }
  }
  return result;
}

String _defaultDeviceName() {
  final computerName = Platform.environment['COMPUTERNAME'];
  if (computerName != null && computerName.trim().isNotEmpty) {
    return computerName.trim();
  }
  return Platform.localHostname;
}
