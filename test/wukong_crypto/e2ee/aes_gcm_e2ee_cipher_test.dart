import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_crypto/e2ee/e2ee_cipher.dart';
import 'package:wukong_im_app/wukong_crypto/e2ee/e2ee_envelope.dart';

void main() {
  test('AES-GCM E2EE cipher round-trips private chat plaintext', () {
    final cipher = AesGcmE2eeCipher(randomBytes: _fixedNonce);
    final key = Uint8List.fromList(List<int>.generate(32, (index) => index));

    final envelope = cipher.encryptString(
      plaintext: 'hello encrypted IM',
      key: key,
      keyId: 'session-alice-bob-1',
      aad: utf8.encode('alice:bob:client-msg-1'),
    );

    expect(envelope.version, 1);
    expect(envelope.algorithm, E2eeAlgorithm.aes256Gcm);
    expect(envelope.keyId, 'session-alice-bob-1');
    expect(envelope.ciphertext, isNot(contains('hello')));

    final plaintext = cipher.decryptString(
      envelope: envelope,
      key: key,
      aad: utf8.encode('alice:bob:client-msg-1'),
    );
    expect(plaintext, 'hello encrypted IM');
  });

  test('AES-GCM E2EE cipher rejects tampered ciphertext', () {
    final cipher = AesGcmE2eeCipher(randomBytes: _fixedNonce);
    final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final envelope = cipher.encryptString(
      plaintext: 'do not tamper',
      key: key,
      keyId: 'session-1',
    );
    final decoded = envelope.toJson();
    decoded['ciphertext'] = base64Encode(<int>[1, 2, 3, 4]);

    expect(
      () => cipher.decryptString(
        envelope: E2eeEncryptedEnvelope.fromJson(decoded),
        key: key,
      ),
      throwsA(isA<E2eeCipherException>()),
    );
  });

  test('E2EE envelope JSON preserves protocol fields', () {
    const envelope = E2eeEncryptedEnvelope(
      version: 1,
      algorithm: E2eeAlgorithm.aes256Gcm,
      keyId: 'kid',
      nonce: 'nonce',
      ciphertext: 'cipher',
      tag: 'tag',
    );

    final decoded = E2eeEncryptedEnvelope.fromJson(envelope.toJson());

    expect(decoded.version, 1);
    expect(decoded.algorithm, E2eeAlgorithm.aes256Gcm);
    expect(decoded.keyId, 'kid');
    expect(decoded.nonce, 'nonce');
    expect(decoded.ciphertext, 'cipher');
    expect(decoded.tag, 'tag');
  });
}

Uint8List _fixedNonce(int length) {
  return Uint8List.fromList(List<int>.generate(length, (index) => index + 1));
}
