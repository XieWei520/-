import 'package:dio/dio.dart';

import 'api_client.dart';

/// Crypto API client for end-to-end encryption operations.
///
/// Handles Signal protocol key exchange for E2E encrypted messaging:
/// - Get user's signal key (prekeys, identity key, signed prekey)
/// - Used for establishing secure channels between users
///
/// Audit status (2026-04-16):
/// - The auditable open-source server and `/opt/wukongim-prod/src` do not
///   expose the routes used below.
/// - No active Flutter runtime currently calls this client.
/// Keep this client quarantined until the backend/API contract is frozen.
@Deprecated(
  'Speculative Signal contract; do not wire into production runtime until the backend/API contract is frozen.',
)
class CryptoApi {
  static final CryptoApi _instance = CryptoApi._();
  static CryptoApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;

  CryptoApi._();

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

  /// Gets user's Signal protocol key data for E2E encryption.
  ///
  /// This is part of the Signal protocol handshake:
  /// 1. Alice requests Bob's signal key from server
  /// 2. Server returns Bob's prekeys bundle
  /// 3. Alice uses this to establish encrypted session
  ///
  /// Returns signal data containing:
  /// - identity_key: User's long-term identity key
  /// - signed_prekey: Signed prekey for session initiation
  /// - prekeys: One-time prekeys for forward secrecy
  /// - registration_id: Registration identifier
  Future<Map<String, dynamic>> getUserSignalKey() async {
    final response = await _client.post(
      '/v1/user/signal/getkey',
      data: {},
    );
    _ensureSuccess(response, fallback: 'Failed to get signal key');

    return _resolveBody(response.data);
  }

  /// Uploads user's Signal protocol keys to server.
  ///
  /// [identityKey] - User's long-term identity public key.
  /// [signedPreKey] - User's signed prekey.
  /// [preKeys] - List of one-time prekeys.
  /// [registrationId] - User's registration ID.
  ///
  /// Called during initial setup or when prekeys are depleted.
  Future<void> uploadSignalKeys({
    required String identityKey,
    required String signedPreKey,
    required List<String> preKeys,
    required int registrationId,
  }) async {
    final response = await _client.post(
      '/v1/user/signal/uploadkeys',
      data: {
        'identity_key': identityKey,
        'signed_prekey': signedPreKey,
        'prekeys': preKeys,
        'registration_id': registrationId,
      },
    );
    _ensureSuccess(response, fallback: 'Failed to upload signal keys');
  }

  /// Sends encrypted message to another user.
  ///
  /// [targetUid] - Target user's unique ID.
  /// [encryptedPayload] - Encrypted message content.
  /// [ messageType] - Type of encrypted message (text, media, etc.).
  ///
  /// The server delivers this to the recipient via their active connections.
  Future<void> sendEncryptedMessage({
    required String targetUid,
    required String encryptedPayload,
    String messageType = 'text',
  }) async {
    final response = await _client.post(
      '/v1/message/encrypt/send',
      data: {
        'to_uid': targetUid,
        'payload': encryptedPayload,
        'type': messageType,
      },
    );
    _ensureSuccess(response, fallback: 'Failed to send encrypted message');
  }

  /// Acknowledges receipt of encrypted message.
  ///
  /// [messageId] - ID of the received message.
  /// [senderUid] - Sender's user ID.
  Future<void> acknowledgeEncryptedMessage({
    required String messageId,
    required String senderUid,
  }) async {
    final response = await _client.post(
      '/v1/message/encrypt/ack',
      data: {
        'message_id': messageId,
        'from_uid': senderUid,
      },
    );
    _ensureSuccess(response, fallback: 'Failed to acknowledge encrypted message');
  }
}
