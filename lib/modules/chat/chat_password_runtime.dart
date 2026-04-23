import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/crypto_utils.dart';
import '../../core/utils/storage_utils.dart';
import 'channel_settings_common.dart';

const int chatPasswordMaxAttempts = 3;
const String chatPasswordMaskedPreview = '******';

enum ChatPasswordUnlockFailure {
  emptyPassword,
  missingPassword,
  incorrectPassword,
  attemptsExhausted,
}

class ChatPasswordUnlockResult {
  const ChatPasswordUnlockResult({
    required this.unlocked,
    required this.remainingAttempts,
    this.failure,
    this.messagesCleared = false,
  });

  final bool unlocked;
  final int remainingAttempts;
  final ChatPasswordUnlockFailure? failure;
  final bool messagesCleared;
}

bool isChatPasswordProtectedChannel(WKChannel? channel) {
  return isChatPasswordProtectedExtras(
    remoteExtra: channel?.remoteExtraMap,
    localExtra: channel?.localExtra,
  );
}

bool isChatPasswordProtectedExtras({
  dynamic remoteExtra,
  dynamic localExtra,
}) {
  return readChannelExtraInt(remoteExtra, 'chat_pwd_on') == 1 ||
      readChannelExtraInt(localExtra, 'chat_pwd_on') == 1;
}

final chatPasswordRuntimeProvider = Provider<ChatPasswordRuntime>((ref) {
  return ChatPasswordRuntime(
    loadChannel: (channelId, channelType) {
      return WKIM.shared.channelManager.getChannel(channelId, channelType);
    },
    clearChannelMessages: (channelId, channelType) async {
      await WKIM.shared.messageManager.clearWithChannel(channelId, channelType);
    },
  );
});

class ChatPasswordRuntime {
  ChatPasswordRuntime({
    required this.loadChannel,
    required this.clearChannelMessages,
  });

  final Future<WKChannel?> Function(String channelId, int channelType)
  loadChannel;
  final Future<void> Function(String channelId, int channelType)
  clearChannelMessages;

  Future<bool> requiresPassword({
    required String channelId,
    required int channelType,
  }) async {
    final channel = await loadChannel(channelId, channelType);
    return isChatPasswordProtectedChannel(channel);
  }

  Future<ChatPasswordUnlockResult> unlockChat({
    required String channelId,
    required int channelType,
    required String password,
    required String uid,
    required String? storedChatPasswordHash,
  }) async {
    final normalizedPassword = password.trim();
    if (normalizedPassword.isEmpty) {
      return ChatPasswordUnlockResult(
        unlocked: false,
        remainingAttempts: _remainingAttempts,
        failure: ChatPasswordUnlockFailure.emptyPassword,
      );
    }

    final normalizedUid = uid.trim();
    final normalizedHash = storedChatPasswordHash?.trim() ?? '';
    if (normalizedUid.isEmpty || normalizedHash.isEmpty) {
      return ChatPasswordUnlockResult(
        unlocked: false,
        remainingAttempts: _remainingAttempts,
        failure: ChatPasswordUnlockFailure.missingPassword,
      );
    }

    final attempts = _remainingAttempts;
    if (attempts <= 0) {
      await clearChannelMessages(channelId, channelType);
      await _saveRemainingAttempts(0);
      return const ChatPasswordUnlockResult(
        unlocked: false,
        remainingAttempts: 0,
        failure: ChatPasswordUnlockFailure.attemptsExhausted,
        messagesCleared: true,
      );
    }

    final nextHash = CryptoUtils.md5('$normalizedPassword$normalizedUid');
    if (nextHash == normalizedHash) {
      await _saveRemainingAttempts(chatPasswordMaxAttempts);
      return const ChatPasswordUnlockResult(
        unlocked: true,
        remainingAttempts: chatPasswordMaxAttempts,
      );
    }

    final remainingAttempts = attempts > 0 ? attempts - 1 : 0;
    await _saveRemainingAttempts(remainingAttempts);
    return ChatPasswordUnlockResult(
      unlocked: false,
      remainingAttempts: remainingAttempts,
      failure: ChatPasswordUnlockFailure.incorrectPassword,
    );
  }

  int get _remainingAttempts {
    if (!StorageUtils.isInitialized) {
      return chatPasswordMaxAttempts;
    }
    return StorageUtils.getInt(AppConstants.keyChatPwdCount) ??
        chatPasswordMaxAttempts;
  }

  Future<void> _saveRemainingAttempts(int value) async {
    if (!StorageUtils.isInitialized) {
      return;
    }
    await StorageUtils.setInt(AppConstants.keyChatPwdCount, value);
  }
}
