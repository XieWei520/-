import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('conversation message reconciliation', () {
    test('refresh upgrades the existing pending message in place', () {
      final newest = _buildMessage(
        clientSeq: 200,
        clientMsgNo: 'latest-msg',
        messageId: 'msg-latest',
        messageSeq: 20,
        orderSeq: 20000,
        status: WKSendMsgResult.sendSuccess,
        text: 'latest',
      );
      final pending = _buildMessage(
        clientSeq: 101,
        clientMsgNo: 'client-101',
        status: WKSendMsgResult.sendLoading,
        text: 'hello',
      );
      final older = _buildMessage(
        clientSeq: 50,
        clientMsgNo: 'older-msg',
        messageId: 'msg-older',
        messageSeq: 10,
        orderSeq: 10000,
        status: WKSendMsgResult.sendSuccess,
        text: 'older',
      );
      final refreshed = _buildMessage(
        clientSeq: 101,
        clientMsgNo: 'client-101',
        messageId: 'msg-101',
        messageSeq: 11,
        orderSeq: 11000,
        status: WKSendMsgResult.sendSuccess,
        text: 'hello',
      );

      final messages = refreshConversationMessages([
        newest,
        pending,
        older,
      ], refreshed);

      expect(messages, hasLength(3));
      expect(messages[0].clientMsgNO, 'latest-msg');
      expect(messages[1].messageID, 'msg-101');
      expect(messages[1].status, WKSendMsgResult.sendSuccess);
      expect(messages[2].messageID, 'msg-older');
    });

    test(
      'merge keeps only one record when same client message is refreshed',
      () {
        final pending = _buildMessage(
          clientSeq: 101,
          clientMsgNo: 'client-101',
          status: WKSendMsgResult.sendLoading,
          text: 'hello',
        );
        final refreshed = _buildMessage(
          clientSeq: 101,
          clientMsgNo: 'client-101',
          messageId: 'msg-101',
          messageSeq: 11,
          orderSeq: 11000,
          status: WKSendMsgResult.sendSuccess,
          text: 'hello',
        );

        final messages = mergeConversationMessages([pending, refreshed]);

        expect(messages, hasLength(1));
        expect(messages.single.messageID, 'msg-101');
        expect(messages.single.status, WKSendMsgResult.sendSuccess);
      },
    );

    test('message match index resolves server ack aliases in one lookup', () {
      final pending = _buildMessage(
        clientSeq: 101,
        clientMsgNo: 'client-101',
        status: WKSendMsgResult.sendLoading,
        text: 'hello',
      );
      final refreshed = _buildMessage(
        clientSeq: 101,
        clientMsgNo: 'client-101',
        messageId: 'msg-101',
        messageSeq: 11,
        orderSeq: 11000,
        status: WKSendMsgResult.sendSuccess,
        text: 'hello',
      );

      final index = ChatMessageMatchIndex([pending]);

      expect(index.find(refreshed), 0);
    });

    test('merge ignores deleted duplicate packets from the sdk', () {
      final pending = _buildMessage(
        clientSeq: 101,
        clientMsgNo: 'client-101',
        status: WKSendMsgResult.sendLoading,
        text: 'hello',
      );
      final deletedDuplicate = _buildMessage(
        clientSeq: 202,
        clientMsgNo: 'duplicate-202',
        messageId: 'msg-101',
        messageSeq: 11,
        orderSeq: 11000,
        status: WKSendMsgResult.sendSuccess,
        isDeleted: 1,
        text: 'hello',
      );

      final messages = mergeConversationMessages([deletedDuplicate, pending]);

      expect(messages, hasLength(1));
      expect(messages.single.clientMsgNO, 'client-101');
      expect(messages.single.messageID, isEmpty);
      expect(messages.single.status, WKSendMsgResult.sendLoading);
    });

    test('refresh prefers newer revoke extra version over cached body', () {
      final cached =
          _buildMessage(
              clientSeq: 301,
              clientMsgNo: 'client-301',
              messageId: 'msg-301',
              messageSeq: 31,
              orderSeq: 31000,
              status: WKSendMsgResult.sendSuccess,
              text: 'revoke-003',
            )
            ..wkMsgExtra = (WKMsgExtra()
              ..messageID = 'msg-301'
              ..revoke = 0
              ..extraVersion = 100);

      final refreshed =
          _buildMessage(
              clientSeq: 301,
              clientMsgNo: 'client-301',
              messageId: 'msg-301',
              messageSeq: 31,
              orderSeq: 31000,
              status: WKSendMsgResult.sendSuccess,
              text: 'revoke-003',
            )
            ..wkMsgExtra = (WKMsgExtra()
              ..messageID = 'msg-301'
              ..revoke = 1
              ..revoker = 'u_me'
              ..extraVersion = 200);

      final messages = refreshConversationMessages([cached], refreshed);

      expect(messages, hasLength(1));
      expect(messages.single.wkMsgExtra?.revoke, 1);
      expect(messages.single.wkMsgExtra?.extraVersion, 200);
    });

    test(
      'message with newer read receipt extra is preferred during merge',
      () {
        final cached =
            _buildMessage(
                clientSeq: 402,
                clientMsgNo: 'client-read-402',
                messageId: 'msg-read-402',
                messageSeq: 42,
                orderSeq: 42000,
                status: WKSendMsgResult.sendSuccess,
                text: 'read receipt merge',
              )
              ..wkMsgExtra = (WKMsgExtra()
                ..messageID = 'msg-read-402'
                ..readed = 0
                ..readedCount = 0
                ..unreadCount = 1
                ..extraVersion = 10);
        final refreshed =
            _buildMessage(
                clientSeq: 402,
                clientMsgNo: 'client-read-402',
                messageId: 'msg-read-402',
                messageSeq: 42,
                orderSeq: 42000,
                status: WKSendMsgResult.sendSuccess,
                text: 'read receipt merge',
              )
              ..wkMsgExtra = (WKMsgExtra()
                ..messageID = 'msg-read-402'
                ..readed = 1
                ..readedCount = 1
                ..unreadCount = 0
                ..extraVersion = 10);

        final messages = mergeConversationMessages([cached, refreshed]);

        expect(messages, hasLength(1));
        expect(messages.single.wkMsgExtra?.readed, 1);
        expect(messages.single.wkMsgExtra?.readedCount, 1);
        expect(messages.single.wkMsgExtra?.unreadCount, 0);
      },
    );

    test(
      'web message extra refresh updates visible read receipt without reopen',
      () {
        final notifier = MessageListNotifier(
          'u_target',
          WKChannelType.personal,
          autoLoad: false,
        );
        final cached =
            _buildMessage(
                clientSeq: 403,
                clientMsgNo: 'client-read-403',
                messageId: 'msg-read-403',
                messageSeq: 43,
                orderSeq: 43000,
                status: WKSendMsgResult.sendSuccess,
                text: 'read receipt visible',
              )
              ..wkMsgExtra = (WKMsgExtra()
                ..messageID = 'msg-read-403'
                ..readed = 0
                ..readedCount = 0
                ..unreadCount = 1
                ..extraVersion = 10);
        final extra = WKMsgExtra()
          ..messageID = 'msg-read-403'
          ..readed = 1
          ..readedCount = 1
          ..unreadCount = 0
          ..extraVersion = 11;

        notifier.applyLocalMessageRefresh(cached);
        notifier.applyLocalMessageRefresh(
          WKMsg()
            ..channelID = 'u_target'
            ..channelType = WKChannelType.personal
            ..messageID = 'msg-read-403'
            ..status = WKSendMsgResult.sendSuccess
            ..wkMsgExtra = extra,
        );

        expect(notifier.state, hasLength(1));
        expect(notifier.state.single.wkMsgExtra?.readed, 1);
        expect(notifier.state.single.wkMsgExtra?.readedCount, 1);
        expect(notifier.state.single.wkMsgExtra?.unreadCount, 0);
        expect(notifier.state.single.wkMsgExtra?.extraVersion, 11);
      },
    );
  });

  group('web realtime conversation projection', () {
    test('remote conversation sync requires stored uid and token', () {
      expect(
        hasAuthenticatedConversationSyncSession(
          uid: 'u_me',
          token: 'token-123',
        ),
        isTrue,
      );
      expect(
        hasAuthenticatedConversationSyncSession(uid: '', token: 'token-123'),
        isFalse,
      );
      expect(
        hasAuthenticatedConversationSyncSession(uid: 'u_me', token: ''),
        isFalse,
      );
    });

    test(
      'realtime message bootstraps a conversation with cached last message',
      () async {
        final notifier = ConversationNotifier.forTest(const []);
        final incoming =
            _buildMessage(
                clientSeq: 0,
                clientMsgNo: 'remote-client-001',
                channelId: 'u_sender',
                fromUid: 'u_sender',
                messageId: '9001',
                messageSeq: 9,
                orderSeq: 9000,
                status: WKSendMsgResult.sendSuccess,
                text: 'web hello',
              )
              ..timestamp = 1777184000
              ..header.redDot = true;

        notifier.applyRealtimeMessage(incoming, currentUid: 'u_me');

        expect(notifier.state, hasLength(1));
        final conversation = notifier.state.single;
        expect(conversation.channelID, 'u_sender');
        expect(conversation.clientMsgNo, 'remote-client-001');
        expect(conversation.lastMsgSeq, 9);
        expect(conversation.lastMsgTimestamp, 1777184000);
        expect(conversation.unreadCount, 1);
        expect(await conversation.getWkMsg(), same(incoming));
      },
    );

    test(
      'sync conversations become UI conversations with recent message cache',
      () async {
        final sync = WKSyncConvMsg()
          ..channelID = 'u_sender'
          ..channelType = WKChannelType.personal
          ..lastClientMsgNO = 'remote-client-002'
          ..lastMsgSeq = 12
          ..timestamp = 1777184100
          ..unread = 2
          ..recents = <WKSyncMsg>[
            WKSyncMsg()
              ..clientMsgNO = 'remote-client-002'
              ..messageID = '9002'
              ..messageSeq = 12
              ..fromUID = 'u_sender'
              ..channelID = 'u_me'
              ..channelType = WKChannelType.personal
              ..timestamp = 1777184100
              ..payload = <String, dynamic>{
                'content': 'synced hello',
                'type': 1,
              },
          ];

        final conversations = mapSyncConversationsToUiConversations([sync]);

        expect(conversations, hasLength(1));
        final conversation = conversations.single;
        expect(conversation.channelID, 'u_sender');
        expect(conversation.unreadCount, 2);
        expect(conversation.clientMsgNo, 'remote-client-002');
        final cachedMessage = await conversation.getWkMsg();
        expect(cachedMessage, isNotNull);
        expect(cachedMessage!.clientMsgNO, 'remote-client-002');
        expect(cachedMessage.channelID, 'u_sender');
      },
    );

    test(
      'sync conversation falls back to the latest recent message timestamp for ordering',
      () async {
        final sync = WKSyncConvMsg()
          ..channelID = 'u_sender'
          ..channelType = WKChannelType.personal
          ..lastClientMsgNO = ''
          ..lastMsgSeq = 0
          ..timestamp = 0
          ..recents = <WKSyncMsg>[
            WKSyncMsg()
              ..clientMsgNO = 'remote-client-latest'
              ..messageID = '9003'
              ..messageSeq = 33
              ..fromUID = 'u_sender'
              ..channelID = 'u_me'
              ..channelType = WKChannelType.personal
              ..timestamp = 1777184300
              ..payload = <String, dynamic>{
                'content': 'timestamp fallback',
                'type': 1,
              },
          ];

        final conversations = mapSyncConversationsToUiConversations([sync]);

        expect(conversations, hasLength(1));
        expect(conversations.single.clientMsgNo, 'remote-client-latest');
        expect(conversations.single.lastMsgSeq, 33);
        expect(conversations.single.lastMsgTimestamp, 1777184300);
      },
    );

    test(
      'conversation patches preserve cached last message for previews',
      () async {
        final notifier = ConversationNotifier.forTest(const []);
        final incoming = _buildMessage(
          clientSeq: 0,
          clientMsgNo: 'remote-client-004',
          channelId: 'u_sender',
          fromUid: 'u_sender',
          messageId: '9004',
          messageSeq: 44,
          orderSeq: 44000,
          status: WKSendMsgResult.sendSuccess,
          text: 'cached preview',
        )..timestamp = 1777184400;

        notifier.applyRealtimeMessage(incoming, currentUid: 'u_me');
        notifier.applyPatch(
          const ConversationPatch(
            channelId: 'u_sender',
            channelType: WKChannelType.personal,
            unreadCount: 0,
            sortTimestamp: 1777184400,
            lastMessageDigest: 'remote-client-004',
            isMuted: true,
          ),
        );

        expect(notifier.state, hasLength(1));
        final cachedMessage = await notifier.state.single.getWkMsg();
        expect(cachedMessage, same(incoming));
      },
    );
  });

  group('web outgoing message projection', () {
    test('local outgoing message is inserted at the top of the chat state', () {
      final notifier = MessageListNotifier(
        'u_target',
        WKChannelType.personal,
        autoLoad: false,
      );
      final older = _buildMessage(
        clientSeq: 1,
        clientMsgNo: 'older-client',
        messageId: 'older-message',
        messageSeq: 1,
        orderSeq: 1000,
        status: WKSendMsgResult.sendSuccess,
        text: 'older',
      );
      final outgoing = _buildMessage(
        clientSeq: 2,
        clientMsgNo: 'local-outgoing',
        status: WKSendMsgResult.sendLoading,
        text: 'send immediately',
      )..timestamp = 1777184500;

      notifier.applyLocalOutgoingMessage(older);
      notifier.applyLocalOutgoingMessage(outgoing);

      expect(notifier.state, hasLength(2));
      expect(notifier.state.first.clientMsgNO, 'local-outgoing');
      expect(notifier.state.first.content, contains('send immediately'));
    });

    test(
      'local message refresh replaces the visible message without mutating the old instance',
      () {
        final notifier = MessageListNotifier(
          'u_target',
          WKChannelType.personal,
          autoLoad: false,
        );
        final original = _buildMessage(
          clientSeq: 12,
          clientMsgNo: 'client-recalled',
          messageId: 'msg-recalled',
          messageSeq: 12,
          orderSeq: 12000,
          status: WKSendMsgResult.sendSuccess,
          text: 'before revoke',
        );
        final recalled =
            _buildMessage(
                clientSeq: 12,
                clientMsgNo: 'client-recalled',
                messageId: 'msg-recalled',
                messageSeq: 12,
                orderSeq: 12000,
                status: WKSendMsgResult.sendSuccess,
                text: 'before revoke',
              )
              ..wkMsgExtra = (WKMsgExtra()
                ..messageID = 'msg-recalled'
                ..revoke = 1
                ..revoker = 'u_me'
                ..extraVersion = 2);

        notifier.applyLocalMessageRefresh(original);
        notifier.applyLocalMessageRefresh(recalled);

        expect(notifier.state, hasLength(1));
        expect(notifier.state.single, same(recalled));
        expect(original.wkMsgExtra, isNull);
      },
    );

    test(
      'local message refresh updates only the matching conversation preview',
      () async {
        final lastMessage = _buildMessage(
          clientSeq: 21,
          clientMsgNo: 'last-client',
          channelId: 'u_target',
          messageId: 'last-message',
          messageSeq: 21,
          orderSeq: 21000,
          status: WKSendMsgResult.sendSuccess,
          text: 'last body',
        )..timestamp = 1777184700;
        final olderMessage = _buildMessage(
          clientSeq: 20,
          clientMsgNo: 'older-client',
          channelId: 'u_target',
          messageId: 'older-message',
          messageSeq: 20,
          orderSeq: 20000,
          status: WKSendMsgResult.sendSuccess,
          text: 'older body',
        );
        final notifier = ConversationNotifier.forTest(const []);
        notifier.applyRealtimeMessage(lastMessage, currentUid: 'u_me');

        notifier.applyLocalMessageRefresh(
          olderMessage
            ..wkMsgExtra = (WKMsgExtra()
              ..messageID = 'older-message'
              ..revoke = 1
              ..extraVersion = 2),
        );

        expect(await notifier.state.single.getWkMsg(), same(lastMessage));

        final recalledLast =
            _buildMessage(
                clientSeq: 21,
                clientMsgNo: 'last-client',
                channelId: 'u_target',
                messageId: 'last-message',
                messageSeq: 21,
                orderSeq: 21000,
                status: WKSendMsgResult.sendSuccess,
                text: 'last body',
              )
              ..timestamp = 1777184700
              ..wkMsgExtra = (WKMsgExtra()
                ..messageID = 'last-message'
                ..revoke = 1
                ..revoker = 'u_me'
                ..extraVersion = 2);
        notifier.applyLocalMessageRefresh(recalledLast);

        final conversation = notifier.state.single;
        expect(conversation.unreadCount, 0);
        expect(conversation.clientMsgNo, 'last-client');
        expect(await conversation.getWkMsg(), same(recalledLast));
      },
    );
  });

  group('conversation deletion suppression', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageUtils.init();
    });

    setUp(() async {
      await StorageUtils.clear();
      await StorageUtils.setUid('conversation_delete_user');
    });

    test('deleted conversation is not re-added by stale sdk refresh', () async {
      final existing = _buildConversation(
        channelId: 'g_deleted',
        channelType: WKChannelType.group,
        lastMsgSeq: 88,
        lastMsgTimestamp: 1777184800,
        clientMsgNo: 'client-old',
      );
      final notifier = ConversationNotifier.forTest(
        <WKUIConversationMsg>[existing],
        deleteConversationAction: (channelId, channelType) async {},
        removeDraftAction: (channelId, channelType) async {},
      );

      await notifier.deleteConversation('g_deleted', WKChannelType.group);
      notifier.applyRefreshForTest(<WKUIConversationMsg>[
        _buildConversation(
          channelId: 'g_deleted',
          channelType: WKChannelType.group,
          lastMsgSeq: 88,
          lastMsgTimestamp: 1777184800,
          clientMsgNo: 'client-old',
        ),
      ]);

      expect(notifier.state, isEmpty);
    });

    test(
      'deleted conversation can reappear when a newer message arrives',
      () async {
        final notifier = ConversationNotifier.forTest(
          <WKUIConversationMsg>[
            _buildConversation(
              channelId: 'g_active',
              channelType: WKChannelType.group,
              lastMsgSeq: 10,
              lastMsgTimestamp: 1777184900,
              clientMsgNo: 'client-10',
            ),
          ],
          deleteConversationAction: (channelId, channelType) async {},
          removeDraftAction: (channelId, channelType) async {},
        );

        await notifier.deleteConversation('g_active', WKChannelType.group);
        notifier.applyRefreshForTest(<WKUIConversationMsg>[
          _buildConversation(
            channelId: 'g_active',
            channelType: WKChannelType.group,
            lastMsgSeq: 11,
            lastMsgTimestamp: 1777184910,
            clientMsgNo: 'client-11',
          ),
        ]);

        expect(notifier.state, hasLength(1));
        expect(notifier.state.single.channelID, 'g_active');
        expect(notifier.state.single.lastMsgSeq, 11);
      },
    );

    test(
      'deleted conversation is not re-added by stale sync after notifier recreation',
      () async {
        final original = ConversationNotifier.forTest(
          <WKUIConversationMsg>[
            _buildConversation(
              channelId: 'g_persisted_delete',
              channelType: WKChannelType.group,
              lastMsgSeq: 31,
              lastMsgTimestamp: 1777185000,
              clientMsgNo: 'client-31',
            ),
          ],
          deleteConversationAction: (channelId, channelType) async {},
          removeDraftAction: (channelId, channelType) async {},
        );

        await original.deleteConversation(
          'g_persisted_delete',
          WKChannelType.group,
        );

        final recreated = ConversationNotifier.forTest(
          const <WKUIConversationMsg>[],
          deleteConversationAction: (channelId, channelType) async {},
          removeDraftAction: (channelId, channelType) async {},
        );
        recreated.applyRefreshForTest(<WKUIConversationMsg>[
          _buildConversation(
            channelId: 'g_persisted_delete',
            channelType: WKChannelType.group,
            lastMsgSeq: 31,
            lastMsgTimestamp: 1777185000,
            clientMsgNo: 'client-31',
          ),
        ]);

        expect(recreated.state, isEmpty);
      },
    );
  });
}

