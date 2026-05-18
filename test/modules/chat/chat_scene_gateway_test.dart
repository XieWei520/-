import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukong_im_app/service/api/collection_api.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test(
    'buildDirectOutgoingMessage mirrors SDK send payload for immediate web UI',
    () {
      final now = DateTime.fromMillisecondsSinceEpoch(1777184600000);
      final channel = WKChannel('u_target', WKChannelType.personal)
        ..channelName = 'Target';
      final content = WKTextContent('hello web');

      final message = buildDirectOutgoingMessage(
        content: content,
        channel: channel,
        currentUid: 'u_me',
        now: now,
      );

      expect(message.channelID, 'u_target');
      expect(message.channelType, WKChannelType.personal);
      expect(message.fromUID, 'u_me');
      expect(message.contentType, WkMessageContentType.text);
      expect(message.status, WKSendMsgResult.sendLoading);
      expect(message.timestamp, 1777184600);
      expect(message.orderSeq, 1777184600000);
      expect(message.expireTime, 0);
      expect(message.expireTimestamp, 0);
      expect(message.messageContent, same(content));
      expect(message.getChannelInfo(), same(channel));
      final payload = jsonDecode(message.content) as Map<String, dynamic>;
      expect(payload['content'], 'hello web');
      expect(payload['type'], WkMessageContentType.text);
    },
  );

  test('buildDirectOutgoingMessage records requested message expiration', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1777184600000);
    final channel = WKChannel('u_target', WKChannelType.personal);
    final content = WKTextContent('expires on web');

    final message = buildDirectOutgoingMessage(
      content: content,
      channel: channel,
      currentUid: 'u_me',
      expireSeconds: defaultChatMessageRetentionSeconds,
      now: now,
    );

    expect(message.expireTime, defaultChatMessageRetentionSeconds);
    expect(
      message.expireTimestamp,
      1777184600 + defaultChatMessageRetentionSeconds,
    );
  });

  test('addFavorite forwards favorite metadata to collection api', () async {
    final collectionApi = _FakeCollectionApi();
    final gateway = ApiChatSceneGateway(collectionApi: collectionApi);
    final message = WKMsg()
      ..clientMsgNO = 'client-1'
      ..messageID = 'message-1'
      ..messageSeq = 3001
      ..orderSeq = 4002
      ..content = 'hello'
      ..contentType = WkMessageContentType.text
      ..channelID = 'group-1'
      ..channelType = WKChannelType.group
      ..fromUID = 'u-sender';

    await gateway.addFavorite(message);

    expect(collectionApi.calls, hasLength(1));
    final call = collectionApi.calls.single;
    expect(call.clientMsgNo, 'client-1');
    expect(call.messageId, 'message-1');
    expect(call.content, 'hello');
    expect(call.contentType, WkMessageContentType.text);
    expect(call.channelId, 'group-1');
    expect(call.channelType, WKChannelType.group);
    expect(call.senderUid, 'u-sender');
    expect(call.senderName, 'u-sender');
    expect(call.messageSeq, 3001);
    expect(call.orderSeq, 4002);
  });

  test('loadForwardTargets uses the injected conversation loader', () async {
    final source = WKUIConversationMsg()
      ..channelID = 'g-source'
      ..channelType = WKChannelType.group;
    source.setWkChannel(
      WKChannel('g-source', WKChannelType.group)..channelName = 'Source',
    );

    final target = WKUIConversationMsg()
      ..channelID = 'u-target'
      ..channelType = WKChannelType.personal;
    target.setWkChannel(
      WKChannel('u-target', WKChannelType.personal)..channelName = 'Target',
    );

    final gateway = ApiChatSceneGateway(
      loadConversations: () async => <WKUIConversationMsg>[source, target],
    );

    final targets = await gateway.loadForwardTargets(
      excludedChannelId: 'g-source',
      excludedChannelType: WKChannelType.group,
    );

    expect(targets, hasLength(1));
    expect(targets.single.channelId, 'u-target');
  });

  test('sendPersistentSdkMessage waits for sendWithOption', () async {
    final completer = Completer<void>();
    final channel = WKChannel('g-active', WKChannelType.group);
    final content = WKTextContent('send through sdk');
    final calls = <String>[];

    var completed = false;
    final sendFuture = sendPersistentSdkMessage(
      content: content,
      channel: channel,
      sendWithOption: (sentContent, sentChannel, options) {
        calls.add('${sentChannel.channelType}:${sentChannel.channelID}');
        expect(sentContent, same(content));
        expect(options, isA<WKSendOptions>());
        return completer.future;
      },
    ).then((_) => completed = true);

    await Future<void>.delayed(Duration.zero);
    expect(calls, <String>['2:g-active']);
    expect(completed, isFalse);

    completer.complete();
    await sendFuture;

    expect(completed, isTrue);
  });

  test('sendPersistentSdkMessage forwards explicit expire option', () async {
    final channel = WKChannel('g-expiring', WKChannelType.group);
    final content = WKTextContent('expires later');
    WKSendOptions? capturedOptions;

    await sendPersistentSdkMessage(
      content: content,
      channel: channel,
      options: WKSendOptions()..expire = 21600,
      sendWithOption: (sentContent, sentChannel, options) {
        expect(sentContent, same(content));
        expect(sentChannel, same(channel));
        capturedOptions = options;
      },
    );

    expect(capturedOptions?.expire, 21600);
  });

  test('sendForwardPayloads uses the injected sender', () async {
    final sent = <String>[];
    final expires = <int?>[];
    final gateway = ApiChatSceneGateway(
      sendMessageWithOptions: (content, channel, options) {
        final text = content as WKTextContent;
        sent.add('${channel.channelType}:${channel.channelID}:${text.content}');
        expires.add(options?.expire);
      },
    );

    await gateway.sendForwardPayloads(
      <ForwardPayload>[
        ForwardPayload(
          clientMsgNo: 'client-forward',
          content: WKTextContent('forward me'),
        ),
      ],
      const <ForwardTarget>[
        ForwardTarget(
          channelId: 'u-destination',
          channelType: WKChannelType.personal,
          name: 'Destination',
        ),
      ],
    );

    expect(sent, <String>['1:u-destination:forward me']);
    expect(expires, <int?>[defaultChatMessageRetentionSeconds]);
  });

  test(
    'sendMessageContent uses 30 day retention for active chat sends by default',
    () async {
      final sent = <String>[];
      final expires = <int?>[];
      final gateway = ApiChatSceneGateway(
        sendMessageWithOptions: (content, channel, options) {
          final text = content as WKTextContent;
          sent.add(
            '${channel.channelType}:${channel.channelID}:${text.content}',
          );
          expires.add(options?.expire);
        },
      );

      await gateway.sendMessageContent(
        WKTextContent('send now'),
        channelId: 'g-active',
        channelType: WKChannelType.group,
      );

      expect(sent, <String>['2:g-active:send now']);
      expect(expires, <int?>[defaultChatMessageRetentionSeconds]);
    },
  );

  test('sendMessageContent passes requested expire option to sender', () async {
    WKSendOptions? capturedOptions;
    final gateway = ApiChatSceneGateway(
      sendMessageWithOptions: (content, channel, options) {
        capturedOptions = options;
      },
    );

    await gateway.sendMessageContent(
      WKTextContent('send with expiry'),
      channelId: 'g-active',
      channelType: WKChannelType.group,
      expireSeconds: 21600,
    );

    expect(capturedOptions?.expire, 21600);
  });

  test(
    'sendMessageContent waits for injected sender futures to complete',
    () async {
      final completer = Completer<void>();
      final gateway = ApiChatSceneGateway(
        sendMessage: (content, channel) => completer.future,
      );

      var completed = false;
      final sendFuture = gateway
          .sendMessageContent(
            WKTextContent('send after persistence'),
            channelId: 'g-active',
            channelType: WKChannelType.group,
          )
          .then((_) => completed = true);

      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      completer.complete();
      await sendFuture;

      expect(completed, isTrue);
    },
  );

  test(
    'sendForwardPayloads waits for injected sender futures to complete',
    () async {
      final completer = Completer<void>();
      final gateway = ApiChatSceneGateway(
        sendMessage: (content, channel) => completer.future,
      );

      var completed = false;
      final forwardFuture = gateway
          .sendForwardPayloads(
            <ForwardPayload>[
              ForwardPayload(
                clientMsgNo: 'client-forward',
                content: WKTextContent('forward me'),
              ),
            ],
            const <ForwardTarget>[
              ForwardTarget(
                channelId: 'u-destination',
                channelType: WKChannelType.personal,
                name: 'Destination',
              ),
            ],
          )
          .then((_) => completed = true);

      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      completer.complete();
      await forwardFuture;

      expect(completed, isTrue);
    },
  );

  test(
    'deleteSelfMessage calls api delete and marks the local message deleted',
    () async {
      final messageApi = _FakeMessageApi();
      final locallyDeletedClientMsgNos = <String>[];
      final gateway = ApiChatSceneGateway(
        messageApi: messageApi,
        deleteLocalMessage: (clientMsgNo) async {
          locallyDeletedClientMsgNos.add(clientMsgNo);
        },
      );
      final message = WKMsg()
        ..messageID = 'message-delete'
        ..messageSeq = 88
        ..clientMsgNO = 'client-delete'
        ..channelID = 'u-delete'
        ..channelType = WKChannelType.personal;

      await gateway.deleteSelfMessage(message);

      expect(messageApi.deleteCalls, hasLength(1));
      expect(messageApi.deleteCalls.single.messageId, 'message-delete');
      expect(messageApi.deleteCalls.single.messageSeq, 88);
      expect(messageApi.deleteCalls.single.channelId, 'u-delete');
      expect(messageApi.deleteCalls.single.channelType, WKChannelType.personal);
      expect(locallyDeletedClientMsgNos, <String>['client-delete']);
    },
  );

  test(
    'recallMessage persists a local revoke extra and publishes a fresh message snapshot',
    () async {
      final messageApi = _FakeMessageApi();
      final savedExtras = <WKMsgExtra>[];
      final refreshedMessages = <WKMsg>[];
      final gateway = ApiChatSceneGateway(
        messageApi: messageApi,
        saveRemoteExtras: (extras) async {
          savedExtras.addAll(extras);
        },
        refreshLocalMessage: (message) {
          refreshedMessages.add(message);
        },
        currentUidReader: () => 'u_me',
      );
      final message = WKMsg()
        ..messageID = 'message-recall'
        ..messageSeq = 77
        ..clientSeq = 707
        ..clientMsgNO = 'client-recall'
        ..channelID = 'u-recall'
        ..channelType = WKChannelType.personal
        ..fromUID = 'u_me'
        ..contentType = WkMessageContentType.text
        ..content = '{"content":"undo me","type":1}'
        ..status = WKSendMsgResult.sendSuccess
        ..orderSeq = 77000
        ..wkMsgExtra = (WKMsgExtra()
          ..messageID = 'message-recall'
          ..extraVersion = 9);

      await gateway.recallMessage(message);

      expect(messageApi.revokeCalls, hasLength(1));
      expect(messageApi.revokeCalls.single.clientMsgNo, 'client-recall');
      expect(messageApi.revokeCalls.single.messageId, 'message-recall');
      expect(savedExtras, hasLength(1));
      expect(savedExtras.single.messageID, 'message-recall');
      expect(savedExtras.single.channelID, 'u-recall');
      expect(savedExtras.single.revoke, 1);
      expect(savedExtras.single.revoker, 'u_me');
      expect(savedExtras.single.extraVersion, greaterThan(9));
      expect(refreshedMessages, hasLength(1));
      expect(refreshedMessages.single, isNot(same(message)));
      expect(refreshedMessages.single.clientMsgNO, 'client-recall');
      expect(refreshedMessages.single.wkMsgExtra, same(savedExtras.single));
      expect(message.wkMsgExtra?.revoke, 0);
    },
  );
}

