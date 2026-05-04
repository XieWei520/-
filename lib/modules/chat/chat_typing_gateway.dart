import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/utils/storage_utils.dart';
import '../../service/api/message_api.dart';

typedef ChatTypingSend =
    Future<void> Function({
      required String channelId,
      required int channelType,
    });
typedef ChatTypingChannelLoader =
    Future<WKChannel?> Function({
      required String channelId,
      required int channelType,
    });
typedef ChatTypingMemberLoader =
    Future<WKChannelMember?> Function({
      required String channelId,
      required int channelType,
      required String uid,
    });
typedef ChatTypingUidReader = String? Function();
typedef ChatTypingNow = int Function();

final chatTypingGatewayProvider = Provider<ChatTypingGateway>(
  (ref) => const WkImChatTypingGateway(),
);

final chatTypingNowProvider = Provider<ChatTypingNow>(
  (ref) => () => DateTime.now().millisecondsSinceEpoch ~/ 1000,
);

abstract class ChatTypingGateway {
  Future<void> sendIfAllowed({
    required String channelId,
    required int channelType,
  });
}

class WkImChatTypingGateway implements ChatTypingGateway {
  const WkImChatTypingGateway({
    this.sendTyping = _defaultSendTyping,
    this.channelLoader = _defaultChannelLoader,
    this.memberLoader = _defaultMemberLoader,
    this.currentUidReader = _defaultCurrentUidReader,
  });

  final ChatTypingSend sendTyping;
  final ChatTypingChannelLoader channelLoader;
  final ChatTypingMemberLoader memberLoader;
  final ChatTypingUidReader currentUidReader;

  static Future<void> _defaultSendTyping({
    required String channelId,
    required int channelType,
  }) {
    return MessageApi.instance.sendTyping(
      channelId: channelId,
      channelType: channelType,
    );
  }

  static Future<WKChannel?> _defaultChannelLoader({
    required String channelId,
    required int channelType,
  }) {
    return WKIM.shared.channelManager.getChannel(channelId, channelType);
  }

  static Future<WKChannelMember?> _defaultMemberLoader({
    required String channelId,
    required int channelType,
    required String uid,
  }) {
    return WKIM.shared.channelMemberManager.getMember(
      channelId,
      channelType,
      uid,
    );
  }

  static String? _defaultCurrentUidReader() => StorageUtils.getUid();

  @override
  Future<void> sendIfAllowed({
    required String channelId,
    required int channelType,
  }) async {
    if (channelType == WKChannelType.group) {
      final uid = currentUidReader()?.trim() ?? '';
      if (uid.isEmpty) {
        return;
      }
      final member = await memberLoader(
        channelId: channelId,
        channelType: channelType,
        uid: uid,
      );
      if (member == null || member.isDeleted == 1 || member.status != 1) {
        return;
      }
    } else {
      final channel = await channelLoader(
        channelId: channelId,
        channelType: channelType,
      );
      final beDeleted = _readExtraFlag(channel?.localExtra, const [
        'beDeleted',
        'be_deleted',
      ]);
      final beBlacklist = _readExtraFlag(channel?.localExtra, const [
        'beBlacklist',
        'be_blacklist',
      ]);
      if (beDeleted == 1 || beBlacklist == 1) {
        return;
      }
    }

    await sendTyping(channelId: channelId, channelType: channelType);
  }

  static int _readExtraFlag(dynamic map, List<String> keys) {
    if (map is! Map) {
      return 0;
    }
    for (final key in keys) {
      final value = map[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return 0;
  }
}
