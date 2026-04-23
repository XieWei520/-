import 'dart:io';

/// Platform utilities for handling platform-specific code
class PlatformUtils {
  /// Check if running on iOS
  static bool get isIOS => Platform.isIOS;

  /// Check if running on Android
  static bool get isAndroid => Platform.isAndroid;

  /// Check if running on macOS
  static bool get isMacOS => Platform.isMacOS;

  /// Check if running on Windows
  static bool get isWindows => Platform.isWindows;

  /// Check if running on Linux
  static bool get isLinux => Platform.isLinux;

  /// Check if running on Fuchsia
  static bool get isFuchsia => Platform.isFuchsia;

  /// Get device name
  static String get deviceName {
    if (isIOS) return 'iOS Device';
    if (isAndroid) return 'Android Device';
    return 'Unknown Device';
  }

  /// Get OS version
  static String get osVersion {
    return Platform.operatingSystemVersion;
  }
}
