import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'mengxia_monitor_shell_client.dart';

typedef MengxiaShellExecutableResolver = Future<String?> Function();
typedef MengxiaShellProcessStarter =
    Future<void> Function(String executablePath, String workingDirectory);
typedef MengxiaShellListeningProbe = Future<bool> Function();
typedef MengxiaShellPlatformProbe = bool Function();

class MengxiaMonitorLaunchException implements Exception {
  const MengxiaMonitorLaunchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MengxiaMonitorLaunchService {
  MengxiaMonitorLaunchService({
    MengxiaShellExecutableResolver? resolveExecutablePath,
    MengxiaShellProcessStarter? startProcess,
    MengxiaShellListeningProbe? isShellListening,
    MengxiaShellPlatformProbe? isSupportedPlatform,
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

  MengxiaMonitorLaunchService.noop()
    : _enabled = false,
      _resolveExecutablePath = _defaultResolveExecutablePath,
      _startProcess = _defaultStartProcess,
      _isShellListening = _defaultIsShellListening,
      _isSupportedPlatform = _defaultIsSupportedPlatform,
      _startupTimeout = Duration.zero,
      _pollInterval = Duration.zero;

  final bool _enabled;
  final MengxiaShellExecutableResolver _resolveExecutablePath;
  final MengxiaShellProcessStarter _startProcess;
  final MengxiaShellListeningProbe _isShellListening;
  final MengxiaShellPlatformProbe _isSupportedPlatform;
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
      throw const MengxiaMonitorLaunchException(
        '找不到“MX信息监控”壳端程序。请先构建 tools/mengxia_monitor_shell_app，或确认打包目录包含 monitor_shells/mengxia/MX信息监控.exe。',
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

    throw const MengxiaMonitorLaunchException(
      '已尝试启动“MX信息监控”，但默认端口 18786 没有响应。请检查窗口是否启动成功，然后重新点击刷新。',
    );
  }

  Future<void> stopShell() async {
    // The MX shell is operator-owned because every launch needs manual login.
    // Do not kill a possibly user-controlled window from the manager page.
  }
}

bool _defaultIsSupportedPlatform() => Platform.isWindows;

Future<String?> _defaultResolveExecutablePath() async {
  const executableName = 'MX信息监控.exe';
  final executableDir = path.dirname(Platform.resolvedExecutable);
  final cwd = Directory.current.path;
  final candidates = <String>[
    path.join(executableDir, 'monitor_shells', 'mengxia', executableName),
    path.join(executableDir, executableName),
    path.join(cwd, 'monitor_shells', 'mengxia', executableName),
    path.join(
      cwd,
      'tools',
      'mengxia_monitor_shell_app',
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
      'mengxia_monitor_shell_app',
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
      'mengxia_monitor_shell_app',
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
      mengxiaMonitorDefaultShellPort,
      timeout: const Duration(milliseconds: 350),
    );
    return true;
  } on Object {
    return false;
  } finally {
    socket?.destroy();
  }
}
