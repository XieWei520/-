import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wukong_im_app/service/api/collection_api.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/utils/storage_utils.dart';
import 'message_forwarding.dart';

WKMsg buildDirectOutgoingMessage({
  required WKMessageContent content,
  required WKChannel channel,
  required String currentUid,
  DateTime? now,
}) {
  final resolvedNow = now ?? DateTime.now();
  final timestamp = (resolvedNow.millisecondsSinceEpoch / 1000).truncate();
  final message = WKMsg()
    ..messageContent = content
    ..channelID = channel.channelID
    ..channelType = channel.channelType
    ..fromUID = currentUid
    ..contentType = content.contentType
    ..status = WKSendMsgResult.sendLoading
    ..timestamp = timestamp
    ..clientSeq = _buildDirectOutgoingClientSeq(resolvedNow);
  message.content = encodeDirectOutgoingPayload(content);
  message.orderSeq = timestamp * WKIM.shared.messageManager.wkOrderSeqFactor;
  message.setChannelInfo(channel);
  return message;
}

@visibleForTesting
WKMsg buildLocalRecalledMessageSnapshot(
  WKMsg source, {
  required String revoker,
  DateTime? now,
}) {
  final extra = _buildLocalRevokeExtra(
    source,
    revoker: revoker,
    now: now ?? DateTime.now(),
  );
  final snapshot = _cloneMessageForLocalRefresh(source)..wkMsgExtra = extra;
  return snapshot;
}

WKMsgExtra _buildLocalRevokeExtra(
  WKMsg source, {
  required String revoker,
  required DateTime now,
}) {
  final previous = source.wkMsgExtra;
  final previousVersion = previous?.extraVersion ?? 0;
  final timestampVersion = now.millisecondsSinceEpoch ~/ 1000;
  final nextVersion = timestampVersion > previousVersion
      ? timestampVersion
      : previousVersion + 1;
  return WKMsgExtra()
    ..messageID = source.messageID.trim()
    ..channelID = source.channelID
    ..channelType = source.channelType
    ..readed = previous?.readed ?? 0
    ..readedCount = previous?.readedCount ?? 0
    ..unreadCount = previous?.unreadCount ?? 0
    ..revoke = 1
    ..isMutualDeleted = previous?.isMutualDeleted ?? 0
    ..revoker = revoker.trim()
    ..extraVersion = nextVersion
    ..editedAt = previous?.editedAt ?? 0
    ..contentEdit = previous?.contentEdit ?? ''
    ..needUpload = previous?.needUpload ?? 0
    ..isPinned = previous?.isPinned ?? 0
    ..messageContent = previous?.messageContent;
}

WKMsg _cloneMessageForLocalRefresh(WKMsg source) {
  final clone = WKMsg()
    ..header = source.header
    ..setting = source.setting
    ..messageID = source.messageID
    ..serverMsgID = source.serverMsgID
    ..messageSeq = source.messageSeq
    ..clientSeq = source.clientSeq
    ..timestamp = source.timestamp
    ..clientMsgNO = source.clientMsgNO
    ..fromUID = source.fromUID
    ..channelID = source.channelID
    ..channelType = source.channelType
    ..contentType = source.contentType
    ..content = source.content
    ..status = source.status
    ..voiceStatus = source.voiceStatus
    ..isDeleted = source.isDeleted
    ..searchableWord = source.searchableWord
    ..orderSeq = source.orderSeq
    ..expireTime = source.expireTime
    ..expireTimestamp = source.expireTimestamp
    ..flame = source.flame
    ..flameSecond = source.flameSecond
    ..viewed = source.viewed
    ..viewedAt = source.viewedAt
    ..topicID = source.topicID
    ..localExtraMap = source.localExtraMap
    ..reactionList = source.reactionList == null
        ? null
        : List<WKMsgReaction>.from(source.reactionList!)
    ..messageContent = source.messageContent;
  final channelInfo = source.getChannelInfo();
  if (channelInfo != null) {
    clone.setChannelInfo(channelInfo);
  }
  final from = source.getFrom();
  if (from != null) {
    clone.setFrom(from);
  }
  final member = source.getMemberOfFrom();
  if (member != null) {
    clone.setMemberOfFrom(member);
  }
  return clone;
}

