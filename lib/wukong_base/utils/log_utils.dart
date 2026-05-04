import 'package:flutter/foundation.dart';

/// Log levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Log utilities
class WKLogUtils {
  static bool _enableLogging = kDebugMode;

  /// Enable or disable logging
  static void setLogging(bool enabled) {
    _enableLogging = enabled;
  }

  /// Enable or disable file logging
  static void setFileLogging(bool enabled) {
    // File logging not implemented yet
  }

  /// Log debug message
  static void d(String tag, String message) {
    _log(LogLevel.debug, tag, message);
  }

  /// Log info message
  static void i(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  /// Log warning message
  static void w(String tag, String message) {
    _log(LogLevel.warning, tag, message);
  }

  /// Log error message
  static void e(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, tag, message, error, stackTrace);
  }

  static void _log(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!_enableLogging) return;

    final timestamp = DateTime.now().toIso8601String().split('T')[1].split('.')[0];
    final levelStr = _getLevelString(level);
    final logMessage = '[$timestamp][$levelStr][$tag] $message';

    switch (level) {
      case LogLevel.debug:
        debugPrint(logMessage);
        break;
      case LogLevel.info:
        debugPrint(logMessage);
        break;
      case LogLevel.warning:
        debugPrintWarn(logMessage);
        break;
      case LogLevel.error:
        debugPrint(logMessage);
        if (error != null) {
          debugPrint('Error: $error');
        }
        if (stackTrace != null) {
          debugPrint('StackTrace: $stackTrace');
        }
        break;
    }
  }

  static String _getLevelString(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warning:
        return 'W';
      case LogLevel.error:
        return 'E';
    }
  }
}

/// Debug print with warning styling
void debugPrintWarn(String message) {
  debugPrint(message);
}
