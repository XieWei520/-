import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/chat_session.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_conversation_extra_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_message_mapper.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry_provider.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'fakes/noop_chat_conversation_extra_gateway.dart';

void main() {
  test(
    'message mapper prefers edited content when remote extra refresh arrives',
    () {
      final message = WKMsg()
        ..messageID = 'mid-edited-preview'
        ..clientMsgNO = 'client-edited-preview'
        ..channelID = 'u_edit_preview'
        ..channelType = WKChannelType.personal
        ..fromUID = 'u_self'
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('original')
        ..wkMsgExtra = (WKMsgExtra()
          ..contentEdit = '{"type":1,"content":"edited"}'
          ..messageContent = WKTextContent('edited'));

      final mapped = ChatMessageMapper().map(message, currentUid: 'u_self');

      expect(mapped.previewText, 'edited');
    },
  );

  testWidgets(
    'edit action enters composer edit state and submits message edit',
    (tester) async {
      WKIM.shared.options.uid = 'u_self';
      addTearDown(() {
        WKIM.shared.options.uid = '';
      });

      final gateway = _FakeChatSceneGateway();
      final container = ProviderContainer(
        overrides: [
          chatConversationExtraGatewayProvider.overrideWithValue(
            NoopChatConversationExtraGateway(),
          ),
          realtimeRolloutTelemetryProvider.overrideWith((ref) {
            final telemetry = RealtimeRolloutTelemetry(
              flushInterval: Duration.zero,
            );
            ref.onDispose(telemetry.dispose);
            return telemetry;
          }),
          messageListProvider.overrideWith(
            (ref, session) => _StaticMessageListNotifier(
              session.channelId,
              session.channelType,
              session.channelId == 'u_edit_flow'
                  ? <WKMsg>[_buildEditableMessage()]
                  : const <WKMsg>[],
            ),
          ),
          chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
          chatMarkConversationReadProvider.overrideWithValue(
            (session, messageIds) async {},
          ),
        ],
      );
      addTearDown(container.dispose);
      const session = ChatSession(
        channelId: 'u_edit_flow',
        channelType: WKChannelType.personal,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_edit_flow',
              channelType: WKChannelType.personal,
              channelName: 'Edit Flow',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('chat-action-edit')));
      await tester.pumpAndSettle();

      expect(
        container.read(chatComposerProvider(session)).pendingEditMessageId,
        'mid-edit-flow',
      );
      expect(find.text('original'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, 'edited locally');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('chat-send-button')));
      await tester.pumpAndSettle();

      expect(gateway.sentContents, isEmpty);
      expect(gateway.editCalls, hasLength(1));
      expect(gateway.editCalls.single.message.messageID, 'mid-edit-flow');
      expect(gateway.editCalls.single.content.content, 'edited locally');
      expect(container.read(chatComposerProvider(session)).text, isEmpty);
      expect(
        container.read(chatComposerProvider(session)).pendingEditMessageId,
        isNull,
      );
    },
  );
}

WKMsg _buildEditableMessage() {
  return WKMsg()
    ..messageID = 'mid-edit-flow'
    ..clientMsgNO = 'client-edit-flow'
    ..channelID = 'u_edit_flow'
    ..channelType = WKChannelType.personal
    ..fromUID = 'u_self'
    ..messageSeq = 88
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('original');
}

class _StaticMessageListNotifier extends MessageListNotifier {
  _StaticMessageListNotifier(
    super.channelId,
    super.channelType,
    List<WKMsg> messages,
  ) : _messages = List<WKMsg>.from(messages, growable: false);

  final List<WKMsg> _messages;

  @override
  Future<void> loadMessages() async {
    state = List<WKMsg>.from(_messages, growable: false);
  }

  @override
  Future<void> loadMore() async {}
}

class _EditInvocation {
  const _EditInvocation({required this.message, required this.content});

  final WKMsg message;
  final WKTextContent content;
}

class _FakeChatSceneGateway extends ChatSceneGateway {
  final List<WKMessageContent> sentContents = <WKMessageContent>[];
  final List<_EditInvocation> editCalls = <_EditInvocation>[];

  @override
  Future<void> addFavorite(WKMsg message) async {}

  @override
  Future<void> editMessage(WKMsg message, WKTextContent content) async {
    editCalls.add(_EditInvocation(message: message, content: content));
  }

  @override
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  }) async {
    return const <ForwardTarget>[];
  }

  @override
  Future<void> recallMessage(WKMsg message) async {}

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {}

  @override
  Future<void> togglePinnedMessage(WKMsg message) async {}

  @override
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

  @override
  Future<void> clearPinnedMessages({
    required String channelId,
    required int channelType,
  }) async {}

  @override
  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
    int? expireSeconds,
  }) async {
    sentContents.add(content);
  }

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) async {}

  @override
  List<MessageReaction> prepareReactions(WKMsg message) {
    return const <MessageReaction>[];
  }

  @override
  Stream<ReactionUpdate> watchReactionUpdates() {
    return const Stream<ReactionUpdate>.empty();
  }
}
