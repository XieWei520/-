import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../service/api/api_client.dart';
import 'device_identity.dart';
import 'device_store.dart';

class BoundDeviceSession {
  const BoundDeviceSession({
    required this.deviceSessionId,
    required this.bindVersion,
  });

  final String deviceSessionId;
  final int bindVersion;
}

abstract class DeviceBindClient {
  Future<BoundDeviceSession> bindDeviceSession({
    required DeviceIdentity identity,
    required int bindVersion,
  });
}

class ApiDeviceBindClient implements DeviceBindClient {
  ApiDeviceBindClient({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  @override
  Future<BoundDeviceSession> bindDeviceSession({
    required DeviceIdentity identity,
    required int bindVersion,
  }) async {
    final response = await _client.post(
      '/v1/user/device/bind',
      data: <String, dynamic>{
        'device_id': identity.deviceId,
        'device_name': identity.deviceName,
        'device_model': identity.deviceModel,
        'device_install_id': identity.deviceInstallId,
        'bind_version': bindVersion,
      },
    );
    final body = _normalizeResponseData(response.data);
    final payload = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;
    final deviceSessionId = (payload['device_session_id'] ?? '')
        .toString()
        .trim();
    final resolvedBindVersion = _readInt(payload['bind_version']);
    if (deviceSessionId.isEmpty || resolvedBindVersion == null) {
      throw StateError('Device bind response missing session data.');
    }
    return BoundDeviceSession(
      deviceSessionId: deviceSessionId,
      bindVersion: resolvedBindVersion,
    );
  }

  Map<String, dynamic> _normalizeResponseData(dynamic rawData) {
    if (rawData == null) {
      return <String, dynamic>{};
    }
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }
    if (rawData is String) {
      final body = rawData.trim();
      if (body.isEmpty) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return <String, dynamic>{'data': decoded};
    }
    return <String, dynamic>{'data': rawData};
  }

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }
}

class DeviceIdentityAuthority {
  DeviceIdentityAuthority({
    required DeviceStore store,
    DeviceBindClient? client,
  }) : _store = store,
       _client = client ?? ApiDeviceBindClient();

  final DeviceStore _store;
  final DeviceBindClient _client;
  static const Uuid _uuid = Uuid();
  static final Map<Object, Future<void>> _scopeQueues =
      <Object, Future<void>>{};

  Future<DeviceIdentity> ensureLocalIdentity() {
    return _runExclusive(_ensureLocalIdentityInternal);
  }

  Future<DeviceIdentity> _ensureLocalIdentityInternal() async {
    final current = await _store.read();
    final hasLocalIdentity =
        current.deviceId.isNotEmpty && current.deviceInstallId.isNotEmpty;
    if (hasLocalIdentity) {
      return current;
    }
    final next = DeviceIdentity(
      deviceId: current.deviceId.isEmpty ? _newId() : current.deviceId,
      deviceInstallId: current.deviceInstallId.isEmpty
          ? _newId()
          : current.deviceInstallId,
      deviceSessionId: current.deviceSessionId,
      bindVersion: current.bindVersion,
      userId: current.userId,
      deviceName: current.deviceName,
      deviceModel: current.deviceModel,
    );
    await _store.write(next);
    return next;
  }

  Future<DeviceIdentity> recordBoundSession({
    required String userId,
    required String deviceSessionId,
    required int bindVersion,
  }) async {
    return _runExclusive(() async {
      final current = await _ensureLocalIdentityInternal();
      return _recordBoundSessionInternal(
        current: current,
        userId: userId,
        deviceSessionId: deviceSessionId,
        bindVersion: bindVersion,
      );
    });
  }

  Future<DeviceIdentity> bindAuthenticatedSession({
    required String userId,
    required String token,
  }) {
    return _runExclusive(() async {
      final normalizedUserId = userId.trim();
      final normalizedToken = token.trim();
      if (normalizedUserId.isEmpty) {
        throw ArgumentError.value(userId, 'userId', 'must not be empty');
      }
      if (normalizedToken.isEmpty) {
        throw ArgumentError.value(token, 'token', 'must not be empty');
      }
      final current = await _ensureLocalIdentityInternal();
      final bound = await _client.bindDeviceSession(
        identity: current,
        bindVersion: current.bindVersion + 1,
      );
      return _recordBoundSessionInternal(
        current: current,
        userId: normalizedUserId,
        deviceSessionId: bound.deviceSessionId,
        bindVersion: bound.bindVersion,
      );
    });
  }

  Future<DeviceIdentity> _recordBoundSessionInternal({
    required DeviceIdentity current,
    required String userId,
    required String deviceSessionId,
    required int bindVersion,
  }) async {
    final shouldIgnoreStaleVersion = bindVersion < current.bindVersion;
    final shouldIgnoreConflictingVersion =
        bindVersion == current.bindVersion &&
        current.deviceSessionId.isNotEmpty &&
        current.deviceSessionId != deviceSessionId;
    if (shouldIgnoreStaleVersion || shouldIgnoreConflictingVersion) {
      return current;
    }
    final next = DeviceIdentity(
      deviceId: current.deviceId,
      deviceInstallId: current.deviceInstallId,
      deviceSessionId: deviceSessionId,
      bindVersion: bindVersion,
      userId: userId,
      deviceName: current.deviceName,
      deviceModel: current.deviceModel,
    );
    await _store.write(next);
    return next;
  }

  static String _newId() => _uuid.v4().replaceAll('-', '');

  Future<T> _runExclusive<T>(Future<T> Function() action) {
    final scope = _store.identityPersistenceScope;
    final previous = _scopeQueues[scope] ?? Future<void>.value();
    final completer = Completer<T>();
    late final Future<void> current;
    current = previous.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    _scopeQueues[scope] = current;
    return completer.future.whenComplete(() {
      if (identical(_scopeQueues[scope], current)) {
        _scopeQueues.remove(scope);
      }
    });
  }
}
