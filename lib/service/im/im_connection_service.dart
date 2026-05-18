import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../api/im_route_info.dart';
import 'coordinators/connection_coordinator.dart';

typedef ImRouteResolver = Future<String> Function(String uid);
typedef ImConnectionStatusHandler =
    void Function(int status, int? reasonCode, String? extra);
typedef ImConnectionLogHandler =
    void Function(Object error, StackTrace stackTrace);

@immutable
class ImSdkSetupOptions {
  const ImSdkSetupOptions({
    required this.credentials,
    required this.fallbackAddr,
    required this.resolveAddr,
    required this.protoVersion,
    required this.deviceFlag,
    required this.debug,
  });

  final ImConnectionCredentials credentials;
  final String fallbackAddr;
  final Future<String> Function() resolveAddr;
  final int protoVersion;
  final int deviceFlag;
  final bool debug;
}

@immutable
class ImConnectionCredentials {
  const ImConnectionCredentials({
    required this.uid,
    required this.apiToken,
    required this.imToken,
    required this.deviceSessionId,
  });

  final String uid;
  final String apiToken;
  final String imToken;
  final String deviceSessionId;

  bool get isComplete {
    return uid.trim().isNotEmpty &&
        apiToken.trim().isNotEmpty &&
        imToken.trim().isNotEmpty &&
        deviceSessionId.trim().isNotEmpty;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ImConnectionCredentials &&
            other.uid == uid &&
            other.apiToken == apiToken &&
            other.imToken == imToken &&
            other.deviceSessionId == deviceSessionId;
  }

  @override
  int get hashCode {
    return Object.hash(uid, apiToken, imToken, deviceSessionId);
  }

  @override
  String toString() {
    return 'ImConnectionCredentials(uid: $uid, apiToken: ***, '
        'imToken: ***, deviceSessionId: $deviceSessionId)';
  }
}

@immutable
class ImConnectionSnapshot {
  const ImConnectionSnapshot({
    this.isInitializing = false,
    this.isInitialized = false,
    this.isConnected = false,
    this.status = WKConnectStatus.fail,
    this.reasonCode,
    this.uid,
    this.error,
  });

  final bool isInitializing;
  final bool isInitialized;
  final bool isConnected;
  final int status;
  final int? reasonCode;
  final String? uid;
  final String? error;

  ImConnectionSnapshot copyWith({
    bool? isInitializing,
    bool? isInitialized,
    bool? isConnected,
    int? status,
    int? reasonCode,
    bool clearReasonCode = false,
    String? uid,
    bool clearUid = false,
    String? error,
    bool clearError = false,
  }) {
    return ImConnectionSnapshot(
      isInitializing: isInitializing ?? this.isInitializing,
      isInitialized: isInitialized ?? this.isInitialized,
      isConnected: isConnected ?? this.isConnected,
      status: status ?? this.status,
      reasonCode: clearReasonCode ? null : (reasonCode ?? this.reasonCode),
      uid: clearUid ? null : (uid ?? this.uid),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ImConnectionSnapshot &&
            other.isInitializing == isInitializing &&
            other.isInitialized == isInitialized &&
            other.isConnected == isConnected &&
            other.status == status &&
            other.reasonCode == reasonCode &&
            other.uid == uid &&
            other.error == error;
  }

  @override
  int get hashCode {
    return Object.hash(
      isInitializing,
      isInitialized,
      isConnected,
      status,
      reasonCode,
      uid,
      error,
    );
  }
}

@immutable
class ImConnectionBackoffPolicy {
  const ImConnectionBackoffPolicy({
    this.baseDelay = const Duration(milliseconds: 800),
    this.maxDelay = const Duration(seconds: 30),
    this.maxAttempts = 8,
  });

  final Duration baseDelay;
  final Duration maxDelay;
  final int maxAttempts;

  Duration delayForAttempt(int attempt) {
    final safeAttempt = attempt <= 0 ? 1 : attempt;
    final multiplier = 1 << (safeAttempt - 1).clamp(0, 30);
    final delayMs = baseDelay.inMilliseconds * multiplier;
    return Duration(
      milliseconds: delayMs.clamp(
        baseDelay.inMilliseconds,
        maxDelay.inMilliseconds,
      ),
    );
  }
}

abstract interface class ImSdkConnectionPort {
  Future<bool> setup(ImSdkSetupOptions options);

  void connect();

  void disconnect({required bool isLogout});

  void bindStatusListener({
    required String key,
    required ImConnectionStatusHandler onStatus,
  });

  void unbindStatusListener(String key);
}

abstract interface class ImRealtimeRuntimePort {
  bool get isRunning;

  Future<void> start({
    required String apiToken,
    required String deviceSessionId,
    required int lastAckedSeq,
  });

  Future<void> stop();
}

class ImConnectionService {
  ImConnectionService({
    required this.sdk,
    required this.realtimeRuntime,
    required this.routeResolver,
    this.backoffPolicy = const ImConnectionBackoffPolicy(),
    this.connectTimeout = const Duration(seconds: 20),
    this.listenerKey = 'im_connection_service_listener',
  });

