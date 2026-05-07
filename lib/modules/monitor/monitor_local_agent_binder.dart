import 'dart:convert';
import 'dart:io';

class LocalAgentBindRequest {
  const LocalAgentBindRequest({
    required this.serverUrl,
    required this.pairingCode,
    this.storeDir,
    this.forcePair = false,
  });

  final String serverUrl;
  final String pairingCode;
  final String? storeDir;
  final bool forcePair;
}

class LocalAgentBindResult {
  const LocalAgentBindResult({required this.message});

  final String message;
}

typedef LocalAgentActionResult = LocalAgentBindResult;

class LocalAgentChatOption {
  const LocalAgentChatOption({required this.name});

  final String name;
}

enum LocalAgentBindPhase {
  platform,
  pair,
  heartbeat,
  browserLogin,
  browserStatus,
  clearBrowserProfile,
  listen,
}

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
    final storeDir = _normalizeStoreDir(request.storeDir);
    if (request.forcePair || !_hasExistingAgentConfig(storeDir)) {
      await _runAgentAction(
        phase: LocalAgentBindPhase.pair,
        command: 'pair',
        arguments: <String>[
          '--server',
          request.serverUrl,
          '--code',
          request.pairingCode,
        ],
        storeDir: storeDir,
      );
    }
    await _runAgentAction(
      phase: LocalAgentBindPhase.heartbeat,
      command: 'run',
      arguments: const <String>['--once'],
      storeDir: storeDir,
    );
    return const LocalAgentBindResult(message: 'Agent 已绑定并上线');
  }

  Future<LocalAgentActionResult> openBrowserLogin({String? storeDir}) {
    return _runCommandAction(
      phase: LocalAgentBindPhase.browserLogin,
      command: 'browser-login',
      arguments: const <String>[],
      storeDir: storeDir,
      fallbackMessage: '已打开 Chromium 飞书登录窗口，请扫码登录。',
    );
  }

  Future<LocalAgentActionResult> checkBrowserStatus({String? storeDir}) {
    return _runCommandAction(
      phase: LocalAgentBindPhase.browserStatus,
      command: 'browser-status',
      arguments: const <String>[],
      storeDir: storeDir,
      fallbackMessage: '飞书浏览器状态已同步。',
    );
  }

  Future<LocalAgentActionResult> clearBrowserProfile({String? storeDir}) {
    return _runCommandAction(
      phase: LocalAgentBindPhase.clearBrowserProfile,
      command: 'clear-browser-profile',
      arguments: const <String>[],
      storeDir: storeDir,
      fallbackMessage: '已清除飞书登录状态，请重新打开飞书登录并扫码。',
    );
  }

  Future<LocalAgentActionResult> listenOnce({String? storeDir}) {
    return _runCommandAction(
      phase: LocalAgentBindPhase.listen,
      command: 'listen',
      arguments: const <String>['--once'],
      storeDir: storeDir,
      fallbackMessage: '监听完成，页面已刷新。',
      preferFallbackMessage: true,
    );
  }

  Future<LocalAgentActionResult> heartbeatOnce({String? storeDir}) {
    return _runCommandAction(
      phase: LocalAgentBindPhase.heartbeat,
      command: 'run',
      arguments: const <String>['--once'],
      storeDir: storeDir,
      fallbackMessage: 'Agent 状态已更新，页面已刷新。',
      preferFallbackMessage: true,
    );
  }

  Future<List<String>> listChats({String? storeDir}) async {
    final effectiveStoreDir = _normalizeStoreDir(storeDir);
    final result = await _runAgentAction(
      phase: LocalAgentBindPhase.browserStatus,
      command: 'list-chats',
      arguments: const <String>[],
      storeDir: effectiveStoreDir,
    );
    final names = _parseChatNames(result.stdout);
    if (names.isNotEmpty) {
      return names;
    }
    return _readCachedChatNames(effectiveStoreDir);
  }

  Future<LocalAgentActionResult> _runCommandAction({
    required LocalAgentBindPhase phase,
    required String command,
    required List<String> arguments,
    required String? storeDir,
    required String fallbackMessage,
    bool preferFallbackMessage = false,
  }) async {
    final result = await _runAgentAction(
      phase: phase,
      command: command,
      arguments: arguments,
      storeDir: storeDir,
    );
    if (preferFallbackMessage) {
      return LocalAgentBindResult(message: fallbackMessage);
    }
    return LocalAgentBindResult(
      message: _firstNonEmpty(<String>[
        result.stdout,
        result.stderr,
        fallbackMessage,
      ]),
    );
  }

  Future<LocalAgentProcessResult> _runAgentAction({
    required LocalAgentBindPhase phase,
    required String command,
    required List<String> arguments,
    required String? storeDir,
  }) async {
    if (!_isWindows()) {
      throw const LocalAgentBindException(
        '请在 Windows 桌面端使用一键绑定。',
        phase: LocalAgentBindPhase.platform,
      );
    }

    final effectiveStoreDir = _normalizeStoreDir(storeDir);
    final result = await _runProcess('dart', <String>[
      'run',
      'bin/feishu_monitor_agent.dart',
      command,
      ...arguments,
      '--store-dir',
      effectiveStoreDir,
    ]);
    final stdout = _sanitizeOutput(result.stdout);
    final stderr = _sanitizeOutput(result.stderr);
    if (result.exitCode != 0) {
      throw LocalAgentBindException(
        _actionFailureMessage(phase, stdout, stderr),
        phase: phase,
      );
    }
    return LocalAgentProcessResult(
      exitCode: result.exitCode,
      stdout: stdout,
      stderr: stderr,
    );
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

  static String _normalizeStoreDir(String? storeDir) {
    final trimmed = storeDir?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return _defaultStoreDir();
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

  static bool _hasExistingAgentConfig(String storeDir) {
    final file = File('$storeDir${Platform.pathSeparator}agent_config.json');
    if (!file.existsSync()) {
      return false;
    }
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        return false;
      }
      final agentId = decoded['agent_id']?.toString().trim() ?? '';
      final agentToken = decoded['agent_token']?.toString().trim() ?? '';
      return agentId.isNotEmpty && agentToken.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String _actionFailureMessage(
    LocalAgentBindPhase phase,
    String stdout,
    String stderr,
  ) {
    final output = _firstNonEmpty(<String>[stderr, stdout]);
    switch (phase) {
      case LocalAgentBindPhase.pair:
        return 'Agent 绑定失败：${_friendlyPairError(output)}';
      case LocalAgentBindPhase.heartbeat:
        return 'Agent 心跳失败：$output';
      case LocalAgentBindPhase.browserLogin:
        return 'Chromium 登录启动失败：$output';
      case LocalAgentBindPhase.browserStatus:
        return '浏览器状态检查失败：$output';
      case LocalAgentBindPhase.clearBrowserProfile:
        return '清除飞书登录状态失败：$output';
      case LocalAgentBindPhase.listen:
        return '监听失败：$output';
      case LocalAgentBindPhase.platform:
        return '请在 Windows 桌面端使用一键绑定。';
    }
  }

  static String _friendlyPairError(String value) {
    final sanitized = _sanitizeOutput(value);
    final lower = sanitized.toLowerCase();
    if (lower.contains('pairing_code_used')) {
      return '配对码已被使用，请重新生成配对码后再绑定。';
    }
    if (lower.contains('pairing_code_expired')) {
      return '配对码已过期，请重新生成配对码后再绑定。';
    }
    if (lower.contains('pairing_code_not_found') ||
        lower.contains('invalid_pairing_code')) {
      return '配对码无效，请重新生成配对码后再绑定。';
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
      return '请检查 Agent 是否存在、配对码是否过期以及网络是否正常。';
    }
    return sanitized;
  }

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  static List<String> _parseChatNames(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) {
        return const <String>[];
      }
      final names = <String>[];
      final seen = <String>{};
      for (final item in decoded) {
        final name = item is Map
            ? item['name']?.toString().trim() ?? ''
            : item.toString().trim();
        if (name.isEmpty || seen.contains(name)) {
          continue;
        }
        seen.add(name);
        names.add(name);
      }
      return names;
    } catch (_) {
      return const <String>[];
    }
  }

  static List<String> _readCachedChatNames(String storeDir) {
    final file = File(
      '$storeDir${Platform.pathSeparator}runtime${Platform.pathSeparator}feishu-chat-cache.json',
    );
    if (!file.existsSync()) {
      return const <String>[];
    }
    try {
      return _parseChatNames(file.readAsStringSync());
    } catch (_) {
      return const <String>[];
    }
  }
}
