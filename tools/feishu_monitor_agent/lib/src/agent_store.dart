import 'dart:convert';
import 'dart:io';

import 'agent_models.dart';

const _configFileName = 'agent_config.json';

class AgentStore {
  AgentStore(this.directoryPath);

  final String directoryPath;

  File get _file =>
      File('$directoryPath${Platform.pathSeparator}$_configFileName');

  Future<AgentConfig?> load() async {
    final file = _file;
    if (!await file.exists()) {
      return null;
    }
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('Agent config must be a JSON object.');
    }
    return AgentConfig.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> save(AgentConfig config) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config.toJson()),
      flush: true,
    );
  }
}

String defaultAgentStoreDirectory() {
  final appData = Platform.environment['APPDATA'];
  if (appData != null && appData.trim().isNotEmpty) {
    return '${appData.trim()}${Platform.pathSeparator}InfoEquity${Platform.pathSeparator}FeishuMonitorAgent';
  }
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home != null && home.trim().isNotEmpty) {
    return '${home.trim()}${Platform.pathSeparator}.infoequity${Platform.pathSeparator}feishu_monitor_agent';
  }
  return '.feishu_monitor_agent';
}