  final ImSdkConnectionPort sdk;
  final ImRealtimeRuntimePort realtimeRuntime;
  final ImRouteResolver routeResolver;
  final ImConnectionBackoffPolicy backoffPolicy;
  final Duration connectTimeout;
  final String listenerKey;
  final ConnectionCoordinator _coordinator = const ConnectionCoordinator();
  ImConnectionSnapshot _snapshot = const ImConnectionSnapshot();

  ImConnectionSnapshot get snapshot {
    return _snapshot;
  }

  static ImConnectionCredentials? resolveStoredCredentials({
    String? uid,
    String? apiToken,
    String? imToken,
    String? deviceSessionId,
  }) {
    final resolvedUid = uid?.trim() ?? '';
    final resolvedApiToken = apiToken?.trim() ?? '';
    final resolvedImToken = imToken?.trim() ?? '';
    final resolvedDeviceSessionId = deviceSessionId?.trim() ?? '';
    final credentials = ImConnectionCredentials(
      uid: resolvedUid,
      apiToken: resolvedApiToken,
      imToken: resolvedImToken,
      deviceSessionId: resolvedDeviceSessionId,
    );
    return credentials.isComplete ? credentials : null;
  }

  static bool shouldReuseInitializedSession({
    required String? initializedUid,
    required String? initializedToken,
    required String? initializedDeviceSessionId,
    required String uid,
    required String token,
    required String deviceSessionId,
    required int connectionStatus,
    required bool sessionRuntimeRunning,
  }) {
    return const ConnectionCoordinator().shouldReuseInitializedSession(
      initializedUid: initializedUid,
      initializedToken: initializedToken,
      initializedDeviceSessionId: initializedDeviceSessionId,
      uid: uid,
      token: token,
      deviceSessionId: deviceSessionId,
      connectionStatus: connectionStatus,
      sessionRuntimeRunning: sessionRuntimeRunning,
    );
  }

  static Uri buildSessionGatewayUri({
    required String baseUrl,
    required String deviceSessionId,
    required int lastAckedSeq,
    String? controlProtocol,
  }) {
    return const ConnectionCoordinator().buildSessionGatewayUri(
      baseUrl: baseUrl,
      deviceSessionId: deviceSessionId,
      lastAckedSeq: lastAckedSeq,
      controlProtocol: controlProtocol,
    );
  }

  static String selectConnectAddr(
    ImRouteInfo route, {
    required String fallbackAddr,
  }) {
    return const ConnectionCoordinator().selectConnectAddr(
      route,
      fallbackAddr: fallbackAddr,
    );
  }

  static bool shouldUseLocalPersistence({
    required bool isWeb,
    required bool sdkAppMode,
  }) {
    return const ConnectionCoordinator().shouldUseLocalPersistence(
      isWeb: isWeb,
      sdkAppMode: sdkAppMode,
    );
  }

  static bool shouldStartNativeSessionRuntime({required bool isWeb}) {
    return const ConnectionCoordinator().shouldStartNativeSessionRuntime(
      isWeb: isWeb,
    );
  }

  static bool shouldDisconnectForBackgroundLifecycle({
    required bool isWeb,
    required bool hasActiveCallOrPendingSetup,
    bool keepRealtimeForDesktopNotifications = false,
    bool keepRealtimeForLocalNotifications = false,
  }) {
    if (keepRealtimeForLocalNotifications) {
      return false;
    }
    return const ConnectionCoordinator().shouldDisconnectForBackgroundLifecycle(
      isWeb: isWeb,
      hasActiveCallOrPendingSetup: hasActiveCallOrPendingSetup,
      keepRealtimeForDesktopNotifications: keepRealtimeForDesktopNotifications,
    );
  }

  static bool shouldKeepConnectionInBackground({
    required bool isWeb,
    required bool hasActiveCallOrPendingSetup,
    bool keepRealtimeForDesktopNotifications = false,
    bool keepRealtimeForLocalNotifications = false,
  }) {
    return !shouldDisconnectForBackgroundLifecycle(
      isWeb: isWeb,
      hasActiveCallOrPendingSetup: hasActiveCallOrPendingSetup,
      keepRealtimeForDesktopNotifications: keepRealtimeForDesktopNotifications,
      keepRealtimeForLocalNotifications: keepRealtimeForLocalNotifications,
    );
  }

  static String? resolveConnectionError(int status, int? reasonCode) {
    switch (status) {
      case WKConnectStatus.success:
      case WKConnectStatus.syncCompleted:
      case WKConnectStatus.connecting:
      case WKConnectStatus.syncMsg:
        return null;
      case WKConnectStatus.kicked:
        return 'IM session was kicked out.';
      case WKConnectStatus.noNetwork:
        return 'Network unavailable.';
      case WKConnectStatus.fail:
        if (reasonCode != null && reasonCode != 0) {
          return 'IM connection failed. reason=$reasonCode';
        }
        return null;
      default:
        return null;
    }
  }