WKUIConversationMsg _buildConversation({
  required String channelId,
  required int channelType,
  required int lastMsgSeq,
  required int lastMsgTimestamp,
  required String clientMsgNo,
  int unreadCount = 0,
}) {
  return WKUIConversationMsg()
    ..channelID = channelId
    ..channelType = channelType
    ..lastMsgSeq = lastMsgSeq
    ..lastMsgTimestamp = lastMsgTimestamp
    ..clientMsgNo = clientMsgNo
    ..unreadCount = unreadCount;
}

WKMsg _buildMessage({
  required int clientSeq,
  required String clientMsgNo,
  String channelId = 'u_target',
  int channelType = WKChannelType.personal,
  String fromUid = 'u_me',
  String messageId = '',
  int messageSeq = 0,
  int orderSeq = 0,
  int status = WKSendMsgResult.sendLoading,
  int isDeleted = 0,
  required String text,
}) {
  return WKMsg()
    ..clientSeq = clientSeq
    ..clientMsgNO = clientMsgNo
    ..channelID = channelId
    ..channelType = channelType
    ..fromUID = fromUid
    ..messageID = messageId
    ..messageSeq = messageSeq
    ..orderSeq = orderSeq
    ..status = status
    ..isDeleted = isDeleted
    ..contentType = WkMessageContentType.text
    ..content = '{"content":"$text","type":1}';
}
