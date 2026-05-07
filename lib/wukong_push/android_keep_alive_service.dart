import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../wukong_base/endpoint/endpoint_handler.dart';
import '../wukong_base/endpoint/endpoint_manager.dart';

const String androidKeepAliveEndpoint = 'show_keep_alive_item';

abstract class AndroidKeepAliveBridge {
  Future<bool> start();

  Future<bool> stop();

  Future<bool> openBatteryOptimizationSettings();
}

class DefaultAndroidKeepAliveBridge implements AndroidKeepAliveBridge {
  const DefaultAndroidKeepAliveBridge();

  static const MethodChannel _channel = MethodChannel(
    'wukong_im_app/android_keep_alive',
  );

  @override
  Future<bool> start() => _invokeBool('startKeepAlive');

  @override
  Future<bool> stop() => _invokeBool('stopKeepAlive');

  @override
  Future<bool> openBatteryOptimizationSettings() {
    return _invokeBool('openBatteryOptimizationSettings');
  }

  Future<bool> _invokeBool(String method) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on FlutterError {
      return false;
    }
  }
}

class AndroidKeepAliveService {
  AndroidKeepAliveService({AndroidKeepAliveBridge? bridge})
    : _bridge = bridge ?? const DefaultAndroidKeepAliveBridge();

  static final AndroidKeepAliveService instance = AndroidKeepAliveService();

  final AndroidKeepAliveBridge _bridge;
  bool _registered = false;

  void registerEndpoint({EndpointManager? endpointManager}) {
    final manager = endpointManager ?? EndpointManager.getInstance();
    if (_registered || manager.hasEndpoint(androidKeepAliveEndpoint)) {
      _registered = true;
      return;
    }
    manager.setMethod(
      androidKeepAliveEndpoint,
      '',
      0,
      SimpleFunctionHandler(([dynamic param]) {
        if (param is! BuildContext) {
          return null;
        }
        return AndroidKeepAliveSettingsTile(bridge: _bridge);
      }),
    );
    _registered = true;
  }

  Future<bool> start() => _bridge.start();

  Future<bool> stop() => _bridge.stop();

  Future<bool> startForLoggedInAndroidAlerts() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return Future<bool>.value(false);
    }
    return start();
  }
}

@visibleForTesting
class AndroidKeepAliveSettingsTile extends StatelessWidget {
  const AndroidKeepAliveSettingsTile({
    super.key,
    required AndroidKeepAliveBridge bridge,
  }) : _bridge = bridge;

  final AndroidKeepAliveBridge _bridge;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.battery_saver_outlined),
      title: const Text('Android background alerts'),
      subtitle: const Text(
        'Keep the local IM connection alive and open battery optimization settings.',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await _bridge.start();
        await _bridge.openBatteryOptimizationSettings();
      },
    );
  }
}