class _FakeCollectionApi implements CollectionApi {
  final List<_AddFavoriteCall> calls = <_AddFavoriteCall>[];

  @override
  Future<void> add({
    required String clientMsgNo,
    String? messageId,
    int? messageSeq,
    int? orderSeq,
    String? content,
    int? contentType,
    String? channelId,
    int? channelType,
    String? senderUid,
    String? senderName,
  }) async {
    calls.add(
      _AddFavoriteCall(
        clientMsgNo: clientMsgNo,
        messageId: messageId,
        messageSeq: messageSeq,
        orderSeq: orderSeq,
        content: content,
        contentType: contentType,
        channelId: channelId,
        channelType: channelType,
        senderUid: senderUid,
        senderName: senderName,
      ),
    );
  }

  @override
  Future<void> delete(dynamic id) async {}

  @override
  Future<List<Map<String, dynamic>>> getList({
    int page = 1,
    int pageSize = 20,
  }) async => const <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> search({
    required String keyword,
    int page = 1,
    int pageSize = 20,
  }) async => const <Map<String, dynamic>>[];
}

class _FakeMessageApi implements MessageApi {
  final List<_DeleteMessageCall> deleteCalls = <_DeleteMessageCall>[];
  final List<_RevokeMessageCall> revokeCalls = <_RevokeMessageCall>[];

