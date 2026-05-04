import 'dart:async';
import 'dart:convert';

import '../service/api/login_bridge_api.dart';

typedef RequestLoginUuid = Future<LoginUuidResult> Function();
typedef PollLoginStatus = Future<LoginStatusResult> Function(String uuid);
typedef LoadDevices = Future<List<LoginBridgeDeviceRecord>> Function();
typedef DeleteDevice = Future<void> Function(String deviceId);
typedef QuitPcWeb = Future<void> Function();

@Deprecated('Use AuthRepositoryImpl and LoginBridgeApi from lib/modules/auth instead.')
class PCLoginService {
  PCLoginService({
    RequestLoginUuid? requestLoginUuid,
    PollLoginStatus? pollLoginStatus,
    LoadDevices? loadDevices,
    DeleteDevice? deleteDevice,
    QuitPcWeb? quitPcWeb,
    Duration pollInterval = const Duration(seconds: 2),
  }) : _requestLoginUuid =
           requestLoginUuid ?? (() => LoginBridgeApi.instance.getLoginUuid()),
       _pollLoginStatus =
           pollLoginStatus ?? ((uuid) => LoginBridgeApi.instance.getLoginStatus(uuid)),
       _loadDevices = loadDevices ?? (() => LoginBridgeApi.instance.getDevices()),
       _deleteDevice =
           deleteDevice ?? ((deviceId) => LoginBridgeApi.instance.deleteDevice(deviceId)),
       _quitPcWeb = quitPcWeb ?? (() => LoginBridgeApi.instance.quitPc()),
       _pollInterval = pollInterval;

  final RequestLoginUuid _requestLoginUuid;
  final PollLoginStatus _pollLoginStatus;
  final LoadDevices _loadDevices;
  final DeleteDevice _deleteDevice;
  final QuitPcWeb _quitPcWeb;
  final Duration _pollInterval;

  Timer? _pollingTimer;
  int _pollingCycleId = 0;
  bool _isPollingRequestInFlight = false;
  Function(bool success, String? authCode)? onLoginStatusChanged;

  Future<String> requestPCLoginQRCode() async {
    final result = await _requestLoginUuid();
    return result.uuid;
  }

  void startPollingLoginStatus(String scene) {
    stopPollingLoginStatus();
    final cycleId = _pollingCycleId;
    _pollingTimer = Timer.periodic(_pollInterval, (timer) async {
      if (cycleId != _pollingCycleId) {
        return;
      }
      if (_isPollingRequestInFlight) {
        return;
      }
      _isPollingRequestInFlight = true;
      try {
        final result = await _pollLoginStatus(scene);
        if (cycleId != _pollingCycleId) {
          return;
        }
        if (!result.isAuthed) {
          return;
        }
        stopPollingLoginStatus();
        onLoginStatusChanged?.call(true, result.authCode);
      } catch (_) {
        // Compatibility facade: ignore transient polling failures and keep polling.
      } finally {
        if (cycleId == _pollingCycleId) {
          _isPollingRequestInFlight = false;
        }
      }
    });
  }

  void stopPollingLoginStatus() {
    _pollingCycleId += 1;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPollingRequestInFlight = false;
  }

  Future<void> logoutAllSessions() => _quitPcWeb();

  Future<void> logoutSession(String deviceId) => _deleteDevice(deviceId);

  Future<List<PCSessionInfo>> getSessions() async {
    final devices = await _loadDevices();
    return devices
        .map(
          (device) => PCSessionInfo(
            deviceId: device.deviceId,
            deviceName: device.deviceName,
            deviceType: device.deviceModel,
            loginTime: 0,
            isMuted: false,
            isOnline: true,
          ),
        )
        .toList();
  }

  String generateQRCodeContent(String scene, String baseUrl) {
    return '$baseUrl/pc_login?scene=$scene';
  }

  String? parseQRCodeContent(String content) {
    try {
      final uri = Uri.parse(content);
      if (uri.queryParameters.containsKey('scene')) {
        return uri.queryParameters['scene'];
      }
      final json = jsonDecode(content) as Map<String, dynamic>;
      return json['scene']?.toString();
    } catch (_) {
      return null;
    }
  }
}

/// PC session info model
class PCSessionInfo {
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final int loginTime;
  final bool isMuted;
  final bool isOnline;

  PCSessionInfo({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.loginTime,
    this.isMuted = false,
    this.isOnline = true,
  });

  factory PCSessionInfo.fromJson(Map<String, dynamic> json) {
    return PCSessionInfo(
      deviceId: json['device_id'] ?? '',
      deviceName: json['device_name'] ?? 'Unknown',
      deviceType: json['device_type'] ?? 'web',
      loginTime: json['login_time'] ?? 0,
      isMuted: json['is_muted'] ?? false,
      isOnline: json['is_online'] ?? true,
    );
  }
}
