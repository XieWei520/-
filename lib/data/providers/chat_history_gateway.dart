import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/utils/storage_utils.dart';
import '../../service/api/im_sync_api.dart';
import '../cache/web_chat_cache_store.dart';
import '../cache/web_chat_cache_store_factory.dart';

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

typedef SyncChannelMessages =
    Future<WKSyncChannelMsg> Function({
      required String channelId,
      required int channelType,
      required int startMessageSeq,
      required int endMessageSeq,
      required int limit,
      required int pullMode,
      required String deviceUuid,
    });

typedef DeviceUuidProvider = String Function();
typedef AuthTokenProvider = String? Function();
typedef UidProvider = String Function();

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

final chatHistoryGatewayProvider = Provider<ChatHistoryGateway>(
  (ref) => WkImChatHistoryGateway(
    webCacheStore: kIsWeb ? createWebChatCacheStore() : null,
  ),
);

class WkImChatHistoryGateway implements ChatHistoryGateway {
  WkImChatHistoryGateway({
    RequestHistoryMessages? requestHistoryMessages,
    SyncChannelMessages? syncChannelMessages,
    DeviceUuidProvider? deviceUuidProvider,
    AuthTokenProvider? authTokenProvider,
    UidProvider? uidProvider,
    WebChatCacheStore? webCacheStore,
    bool? useDirectRemoteSync,
  }) : _requestHistoryMessages =
           requestHistoryMessages ?? _defaultRequestHistoryMessages,
       _syncChannelMessages =
           syncChannelMessages ?? _defaultSyncChannelMessages,
       _deviceUuidProvider = deviceUuidProvider ?? _defaultDeviceUuidProvider,
       _authTokenProvider = authTokenProvider ?? _defaultAuthTokenProvider,
       _uidProvider = uidProvider ?? _defaultUidProvider,
       _webCacheStore =
           webCacheStore ??
           ((useDirectRemoteSync ?? kIsWeb) ? createWebChatCacheStore() : null),
       _useDirectRemoteSync = useDirectRemoteSync ?? kIsWeb;

  final RequestHistoryMessages _requestHistoryMessages;
  final SyncChannelMessages _syncChannelMessages;
  final DeviceUuidProvider _deviceUuidProvider;
  final AuthTokenProvider _authTokenProvider;
  final UidProvider _uidProvider;
  final WebChatCacheStore? _webCacheStore;
  final bool _useDirectRemoteSync;

