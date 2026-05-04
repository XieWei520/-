import 'package:flutter/foundation.dart';

enum E2eeAlgorithm {
  aes256Gcm('AES-256-GCM');

  const E2eeAlgorithm(this.wireName);

  final String wireName;

  static E2eeAlgorithm fromWireName(String value) {
    final normalized = value.trim().toUpperCase();
    for (final algorithm in E2eeAlgorithm.values) {
      if (algorithm.wireName == normalized) {
        return algorithm;
      }
    }
    return E2eeAlgorithm.aes256Gcm;
  }
}

@immutable
class E2eeEncryptedEnvelope {
  const E2eeEncryptedEnvelope({
    required this.version,
    required this.algorithm,
    required this.keyId,
    required this.nonce,
    required this.ciphertext,
    required this.tag,
  });

  final int version;
  final E2eeAlgorithm algorithm;
  final String keyId;
  final String nonce;
  final String ciphertext;
  final String tag;

  factory E2eeEncryptedEnvelope.fromJson(Map<String, dynamic> json) {
    return E2eeEncryptedEnvelope(
      version: _readInt(json['v'] ?? json['version'], fallback: 1),
      algorithm: E2eeAlgorithm.fromWireName(
        json['alg']?.toString() ?? json['algorithm']?.toString() ?? '',
      ),
      keyId: json['kid']?.toString() ?? json['key_id']?.toString() ?? '',
      nonce: json['nonce']?.toString() ?? '',
      ciphertext: json['ciphertext']?.toString() ?? '',
      tag: json['tag']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'v': version,
      'alg': algorithm.wireName,
      'kid': keyId,
      'nonce': nonce,
      'ciphertext': ciphertext,
      'tag': tag,
    };
  }

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