@visibleForTesting
String encodeDirectOutgoingPayload(WKMessageContent content) {
  final json = Map<String, dynamic>.from(content.encodeJson());
  json['type'] = content.contentType;
  if (content.reply != null) {
    json['reply'] = content.reply!.encode();
  }

  final entities = content.entities;
  if (entities != null && entities.isNotEmpty) {
    json['entities'] = entities
        .map(
          (entity) => <String, dynamic>{
            'offset': entity.offset,
            'length': entity.length,
            'type': entity.type,
            'value': entity.value,
          },
        )
        .toList(growable: false);
  }

  final mentionInfo = content.mentionInfo;
  if (mentionInfo != null) {
    final mention = <String, dynamic>{};
    if (mentionInfo.mentionAll) {
      mention['all'] = 1;
    }
    final uids = mentionInfo.uids;
    if (uids != null && uids.isNotEmpty) {
      mention['uids'] = List<String>.from(uids, growable: false);
    }
    if (mention.isNotEmpty) {
      json['mention'] = mention;
    }
  }

  return jsonEncode(json);
}

int _buildDirectOutgoingClientSeq(DateTime now) {
  final seq = now.microsecondsSinceEpoch & 0x7fffffff;
  return seq == 0 ? 1 : seq;
}

abstract class ChatSceneGateway {
  Future<void> addFavorite(WKMsg message);

  Future<void> editMessage(WKMsg message, WKTextContent content);

  Future<void> deleteSelfMessage(WKMsg message) async {}

  Future<void> recallMessage(WKMsg message);

  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
  });

  Future<void> retryMessage(WKMsg message) async {}

  Future<void> toggleReaction(WKMsg message, String emoji);

  Future<void> togglePinnedMessage(WKMsg message) async {}

  Future<PinnedMessageSyncSnapshot> syncPinnedMessages({
    required String channelId,
    required int channelType,
    int version = 0,
  }) async {
    return const PinnedMessageSyncSnapshot(
      pinnedMessages: <PinnedMessageEntry>[],
      messages: <WKSyncMsg>[],
    );
  }

  Future<void> clearPinnedMessages({
    required String channelId,
    required int channelType,
  }) async {}

  List<MessageReaction> prepareReactions(WKMsg message) {
    return const <MessageReaction>[];
  }

  Stream<ReactionUpdate> watchReactionUpdates() {
    return const Stream<ReactionUpdate>.empty();
  }

  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  });

  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  );
}

class ApiChatSceneGateway implements ChatSceneGateway {
  ApiChatSceneGateway({
    CollectionApi? collectionApi,
    MessageApi? messageApi,
    ReactionManager? reactionManager,
    Future<List<WKUIConversationMsg>> Function()? loadConversations,
    FutureOr<void> Function(WKMessageContent content, WKChannel channel)?
    sendMessage,
    FutureOr<void> Function(WKMsg message)? retryMessage,
    Future<void> Function(String clientMsgNo)? deleteLocalMessage,
    FutureOr<void> Function(List<WKMsgExtra> extras)? saveRemoteExtras,
    FutureOr<void> Function(WKMsg message)? refreshLocalMessage,
    String Function()? currentUidReader,
  }) : _collectionApi = collectionApi ?? CollectionApi.instance,
       _messageApi = messageApi ?? MessageApi.instance,
       _reactionManager = reactionManager ?? ReactionManager(),
       _loadConversations = loadConversations ?? _defaultLoadConversations,
       _sendMessage = sendMessage ?? _defaultSendMessage,
       _retryMessage = retryMessage ?? _defaultRetryMessage,
       _deleteLocalMessage = deleteLocalMessage ?? _defaultDeleteLocalMessage,
       _saveRemoteExtras = saveRemoteExtras ?? _defaultSaveRemoteExtras,
       _refreshLocalMessage = refreshLocalMessage,
       _currentUidReader = currentUidReader ?? _defaultCurrentUidReader;

  final CollectionApi _collectionApi;
  final MessageApi _messageApi;
  final ReactionManager _reactionManager;
  final Future<List<WKUIConversationMsg>> Function() _loadConversations;
  final FutureOr<void> Function(WKMessageContent content, WKChannel channel)
  _sendMessage;
  final FutureOr<void> Function(WKMsg message) _retryMessage;
  final Future<void> Function(String clientMsgNo) _deleteLocalMessage;
  final FutureOr<void> Function(List<WKMsgExtra> extras) _saveRemoteExtras;
  final FutureOr<void> Function(WKMsg message)? _refreshLocalMessage;
  final String Function() _currentUidReader;

