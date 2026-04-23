/// Signal protocol key data for end-to-end encryption.
///
/// This class represents the prekey bundle used in the Signal protocol
/// for establishing encrypted sessions between users.
class SignalData {
  /// User's identity public key (base64 encoded).
  final String identityKey;

  /// User's signed prekey (base64 encoded).
  final String signedPreKey;

  /// Signature of the signed prekey (base64 encoded).
  final String signedPreKeySignature;

  /// List of one-time prekeys (base64 encoded).
  final List<PreKey> preKeys;

  /// User's registration ID.
  final int registrationId;

  /// Device ID associated with these keys.
  final int deviceId;

  SignalData({
    required this.identityKey,
    required this.signedPreKey,
    required this.signedPreKeySignature,
    required this.preKeys,
    required this.registrationId,
    this.deviceId = 1,
  });

  factory SignalData.fromJson(Map<String, dynamic> json) {
    return SignalData(
      identityKey: json['identity_key']?.toString() ?? '',
      signedPreKey: json['signed_prekey']?.toString() ?? json['signed_pre_key']?.toString() ?? '',
      signedPreKeySignature: json['signed_prekey_signature']?.toString() ??
          json['signed_pre_key_signature']?.toString() ??
          '',
      preKeys: _parsePreKeys(json['prekeys']),
      registrationId: json['registration_id'] as int? ??
          int.tryParse(json['registration_id']?.toString() ?? '0') ??
          0,
      deviceId: json['device_id'] as int? ??
          int.tryParse(json['device_id']?.toString() ?? '1') ??
          1,
    );
  }

  static List<PreKey> _parsePreKeys(dynamic preKeysJson) {
    if (preKeysJson == null) return const [];
    if (preKeysJson is! List) return const [];

    return preKeysJson
        .whereType<Map>()
        .map((key) => PreKey.fromJson(Map<String, dynamic>.from(key)))
        .toList();
  }

  /// Gets the first available one-time prekey.
  ///
  /// Returns null if no prekeys are available.
  PreKey? getFirstPreKey() {
    if (preKeys.isEmpty) return null;
    return preKeys.first;
  }

  /// Checks if there are any one-time prekeys available.
  bool get hasPreKeys => preKeys.isNotEmpty;

  /// Gets the number of remaining one-time prekeys.
  int get preKeyCount => preKeys.length;

  Map<String, dynamic> toJson() {
    return {
      'identity_key': identityKey,
      'signed_prekey': signedPreKey,
      'signed_prekey_signature': signedPreKeySignature,
      'prekeys': preKeys.map((key) => key.toJson()).toList(),
      'registration_id': registrationId,
      'device_id': deviceId,
    };
  }

  @override
  String toString() {
    return 'SignalData(identityKey: ${identityKey.substring(0, 16)}..., preKeys: ${preKeys.length}, registrationId: $registrationId)';
  }
}

/// Represents a single one-time prekey.
class PreKey {
  /// Unique prekey identifier.
  final int preKeyId;

  /// The prekey value (base64 encoded).
  final String preKey;

  PreKey({
    required this.preKeyId,
    required this.preKey,
  });

  factory PreKey.fromJson(Map<String, dynamic> json) {
    return PreKey(
      preKeyId: json['prekey_id'] as int? ??
          int.tryParse(json['prekey_id']?.toString() ?? '0') ??
          0,
      preKey: json['prekey']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prekey_id': preKeyId,
      'prekey': preKey,
    };
  }

  @override
  String toString() {
    return 'PreKey(id: $preKeyId)';
  }
}

/// Encrypted message payload wrapper.
class EncryptedPayload {
  /// Message type (text, image, file, etc.).
  final String messageType;

  /// Encrypted content (base64 encoded).
  final String encryptedContent;

  /// Initialization vector (base64 encoded).
  final String iv;

  /// MAC for integrity verification (base64 encoded).
  final String mac;

  /// Version of encryption protocol used.
  final int version;

  /// Timestamp when message was encrypted.
  final DateTime timestamp;

  EncryptedPayload({
    required this.messageType,
    required this.encryptedContent,
    required this.iv,
    required this.mac,
    this.version = 1,
    DateTime? timestamp}
  ) : timestamp = timestamp ?? DateTime.now();

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) {
    return EncryptedPayload(
      messageType: json['type']?.toString() ?? 'text',
      encryptedContent: json['content']?.toString() ?? '',
      iv: json['iv']?.toString() ?? '',
      mac: json['mac']?.toString() ?? '',
      version: json['version'] as int? ?? 1,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': messageType,
      'content': encryptedContent,
      'iv': iv,
      'mac': mac,
      'version': version,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Creates a copy with optional updates.
  EncryptedPayload copyWith({
    String? messageType,
    String? encryptedContent,
    String? iv,
    String? mac,
    int? version,
    DateTime? timestamp,
  }) {
    return EncryptedPayload(
      messageType: messageType ?? this.messageType,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      iv: iv ?? this.iv,
      mac: mac ?? this.mac,
      version: version ?? this.version,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Session state for E2E encrypted communication.
enum SessionState {
  /// No session established yet.
  none,

  /// Session establishment in progress.
  pending,

  /// Active encrypted session.
  active,

  /// Session has expired or been terminated.
  expired,
}

/// Information about an E2E encrypted session.
class SessionInfo {
  /// Other participant's user ID.
  final String peerUserId;

  /// Current session state.
  final SessionState state;

  /// When the session was established.
  final DateTime? establishedAt;

  /// Last time a message was sent/received.
  final DateTime? lastActivity;

  /// Number of messages exchanged in this session.
  final int messageCount;

  SessionInfo({
    required this.peerUserId,
    required this.state,
    this.establishedAt,
    this.lastActivity,
    this.messageCount = 0,
  });

  /// Checks if session is currently active.
  bool get isActive => state == SessionState.active;

  /// Checks if session needs to be refreshed.
  bool get needsRefresh {
    if (state != SessionState.active) return true;
    if (lastActivity == null) return false;

    // Refresh if inactive for more than 7 days
    final elapsed = DateTime.now().difference(lastActivity!);
    return elapsed.inDays > 7;
  }

  Map<String, dynamic> toJson() {
    return {
      'peer_user_id': peerUserId,
      'state': state.name,
      'established_at': establishedAt?.toIso8601String(),
      'last_activity': lastActivity?.toIso8601String(),
      'message_count': messageCount,
    };
  }
}
