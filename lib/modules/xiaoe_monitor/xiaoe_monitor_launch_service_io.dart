import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'xiaoe_monitor_shell_client.dart';

typedef XiaoeShellExecutableResolver = Future<String?> Function();
typedef XiaoeShellProcessStarter =
    Future<void> Function(String executablePath, String workingDirectory);
typedef XiaoeShellListeningProbe = Future<bool> Function();
typedef XiaoeShellPlatformProbe = bool Function();

class XiaoeMonitorLaunchException implements Exception {
  const XiaoeMonitorLaunchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class XiaoeMonitorLaunchService {
  XiaoeMonitorLaunchService({
    XiaoeShellExecutableResolver? resolveExecutablePath,
    XiaoeShellProcessStarter? startProcess,
    XiaoeShellListeningProbe? isShellListening,
    XiaoeShellPlatformProbe? isSupportedPlatform,
    Duration startupTimeout = const Duration(seconds: 8),
    Duration pollInterval = const Duration(milliseconds: 250),
  }) : _enabled = true,
       _resolveExecutablePath =
           resolveExecutablePath ?? _defaultResolveExecutablePath,
       _startProcess = startProcess ?? _defaultStartProcess,
       _isShellListening = isShellListening ?? _defaultIsShellListening,
       _isSupportedPlatform =
           isSupportedPlatform ?? _defaultIsSupportedPlatform,
       _startupTimeout = startupTimeout,
       _pollInterval = pollInterval;

  const XiaoeMonitorLaunchService.noop()
    : _enabled = false,
      _resolveExecutablePath = _defaultResolveExecutablePath,
      _startProcess = _defaultStartProcess,
      _isShellListening = _defaultIsShellListening,
      _isSupportedPlatform = _defaultIsSupportedPlatform,
      _startupTimeout = Duration.zero,
      _pollInterval = Duration.zero;

  final bool _enabled;
  final XiaoeShellExecutableResolver _resolveExecutablePath;
  final XiaoeShellProcessStarter _startProcess;
  final XiaoeShellListeningProbe _isShellListening;
  final XiaoeShellPlatformProbe _isSupportedPlatform;
  final Duration _startupTimeout;
  final Duration _pollInterval;

  Future<void> startShell() async {
    if (!_enabled || !_isSupportedPlatform()) {
      return;
    }
    if (await _isShellListening()) {
      return;
    }

    final executablePath = await _resolveExecutablePath();
    if (executablePath == null || executablePath.trim().isEmpty) {
      throw const XiaoeMonitorLaunchException(
        '找不到“小鹅通信息监控”壳端程序。请先构建 tools/xiaoe_monitor_shell_app，'
        '或确认打包目录包含 monitor_shells/xiaoe/xiaoe_monitor_shell_app.exe。',
      );
    }

    await _startProcess(executablePath, path.dirname(executablePath));
    if (_startupTimeout <= Duration.zero) {
      return;
    }

    final deadline = DateTime.now().add(_startupTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _isShellListening()) {
        return;
      }
      await Future<void>.delayed(_pollInterval);
    }

    throw const XiaoeMonitorLaunchException(
      '已尝试启动“小鹅通信息监控”，但默认端口 18806 没有响应。'
      '请检查窗口是否启动成功，然后重新点击刷新。',
    );
  }

  Future<void> stopShell() async {
    // The Xiaoe shell is operator-owned because the page requires manual login
    // and manual target-page selection.
  }
}

bool _defaultIsSupportedPlatform() => Platform.isWindows;

Future<String?> _defaultResolveExecutablePath() async {
  const executableName = 'xiaoe_monitor_shell_app.exe';
  final executableDir = path.dirname(Platform.resolvedExecutable);
  final cwd = Directory.current.path;
  final candidates = <String>[
    path.join(executableDir, 'monitor_shells', 'xiaoe', executableName),
    path.join(executableDir, executableName),
    path.join(cwd, 'monitor_shells', 'xiaoe', executableName),
    path.join(
      cwd,
      'tools',
      'xiaoe_monitor_shell_app',
      'build',
      'windows',
      'x64',
      'runner',
      'Release',
      executableName,
    ),
    path.join(
      cwd,
      'tools',
      'xiaoe_monitor_shell_app',
      'build',
      'windows',
      'x64',
      'runner',
      'Debug',
      executableName,
    ),
    path.join(
      cwd,
      'tools',
      'xiaoe_monitor_shell_app',
      'build',
      'windows',
      'x64',
      'runner',
      'Profile',
      executableName,
    ),
  ];

  for (final candidate in candidates) {
    if (candidate.trim().isNotEmpty && await File(candidate).exists()) {
      return candidate;
    }
  }
  return null;
}

Future<void> _defaultStartProcess(
  String executablePath,
  String workingDirectory,
) async {
  await Process.start(
    executablePath,
    const <String>[],
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.detached,
  );
}

Future<bool> _defaultIsShellListening() async {
  Socket? socket;
  try {
    socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      Uri.parse(xiaoeMonitorDefaultShellBaseUrl).port,
      timeout: const Duration(milliseconds: 350),
    );
    return true;
  } on Object {
    return false;
  } finally {
    socket?.destroy();
  }
}
