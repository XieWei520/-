import 'package:wukongimfluttersdk/entity/msg.dart';

class MessageSyncCoordinator {
  const MessageSyncCoordinator();

  String messageExtraSyncKey(String channelId, int channelType) {
    final normalizedChannelId = channelId.trim();
    if (normalizedChannelId.isEmpty || channelType <= 0) {
      return '';
    }
    return '$normalizedChannelId:$channelType';
  }

  int resolveOfflineCommandAckSequence(Iterable<dynamic> messages) {
    var maxSeq = 0;
    for (final raw in messages) {
      if (raw is WKSyncMsg) {
        if (raw.messageSeq > maxSeq) {
          maxSeq = raw.messageSeq;
        }
        continue;
      }
      if (raw is! Map) {
        continue;
      }
      final current = _readInt(raw['message_seq']);
      if (current > maxSeq) {
        maxSeq = current;
      }
    }
    return maxSeq;
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }
}
