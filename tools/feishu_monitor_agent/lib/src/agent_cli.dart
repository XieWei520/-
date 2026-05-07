import 'dart:convert';
import 'dart:io';

import 'agent_api.dart';
import 'agent_models.dart';
import 'agent_store.dart';
import 'browser_controller.dart';
import 'browser_profile.dart';
import 'feishu_web_adapter.dart';
import 'heartbeat_runner.dart';
import 'listen_runner.dart';
import 'message_dedupe_store.dart';

const agentVersion = '0.1.0';

typedef AgentApiFactory = AgentApiLike Function(String serverUrl);
typedef BrowserControllerFactory =
    BrowserControllerLike Function(BrowserProfilePaths paths);
typedef WriteLine = void Function(String line);
typedef Now = DateTime Function();
typedef DeviceNameProvider = String Function();

Future<int> runAgentCli(
  List<String> args, {
  AgentApiFactory? apiFactory,
  BrowserControllerFactory? browserFactory,
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
  final storeDir = options['store-dir'] ?? defaultAgentStoreDirectory();
  final store = AgentStore(storeDir);
  final paths = BrowserProfilePaths(storeDir);
  final logger = AgentRuntimeLogger(paths.agentLogFile);
  await logger.info('command_start $command');

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
    final config = await _loadConfigOrPrint(store, out);
    if (config == null) {
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

  if (command == 'browser-login') {
    final config = await _loadConfigOrPrint(store, out);
    if (config == null) {
      return 66;
    }
    final browser =
        browserFactory?.call(paths) ?? PuppeteerBrowserController(paths);
    try {
      final status = await browser.openLogin(keepOpen: true);
      await logger.info('browser-login status=${status.apiValue}');
      if (status == BrowserLoginStatus.browserError) {
        out('Chromium 浏览器启动失败，请稍后重试或清除登录状态。');
        await browser.close();
        return 70;
      }
      out('已打开 Chromium 飞书登录窗口，请扫码登录。');
      return 0;
    } catch (error) {
      await logger.error('browser-login failed', error);
      out('Chromium 浏览器启动失败：$error');
      await browser.close();
      return 70;
    }
  }

  if (command == 'browser-status') {
    final config = await _loadConfigOrPrint(store, out);
    if (config == null) {
      return 66;
    }
    final api =
        apiFactory?.call(config.serverUrl) ??
        AgentApi(serverUrl: config.serverUrl);
    final browser =
        browserFactory?.call(paths) ?? PuppeteerBrowserController(paths);
    try {
      final observedAt = clock().toUtc().toIso8601String();
      final status = await browser.checkStatus();
      await logger.info('browser-status status=${status.apiValue}');
      await api.reportBrowserStatus(
        agentToken: config.agentToken,
        request: _browserStatusRequest(config, status, observedAt),
      );
      out(_browserStatusLine(status));
      return 0;
    } finally {
      await browser.close();
      api.close();
    }
  }

  if (command == 'list-chats') {
    final config = await _loadConfigOrPrint(store, out);
    if (config == null) {
      return 66;
    }
    final browser =
        browserFactory?.call(paths) ?? PuppeteerBrowserController(paths);
    try {
      final chats = await browser.listChats();
      final unique = await _mergeChatCache(paths.chatCacheFile, chats);
      await logger.info('list-chats count=${unique.length}');
      out(
        jsonEncode([
          for (final name in unique) <String, String>{'name': name},
        ]),
      );
      return 0;
    } finally {
      await browser.close();
    }
  }

  if (command == 'clear-browser-profile') {
    final config = await _loadConfigOrPrint(store, out);
    if (config == null) {
      return 66;
    }
    final api =
        apiFactory?.call(config.serverUrl) ??
        AgentApi(serverUrl: config.serverUrl);
    try {
      await BrowserProfileCleaner(paths).clearProfile();
      await api.reportBrowserStatus(
        agentToken: config.agentToken,
        request: _browserStatusRequest(
          config,
          BrowserLoginStatus.loginRequired,
          clock().toUtc().toIso8601String(),
        ),
      );
      out('已清除飞书登录状态，请重新打开飞书登录并扫码。');
      return 0;
    } finally {
      api.close();
    }
  }

  if (command == 'listen') {
    final config = await _loadConfigOrPrint(store, out);
    if (config == null) {
      return 66;
    }
    final api =
        apiFactory?.call(config.serverUrl) ??
        AgentApi(serverUrl: config.serverUrl);
    final browser =
        browserFactory?.call(paths) ?? PuppeteerBrowserController(paths);
    final runner = ListenRunner(
      api: api,
      browser: browser,
      dedupeStore: MessageDedupeStore(paths.dedupeCacheFile),
      now: clock,
    );
    try {
      final result = await runner.runOnce(config);
      out(
        '监听完成：规则 ${result.routeCount} 条，观察 ${result.observedCount} 条，上报 ${result.reportedCount} 条。',
      );
      return 0;
    } finally {
      await browser.close();
      api.close();
    }
  }

  out('未知命令：$command');
  _printUsage(out);
  return 64;
}

Future<List<String>> _mergeChatCache(File cacheFile, List<String> chats) async {
  final merged = <String>[];
  final seen = <String>{};

  void add(String value) {
    final name = FeishuChatNameNormalizer.normalize(value);
    if (name.isEmpty) {
      return;
    }
    final key = FeishuChatNameNormalizer.dedupeKey(name);
    if (key.isEmpty || seen.contains(key)) {
      return;
    }
    seen.add(key);
    merged.add(name);
  }

  try {
    if (await cacheFile.exists()) {
      final decoded = jsonDecode(await cacheFile.readAsString());
      if (decoded is List) {
        for (final item in decoded) {
          add(item.toString());
        }
      }
    }
  } catch (_) {
    // Ignore a corrupt cache; current browser data will rebuild it.
  }

  for (final chat in chats) {
    add(chat);
  }

  try {
    await cacheFile.parent.create(recursive: true);
    await cacheFile.writeAsString(jsonEncode(merged));
  } catch (_) {
    // Cache persistence must not break chat listing.
  }

  return merged;
}

class AgentRuntimeLogger {
  const AgentRuntimeLogger(this.file);

  final File file;

  Future<void> info(String message) => _write('INFO', message);

  Future<void> error(String message, Object error) =>
      _write('ERROR', '$message: $error');

  Future<void> _write(String level, String message) async {
    try {
      await file.parent.create(recursive: true);
      final sanitized = message
          .replaceAll(
            RegExp(r'Bearer\s+[A-Za-z0-9._\-]+', caseSensitive: false),
            'Bearer ***',
          )
          .replaceAll(
            RegExp(
              r'agent_token["\s:=]+[A-Za-z0-9._\-]+',
              caseSensitive: false,
            ),
            'agent_token ***',
          );
      await file.writeAsString(
        '${DateTime.now().toUtc().toIso8601String()} [$level] $sanitized\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Logging must never break the local Agent command.
    }
  }
}

Future<AgentConfig?> _loadConfigOrPrint(AgentStore store, WriteLine out) async {
  final config = await store.load();
  if (config == null) {
    out('未找到 Agent 配置，请先执行 pair 命令绑定设备。');
  }
  return config;
}

BrowserStatusReportRequest _browserStatusRequest(
  AgentConfig config,
  BrowserLoginStatus status,
  String observedAt,
) {
  return BrowserStatusReportRequest(
    agentId: config.agentId,
    platform: 'feishu',
    browser: 'chromium',
    profileMode: 'isolated_persistent',
    loginStatus: status,
    observedAt: observedAt,
    errorMessage: '',
  );
}

String _browserStatusLine(BrowserLoginStatus status) {
  switch (status) {
    case BrowserLoginStatus.loggedIn:
      return '飞书已登录，浏览器状态已同步。';
    case BrowserLoginStatus.loginRequired:
      return '飞书未登录，请点击打开飞书登录并扫码。';
    case BrowserLoginStatus.browserError:
      return 'Chromium 浏览器异常，请稍后重试或清除登录状态。';
    case BrowserLoginStatus.unknown:
      return '飞书登录状态未知，请打开飞书登录页确认。';
  }
}

void _printUsage(WriteLine out) {
  out('用法：');
  out(
    '  feishu_monitor_agent pair --server https://infoequity.qingyunshe.top --code A7K9Q2 [--store-dir C:\\Temp\\feishu-agent]',
  );
  out(
    '  feishu_monitor_agent run [--once] [--store-dir C:\\Temp\\feishu-agent]',
  );
  out(
    '  feishu_monitor_agent browser-login [--store-dir C:\\Temp\\feishu-agent]',
  );
  out(
    '  feishu_monitor_agent browser-status [--store-dir C:\\Temp\\feishu-agent]',
  );
  out('  feishu_monitor_agent list-chats [--store-dir C:\\Temp\\feishu-agent]');
  out(
    '  feishu_monitor_agent clear-browser-profile [--store-dir C:\\Temp\\feishu-agent]',
  );
  out(
    '  feishu_monitor_agent listen --once [--store-dir C:\\Temp\\feishu-agent]',
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
