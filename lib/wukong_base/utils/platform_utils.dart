import 'package:flutter/foundation.dart';

/// Platform utilities for handling platform-specific code
class PlatformUtils {
  /// Check if running on web
  static bool get isWeb => kIsWeb;

  /// Check if running on iOS
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Check if running on Android
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Check if running on macOS
  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// Check if running on Windows
  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Check if running on Linux
  static bool get isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// Check if running on Fuchsia
  static bool get isFuchsia =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia;

  /// Get device name
  static String get deviceName {
    if (isWeb) return 'Web Browser';
    if (isIOS) return 'iOS Device';
    if (isAndroid) return 'Android Device';
    return 'Unknown Device';
  }

  /// Get OS version
  static String get osVersion {
    if (isWeb) return 'web';
    return defaultTargetPlatform.name;
  }
}