  static Future<List<WKUIConversationMsg>> _defaultLoadConversations() {
    return WKIM.shared.conversationManager.getAll();
  }

  static Future<void> _defaultSendMessage(
    WKMessageContent content,
    WKChannel channel,
  ) async {
    await WKIM.shared.messageManager.sendMessage(content, channel);
  }

  static Future<void> _defaultDeleteLocalMessage(String clientMsgNo) {
    return WKIM.shared.messageManager.deleteWithClientMsgNo(clientMsgNo);
  }

  static Future<void> _defaultSaveRemoteExtras(List<WKMsgExtra> extras) {
    return WKIM.shared.messageManager.saveRemoteExtraMsg(extras);
  }

  static String _defaultCurrentUidReader() {
    final sdkUid = WKIM.shared.options.uid?.trim() ?? '';
    if (sdkUid.isNotEmpty) {
      return sdkUid;
    }
    return StorageUtils.getUid()?.trim() ?? '';
  }

  static Future<void> _defaultRetryMessage(WKMsg message) async {
    message.status = WKSendMsgResult.sendLoading;
    WKIM.shared.connectionManager.sendMessage(message);
  }

  @override
  Future<void> addFavorite(WKMsg message) {
    return _collectionApi.add(
      clientMsgNo: message.clientMsgNO,
      messageId: message.messageID.trim().isEmpty ? null : message.messageID,
      messageSeq: message.messageSeq > 0 ? message.messageSeq : null,
      orderSeq: message.orderSeq > 0 ? message.orderSeq : null,
      content: message.content,
      contentType: message.contentType,
      channelId: message.channelID.trim().isEmpty ? null : message.channelID,
      channelType: message.channelType > 0 ? message.channelType : null,
      senderUid: message.fromUID.trim().isEmpty ? null : message.fromUID,
      senderName: _resolveFavoriteSenderName(message),
    );
  }

  @override
  Future<void> editMessage(WKMsg message, WKTextContent content) async {
    final messageId = message.messageID.trim();
    if (messageId.isEmpty) {
      throw UnsupportedError('Message edit requires a server message id.');
    }

    final contentEdit = _buildEditedContentJson(content);
    await _messageApi.editMessage(
      messageId: messageId,
      messageSeq: message.messageSeq,
      channelId: message.channelID,
      channelType: message.channelType,
      contentEdit: jsonEncode(contentEdit),
    );

    final extra = WKMsgExtra()
      ..messageID = messageId
      ..channelID = message.channelID
      ..channelType = message.channelType
      ..editedAt = (DateTime.now().millisecondsSinceEpoch / 1000).truncate()
      ..contentEdit = jsonEncode(contentEdit);
    await WKIM.shared.messageManager.saveRemoteExtraMsg(<WKMsgExtra>[extra]);
  }

  @override
  Future<void> deleteSelfMessage(WKMsg message) async {
    final messageId = message.messageID.trim();
    if (messageId.isEmpty || message.messageSeq <= 0) {
      throw UnsupportedError(
        'Message delete requires a server message id and sequence.',
      );
    }
    final clientMsgNo = message.clientMsgNO.trim();

    await _messageApi.deleteMessage(
      messageId: messageId,
      messageSeq: message.messageSeq,
      channelId: message.channelID,
      channelType: message.channelType,
    );
    if (clientMsgNo.isNotEmpty) {
      await _deleteLocalMessage(clientMsgNo);
    }
  }

