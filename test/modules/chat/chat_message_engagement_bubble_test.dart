import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/chat_session.dart';
import 'package:wukong_im_app/modules/chat/chat_message_mapper.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukong_im_app/modules/chat/chat_voice_playback_controller.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_message_engagement_bubble.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukong_im_app/wukong_base/utils/audio_record_manager.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ChatMessageEngagementBubble', () {
    const session = ChatSession(
      channelId: 'c-1',
      channelType: WKChannelType.personal,
    );

    testWidgets('prepared reactions render through the bubble', (tester) async {
      final message = _buildMessage(messageId: 'm-1');
      final gateway = _FakeChatSceneGateway(
        preparedByMessageId: <String, List<MessageReaction>>{
          'm-1': <MessageReaction>[
            const MessageReaction(
              type: 0x1F600,
              emoji: '\u{1F600}',
              count: 2,
              isMe: true,
              userIds: <String>['u_self', 'u_other'],
              usernames: <String>['Self', 'Other'],
            ),
          ],
        },
      );

      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageEngagementBubble(
            session: session,
            model: ChatMessageMapper().map(message, currentUid: 'u_self'),
            gateway: gateway,
          ),
        ),
      );

      expect(find.text('\u{1F600}'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('chip taps forward emoji back out', (tester) async {
      final message = _buildMessage(messageId: 'm-2');
      final gateway = _FakeChatSceneGateway(
        preparedByMessageId: <String, List<MessageReaction>>{
          'm-2': <MessageReaction>[
            const MessageReaction(
              type: 0x1F389,
              emoji: '\u{1F389}',
              count: 1,
              isMe: false,
              userIds: <String>['u_other'],
              usernames: <String>['Other'],
            ),
          ],
        },
      );
      String? tappedEmoji;

      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageEngagementBubble(
            session: session,
            model: ChatMessageMapper().map(message, currentUid: 'u_self'),
            gateway: gateway,
            onReactionTap: (emoji) => tappedEmoji = emoji,
          ),
        ),
      );

      await tester.tap(find.text('\u{1F389}'));
      await tester.pump();

      expect(tappedEmoji, '\u{1F389}');
    });

    testWidgets('voice messages bridge into the custom voice bubble', (
      tester,
    ) async {
      final message = _buildVoiceMessage(messageId: 'm-voice-bridge');
      final model = ChatMessageMapper().map(message, currentUid: 'u_self');
      final expectedVoiceKey = message.clientMsgNO.trim().isNotEmpty
          ? 'cid:${message.clientMsgNO.trim()}'
          : message.messageID.trim().isNotEmpty
          ? 'mid:${message.messageID.trim()}'
          : model.identity;
      final gateway = _FakeChatSceneGateway(
        preparedByMessageId: const <String, List<MessageReaction>>{},
      );
      final playManager = AudioPlayManager.test(
        playbackRuntime: _IdleAudioPlaybackRuntime(),
      );
      final controller = ChatVoicePlaybackController(playManager: playManager);
      addTearDown(controller.dispose);
      addTearDown(playManager.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatVoicePlaybackControllerProvider.overrideWith(
              (ref, providedSession) => controller,
            ),
          ],
          child: _buildHarness(
            child: ChatMessageEngagementBubble(
              session: session,
              model: model,
              gateway: gateway,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(
          ValueKey<String>('chat-voice-bubble-$expectedVoiceKey'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'does not render inline add reaction button even when callback exists',
      (tester) async {
      final message = _buildMessage(messageId: 'm-3');
      final gateway = _FakeChatSceneGateway(
        preparedByMessageId: const <String, List<MessageReaction>>{},
      );

      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageEngagementBubble(
            session: session,
            model: ChatMessageMapper().map(message, currentUid: 'u_self'),
            gateway: gateway,
            onAddReaction: () {},
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('message-reaction-add')),
        findsNothing,
      );
    });

    testWidgets(
      'only matching reaction stream updates affect the target message',
      (tester) async {
        final firstMessage = _buildMessage(messageId: 'm-stream-a');
        final secondMessage = _buildMessage(messageId: 'm-stream-b');
        final gateway = _FakeChatSceneGateway(
          preparedByMessageId: <String, List<MessageReaction>>{
            'm-stream-a': const <MessageReaction>[
              MessageReaction(
                type: 0x1F600,
                emoji: '\u{1F600}',
                count: 1,
                isMe: true,
                userIds: <String>['u_self'],
                usernames: <String>['Self'],
              ),
            ],
            'm-stream-b': const <MessageReaction>[
              MessageReaction(
                type: 0x1F60E,
                emoji: '\u{1F60E}',
                count: 1,
                isMe: false,
                userIds: <String>['u_other'],
                usernames: <String>['Other'],
              ),
            ],
          },
        );

        await tester.pumpWidget(
          _buildHarness(
            child: Column(
              children: <Widget>[
                ChatMessageEngagementBubble(
                  session: session,
                  model: ChatMessageMapper().map(
                    firstMessage,
                    currentUid: 'u_self',
                  ),
                  gateway: gateway,
                ),
                ChatMessageEngagementBubble(
                  session: session,
                  model: ChatMessageMapper().map(
                    secondMessage,
                    currentUid: 'u_self',
                  ),
                  gateway: gateway,
                ),
              ],
            ),
          ),
        );

        gateway.emit(
          const ReactionUpdate(
            messageId: 'm-stream-b',
            reactions: <MessageReaction>[
              MessageReaction(
                type: 0x1F525,
                emoji: '\u{1F525}',
                count: 2,
                isMe: true,
                userIds: <String>['u_self', 'u_other'],
                usernames: <String>['Self', 'Other'],
              ),
            ],
          ),
        );
        await tester.pump();

        expect(find.text('\u{1F600}'), findsOneWidget);
        expect(find.text('\u{1F60E}'), findsNothing);
        expect(find.text('\u{1F525}'), findsOneWidget);
      },
    );

    testWidgets('same message id model refresh reseeds prepared reactions', (
      tester,
    ) async {
      final gateway = _FakeChatSceneGateway(
        preparedByMessageId: const <String, List<MessageReaction>>{},
        prepareReactionsBuilder: (message) {
          final raw = message.reactionList ?? const <WKMsgReaction>[];
          if (raw.isEmpty) {
            return const <MessageReaction>[];
          }
          final emoji = raw.first.emoji;
          return <MessageReaction>[
            MessageReaction(
              type: emoji.runes.isEmpty ? 0 : emoji.runes.first,
              emoji: emoji,
              count: 1,
              isMe: false,
              userIds: const <String>['u_other'],
              usernames: const <String>['Other'],
            ),
          ];
        },
      );
      final oldMessage = _buildMessage(messageId: 'm-refresh')
        ..reactionList = <WKMsgReaction>[_rawReaction(emoji: '\u{1F44D}')];
      final refreshedMessage = _buildMessage(messageId: 'm-refresh')
        ..reactionList = <WKMsgReaction>[_rawReaction(emoji: '\u{1F44E}')];
      final mapper = ChatMessageMapper();

      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageEngagementBubble(
            session: session,
            model: mapper.map(oldMessage, currentUid: 'u_self'),
            gateway: gateway,
          ),
        ),
      );
      expect(find.text('\u{1F44D}'), findsOneWidget);
      expect(find.text('\u{1F44E}'), findsNothing);

      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageEngagementBubble(
            session: session,
            model: mapper.map(refreshedMessage, currentUid: 'u_self'),
            gateway: gateway,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('\u{1F44D}'), findsNothing);
      expect(find.text('\u{1F44E}'), findsOneWidget);
    });
  });
}

