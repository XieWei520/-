import 'package:flutter/foundation.dart';

@immutable
class E2eeRolloutPolicy {
  const E2eeRolloutPolicy.disabled()
    : enabled = false,
      privateChannelTypes = const <int>{},
      trustedPeerUserIds = const <String>{},
      trustedKeyIds = const <String>{};

  const E2eeRolloutPolicy.privateChatPreview({
    required this.privateChannelTypes,
    this.trustedPeerUserIds = const <String>{},
    required this.trustedKeyIds,
  }) : enabled = true;

  final bool enabled;
  final Set<int> privateChannelTypes;
  final Set<String> trustedPeerUserIds;
  final Set<String> trustedKeyIds;

  bool canEncryptPrivateChat({
    required int channelType,
    required String peerUserId,
    required String keyId,
  }) {
    if (!enabled) {
      return false;
    }
    if (!privateChannelTypes.contains(channelType)) {
      return false;
    }
    final normalizedPeerUserId = peerUserId.trim();
    if (normalizedPeerUserId.isEmpty) {
      return false;
    }
    if (trustedPeerUserIds.isNotEmpty &&
        !trustedPeerUserIds.contains(normalizedPeerUserId)) {
      return false;
    }
    final normalizedKeyId = keyId.trim();
    if (normalizedKeyId.isEmpty) {
      return false;
    }
    if (trustedKeyIds.isNotEmpty && !trustedKeyIds.contains(normalizedKeyId)) {
      return false;
    }
    return true;
  }
}
