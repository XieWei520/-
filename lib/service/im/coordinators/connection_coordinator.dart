import 'package:flutter/widgets.dart';

import '../../api/im_route_info.dart';
import 'package:wukongimfluttersdk/type/const.dart';

class StoredImInitCredentials {
  const StoredImInitCredentials({
    required this.uid,
    required this.apiToken,
    required this.imToken,
    required this.deviceSessionId,
  });

  final String uid;
  final String apiToken;
  final String imToken;
  final String deviceSessionId;

  @override
  bool operator ==(Object other) {
    return other is StoredImInitCredentials &&
        other.uid == uid &&
        other.apiToken == apiToken &&
        other.imToken == imToken &&
        other.deviceSessionId == deviceSessionId;
  }

  @override
  int get hashCode => Object.hash(uid, apiToken, imToken, deviceSessionId);

  @override
  String toString() {
    return 'StoredImInitCredentials(uid: $uid, apiToken: ***,'
        ' imToken: ***, deviceSessionId: $deviceSessionId)';
  }
}

class ConnectionCoordinator {
  const ConnectionCoordinator();

  StoredImInitCredentials? resolveStoredCredentials({
    String? uid,
    String? apiToken,
    String? imToken,
    String? deviceSessionId,
  }) {
    final resolvedUid = uid?.trim() ?? '';
    final resolvedApiToken = apiToken?.trim() ?? '';
    final resolvedImToken = imToken?.trim() ?? '';
    final resolvedDeviceSessionId = deviceSessionId?.trim() ?? '';
    if (resolvedUid.isEmpty ||
        resolvedApiToken.isEmpty ||
        resolvedImToken.isEmpty ||
        resolvedDeviceSessionId.isEmpty) {
      return null;
    }
    return StoredImInitCredentials(
      uid: resolvedUid,
      apiToken: resolvedApiToken,
      imToken: resolvedImToken,
      deviceSessionId: resolvedDeviceSessionId,
    );
  }

  bool shouldReuseInitializedSession({
    required String? initializedUid,
    required String? initializedToken,
    required String? initializedDeviceSessionId,
    required String uid,
    required String token,
    required String deviceSessionId,
    required int connectionStatus,
    required bool sessionRuntimeRunning,
  }) {
    if (initializedUid != uid ||
        initializedToken != token ||
        initializedDeviceSessionId != deviceSessionId) {
      return false;
    }

    switch (connectionStatus) {
      case WKConnectStatus.connecting:
      case WKConnectStatus.success:
      case WKConnectStatus.syncMsg:
      case WKConnectStatus.syncCompleted:
        return true;
      default:
        return false;
    }
  }

  Uri buildSessionGatewayUri({
    required String baseUrl,
    required String deviceSessionId,
    required int lastAckedSeq,
    String? controlProtocol,
  }) {
    final baseUri = Uri.parse(baseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final queryParameters = <String, String>{
      'device_session_id': deviceSessionId,
      'last_acked_seq': '$lastAckedSeq',
      if (controlProtocol != null && controlProtocol.trim().isNotEmpty)
        'control_protocol': controlProtocol.trim(),
    };

    if (baseUri.hasPort) {
      return Uri(
        scheme: scheme,
        host: baseUri.host,
        port: baseUri.port,
        path: '/v1/realtime/session/events/ws',
        queryParameters: queryParameters,
      );
    }
    return Uri(
      scheme: scheme,
      host: baseUri.host,
      path: '/v1/realtime/session/events/ws',
      queryParameters: queryParameters,
    );
  }

  String selectConnectAddr(ImRouteInfo route, {required String fallbackAddr}) {
    if (shouldPreferLocalFallbackImAddr(fallbackAddr) &&
        isValidTcpConnectAddr(fallbackAddr)) {
      return fallbackAddr.trim();
    }
    return route.resolvePreferredAddr(fallbackAddr: fallbackAddr);
  }

  bool shouldUseLocalPersistence({
    required bool isWeb,
    required bool sdkAppMode,
  }) {
    return !isWeb && sdkAppMode;
  }

  bool shouldStartNativeSessionRuntime({required bool isWeb}) => !isWeb;

  bool shouldDisconnectForBackgroundLifecycle({
    required bool isWeb,
    required bool hasActiveCallOrPendingSetup,
    bool keepRealtimeForDesktopNotifications = false,
  }) {
    if (isWeb || keepRealtimeForDesktopNotifications) {
      return false;
    }
    return !hasActiveCallOrPendingSetup;
  }

  bool shouldKeepConnectionInBackground({
    required AppLifecycleState lifecycleState,
    required bool hasActiveCallOrPendingSetup,
  }) {
    if (lifecycleState == AppLifecycleState.resumed ||
        lifecycleState == AppLifecycleState.inactive) {
      return true;
    }
    return hasActiveCallOrPendingSetup;
  }
}
