import 'dart:async';

import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/wkim.dart';

typedef RequestHistoryMessages =
    void Function({
      required String channelId,
      required int channelType,
      required int oldestOrderSeq,
      required bool contain,
      required int pullMode,
      required int limit,
      required int aroundOrderSeq,
      required void Function(List<WKMsg>) onResult,
      required void Function() onSyncStart,
    });

abstract class ChatHistoryGateway {
  Future<List<WKMsg>> loadLatest({
    required String channelId,
    required int channelType,
    required int limit,
  });

  Future<List<WKMsg>> loadMore({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int limit,
  });

  Future<List<WKMsg>> loadAroundOrderSeq({
    required String channelId,
    required int channelType,
    required int limit,
    required int aroundOrderSeq,
  });
}

class WkImChatHistoryGateway implements ChatHistoryGateway {
  WkImChatHistoryGateway({RequestHistoryMessages? requestHistoryMessages})
    : _requestHistoryMessages =
          requestHistoryMessages ?? _defaultRequestHistoryMessages;

  final RequestHistoryMessages _requestHistoryMessages;

  @override
  Future<List<WKMsg>> loadLatest({
    required String channelId,
    required int channelType,
    required int limit,
  }) {
    return _fetch(
      channelId: channelId,
      channelType: channelType,
      oldestOrderSeq: 0,
      pullMode: 0,
      limit: limit,
      aroundOrderSeq: 0,
    );
  }

  @override
  Future<List<WKMsg>> loadMore({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int limit,
  }) {
    return _fetch(
      channelId: channelId,
      channelType: channelType,
      oldestOrderSeq: oldestOrderSeq,
      pullMode: 1,
      limit: limit,
      aroundOrderSeq: 0,
    );
  }

  @override
  Future<List<WKMsg>> loadAroundOrderSeq({
    required String channelId,
    required int channelType,
    required int limit,
    required int aroundOrderSeq,
  }) {
    return _fetch(
      channelId: channelId,
      channelType: channelType,
      oldestOrderSeq: 0,
      pullMode: 0,
      limit: limit,
      aroundOrderSeq: aroundOrderSeq,
    );
  }

  Future<List<WKMsg>> _fetch({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int pullMode,
    required int limit,
    required int aroundOrderSeq,
  }) {
    final completer = Completer<List<WKMsg>>();
    try {
      _requestHistoryMessages(
        channelId: channelId,
        channelType: channelType,
        oldestOrderSeq: oldestOrderSeq,
        contain: false,
        pullMode: pullMode,
        limit: limit,
        aroundOrderSeq: aroundOrderSeq,
        onResult: (msgs) {
          if (!completer.isCompleted) {
            completer.complete(msgs);
          }
        },
        onSyncStart: () {},
      );
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(const <WKMsg>[]);
      }
    }
    return completer.future;
  }

  static void _defaultRequestHistoryMessages({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required bool contain,
    required int pullMode,
    required int limit,
    required int aroundOrderSeq,
    required void Function(List<WKMsg>) onResult,
    required void Function() onSyncStart,
  }) {
    WKIM.shared.messageManager.getOrSyncHistoryMessages(
      channelId,
      channelType,
      oldestOrderSeq,
      contain,
      pullMode,
      limit,
      aroundOrderSeq,
      onResult,
      onSyncStart,
    );
  }
}
