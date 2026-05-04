import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'e2ee_envelope.dart';

typedef SecureRandomBytes = Uint8List Function(int length);

abstract interface class E2eeCipher {
  E2eeEncryptedEnvelope encryptString({
    required String plaintext,
    required Uint8List key,
    required String keyId,
    List<int> aad = const <int>[],
  });

  String decryptString({
    required E2eeEncryptedEnvelope envelope,
    required Uint8List key,
    List<int> aad = const <int>[],
  });
}

class AesGcmE2eeCipher implements E2eeCipher {
  AesGcmE2eeCipher({SecureRandomBytes? randomBytes})
    : _randomBytes = randomBytes ?? _secureRandomBytes;

  static const int _nonceLength = 12;
  static const int _tagLength = 16;

  final SecureRandomBytes _randomBytes;

  @override
  E2eeEncryptedEnvelope encryptString({
    required String plaintext,
    required Uint8List key,
    required String keyId,
    List<int> aad = const <int>[],
  }) {
    _validateKey(key);
    final nonce = _randomBytes(_nonceLength);
    final plainBytes = Uint8List.fromList(utf8.encode(plaintext));
    final output = _runGcm(
      encrypt: true,
      key: key,
      nonce: nonce,
      input: plainBytes,
      aad: aad,
    );
    final ciphertext = output.sublist(0, output.length - _tagLength);
    final tag = output.sublist(output.length - _tagLength);
    return E2eeEncryptedEnvelope(
      version: 1,
      algorithm: E2eeAlgorithm.aes256Gcm,
      keyId: keyId,
      nonce: base64Encode(nonce),
      ciphertext: base64Encode(ciphertext),
      tag: base64Encode(tag),
    );
  }

  @override
  String decryptString({
    required E2eeEncryptedEnvelope envelope,
    required Uint8List key,
    List<int> aad = const <int>[],
  }) {
    _validateKey(key);
    if (envelope.algorithm != E2eeAlgorithm.aes256Gcm) {
      throw E2eeCipherException('unsupported algorithm: ${envelope.algorithm}');
    }
    try {
      final nonce = Uint8List.fromList(base64Decode(envelope.nonce));
      final ciphertext = base64Decode(envelope.ciphertext);
      final tag = base64Decode(envelope.tag);
      final sealed = Uint8List.fromList(<int>[...ciphertext, ...tag]);
      final plaintext = _runGcm(
        encrypt: false,
        key: key,
        nonce: nonce,
        input: sealed,
        aad: aad,
      );
      return utf8.decode(plaintext);
    } catch (error) {
      throw E2eeCipherException('decrypt failed', error);
    }
  }

  Uint8List _runGcm({
    required bool encrypt,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List input,
    required List<int> aad,
  }) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        encrypt,
        AEADParameters(
          KeyParameter(key),
          _tagLength * 8,
          nonce,
          Uint8List.fromList(aad),
        ),
      );
    return cipher.process(input);
  }

  void _validateKey(Uint8List key) {
    if (key.length != 32) {
      throw E2eeCipherException('AES-256-GCM requires a 32-byte key');
    }
  }

  static Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}

class E2eeCipherException implements Exception {
  const E2eeCipherException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message: $cause';
}
