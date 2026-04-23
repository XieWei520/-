import 'dart:io';

class PlatformUtils {
  PlatformUtils._();

  /// 是否是Webƽ̨
  static bool get isWeb => identical(0, 0.0);

  /// 是否是Androidƽ̨
  static bool get isAndroid => !isWeb && Platform.isAndroid;

  /// 是否是iOSƽ̨
  static bool get isIOS => !isWeb && Platform.isIOS;

  /// 是否是MacOSƽ̨
  static bool get isMacOS => !isWeb && Platform.isMacOS;

  /// 是否是Windowsƽ̨
  static bool get isWindows => !isWeb && Platform.isWindows;

  /// 是否是Linuxƽ̨
  static bool get isLinux => !isWeb && Platform.isLinux;

  /// 是否是移动端
  static bool get isMobile => isAndroid || isIOS;

  /// 是否是桌面端
  static bool get isDesktop => isMacOS || isWindows || isLinux;

  /// 获取平台名称
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