Widget _buildHarness({required Widget child}) {
  return MaterialApp(home: Scaffold(body: child));
}

WKMsg _buildMessage({required String messageId}) {
  return WKMsg()
    ..messageID = messageId
    ..fromUID = 'u_other'
    ..channelID = 'c-1'
    ..channelType = WKChannelType.personal
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('hello');
}

WKMsg _buildVoiceMessage({required String messageId}) {
  return WKMsg()
    ..messageID = messageId
    ..fromUID = 'u_other'
    ..channelID = 'c-1'
    ..channelType = WKChannelType.personal
    ..contentType = WkMessageContentType.voice
    ..messageContent = (WKVoiceContent(6)..localPath = '/tmp/$messageId.m4a');
}

WKMsgReaction _rawReaction({required String emoji}) {
  return WKMsgReaction()
    ..uid = 'u_other'
    ..name = 'Other'
    ..emoji = emoji
    ..isDeleted = 0
    ..seq = 1;
}

class _FakeChatSceneGateway extends ChatSceneGateway {
  _FakeChatSceneGateway({
    required Map<String, List<MessageReaction>> preparedByMessageId,
    this.prepareReactionsBuilder,
  }) : _preparedByMessageId = preparedByMessageId;

  final Map<String, List<MessageReaction>> _preparedByMessageId;
  final List<MessageReaction> Function(WKMsg message)? prepareReactionsBuilder;
  final StreamController<ReactionUpdate> _updatesController =
      StreamController<ReactionUpdate>.broadcast();

  void emit(ReactionUpdate update) {
    _updatesController.add(update);
  }

  @override
  List<MessageReaction> prepareReactions(WKMsg message) {
    final built = prepareReactionsBuilder?.call(message);
    if (built != null) {
      return List<MessageReaction>.from(built);
    }
    return List<MessageReaction>.from(
      _preparedByMessageId[message.messageID] ?? const <MessageReaction>[],
    );
  }

  @override
  Stream<ReactionUpdate> watchReactionUpdates() {
    return _updatesController.stream;
  }

  @override
  Future<void> addFavorite(WKMsg message) async {}

  @override
  Future<void> editMessage(WKMsg message, WKTextContent content) async {}

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
  Future<void> sendMessageContent(
    content, {
    required String channelId,
    required int channelType,
    String? channelName,
  }) async {}

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) async {}
}

class _IdleAudioPlaybackRuntime implements AudioPlaybackRuntime {
  @override
  Future<void> dispose() async {}

  @override
  Future<Duration> durationValue() async => const Duration(seconds: 6);

  @override
  Future<bool> isPlaying() async => false;

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<Duration> position() async => Duration.zero;

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSource(AudioPlaybackSource source) async {}

  @override
  Future<void> stop() async {}
}
