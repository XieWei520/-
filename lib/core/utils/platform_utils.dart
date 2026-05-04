import 'package:flutter/foundation.dart';

class PlatformUtils {
  PlatformUtils._();

  static bool get isWeb => kIsWeb;

  static bool get isAndroid =>
      !isWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !isWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isMacOS =>
      !isWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isWindows =>
      !isWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool get isLinux =>
      !isWeb && defaultTargetPlatform == TargetPlatform.linux;

  static bool get isMobile => isAndroid || isIOS;

  static bool get isDesktop => isMacOS || isWindows || isLinux;

  static String get platformName {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isMacOS) return 'macOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }
}
