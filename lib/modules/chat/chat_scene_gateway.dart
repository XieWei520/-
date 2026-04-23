import 'dart:async';
import 'dart:convert';

import 'package:wukong_im_app/service/api/collection_api.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'message_forwarding.dart';

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
    Future<void> Function(String clientMsgNo)? deleteLocalMessage,
  }) : _collectionApi = collectionApi ?? CollectionApi.instance,
       _messageApi = messageApi ?? MessageApi.instance,
       _reactionManager = reactionManager ?? ReactionManager(),
       _loadConversations = loadConversations ?? _defaultLoadConversations,
       _sendMessage = sendMessage ?? _defaultSendMessage,
       _deleteLocalMessage = deleteLocalMessage ?? _defaultDeleteLocalMessage;

  final CollectionApi _collectionApi;
  final MessageApi _messageApi;
  final ReactionManager _reactionManager;
  final Future<List<WKUIConversationMsg>> Function() _loadConversations;
  final FutureOr<void> Function(WKMessageContent content, WKChannel channel)
  _sendMessage;
  final Future<void> Function(String clientMsgNo) _deleteLocalMessage;

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
  Future<void> recallMessage(WKMsg message) {
    return _messageApi.revokeMessage(
      clientMsgNo: message.clientMsgNO,
      channelId: message.channelID,
      channelType: message.channelType,
      messageId: message.messageID,
    );
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
