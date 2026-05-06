import 'dart:async';
import 'dart:io';

class LocalAgentBindRequest {
  const LocalAgentBindRequest({
    required this.serverUrl,
    required this.pairingCode,
    this.storeDir,
  });

  final String serverUrl;
  final String pairingCode;
  final String? storeDir;
}

class LocalAgentBindResult {
  const LocalAgentBindResult({required this.message});

  final String message;
}

enum LocalAgentBindPhase { platform, pair, heartbeat }

class LocalAgentBindException implements Exception {
  const LocalAgentBindException(this.message, {required this.phase});

  final String message;
  final LocalAgentBindPhase phase;

  @override
  String toString() => message;
}

class LocalAgentProcessResult {
  const LocalAgentProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

typedef LocalAgentProcessRunner =
    Future<LocalAgentProcessResult> Function(
      String executable,
      List<String> arguments,
    );

typedef LocalAgentPlatformDetector = bool Function();

class MonitorLocalAgentBinder {
  MonitorLocalAgentBinder({
    LocalAgentProcessRunner? runProcess,
    LocalAgentPlatformDetector? isWindows,
  }) : _runProcess = runProcess ?? _defaultRunProcess,
       _isWindows = isWindows ?? (() => Platform.isWindows);

  final LocalAgentProcessRunner _runProcess;
  final LocalAgentPlatformDetector _isWindows;

  Future<LocalAgentBindResult> bindAndHeartbeat(
    LocalAgentBindRequest request,
  ) async {
    if (!_isWindows()) {
      throw const LocalAgentBindException(
        '请在 Windows 桌面端使用一键绑定。',
        phase: LocalAgentBindPhase.platform,
      );
    }

    final storeDir = request.storeDir ?? _defaultStoreDir();
    final pair = await _runProcess('dart', <String>[
      'run',
      'bin/feishu_monitor_agent.dart',
      'pair',
      '--server',
      request.serverUrl,
      '--code',
      request.pairingCode,
      '--store-dir',
      storeDir,
    ]);
    if (pair.exitCode != 0) {
      throw LocalAgentBindException(
        'Agent 绑定失败：${_friendlyPairError(pair.stderr.isNotEmpty ? pair.stderr : pair.stdout)}',
        phase: LocalAgentBindPhase.pair,
      );
    }

    final heartbeat = await _runProcess('dart', <String>[
      'run',
      'bin/feishu_monitor_agent.dart',
      'run',
      '--once',
      '--store-dir',
      storeDir,
    ]);
    if (heartbeat.exitCode != 0) {
      throw LocalAgentBindException(
        'Agent 心跳失败：${_sanitizeOutput(heartbeat.stderr.isNotEmpty ? heartbeat.stderr : heartbeat.stdout)}',
        phase: LocalAgentBindPhase.heartbeat,
      );
    }

    return const LocalAgentBindResult(message: 'Agent 已绑定并上线');
  }

  static Future<LocalAgentProcessResult> _defaultRunProcess(
    String executable,
    List<String> arguments,
  ) async {
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: _agentWorkingDirectory(),
      runInShell: true,
    );
    return LocalAgentProcessResult(
      exitCode: result.exitCode,
      stdout: '${result.stdout}',
      stderr: '${result.stderr}',
    );
  }

  static String _agentWorkingDirectory() {
    final executableDir = File(Platform.resolvedExecutable).parent;
    final candidates = <Directory>[];
    void addAncestors(Directory start) {
      var current = start;
      for (var depth = 0; depth < 8; depth++) {
        if (!candidates.any((candidate) => candidate.path == current.path)) {
          candidates.add(current);
        }
        final parent = current.parent;
        if (parent.path == current.path) {
          break;
        }
        current = parent;
      }
    }

    addAncestors(Directory.current);
    addAncestors(executableDir);

    for (final candidate in candidates) {
      final agentDir = Directory(
        '${candidate.path}${Platform.pathSeparator}tools${Platform.pathSeparator}feishu_monitor_agent',
      );
      if (File(
        '${agentDir.path}${Platform.pathSeparator}bin${Platform.pathSeparator}feishu_monitor_agent.dart',
      ).existsSync()) {
        return agentDir.path;
      }
    }
    return '${Directory.current.path}${Platform.pathSeparator}tools${Platform.pathSeparator}feishu_monitor_agent';
  }

  static String _defaultStoreDir() {
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

  static String _friendlyPairError(String value) {
    final sanitized = _sanitizeOutput(value);
    final lower = sanitized.toLowerCase();
    if (lower.contains('pairing_code_used')) {
      return '\u914d\u5bf9\u7801\u5df2\u88ab\u4f7f\u7528\uff0c\u8bf7\u91cd\u65b0\u751f\u6210\u914d\u5bf9\u7801\u540e\u518d\u7ed1\u5b9a\u3002';
    }
    if (lower.contains('pairing_code_expired')) {
      return '\u914d\u5bf9\u7801\u5df2\u8fc7\u671f\uff0c\u8bf7\u91cd\u65b0\u751f\u6210\u914d\u5bf9\u7801\u540e\u518d\u7ed1\u5b9a\u3002';
    }
    if (lower.contains('pairing_code_not_found') ||
        lower.contains('invalid_pairing_code')) {
      return '\u914d\u5bf9\u7801\u65e0\u6548\uff0c\u8bf7\u91cd\u65b0\u751f\u6210\u914d\u5bf9\u7801\u540e\u518d\u7ed1\u5b9a\u3002';
    }
    return sanitized;
  }

  static String _sanitizeOutput(String value) {
    final withoutStack = value
        .split(RegExp(r'\r?\n'))
        .where((line) {
          final trimmed = line.trimLeft();
          return !trimmed.startsWith('#') &&
              !trimmed.startsWith('<asynchronous suspension>') &&
              !trimmed.startsWith('Unhandled exception');
        })
        .join('\n');
    final sanitized = withoutStack
        .replaceAll(
          RegExp(r'Bearer\s+[A-Za-z0-9._\-]+', caseSensitive: false),
          'Bearer ***',
        )
        .replaceAll(
          RegExp(r'agent_token["\s:=]+[A-Za-z0-9._\-]+', caseSensitive: false),
          'agent_token ***',
        )
        .trim();
    if (sanitized.isEmpty) {
      return '\u8bf7\u68c0\u67e5 Agent \u662f\u5426\u5b58\u5728\u3001\u914d\u5bf9\u7801\u662f\u5426\u8fc7\u671f\u4ee5\u53ca\u7f51\u7edc\u662f\u5426\u6b63\u5e38\u3002';
    }
    return sanitized;
  }
}