  static ImConnectionSnapshot snapshotForStatus({
    required ImConnectionSnapshot previous,
    required int status,
    required int? reasonCode,
  }) {
    final isConnected =
        status == WKConnectStatus.success ||
        status == WKConnectStatus.syncCompleted;
    return previous.copyWith(
      status: status,
      reasonCode: reasonCode,
      clearReasonCode: reasonCode == null,
      isConnected: isConnected,
      isInitialized:
          previous.isInitialized || status == WKConnectStatus.syncCompleted,
      error: resolveConnectionError(status, reasonCode),
      clearError:
          status == WKConnectStatus.success ||
          status == WKConnectStatus.syncCompleted,
    );
  }

  Future<bool> initialize(ImConnectionCredentials credentials) {
    throw UnimplementedError(
      'Skeleton only: move setup, DB readiness, and first connect here.',
    );
  }

  Future<bool> setupSdk({
    required ImConnectionCredentials credentials,
    required String fallbackAddr,
    required int protoVersion,
    required int deviceFlag,
    required bool debug,
    ImConnectionLogHandler? onRouteResolveError,
  }) async {
    _snapshot = _snapshot.copyWith(
      isInitializing: true,
      uid: credentials.uid,
      clearError: true,
      clearReasonCode: true,
    );
    return sdk.setup(
      ImSdkSetupOptions(
        credentials: credentials,
        fallbackAddr: fallbackAddr,
        resolveAddr: () async {
          try {
            return await routeResolver(credentials.uid);
          } catch (error, stackTrace) {
            onRouteResolveError?.call(error, stackTrace);
            return fallbackAddr;
          }
        },
        protoVersion: protoVersion,
        deviceFlag: deviceFlag,
        debug: debug,
      ),
    );
  }

  void connect() {
    sdk.connect();
  }

  Future<void> reconnect({String reason = 'manual'}) {
    throw UnimplementedError(
      'Skeleton only: move exponential reconnect scheduling here.',
    );
  }

  Future<void> disconnect({bool isLogout = false}) {
    throw UnimplementedError(
      'Skeleton only: move SDK/runtime disconnect orchestration here.',
    );
  }

  Future<void> startRealtimeRuntime(ImConnectionCredentials credentials) {
    throw UnimplementedError(
      'Skeleton only: move SessionRuntime start and resume URI wiring here.',
    );
  }

  Future<void> stopRealtimeRuntime() {
    throw UnimplementedError('Skeleton only: stop SessionRuntime here.');
  }

  void bindConnectionStatusListener({
    required ImConnectionStatusHandler onStatus,
  }) {
    sdk.unbindStatusListener(listenerKey);
    sdk.bindStatusListener(
      key: listenerKey,
      onStatus: (status, reasonCode, extra) {
        _snapshot = snapshotForStatus(
          previous: _snapshot,
          status: status,
          reasonCode: reasonCode,
        );
        onStatus(status, reasonCode, extra);
      },
    );
  }

  void unbindConnectionStatusListener() {
    sdk.unbindStatusListener(listenerKey);
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    _coordinator.shouldKeepConnectionInBackground(
      lifecycleState: state,
      hasActiveCallOrPendingSetup: false,
    );
  }
}

class SkeletonImSdkConnectionPort implements ImSdkConnectionPort {
  const SkeletonImSdkConnectionPort();

  @override
  Future<bool> setup(ImSdkSetupOptions options) {
    throw UnimplementedError('Skeleton only: bind WKIM.setup in migration.');
  }

  @override
  void connect() {
    throw UnimplementedError(
      'Skeleton only: bind WKIM.connectionManager.connect in migration.',
    );
  }

  @override
  void disconnect({required bool isLogout}) {
    throw UnimplementedError(
      'Skeleton only: bind WKIM.connectionManager.disconnect in migration.',
    );
  }

  @override
  void bindStatusListener({
    required String key,
    required ImConnectionStatusHandler onStatus,
  }) {
    throw UnimplementedError(
      'Skeleton only: bind WKIM connection listener in migration.',
    );
  }

  @override
  void unbindStatusListener(String key) {
    throw UnimplementedError(
      'Skeleton only: remove WKIM connection listener in migration.',
    );
  }
}

class SkeletonImRealtimeRuntimePort implements ImRealtimeRuntimePort {
  const SkeletonImRealtimeRuntimePort();

  @override
  bool get isRunning => false;

  @override
  Future<void> start({
    required String apiToken,
    required String deviceSessionId,
    required int lastAckedSeq,
  }) {
    throw UnimplementedError('Skeleton only: bind SessionRuntime.start later.');
  }

  @override
  Future<void> stop() {
    throw UnimplementedError('Skeleton only: bind SessionRuntime.stop later.');
  }
}
