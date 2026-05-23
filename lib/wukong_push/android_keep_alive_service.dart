import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../wukong_base/endpoint/endpoint_handler.dart';
import '../wukong_base/endpoint/endpoint_manager.dart';

const String androidKeepAliveEndpoint = 'show_keep_alive_item';

abstract class AndroidKeepAliveBridge {
  Future<bool> start();

  Future<bool> stop();

  Future<AndroidKeepAliveStatus> getStatus();

  Future<bool> openNotificationSettings();

  Future<bool> openBatteryOptimizationSettings();
}

class AndroidKeepAliveStatus {
  const AndroidKeepAliveStatus({
    required this.supported,
    required this.notificationEnabled,
    required this.ignoringBatteryOptimizations,
    required this.serviceRunning,
  });

  factory AndroidKeepAliveStatus.unsupported() {
    return const AndroidKeepAliveStatus(
      supported: false,
      notificationEnabled: false,
      ignoringBatteryOptimizations: false,
      serviceRunning: false,
    );
  }

  factory AndroidKeepAliveStatus.fromMap(Map<dynamic, dynamic> raw) {
    return AndroidKeepAliveStatus(
      supported: raw['supported'] == true,
      notificationEnabled: raw['notificationEnabled'] == true,
      ignoringBatteryOptimizations:
          raw['ignoringBatteryOptimizations'] == true,
      serviceRunning: raw['serviceRunning'] == true,
    );
  }

  final bool supported;
  final bool notificationEnabled;
  final bool ignoringBatteryOptimizations;
  final bool serviceRunning;
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
  Future<AndroidKeepAliveStatus> getStatus() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return AndroidKeepAliveStatus.unsupported();
    }
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getKeepAliveStatus',
      );
      if (result == null) {
        return AndroidKeepAliveStatus.unsupported();
      }
      return AndroidKeepAliveStatus.fromMap(result);
    } on MissingPluginException {
      return AndroidKeepAliveStatus.unsupported();
    } on PlatformException {
      return AndroidKeepAliveStatus.unsupported();
    } on FlutterError {
      return AndroidKeepAliveStatus.unsupported();
    }
  }

  @override
  Future<bool> openNotificationSettings() => _invokeBool(
    'openNotificationSettings',
  );

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
      leading: const Icon(Icons.phonelink_ring_outlined),
      title: const Text('本机后台提醒增强'),
      subtitle: const Text(
        '没有厂商推送时，尽量保持 IM 连接存活；不等同于离线推送，'
        '仍需允许通知、后台运行和忽略电池优化。',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await _bridge.start();
        if (!context.mounted) {
          return;
        }
        final status = await _bridge.getStatus();
        if (!context.mounted) {
          return;
        }
        await _showDiagnostics(context, status);
      },
    );
  }

  Future<void> _showDiagnostics(
    BuildContext context,
    AndroidKeepAliveStatus status,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('本机后台提醒诊断'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _StatusRow(
                label: '通知权限',
                enabled: status.notificationEnabled,
                enabledText: '已开启',
                disabledText: '未开启',
              ),
              _StatusRow(
                label: '电池优化',
                enabled: status.ignoringBatteryOptimizations,
                enabledText: '已忽略',
                disabledText: '可能限制后台',
              ),
              _StatusRow(
                label: '保活服务',
                enabled: status.serviceRunning,
                enabledText: '运行中',
                disabledText: '未运行',
              ),
              const SizedBox(height: 12),
              const Text(
                '没有厂商推送时，应用需要保持进程和 IM 连接存活。'
                '如果系统限制后台运行，消息提醒仍可能延迟或丢失。',
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _bridge.openNotificationSettings();
              },
              child: const Text('通知设置'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _bridge.openBatteryOptimizationSettings();
              },
              child: const Text('后台设置'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.enabled,
    required this.enabledText,
    required this.disabledText,
  });

  final String label;
  final bool enabled;
  final String enabledText;
  final String disabledText;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.green : Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(
            enabled ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            enabled ? enabledText : disabledText,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
