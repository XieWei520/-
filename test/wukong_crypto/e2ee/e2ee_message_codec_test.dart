import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_crypto/e2ee/e2ee_message_codec.dart';
import 'package:wukong_im_app/wukong_crypto/e2ee/e2ee_rollout_policy.dart';

void main() {
  test(
    'rollout policy is disabled by default and requires trusted key ids',
    () {
      const disabled = E2eeRolloutPolicy.disabled();
      expect(
        disabled.canEncryptPrivateChat(
          channelType: 1,
          peerUserId: 'bob',
          keyId: 'kid-1',
        ),
        isFalse,
      );

      const enabled = E2eeRolloutPolicy.privateChatPreview(
        privateChannelTypes: <int>{1},
        trustedPeerUserIds: <String>{'bob'},
        trustedKeyIds: <String>{'kid-1'},
      );
      expect(
        enabled.canEncryptPrivateChat(
          channelType: 1,
          peerUserId: 'bob',
          keyId: 'kid-1',
        ),
        isTrue,
      );
      expect(
        enabled.canEncryptPrivateChat(
          channelType: 2,
          peerUserId: 'bob',
          keyId: 'kid-1',
        ),
        isFalse,
      );
      expect(
        enabled.canEncryptPrivateChat(
          channelType: 1,
          peerUserId: 'mallory',
          keyId: 'kid-1',
        ),
        isFalse,
      );
    },
  );

  test(
    'codec wraps private text without leaking plaintext and decrypts it',
    () {
      final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
      const context = E2eeMessageContext(
        channelId: 'bob',
        channelType: 1,
        fromUid: 'alice',
        peerUid: 'bob',
        clientMsgNo: 'client-1',
      );
      const policy = E2eeRolloutPolicy.privateChatPreview(
        privateChannelTypes: <int>{1},
        trustedPeerUserIds: <String>{'bob'},
        trustedKeyIds: <String>{'kid-1'},
      );
      final codec = E2eeMessageCodec(randomBytes: _fixedNonce);

      final encoded = codec.tryEncryptText(
        plaintext: 'secret hello',
        key: key,
        keyId: 'kid-1',
        context: context,
        policy: policy,
      );

      expect(encoded, isNotNull);
      expect(encoded!.contentType, E2eeMessageCodec.encryptedContentType);
      expect(encoded.content, isNot(contains('secret hello')));
      final payload = jsonDecode(encoded.content) as Map<String, dynamic>;
      expect(E2eeMessageCodec.isEncryptedPayload(payload), isTrue);

      final decrypted = codec.decryptTextPayload(
        payload: payload,
        key: key,
        context: context,
      );
      expect(decrypted, 'secret hello');
    },
  );

  test('codec refuses disabled rollout and context tampering', () {
    final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
    const context = E2eeMessageContext(
      channelId: 'bob',
      channelType: 1,
      fromUid: 'alice',
      peerUid: 'bob',
      clientMsgNo: 'client-1',
    );
    final codec = E2eeMessageCodec(randomBytes: _fixedNonce);

    expect(
      codec.tryEncryptText(
        plaintext: 'secret hello',
        key: key,
        keyId: 'kid-1',
        context: context,
        policy: const E2eeRolloutPolicy.disabled(),
      ),
      isNull,
    );

    final encoded = codec.tryEncryptText(
      plaintext: 'secret hello',
      key: key,
      keyId: 'kid-1',
      context: context,
      policy: const E2eeRolloutPolicy.privateChatPreview(
        privateChannelTypes: <int>{1},
        trustedPeerUserIds: <String>{'bob'},
        trustedKeyIds: <String>{'kid-1'},
      ),
    );
    final payload = jsonDecode(encoded!.content) as Map<String, dynamic>;

    expect(
      () => codec.decryptTextPayload(
        payload: payload,
        key: key,
        context: const E2eeMessageContext(
          channelId: 'bob',
          channelType: 1,
          fromUid: 'alice',
          peerUid: 'bob',
          clientMsgNo: 'client-2',
        ),
      ),
      throwsA(isA<E2eeMessageCodecException>()),
    );
  });
}

Uint8List _fixedNonce(int length) {
  return Uint8List.fromList(List<int>.generate(length, (index) => index + 1));
}
