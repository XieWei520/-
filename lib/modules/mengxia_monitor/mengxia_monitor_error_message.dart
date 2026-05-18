import 'package:dio/dio.dart';

import 'mengxia_monitor_launch_service.dart';
import 'mengxia_monitor_shell_client.dart';

String describeMengxiaMonitorShellError(Object error) {
  if (error is MengxiaMonitorLaunchException) {
    return error.message;
  }

  if (_isShellUnavailable(error)) {
    return 'MX信息监控未连接。请先启动或重启“MX信息监控”窗口，完成人工登录后点击刷新；默认端口 $mengxiaMonitorDefaultShellPort。';
  }

  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return 'MX信息监控请求失败（HTTP $statusCode）。请确认打开的是最新“MX信息监控”窗口，然后刷新。';
    }
  }

  final detail = _sanitizeErrorText(error.toString());
  if (detail.isEmpty) {
    return 'MX信息监控请求失败。请确认壳端已启动后重试。';
  }
  return 'MX信息监控请求失败：$detail';
}

bool _isShellUnavailable(Object error) {
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.unknown => _looksLikeLoopbackConnectionError(
        '${error.message} ${error.error}',
      ),
      _ => false,
    };
  }
  return _looksLikeLoopbackConnectionError(error.toString());
}

bool _looksLikeLoopbackConnectionError(String value) {
  final normalized = value.toLowerCase();
  final mentionsLoopback =
      normalized.contains('127.0.0.1') || normalized.contains('localhost');
  final mentionsConnection =
      normalized.contains('connection') ||
      normalized.contains('refused') ||
      normalized.contains('failed') ||
      normalized.contains('port');
  return mentionsLoopback && mentionsConnection;
}

String _sanitizeErrorText(String value) {
  var normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  normalized = normalized.replaceFirst(
    RegExp(r'^DioException\s*\[[^\]]+\]:\s*'),
    '',
  );
  normalized = normalized.replaceAll(
    RegExp(r'https?://(?:127\.0\.0\.1|localhost):\d+', caseSensitive: false),
    '本机服务',
  );
  normalized = normalized.replaceAll(
    RegExp(
      r'(address\s*=\s*)?(127\.0\.0\.1|localhost),?\s*port\s*=\s*\d+',
      caseSensitive: false,
    ),
    '本机服务',
  );
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length > 160) {
    return '${normalized.substring(0, 160)}...';
  }
  return normalized;
}
