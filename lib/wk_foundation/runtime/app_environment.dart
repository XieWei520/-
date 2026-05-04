import 'package:flutter/foundation.dart';

enum AppPlatform {
  android,
  ios,
  web,
  windows,
  linux,
  macos,
  unknown,
}

@immutable
class AppEnvironment {
  const AppEnvironment._({
    required this.platform,
    required this.isWeb,
  });

  factory AppEnvironment({
    required AppPlatform platform,
    required bool isWeb,
  }) {
    final isWebPlatform = platform == AppPlatform.web;
    if (isWeb && !isWebPlatform) {
      throw ArgumentError.value(
        isWeb,
        'isWeb',
        'Only AppPlatform.web can be marked as web.',
      );
    }
    if (!isWeb && isWebPlatform) {
      throw ArgumentError.value(
        isWeb,
        'isWeb',
        'Web platform instances must be marked as web.',
      );
    }
    return AppEnvironment._(
      platform: platform,
      isWeb: isWeb,
    );
  }

  final AppPlatform platform;
  final bool isWeb;
  bool get usesSqfliteFfi {
    if (isWeb) {
      return false;
    }
    return platform == AppPlatform.windows ||
        platform == AppPlatform.linux ||
        platform == AppPlatform.macos;
  }

  static AppEnvironment detect() {
    if (kIsWeb) {
      return const AppEnvironment._(
        platform: AppPlatform.web,
        isWeb: true,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const AppEnvironment._(
          platform: AppPlatform.android,
          isWeb: false,
        );
      case TargetPlatform.iOS:
        return const AppEnvironment._(
          platform: AppPlatform.ios,
          isWeb: false,
        );
      case TargetPlatform.windows:
        return const AppEnvironment._(
          platform: AppPlatform.windows,
          isWeb: false,
        );
      case TargetPlatform.linux:
        return const AppEnvironment._(
          platform: AppPlatform.linux,
          isWeb: false,
        );
      case TargetPlatform.macOS:
        return const AppEnvironment._(
          platform: AppPlatform.macos,
          isWeb: false,
        );
      case TargetPlatform.fuchsia:
        return const AppEnvironment._(
          platform: AppPlatform.unknown,
          isWeb: false,
        );
    }
  }
}
