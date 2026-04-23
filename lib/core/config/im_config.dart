import 'package:flutter/foundation.dart';

import 'api_config.dart';

class IMConfig {
  IMConfig._();

  static String get connectAddr => ApiConfig.wsAddr;

  static const int protoVersion = 0x04;

  static const int deviceFlagApp = 0;
  static const int deviceFlagWeb = 1;
  static const int deviceFlagPC = 2;
  static const int deviceFlagIPad = 3;
  static int? _debugDeviceFlagOverride;

  static void setDebugDeviceFlagOverride(int deviceFlag) {
    _debugDeviceFlagOverride = deviceFlag;
  }

  static void clearDebugDeviceFlagOverride() {
    _debugDeviceFlagOverride = null;
  }

  static bool isSupportedDeviceFlag(int deviceFlag) {
    return deviceFlag >= deviceFlagApp && deviceFlag <= deviceFlagIPad;
  }

  static int get platformDeviceFlag {
    if (kIsWeb) {
      return deviceFlagWeb;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return deviceFlagPC;
      default:
        return deviceFlagApp;
    }
  }

  static int get currentDeviceFlag {
    final debugOverride = _debugDeviceFlagOverride;
    if (kDebugMode &&
        debugOverride != null &&
        isSupportedDeviceFlag(debugOverride)) {
      return debugOverride;
    }
    return platformDeviceFlag;
  }

  static const int maxRetryCount = 5;
  static const int heartbeatInterval = 60;
  static const int pageSize = 50;
}