  @override
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  }) async {
    final conversations = await _loadConversations();
    return buildForwardTargetsFromConversations(
      conversations,
      excludedChannelId: excludedChannelId,
      excludedChannelType: excludedChannelType,
    );
  }

  @override
  Future<void> recallMessage(WKMsg message) async {
    await _messageApi.revokeMessage(
      clientMsgNo: message.clientMsgNO,
      channelId: message.channelID,
      channelType: message.channelType,
      messageId: message.messageID,
    );

    final recalled = buildLocalRecalledMessageSnapshot(
      message,
      revoker: _currentUidReader(),
    );
    final extra = recalled.wkMsgExtra;
    if (extra != null && extra.messageID.trim().isNotEmpty) {
      await _persistLocalRevokeExtra(<WKMsgExtra>[extra]);
    }
    final refreshLocalMessage = _refreshLocalMessage;
    if (refreshLocalMessage != null) {
      await Future<void>.sync(() => refreshLocalMessage(recalled));
    }
  }

  Future<void> _persistLocalRevokeExtra(List<WKMsgExtra> extras) async {
    if (kIsWeb || !WKIM.shared.isApp()) {
      return;
    }
    await Future<void>.sync(() => _saveRemoteExtras(extras));
  }

  @override
  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
  }) async {
    final channel = WKChannel(channelId, channelType);
    if (channelName != null && channelName.trim().isNotEmpty) {
      channel.channelName = channelName.trim();
    }
    await Future<void>.sync(() => _sendMessage(content, channel));
  }

  @override
  Future<void> retryMessage(WKMsg message) {
    return Future<void>.sync(() => _retryMessage(message));
  }

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {
    final pendingSends = <Future<void>>[];
    for (final target in targets) {
      final channel = WKChannel(target.channelId, target.channelType)
        ..channelName = target.displayName;
      for (final payload in payloads) {
        final content = payload.cloneContent();
        if (content == null) {
          continue;
        }
        pendingSends.add(
          Future<void>.sync(() => _sendMessage(content, channel)),
        );
      }
    }
    await Future.wait(pendingSends);
  }

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) {
    return _reactionManager.toggleReaction(message: message, emoji: emoji);
  }

  @override
  Future<void> togglePinnedMessage(WKMsg message) {
    final messageId = message.messageID.trim();
    if (messageId.isEmpty || message.messageSeq <= 0) {
      throw UnsupportedError(
        'Pinned message updates require a server message id and sequence.',
      );
    }
    return _messageApi.togglePinnedMessage(
      messageId: messageId,
      messageSeq: message.messageSeq,
      channelId: message.channelID,
      channelType: message.channelType,
    );
  }

  @override
  Future<PinnedMessageSyncSnapshot> syncPinnedMessages({
    required String channelId,
    required int channelType,
    int version = 0,
  }) {
    return _messageApi.syncPinnedMessages(
      channelId: channelId,
      channelType: channelType,
      version: version,
    );
  }

  @override
  Future<void> clearPinnedMessages({
    required String channelId,
    required int channelType,
  }) {
    return _messageApi.clearPinnedMessages(
      channelId: channelId,
      channelType: channelType,
    );
  }

  @override
  List<MessageReaction> prepareReactions(WKMsg message) {
    return _reactionManager.prepareReactions(message);
  }

  @override
  Stream<ReactionUpdate> watchReactionUpdates() {
    return _reactionManager.reactionUpdates;
  }

  Map<String, dynamic> _buildEditedContentJson(WKTextContent content) {
    final json = <String, dynamic>{
      ...content.encodeJson(),
      'type': content.contentType,
    };
    final entities = content.entities;
    if (entities != null && entities.isNotEmpty) {
      json['entities'] = entities
          .map(
            (entity) => <String, dynamic>{
              'offset': entity.offset,
              'length': entity.length,
              'type': entity.type,
              'value': entity.value,
            },
          )
          .toList(growable: false);
    }
    final mentionInfo = content.mentionInfo;
    if (mentionInfo != null) {
      final mention = <String, dynamic>{};
      if (mentionInfo.mentionAll) {
        mention['all'] = 1;
      }
      final uids = mentionInfo.uids;
      if (uids != null && uids.isNotEmpty) {
        mention['uids'] = List<String>.from(uids, growable: false);
      }
      if (mention.isNotEmpty) {
        json['mention'] = mention;
      }
    }
    return json;
  }

  String? _resolveFavoriteSenderName(WKMsg message) {
    final member = message.getMemberOfFrom();
    final memberRemark = member?.memberRemark.trim() ?? '';
    if (memberRemark.isNotEmpty) {
      return memberRemark;
    }

    final memberName = member?.memberName.trim() ?? '';
    if (memberName.isNotEmpty) {
      return memberName;
    }

    final from = message.getFrom();
    final channelRemark = from?.channelRemark.trim() ?? '';
    if (channelRemark.isNotEmpty) {
      return channelRemark;
    }

    final channelName = from?.channelName.trim() ?? '';
    if (channelName.isNotEmpty) {
      return channelName;
    }

    final fromUid = message.fromUID.trim();
    return fromUid.isEmpty ? null : fromUid;
  }
}
