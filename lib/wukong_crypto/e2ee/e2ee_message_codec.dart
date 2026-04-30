import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'e2ee_cipher.dart';
import 'e2ee_envelope.dart';
import 'e2ee_rollout_policy.dart';

@immutable
class E2eeMessageContext {
  const E2eeMessageContext({
    required this.channelId,
    required this.channelType,
    required this.fromUid,
    required this.peerUid,
    required this.clientMsgNo,
  });

  final String channelId;
  final int channelType;
  final String fromUid;
  final String peerUid;
  final String clientMsgNo;

  List<int> get aadBytes {
    return utf8.encode(
      <Object>[
        channelType,
        channelId.trim(),
        fromUid.trim(),
        peerUid.trim(),
        clientMsgNo.trim(),
      ].join('\n'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channel_id': channelId,
      'channel_type': channelType,
      'from_uid': fromUid,
      'peer_uid': peerUid,
      'client_msg_no': clientMsgNo,
    };
  }
}

@immutable
class E2eeEncodedMessage {
  const E2eeEncodedMessage({required this.contentType, required this.content});

  final int contentType;
  final String content;
}

class E2eeMessageCodec {
  E2eeMessageCodec({E2eeCipher? cipher, SecureRandomBytes? randomBytes})
    : _cipher = cipher ?? AesGcmE2eeCipher(randomBytes: randomBytes);

  static const int encryptedContentType = 91001;
  static const String encryptedPayloadKind = 'wk.e2ee.v1';
  static const String fallbackText = '[Encrypted message]';

  final E2eeCipher _cipher;

  E2eeEncodedMessage? tryEncryptText({
    required String plaintext,
    required Uint8List key,
    required String keyId,
    required E2eeMessageContext context,
    required E2eeRolloutPolicy policy,
  }) {
    if (!policy.canEncryptPrivateChat(
      channelType: context.channelType,
      peerUserId: context.peerUid,
      keyId: keyId,
    )) {
      return null;
    }
    final envelope = _cipher.encryptString(
      plaintext: plaintext,
      key: key,
      keyId: keyId,
      aad: context.aadBytes,
    );
    return E2eeEncodedMessage(
      contentType: encryptedContentType,
      content: jsonEncode(<String, dynamic>{
        'type': encryptedContentType,
        'kind': encryptedPayloadKind,
        'plaintext_type': 'text',
        'fallback': fallbackText,
        'context': context.toJson(),
        'e2ee': envelope.toJson(),
      }),
    );
  }

  String decryptTextPayload({
    required Map<String, dynamic> payload,
    required Uint8List key,
    required E2eeMessageContext context,
  }) {
    if (!isEncryptedPayload(payload)) {
      throw const E2eeMessageCodecException('invalid E2EE payload');
    }
    final rawEnvelope = payload['e2ee'];
    if (rawEnvelope is! Map) {
      throw const E2eeMessageCodecException('missing E2EE envelope');
    }
    try {
      return _cipher.decryptString(
        envelope: E2eeEncryptedEnvelope.fromJson(
          Map<String, dynamic>.from(rawEnvelope),
        ),
        key: key,
        aad: context.aadBytes,
      );
    } on E2eeCipherException catch (error) {
      throw E2eeMessageCodecException('decrypt E2EE payload failed', error);
    }
  }

  static bool isEncryptedPayload(Map<String, dynamic> payload) {
    return _readInt(payload['type']) == encryptedContentType &&
        payload['kind'] == encryptedPayloadKind &&
        payload['e2ee'] is Map;
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class E2eeMessageCodecException implements Exception {
  const E2eeMessageCodecException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message: $cause';
}
