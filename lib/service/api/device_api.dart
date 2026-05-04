import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/device.dart';
import 'api_client.dart';

/// API client for device management operations.
///
/// Handles all device-related operations including:
/// - Listing user devices
/// - Locking/unlocking devices
/// - Forcing device logout
/// - Managing trusted devices
class DeviceApi {
  static final DeviceApi _instance = DeviceApi._();
  static DeviceApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;

  DeviceApi._();

  /// Resolves response body to a `Map<String, dynamic>`.
  Map<String, dynamic> _resolveBody(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }

  /// Resolves response data to a `List<dynamic>`.
  List<dynamic> _resolveList(dynamic raw) {
    if (raw is List) {
      return raw;
    }
    if (raw is Map && raw['data'] is List) {
      return List<dynamic>.from(raw['data'] as List);
    }
    if (raw is Map && raw['devices'] is List) {
      return List<dynamic>.from(raw['devices'] as List);
    }
    return const <dynamic>[];
  }

  /// Validates API response and throws exception on error.
  void _ensureSuccess(Response<dynamic> response, {required String fallback}) {
    final body = _resolveBody(response.data);
    final statusCode = response.statusCode ?? 200;
    final code = body['code'];
    final status = body['status'];
    final message = (body['msg'] ?? body['message'] ?? fallback).toString();

    final hasErrorCode = (code is num && code.toInt() != 0) ||
        (status is num && status.toInt() >= 400);

    if (statusCode >= 400 || hasErrorCode) {
      throw Exception(message);
    }
  }

  /// Gets all devices for the current user.
  ///
  /// Returns a list of [Device] objects representing all devices
  /// that have logged in with this account.
  Future<List<Device>> getAllDevices() async {
    final response = await _client.get('/v1/user/devices');
    _ensureSuccess(response, fallback: 'Failed to fetch device list');

    final list = _resolveList(response.data);
    return list
        .map((json) => Device.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Gets the current user's device list (alias for getAllDevices).
  Future<List<Device>> getUserDevices() async {
    return getAllDevices();
  }

  /// Locks or unlocks a specific device.
  ///
  /// [deviceId] - The ID of the device to lock/unlock.
  /// [locked] - True to lock the device, false to unlock.
  ///
  /// Locked devices cannot authenticate until unlocked by the user.
  Future<void> lockDevice(String deviceId, bool locked) async {
    final action = locked ? 'lock' : 'unlock';
    final response = await _client.post(
      '/v1/user/device/$deviceId/$action',
      data: {'locked': locked},
    );
    _ensureSuccess(response, fallback: 'Failed to $action device');
  }

  /// Forces a device to logout.
  ///
  /// [deviceId] - The ID of the device to logout.
  ///
  /// This will invalidate the device's session and require
  /// re-authentication.
  Future<void> offlineDevice(String deviceId) async {
    final response = await _client.delete('/v1/user/device/$deviceId');
    _ensureSuccess(response, fallback: 'Failed to logout device');
  }

  /// Logs out all devices except the current one.
  ///
  /// This is useful for security when the user suspects
  /// unauthorized access.
  Future<void> logoutAllExceptCurrent() async {
    final devices = await getAllDevices();
    final otherDevices = devices.where((d) => !d.isCurrent).toList();

    for (final device in otherDevices) {
      try {
        await offlineDevice(device.id);
      } catch (e) {
        // Continue logging out other devices even if one fails
        debugPrint('Failed to logout device ${device.id}: $e');
      }
    }
  }

  /// Marks a device as trusted.
  ///
  /// [deviceId] - The ID of the device to trust.
  ///
  /// Trusted devices may bypass certain security checks.
  Future<void> trustDevice(String deviceId) async {
    final response = await _client.post(
      '/v1/user/device/$deviceId/trust',
      data: {'trusted': true},
    );
    _ensureSuccess(response, fallback: 'Failed to trust device');
  }

  /// Removes trust from a device.
  ///
  /// [deviceId] - The ID of the device to untrust.
  Future<void> untrustDevice(String deviceId) async {
    final response = await _client.post(
      '/v1/user/device/$deviceId/trust',
      data: {'trusted': false},
    );
    _ensureSuccess(response, fallback: 'Failed to untrust device');
  }

  /// Gets device login logs.
  ///
  /// Returns login history for security audit.
  Future<List<Map<String, dynamic>>> getDeviceLoginLogs({
    String? deviceId,
    int limit = 50,
  }) async {
    final response = await _client.get(
      '/v1/user/device/login_logs',
      queryParameters: {
        'device_id': ?deviceId,
        'limit': limit,
      },
    );
    _ensureSuccess(response, fallback: 'Failed to fetch login logs');

    final body = _resolveBody(response.data);
    final list = _resolveList(body);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