  @override
  Future<List<WKMsg>> loadLatest({
    required String channelId,
    required int channelType,
    required int limit,
  }) {
    if (_useDirectRemoteSync) {
      return _fetchRemote(
        channelId: channelId,
        channelType: channelType,
        oldestOrderSeq: 0,
        pullMode: 0,
        limit: limit,
      );
    }
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
    if (_useDirectRemoteSync) {
      return _fetchRemote(
        channelId: channelId,
        channelType: channelType,
        oldestOrderSeq: oldestOrderSeq,
        pullMode: 0,
        limit: limit,
      );
    }
    return _fetch(
      channelId: channelId,
      channelType: channelType,
      oldestOrderSeq: oldestOrderSeq,
      pullMode: 0,
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
    if (_useDirectRemoteSync) {
      return _fetchRemote(
        channelId: channelId,
        channelType: channelType,
        oldestOrderSeq: aroundOrderSeq,
        pullMode: 0,
        limit: limit,
        aroundAnchor: true,
      );
    }
    return _fetch(
      channelId: channelId,
      channelType: channelType,
      oldestOrderSeq: 0,
      pullMode: 0,
      limit: limit,
      aroundOrderSeq: aroundOrderSeq,
    );
  }

  Future<List<WKMsg>> _fetchRemote({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int pullMode,
    required int limit,
    bool aroundAnchor = false,
  }) async {
    if ((_authTokenProvider()?.trim() ?? '').isEmpty) {
      return _readCachedRemoteMessages(
        channelId: channelId,
        channelType: channelType,
        oldestOrderSeq: oldestOrderSeq,
        pullMode: pullMode,
        limit: limit,
        aroundAnchor: aroundAnchor,
      );
    }
    try {
      final messageSeq = _messageSeqFromOrderSeq(oldestOrderSeq);
      final result = await _syncChannelMessages(
        channelId: channelId,
        channelType: channelType,
        startMessageSeq: _resolveRemoteStartMessageSeq(
          messageSeq: messageSeq,
          pullMode: pullMode,
        ),
        endMessageSeq: 0,
        limit: limit,
        pullMode: pullMode,
        deviceUuid: _deviceUuidProvider(),
      );
      final messages = (result.messages ?? const <WKSyncMsg>[])
          .map(_syncMessageToDisplayMessage)
          .where(shouldIncludeRemoteHistoryMessage)
          .toList(growable: false);
      final sortedMessages = _sortRemoteHistoryMessages(messages);
      final uid = _uidProvider().trim();
      await _webCacheStore?.upsertMessages(
        uid: uid,
        channelId: channelId,
        channelType: channelType,
        messages: sortedMessages,
      );
      return sortedMessages;
    } catch (_) {
      return _readCachedRemoteMessages(
        channelId: channelId,
        channelType: channelType,
        oldestOrderSeq: oldestOrderSeq,
        pullMode: pullMode,
        limit: limit,
        aroundAnchor: aroundAnchor,
      );
    }
  }

  Future<List<WKMsg>> _readCachedRemoteMessages({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int pullMode,
    required int limit,
    bool aroundAnchor = false,
  }) async {
    final webCacheStore = _webCacheStore;
    if (webCacheStore == null) {
      return const <WKMsg>[];
    }
    final uid = _uidProvider().trim();
    return webCacheStore.readMessages(
      uid: uid,
      channelId: channelId,
      channelType: channelType,
      beforeOrderSeq: !aroundAnchor && oldestOrderSeq > 0 ? oldestOrderSeq : 0,
      aroundOrderSeq: aroundAnchor ? oldestOrderSeq : 0,
      limit: limit,
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

  static WKMsg _syncMessageToDisplayMessage(WKSyncMsg syncMessage) {
    final message = syncMessage.getWKMsg();
    if (message.orderSeq <= 0 && message.messageSeq > 0) {
      message.orderSeq =
          message.messageSeq * WKIM.shared.messageManager.wkOrderSeqFactor;
    }
    return message;
  }

  static List<WKMsg> _sortRemoteHistoryMessages(List<WKMsg> messages) {
    final next = List<WKMsg>.from(messages, growable: false);
    next.sort((left, right) {
      final orderCompare = left.orderSeq.compareTo(right.orderSeq);
      if (orderCompare != 0) {
        return orderCompare;
      }
      return left.messageSeq.compareTo(right.messageSeq);
    });
    return next;
  }

  static int _messageSeqFromOrderSeq(int orderSeq) {
    if (orderSeq <= 0) {
      return 0;
    }
    return orderSeq ~/ WKIM.shared.messageManager.wkOrderSeqFactor;
  }

  static int _resolveRemoteStartMessageSeq({
    required int messageSeq,
    required int pullMode,
  }) {
    if (messageSeq <= 0) {
      return 0;
    }
    if (pullMode == 1) {
      return messageSeq + 1;
    }
    return messageSeq > 1 ? messageSeq - 1 : 0;
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

  static Future<WKSyncChannelMsg> _defaultSyncChannelMessages({
    required String channelId,
    required int channelType,
    required int startMessageSeq,
    required int endMessageSeq,
    required int limit,
    required int pullMode,
    required String deviceUuid,
  }) {
    return IMSyncApi.instance.syncChannelMessages(
      channelId: channelId,
      channelType: channelType,
      startMessageSeq: startMessageSeq,
      endMessageSeq: endMessageSeq,
      limit: limit,
      pullMode: pullMode,
      deviceUuid: deviceUuid,
    );
  }

  static String _defaultDeviceUuidProvider() {
    return StorageUtils.getDeviceId()?.trim() ?? '';
  }

  static String? _defaultAuthTokenProvider() {
    return StorageUtils.getToken();
  }

  static String _defaultUidProvider() {
    return StorageUtils.getUid()?.trim() ??
        WKIM.shared.options.uid?.trim() ??
        '';
  }
}

@visibleForTesting
bool shouldIncludeRemoteHistoryMessage(WKMsg message) {
  return message.isDeleted == 0 &&
      message.contentType != WkMessageContentType.insideMsg;
}
