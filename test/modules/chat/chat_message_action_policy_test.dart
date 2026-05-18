import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/constants/im_constants.dart';
import 'package:wukong_im_app/modules/chat/chat_message_action_policy.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('chat message action policy', () {
    test('self text message keeps Android action order with recall', () {
      final actions = buildChatMessageActionDescriptors(
        message: _buildInteractiveTextMessage(),
        isSelf: true,
        canRecall: true,
      );

      expect(
        actions.map((entry) => entry.action).toList(growable: false),
        const <ChatSceneAction>[
          ChatSceneAction.reply,
          ChatSceneAction.forward,
          ChatSceneAction.copy,
          ChatSceneAction.edit,
          ChatSceneAction.favorite,
          ChatSceneAction.select,
          ChatSceneAction.recall,
          ChatSceneAction.react,
        ],
      );
      expect(
        actions.map((entry) => entry.label).toList(growable: false),
        const <String>[
          '\u56de\u590d',
          '\u8f6c\u53d1',
          '\u590d\u5236',
          '\u7f16\u8f91',
          '\u6536\u85cf',
          '\u591a\u9009',
          '\u64a4\u56de',
          '\u8868\u60c5\u56de\u5e94',
        ],
      );
      expect(
        actions.map((entry) => entry.order).toList(growable: false),
        const <int>[0, 1, 2, 3, 4, 5, 7, 8],
      );
    });

    test('foreign text message without recall permission omits recall', () {
      final actions = buildChatMessageActionDescriptors(
        message: _buildInteractiveTextMessage(),
        isSelf: false,
        canRecall: false,
      );

      expect(
        actions.map((entry) => entry.action).toList(growable: false),
        const <ChatSceneAction>[
          ChatSceneAction.reply,
          ChatSceneAction.forward,
          ChatSceneAction.copy,
          ChatSceneAction.favorite,
          ChatSceneAction.select,
          ChatSceneAction.react,
        ],
      );
      expect(
        actions.map((entry) => entry.label).toList(growable: false),
        const <String>[
          '\u56de\u590d',
          '\u8f6c\u53d1',
          '\u590d\u5236',
          '\u6536\u85cf',
          '\u591a\u9009',
          '\u8868\u60c5\u56de\u5e94',
        ],
      );
      expect(
        actions.map((entry) => entry.order).toList(growable: false),
        const <int>[0, 1, 2, 4, 5, 8],
      );
    });

    test('foreign text message with moderator permission exposes recall', () {
      final actions = buildChatMessageActionDescriptors(
        message: _buildInteractiveTextMessage(),
        isSelf: false,
        canRecall: true,
      );

      expect(
        actions.map((entry) => entry.action).toList(growable: false),
        const <ChatSceneAction>[
          ChatSceneAction.reply,
          ChatSceneAction.forward,
          ChatSceneAction.copy,
          ChatSceneAction.favorite,
          ChatSceneAction.select,
          ChatSceneAction.recall,
          ChatSceneAction.react,
        ],
      );
    });

    test('legacy wrapper builder uses the same ordered action set', () {
      final legacyActions = buildLegacyLongPressActionDescriptors(
        messageType: 'text',
        isFromMe: true,
        canRecall: true,
      );

      expect(
        legacyActions.map((entry) => entry.action).toList(growable: false),
        const <ChatSceneAction>[
          ChatSceneAction.reply,
          ChatSceneAction.forward,
          ChatSceneAction.copy,
          ChatSceneAction.edit,
          ChatSceneAction.favorite,
          ChatSceneAction.select,
          ChatSceneAction.recall,
          ChatSceneAction.react,
        ],
      );
      expect(
        legacyActions.map((entry) => entry.label).toList(growable: false),
        const <String>[
          '\u56de\u590d',
          '\u8f6c\u53d1',
          '\u590d\u5236',
          '\u7f16\u8f91',
          '\u6536\u85cf',
          '\u591a\u9009',
          '\u64a4\u56de',
          '\u8868\u60c5\u56de\u5e94',
        ],
      );
      expect(
        legacyActions.map((entry) => entry.order).toList(growable: false),
        const <int>[0, 1, 2, 3, 4, 5, 7, 8],
      );
    });

    test('self message without recall permission omits recall', () {
      final actions = buildChatMessageActionDescriptors(
        message: _buildInteractiveTextMessage(),
        isSelf: true,
        canRecall: false,
      );

      expect(
        actions.map((entry) => entry.action).toList(growable: false),
        const <ChatSceneAction>[
          ChatSceneAction.reply,
          ChatSceneAction.forward,
          ChatSceneAction.copy,
          ChatSceneAction.edit,
          ChatSceneAction.favorite,
          ChatSceneAction.select,
          ChatSceneAction.react,
        ],
      );
    });

    test('foreign message without recall permission omits recall', () {
      final actions = buildChatMessageActionDescriptors(
        message: _buildInteractiveTextMessage(),
        isSelf: false,
        canRecall: false,
      );

      expect(
        actions.map((entry) => entry.action).toList(growable: false),
        const <ChatSceneAction>[
          ChatSceneAction.reply,
          ChatSceneAction.forward,
          ChatSceneAction.copy,
          ChatSceneAction.favorite,
          ChatSceneAction.select,
          ChatSceneAction.react,
        ],
      );
    });

    test('deleted message is non-interactive', () {
      final actions = buildChatMessageActionDescriptors(
        message: _buildMessage(isDeleted: 1),
        isSelf: true,
        canRecall: true,
      );

      expect(actions, isEmpty);
    });

    test('revoked message is non-interactive', () {
      final actions = buildChatMessageActionDescriptors(
        message: _buildMessage(revoke: 2),
        isSelf: true,
        canRecall: true,
      );

      expect(actions, isEmpty);
    });

    test('system message is non-interactive', () {
      final actions = buildChatMessageActionDescriptors(
        message: _buildMessage(contentType: MessageContentType.systemMsg),
        isSelf: true,
        canRecall: true,
      );

      expect(actions, isEmpty);
    });

    test('legacy system message type is non-interactive', () {
      final actions = buildLegacyLongPressActionDescriptors(
        messageType: 'system',
        isFromMe: true,
        canRecall: true,
      );

      expect(actions, isEmpty);
    });

    test('message without extra still keeps interactive actions', () {
      final actions = buildChatMessageActionDescriptors(
        message: _buildMessage(includeExtra: false),
        isSelf: true,
        canRecall: true,
      );

      expect(
        actions.map((entry) => entry.action).toList(growable: false),
        const <ChatSceneAction>[
          ChatSceneAction.reply,
          ChatSceneAction.forward,
          ChatSceneAction.copy,
          ChatSceneAction.edit,
          ChatSceneAction.favorite,
          ChatSceneAction.select,
          ChatSceneAction.recall,
          ChatSceneAction.react,
        ],
      );
    });

    test('returned action lists are unmodifiable', () {
      final actions = buildChatMessageActionDescriptors(
        message: _buildInteractiveTextMessage(),
        isSelf: true,
        canRecall: true,
      );

      expect(
        () => actions.add(
          const ChatMessageActionDescriptor(
            action: ChatSceneAction.reply,
            label: '\u56de\u590d',
            order: 0,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('unpinned message exposes pin action label', () {
      final labels = buildChatMessageActionDescriptors(
        message: _buildMessage(isPinned: 0),
        isSelf: true,
        canRecall: true,
        canPin: true,
      ).map((entry) => entry.label).toList(growable: false);

      expect(labels, contains('\u7f6e\u9876'));
      expect(labels, isNot(contains('\u53d6\u6d88\u7f6e\u9876')));
    });

    test('pinned message exposes unpin action label', () {
      final labels = buildChatMessageActionDescriptors(
        message: _buildMessage(isPinned: 1),
        isSelf: true,
        canRecall: true,
        canPin: true,
      ).map((entry) => entry.label).toList(growable: false);

      expect(labels, contains('\u53d6\u6d88\u7f6e\u9876'));
      expect(labels, isNot(contains('\u7f6e\u9876')));
    });

    test('message without server identity omits pin actions', () {
      final labels = buildChatMessageActionDescriptors(
        message: _buildMessage(messageSeq: 0),
        isSelf: true,
        canRecall: true,
        canPin: true,
      ).map((entry) => entry.label).toList(growable: false);

      expect(labels, isNot(contains('\u7f6e\u9876')));
      expect(labels, isNot(contains('\u53d6\u6d88\u7f6e\u9876')));
    });

    test('group owner can recall messages from any member role', () {
      expect(
        canRecallChatMessage(
          isSelf: false,
          channelType: ChannelType.group,
          currentUserGroupRole: ChatGroupRole.owner,
          senderGroupRole: ChatGroupRole.normal,
        ),
        isTrue,
      );
      expect(
        canRecallChatMessage(
          isSelf: false,
          channelType: ChannelType.group,
          currentUserGroupRole: ChatGroupRole.owner,
          senderGroupRole: ChatGroupRole.admin,
        ),
        isTrue,
      );
    });

    test('group admin can recall normal member messages only', () {
      expect(
        canRecallChatMessage(
          isSelf: false,
          channelType: ChannelType.group,
          currentUserGroupRole: ChatGroupRole.admin,
          senderGroupRole: ChatGroupRole.normal,
        ),
        isTrue,
      );
      expect(
        canRecallChatMessage(
          isSelf: false,
          channelType: ChannelType.group,
          currentUserGroupRole: ChatGroupRole.admin,
          senderGroupRole: ChatGroupRole.owner,
        ),
        isFalse,
      );
    });

    test('normal member cannot recall foreign messages', () {
      expect(
        canRecallChatMessage(
          isSelf: false,
          channelType: ChannelType.group,
          currentUserGroupRole: ChatGroupRole.normal,
          senderGroupRole: ChatGroupRole.normal,
        ),
        isFalse,
      );
    });

    test('self messages can be recalled outside groups', () {
      expect(
        canRecallChatMessage(
          isSelf: true,
          channelType: ChannelType.personal,
          currentUserGroupRole: ChatGroupRole.normal,
        ),
        isTrue,
      );
    });
  });
}

WKMsg _buildInteractiveTextMessage() {
  return _buildMessage();
}

WKMsg _buildMessage({
  int contentType = WkMessageContentType.text,
  int isDeleted = 0,
  int revoke = 0,
  int isPinned = 0,
  bool includeExtra = true,
  String messageId = 'mid:test',
  int messageSeq = 1,
}) {
  final message = WKMsg()
    ..messageID = messageId
    ..messageSeq = messageSeq
    ..contentType = contentType
    ..isDeleted = isDeleted;
  if (includeExtra) {
    message.wkMsgExtra = WKMsgExtra()
      ..revoke = revoke
      ..isPinned = isPinned;
  }
  return message;
}