  @override
  Future<void> deleteMessage({
    required String messageId,
    required int messageSeq,
    required String channelId,
    required int channelType,
  }) async {
    deleteCalls.add(
      _DeleteMessageCall(
        messageId: messageId,
        messageSeq: messageSeq,
        channelId: channelId,
        channelType: channelType,
      ),
    );
  }

  @override
  Future<void> revokeMessage({
    required String clientMsgNo,
    required String channelId,
    required int channelType,
    String? messageId,
  }) async {
    revokeCalls.add(
      _RevokeMessageCall(
        clientMsgNo: clientMsgNo,
        channelId: channelId,
        channelType: channelType,
        messageId: messageId,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AddFavoriteCall {
  const _AddFavoriteCall({
    required this.clientMsgNo,
    this.messageId,
    this.messageSeq,
    this.orderSeq,
    this.content,
    this.contentType,
    this.channelId,
    this.channelType,
    this.senderUid,
    this.senderName,
  });

  final String clientMsgNo;
  final String? messageId;
  final int? messageSeq;
  final int? orderSeq;
  final String? content;
  final int? contentType;
  final String? channelId;
  final int? channelType;
  final String? senderUid;
  final String? senderName;
}

class _DeleteMessageCall {
  const _DeleteMessageCall({
    required this.messageId,
    required this.messageSeq,
    required this.channelId,
    required this.channelType,
  });

  final String messageId;
  final int messageSeq;
  final String channelId;
  final int channelType;
}

class _RevokeMessageCall {
  const _RevokeMessageCall({
    required this.clientMsgNo,
    required this.channelId,
    required this.channelType,
    this.messageId,
  });

  final String clientMsgNo;
  final String channelId;
  final int channelType;
  final String? messageId;
}
