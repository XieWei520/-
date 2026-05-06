import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/cache/media_cache_manager.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/data/models/link_preview.dart';
import 'package:wukong_im_app/data/models/wk_custom_content.dart'
    show WKLocationContent;
import 'package:wukong_im_app/data/models/wk_robot_card_content.dart';
import 'package:wukong_im_app/modules/chat/chat_message_mapper.dart';
import 'package:wukong_im_app/modules/chat/link_preview_service.dart';
import 'package:wukong_im_app/widgets/message_bubble.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';
import 'package:wukong_im_app/widgets/wk_emoji_text.dart';
import 'package:wukong_im_app/widgets/wk_reference_assets.dart';
import 'package:wukong_im_app/widgets/wk_web_ui_tokens.dart';
import 'package:wukong_im_app/wukong_base/emoji/android_emoji_catalog.dart';
import 'package:wukong_im_app/wukong_base/msg/msg_content_type.dart';
import 'package:wukong_im_app/wukong_base/msg/widget/wk_message_reaction.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_card_content.dart';
import 'package:wukongimfluttersdk/model/wk_gif_content.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_sticker_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/model/wk_unknown_content.dart';
import 'package:wukongimfluttersdk/model/wk_video_content.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

Finder _statusAssetFinder(String assetName) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == assetName,
  );
}

void main() {
  group('message bubble presentation', () {
    setUp(() {
      WKAvatar.setBytesLoaderForTesting((url) async => null);
    });

    tearDown(() {
      WKAvatar.setBytesLoaderForTesting(null);
    });

    test('resolveMessageParticipantInfo prefers group member data', () {
      final message = WKMsg()
        ..fromUID = 'u_alice'
        ..channelType = WKChannelType.group;
      final member = WKChannelMember()
        ..memberUID = 'u_alice'
        ..remark = 'Alias Alice'
        ..memberName = 'Alice'
        ..memberAvatar = 'users/alice/avatar';
      message.setMemberOfFrom(member);
      message.setFrom(
        WKChannel('u_alice', WKChannelType.personal)..channelName = 'Alice',
      );

      final info = resolveMessageParticipantInfo(message);

      expect(info.displayName, 'Alias Alice');
      expect(info.avatarUrl, ApiConfig.resolveMediaUrl('users/alice/avatar'));
    });

    test(
      'resolveMessageParticipantInfo uses fallback group member when message omits member payload',
      () {
        final message = WKMsg()
          ..fromUID = 'u_test3'
          ..channelType = WKChannelType.group;
        final fallbackMember = WKChannelMember()
          ..memberUID = 'u_test3'
          ..memberName = 'test3'
          ..memberAvatar = 'users/test3/avatar';

        final info = resolveMessageParticipantInfo(
          message,
          fallbackGroupMember: fallbackMember,
        );

        expect(info.displayName, 'test3');
        expect(info.avatarUrl, ApiConfig.resolveMediaUrl('users/test3/avatar'));
      },
    );

    test(
      'resolveMessageParticipantInfo prefers current group member data over stale message member data',
      () {
        final message = WKMsg()
          ..fromUID = 'u_test3'
          ..channelType = WKChannelType.group;
        message.setMemberOfFrom(
          WKChannelMember()
            ..memberUID = 'u_test3'
            ..memberName = 'Old Name'
            ..memberAvatar = 'users/test3/old-avatar',
        );
        final fallbackMember = WKChannelMember()
          ..memberUID = 'u_test3'
          ..memberName = 'Current Name'
          ..memberAvatar = 'users/test3/current-avatar';

        final info = resolveMessageParticipantInfo(
          message,
          fallbackGroupMember: fallbackMember,
        );

        expect(info.displayName, 'Current Name');
        expect(
          info.avatarUrl,
          ApiConfig.resolveMediaUrl('users/test3/current-avatar'),
        );
      },
    );

    test(
      'resolveMessageParticipantInfo uses current peer channel for incoming personal messages',
      () {
        final message = WKMsg()
          ..fromUID = 'u_peer'
          ..channelID = 'u_peer'
          ..channelType = WKChannelType.personal;
        final peerChannel = WKChannel('u_peer', WKChannelType.personal)
          ..channelName = 'Peer Name'
          ..avatar = 'users/u_peer/current-avatar';

        final info = resolveMessageParticipantInfo(
          message,
          fallbackSenderChannel: peerChannel,
        );

        expect(info.displayName, 'Peer Name');
        expect(
          info.avatarUrl,
          ApiConfig.resolveMediaUrl('users/u_peer/current-avatar'),
        );
      },
    );

    test(
      'resolveMessageParticipantInfo prefers robot identity for group robot payloads',
      () {
        final message = WKMsg()
          ..fromUID = 'u_bot_sender'
          ..channelType = WKChannelType.group
          ..contentType = WkMessageContentType.unknown
          ..content =
              '{"type":1,"content":"bot text","robot":{"provider":"feishu","display_name":"Weather Robot","display_avatar":"robots/weather/avatar.png"}}';
        final fallbackMember = WKChannelMember()
          ..memberUID = 'u_bot_sender'
          ..memberName = 'Fallback Member'
          ..memberAvatar = 'users/fallback/avatar';
        message.setMemberOfFrom(fallbackMember);
        message.setFrom(
          WKChannel('u_bot_sender', WKChannelType.personal)
            ..channelName = 'Fallback User'
            ..avatar = 'users/fallback/avatar',
        );

        final info = resolveMessageParticipantInfo(message);

        expect(info.displayName, 'Weather Robot');
        expect(
          info.avatarUrl,
          ApiConfig.resolveMediaUrl('robots/weather/avatar.png'),
        );
      },
    );

    test(
      'resolveMessageParticipantInfo does not use the peer channel avatar for outgoing personal messages',
      () {
        final message = WKMsg()
          ..fromUID = 'u_me'
          ..channelID = 'u_peer'
          ..channelType = WKChannelType.personal;
        message.setChannelInfo(
          WKChannel('u_peer', WKChannelType.personal)
            ..channelName = 'Peer'
            ..avatar = 'users/peer/avatar',
        );

        final info = resolveMessageParticipantInfo(message);

        expect(info.displayName, 'u_me');
        expect(info.avatarUrl, ApiConfig.resolveMediaUrl('users/u_me/avatar'));
      },
    );

    test(
      'resolveMessageParticipantInfo uses current user profile for outgoing messages',
      () {
        final message = WKMsg()
          ..fromUID = 'u_me'
          ..channelID = 'g_team'
          ..channelType = WKChannelType.group;
        final fallbackMember = WKChannelMember()
          ..memberUID = 'u_me'
          ..memberName = 'Group Nickname'
          ..memberAvatar = 'users/stale/avatar';

        final info = resolveMessageParticipantInfo(
          message,
          fallbackGroupMember: fallbackMember,
          currentUid: 'u_me',
          currentUserDisplayName: 'Current Me',
          currentUserAvatarUrl: 'users/current/avatar',
        );

        expect(info.displayName, 'Current Me');
        expect(
          info.avatarUrl,
          ApiConfig.resolveMediaUrl('users/current/avatar'),
        );
      },
    );

    test(
      'resolveMessageParticipantInfo does not reuse the group avatar as a member avatar',
      () {
        final message = WKMsg()
          ..fromUID = 'u_alice'
          ..channelID = 'g_team'
          ..channelType = WKChannelType.group;
        message.setChannelInfo(
          WKChannel('g_team', WKChannelType.group)
            ..channelName = 'Team'
            ..avatar = 'groups/g_team/avatar',
        );

        final info = resolveMessageParticipantInfo(message);

        expect(info.displayName, 'u_alice');
        expect(
          info.avatarUrl,
          ApiConfig.resolveMediaUrl('users/u_alice/avatar'),
        );
      },
    );

    test(
      'resolveMessageStatusInfo maps outgoing send status to visual states',
      () {
        final sendingMessage = WKMsg()
          ..fromUID = 'u_self'
          ..status = WKSendMsgResult.sendLoading
          ..channelType = WKChannelType.personal;
        final sentMessage = WKMsg()
          ..fromUID = 'u_self'
          ..status = WKSendMsgResult.sendSuccess
          ..channelType = WKChannelType.personal;
        final deliveredMessage = WKMsg()
          ..fromUID = 'u_self'
          ..status = WKSendMsgResult.sendSuccess
          ..channelType = WKChannelType.personal
          ..wkMsgExtra = WKMsgExtra();
        final readMessage = WKMsg()
          ..fromUID = 'u_self'
          ..status = WKSendMsgResult.sendSuccess
          ..channelType = WKChannelType.personal
          ..wkMsgExtra = (WKMsgExtra()..readed = 1);
        final failedMessage = WKMsg()
          ..fromUID = 'u_self'
          ..status = WKSendMsgResult.sendFail
          ..channelType = WKChannelType.personal;
        final unknownMessage = WKMsg()
          ..fromUID = 'u_self'
          ..status = 999
          ..channelType = WKChannelType.personal;
        final incomingMessage = WKMsg()
          ..fromUID = 'u_other'
          ..status = WKSendMsgResult.sendSuccess
          ..channelType = WKChannelType.personal;

        expect(
          resolveMessageStatusInfo(sendingMessage, isSelf: true)?.visualState,
          ChatSendVisualState.sending,
        );
        expect(
          resolveMessageStatusInfo(sentMessage, isSelf: true)?.visualState,
          ChatSendVisualState.sent,
        );
        expect(
          resolveMessageStatusInfo(deliveredMessage, isSelf: true)?.visualState,
          ChatSendVisualState.delivered,
        );
        expect(
          resolveMessageStatusInfo(readMessage, isSelf: true)?.visualState,
          ChatSendVisualState.read,
        );
        expect(
          resolveMessageStatusInfo(failedMessage, isSelf: true)?.visualState,
          ChatSendVisualState.failed,
        );
        expect(
          resolveMessageStatusInfo(unknownMessage, isSelf: true)?.visualState,
          ChatSendVisualState.sent,
        );
        expect(
          resolveMessageStatusInfo(incomingMessage, isSelf: false),
          isNull,
        );
      },
    );

    test(
      'resolveMessageStatusInfo treats server-acknowledged loading as sent',
      () {
        final syncedLoadingMessage = WKMsg()
          ..fromUID = 'u_self'
          ..status = WKSendMsgResult.sendLoading
          ..channelType = WKChannelType.personal
          ..messageID = 'server-msg-1';

        final status = resolveMessageStatusInfo(
          syncedLoadingMessage,
          isSelf: true,
        );

        expect(status?.visualState, ChatSendVisualState.sent);
        expect(status?.isLoading, isFalse);
      },
    );

    test('resolveMessageStatusInfo returns personal read state', () {
      final readMessage = WKMsg()
        ..status = WKSendMsgResult.sendSuccess
        ..channelType = WKChannelType.personal
        ..wkMsgExtra = (WKMsgExtra()..readedCount = 1);

      final unreadMessage = WKMsg()
        ..status = WKSendMsgResult.sendSuccess
        ..channelType = WKChannelType.personal
        ..wkMsgExtra = WKMsgExtra();

      final readLabel = resolveMessageStatusInfo(
        readMessage,
        isSelf: true,
      )?.label;
      final unreadLabel = resolveMessageStatusInfo(
        unreadMessage,
        isSelf: true,
      )?.label;

      expect(readLabel, isNotEmpty);
      expect(unreadLabel, isNotEmpty);
      expect(readLabel, isNot(equals(unreadLabel)));
    });

    test('resolveMessageStatusInfo returns group receipt summary', () {
      final message = WKMsg()
        ..fromUID = 'u_self'
        ..messageID = ''
        ..clientMsgNO = ''
        ..status = WKSendMsgResult.sendSuccess
        ..channelType = WKChannelType.group
        ..wkMsgExtra = (WKMsgExtra()
          ..readedCount = 3
          ..unreadCount = 1);

      final mapper = ChatMessageMapper();
      final model = mapper.map(message, currentUid: 'u_self');
      final label = resolveMessageStatusInfo(
        model.message,
        isSelf: model.self,
      )?.label;

      expect(model.identity, startsWith('seq:'));
      expect(model.self, isTrue);
      expect(label, allOf(contains('3'), contains('1')));
    });

    testWidgets('send status badge renders sent as a single neutral check', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('sent only')
        ..status = WKSendMsgResult.sendSuccess;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );

      expect(_statusAssetFinder(WKReferenceAssets.sendSingle), findsOneWidget);
      expect(_statusAssetFinder(WKReferenceAssets.sendDouble), findsNothing);
      final image = tester.widget<Image>(
        _statusAssetFinder(WKReferenceAssets.sendSingle),
      );
      expect(image.color, const Color(0xFF677487));
    });

    testWidgets(
      'send status badge renders delivered as double neutral checks',
      (tester) async {
        final message = WKMsg()
          ..fromUID = 'u_me'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('delivered')
          ..status = WKSendMsgResult.sendSuccess
          ..wkMsgExtra = WKMsgExtra();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              ),
            ),
          ),
        );

        expect(
          _statusAssetFinder(WKReferenceAssets.sendDouble),
          findsOneWidget,
        );
        final image = tester.widget<Image>(
          _statusAssetFinder(WKReferenceAssets.sendDouble),
        );
        expect(image.color, const Color(0xFF677487));
      },
    );

    testWidgets('send status badge renders read as double blue checks', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('read')
        ..status = WKSendMsgResult.sendSuccess
        ..wkMsgExtra = (WKMsgExtra()..readedCount = 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );

      expect(_statusAssetFinder(WKReferenceAssets.sendDouble), findsOneWidget);
      final image = tester.widget<Image>(
        _statusAssetFinder(WKReferenceAssets.sendDouble),
      );
      expect(image.color, const Color(0xFF2196F3));
    });

    testWidgets('send status badge keeps failed retry affordance red', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('failed')
        ..status = WKSendMsgResult.sendFail;
      var retryCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              onRetrySend: () => retryCount += 1,
            ),
          ),
        ),
      );

      expect(_statusAssetFinder(WKReferenceAssets.sendFail), findsOneWidget);
      final image = tester.widget<Image>(
        _statusAssetFinder(WKReferenceAssets.sendFail),
      );
      expect(image.color, const Color(0xFFD64545));

      await tester.tap(
        find.byKey(const ValueKey<String>('message-retry-send-button')),
      );
      expect(retryCount, 1);
    });

    testWidgets('failed outgoing status exposes a retry tap target', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('retry me')
        ..status = WKSendMsgResult.sendFail;
      var retryCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              onRetrySend: () {
                retryCount += 1;
              },
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('message-retry-send-button')),
      );

      expect(retryCount, 1);
    });

    testWidgets('failed outgoing status plays a short shake affordance', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('retry me')
        ..status = WKSendMsgResult.sendFail;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              onRetrySend: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 48));

      final shake = tester.widget<Transform>(
        find.byKey(const ValueKey<String>('message-send-failure-shake')),
      );
      expect(shake.transform.getTranslation().x.abs(), greaterThan(0));
    });

    testWidgets('pending outgoing status shows a subtle pulse affordance', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('sending')
        ..status = WKSendMsgResult.sendLoading;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));

      final pulse = tester.widget<Opacity>(
        find.byKey(const ValueKey<String>('message-send-pending-pulse')),
      );
      expect(pulse.opacity, lessThan(1));
      expect(pulse.opacity, greaterThan(0.65));
    });

    test('reaction picker exposes real emoji instead of placeholders', () {
      expect(
        WKReactionPicker.commonEmojis.every((emoji) => !emoji.contains('?')),
        isTrue,
      );
      expect(WKReactionPicker.commonEmojis, contains('\u{1F44D}'));
      expect(WKReactionPicker.commonEmojis, contains('\u{1F389}'));
    });

    testWidgets(
      'reaction row keeps stable chips without rendering inline add button',
      (tester) async {
        String? tappedEmoji;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  WKMessageReactions(
                    reactions: [
                      WKMessageReaction(
                        emoji: '\u{1F44D}',
                        count: 2,
                        isMe: true,
                        usernames: const <String>['Self', 'Other'],
                      ),
                    ],
                    onReactionTap: (emoji) => tappedEmoji = emoji,
                  ),
                  WKReactionPicker(
                    selectedEmoji: '\u{1F44D}',
                    onEmojiSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('message-reaction-chip-\u{1F44D}')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('reaction-picker-\u{1F44D}')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('message-reaction-chip-\u{1F44D}')),
        );
        await tester.pump();
        expect(tappedEmoji, '\u{1F44D}');
        expect(
          find.byKey(const ValueKey<String>('message-reaction-add')),
          findsNothing,
        );

        final selectedCell = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(
                  const ValueKey<String>('reaction-picker-\u{1F44D}'),
                ),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = selectedCell.decoration as BoxDecoration;
        expect(decoration.border, isNotNull);
      },
    );

    testWidgets(
      'reaction picker normalizes selected emoji variants for highlight',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WKReactionPicker(
                selectedEmoji: '\u2764',
                onEmojiSelected: (_) {},
              ),
            ),
          ),
        );

        final selectedCell = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(
                  const ValueKey<String>('reaction-picker-\u2764\uFE0F'),
                ),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = selectedCell.decoration as BoxDecoration;
        expect(decoration.border, isNotNull);
      },
    );

    testWidgets(
      'sticker bubble renders bundled local asset when animation key exists',
      (tester) async {
        final message = WKMsg()
          ..fromUID = 'u_me'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.sticker
          ..messageContent = WKStickerContent(
            packId: 'android_sample_motion',
            stickerId: 'typing',
            previewKey: 'assets/stickers/sample_pack/typing.webp',
            animationKey: 'assets/stickers/sample_pack/typing.webp',
            fallbackText: '[贴纸]',
          )
          ..status = WKSendMsgResult.sendSuccess;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('message-sticker-body')),
          findsOneWidget,
        );
        final stickerImage = tester.widget<Image>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('message-sticker-body')),
            matching: find.byType(Image),
          ),
        );
        expect(stickerImage.image, isA<ResizeImage>());
        final resizedImage = stickerImage.image as ResizeImage;
        expect(resizedImage.imageProvider, isA<AssetImage>());
        expect(
          (resizedImage.imageProvider as AssetImage).assetName,
          'assets/stickers/sample_pack/typing.webp',
        );
      },
    );

    testWidgets('sticker bubble prefers preview asset before full animation', (
      tester,
    ) async {
      const previewKey =
          'assets/stickers/sample_pack/previews/typing-preview.webp';
      const animationKey = 'assets/stickers/sample_pack/typing.webp';
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.sticker
        ..messageContent = WKStickerContent(
          packId: 'android_sample_motion',
          stickerId: 'typing',
          previewKey: previewKey,
          animationKey: animationKey,
          fallbackText: '[贴纸]',
        )
        ..status = WKSendMsgResult.sendSuccess;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );

      final stickerImage = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('message-sticker-body')),
          matching: find.byType(Image),
        ),
      );

      expect(stickerImage.image, isA<ResizeImage>());
      final resizedImage = stickerImage.image as ResizeImage;
      expect(resizedImage.imageProvider, isA<AssetImage>());
      expect((resizedImage.imageProvider as AssetImage).assetName, previewKey);
      expect(resizedImage.width, (160 * tester.view.devicePixelRatio).round());
      expect(resizedImage.height, (160 * tester.view.devicePixelRatio).round());
    });

    testWidgets(
      'sticker bubble falls back to placeholder card when assets are missing',
      (tester) async {
        final message = WKMsg()
          ..fromUID = 'u_other'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.sticker
          ..messageContent = WKStickerContent(
            packId: 'missing_pack',
            stickerId: 'missing_sticker',
            previewKey: 'assets/stickers/sample_pack/not-found.webp',
            animationKey: 'assets/stickers/sample_pack/not-found.webp',
            fallbackText: '[贴纸]',
          )
          ..status = WKSendMsgResult.sendSuccess;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('message-sticker-placeholder')),
          findsOneWidget,
        );
        expect(find.text('[贴纸]'), findsOneWidget);
      },
    );

    testWidgets(
      'sticker bubble renders remote sticker url when asset keys are absent',
      (tester) async {
        final message = WKMsg()
          ..fromUID = 'u_other'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.sticker
          ..messageContent = WKStickerContent(
            packId: 'remote_pack',
            stickerId: 'remote_sticker',
            fallbackText: '[\u8d34\u7eb8]',
            url: 'https://cdn.example.com/stickers/remote.webp',
          )
          ..status = WKSendMsgResult.sendSuccess;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('message-sticker-body')),
          findsOneWidget,
        );
        final cachedSticker = tester.widget<CachedMediaImage>(
          find.byType(CachedMediaImage),
        );
        final expectedDecodeSize = (160 * tester.view.devicePixelRatio).round();
        expect(
          cachedSticker.imageUrl,
          'https://cdn.example.com/stickers/remote.webp',
        );
        expect(cachedSticker.cacheKey, cachedSticker.imageUrl);
        expect(cachedSticker.fit, BoxFit.contain);
        expect(cachedSticker.maxWidth, expectedDecodeSize);
        expect(cachedSticker.maxHeight, expectedDecodeSize);
        expect(
          find.byKey(const ValueKey<String>('message-sticker-placeholder')),
          findsNothing,
        );
      },
    );

    testWidgets('text bubble shows delivery state and selection support', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('hello codex')
        ..status = WKSendMsgResult.sendSuccess
        ..wkMsgExtra = (WKMsgExtra()..readedCount = 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );

      expect(find.text('hello codex'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('message-status-badge')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('message-bubble-body')),
          matching: find.byKey(const ValueKey<String>('message-status-badge')),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  WKReferenceAssets.sendDouble,
        ),
        findsOneWidget,
      );

      final bubble = tester.widget<Container>(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      final decoration = bubble.decoration as BoxDecoration;
      expect(decoration.gradient, isNotNull);
    });

    testWidgets(
      'text bubble with android emoji tag renders inline emoji asset and keeps status badge',
      (tester) async {
        final entry = androidEmojiCatalog.lookupById('0_0')!;
        final message = WKMsg()
          ..fromUID = 'u_me'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('hello ${entry.tag} codex')
          ..status = WKSendMsgResult.sendSuccess
          ..wkMsgExtra = (WKMsgExtra()..readedCount = 1);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              ),
            ),
          ),
        );

        expect(find.byType(WKEmojiText), findsOneWidget);
        expect(find.byType(SelectionArea), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName == entry.assetPath,
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('message-status-badge')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'text bubble with android emoji tag and url shows inline emoji handling and link preview',
      (tester) async {
        final entry = androidEmojiCatalog.lookupById('0_0')!;
        final message = WKMsg()
          ..fromUID = 'u_me'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent(
            'check ${entry.tag} https://example.com/emoji-preview',
          )
          ..status = WKSendMsgResult.sendSuccess
          ..wkMsgExtra = (WKMsgExtra()..readedCount = 1);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(WKEmojiText), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName == entry.assetPath,
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.link_rounded), findsOneWidget);
        expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);

        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('reply preview renders catalog emoji as inline image asset', (
      tester,
    ) async {
      final entry = androidEmojiCatalog.lookupById('0_0')!;
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = (WKTextContent('replying body')
          ..reply = (WKReply()
            ..fromName = 'Alice'
            ..payload = WKTextContent('quoted ${entry.tag}')))
        ..status = WKSendMsgResult.sendSuccess;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );

      expect(find.byType(WKEmojiText), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == entry.assetPath,
        ),
        findsOneWidget,
      );
    });

    testWidgets('link preview updates when bubble url changes', (tester) async {
      final firstMessage = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('https://example.com/preview-first')
        ..status = WKSendMsgResult.sendSuccess;
      final secondMessage = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('https://example.com/preview-second')
        ..status = WKSendMsgResult.sendSuccess;

      var current = firstMessage;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: MessageBubble(
                  model: ChatMessageMapper().map(current, currentUid: 'u_me'),
                  onTap: () {},
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      current = secondMessage;
                    });
                  },
                ),
              );
            },
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 5));
      expect(find.textContaining('example.com/preview-first'), findsWidgets);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));

      expect(find.textContaining('example.com/preview-second'), findsWidgets);
      expect(find.textContaining('example.com/preview-first'), findsNothing);
    });

    testWidgets('link preview image uses the shared media cache pipeline', (
      tester,
    ) async {
      const url = 'https://example.com/preview-with-image';
      const imageUrl = 'https://cdn.example.com/preview/card.jpg';
      LinkPreviewService.instance.setPreviewForTesting(
        url,
        const LinkPreview(
          url: url,
          host: 'example.com',
          displayUrl: 'example.com/preview-with-image',
          title: 'Preview with image',
          description: 'Cached preview image',
          imageUrl: imageUrl,
        ),
      );
      addTearDown(LinkPreviewService.instance.clearCacheForTesting);
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent(url)
        ..status = WKSendMsgResult.sendSuccess;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );
      await tester.pump();

      final cachedImage = tester.widget<CachedMediaImage>(
        find.byType(CachedMediaImage),
      );
      expect(cachedImage.imageUrl, imageUrl);
      expect(cachedImage.cacheKey, imageUrl);
      expect(cachedImage.height, 132);
      expect(find.text('Preview with image'), findsOneWidget);
    });

    testWidgets('incoming text bubble uses a bordered card surface', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_other'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('incoming hello')
        ..status = WKSendMsgResult.sendSuccess;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );

      final bubble = tester.widget<Container>(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      final decoration = bubble.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, isNotEmpty);
    });

    testWidgets('pinned text bubble shows compact pinned marker', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('hello pinned')
        ..status = WKSendMsgResult.sendSuccess
        ..wkMsgExtra = (WKMsgExtra()..isPinned = 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('message-pinned-indicator')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('message-bubble-body')),
          matching: find.byKey(
            const ValueKey<String>('message-pinned-indicator'),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('revoked self message renders revoke notice instead of body', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('revoke-002')
        ..status = WKSendMsgResult.sendSuccess
        ..wkMsgExtra = (WKMsgExtra()
          ..revoke = 1
          ..revoker = 'u_me');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );

      expect(find.text('你撤回了一条消息'), findsOneWidget);
      expect(find.text('revoke-002'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('message-bubble-body')),
        findsNothing,
      );
    });

    testWidgets('sensitive word bubble prefers Android synced tip text', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = MsgContentType.sensitiveWord
        ..content = '{"type":-10,"content":"该消息包含敏感词，仅自己可见"}';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );

      expect(find.text('该消息包含敏感词，仅自己可见'), findsOneWidget);
    });

    testWidgets('voice branch prefers injected voice builder', (tester) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.voice
        ..messageContent = WKVoiceContent(7)
        ..status = WKSendMsgResult.sendSuccess;
      var builderCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              voiceContentBuilder: (context, model, isSelf) {
                builderCalls += 1;
                return const Text('custom voice bubble');
              },
            ),
          ),
        ),
      );

      expect(find.text('custom voice bubble'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
      expect(builderCalls, 1);
    });

    testWidgets('non-voice content ignores injected voice builder', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('still text')
        ..status = WKSendMsgResult.sendSuccess;
      var builderCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              voiceContentBuilder: (context, model, isSelf) {
                builderCalls += 1;
                return const Text('should not render');
              },
            ),
          ),
        ),
      );

      expect(find.text('still text'), findsOneWidget);
      expect(find.text('should not render'), findsNothing);
      expect(builderCalls, 0);
    });

    testWidgets(
      'image bubble falls back to local file path when url is empty',
      (tester) async {
        final content = WKImageContent(918, 352)
          ..localPath = r'C:\Users\COLORFUL\Pictures\Screenshots\sample.png';
        final message = WKMsg()
          ..fromUID = 'u_me'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.image
          ..messageContent = content
          ..status = WKSendMsgResult.sendSuccess;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_me'),
                participant: const MessageParticipantInfo(
                  displayName: 'Me',
                  avatarUrl: null,
                ),
              ),
            ),
          ),
        );

        final imageWidget = tester.widget<Image>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is ResizeImage &&
                (widget.image as ResizeImage).imageProvider is FileImage,
          ),
        );

        expect(
          ((imageWidget.image as ResizeImage).imageProvider as FileImage)
              .file
              .path,
          content.localPath,
        );
        expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      },
    );

    testWidgets(
      'rich media bubbles shrink rendered media to narrow Android lane',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 720);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Widget host(WKMsg message) {
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: MessageBubble(
                  model: ChatMessageMapper().map(message, currentUid: 'u_me'),
                  participant: const MessageParticipantInfo(
                    displayName: 'Me',
                    avatarUrl: null,
                  ),
                ),
              ),
            ),
          );
        }

        final imageMessage = WKMsg()
          ..fromUID = 'u_me'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.image
          ..messageContent = (WKImageContent(918, 352)
            ..url = '/uploads/narrow-panel.png')
          ..status = WKSendMsgResult.sendSuccess;

        await tester.pumpWidget(host(imageMessage));

        var bubbleWidth = tester
            .getSize(find.byKey(const ValueKey<String>('message-bubble-body')))
            .width;
        var cachedMedia = tester.widget<CachedMediaImage>(
          find.byType(CachedMediaImage),
        );
        expect(cachedMedia.width, lessThan(200));
        expect(cachedMedia.width, lessThanOrEqualTo(bubbleWidth - 20 + 0.1));
        expect(tester.takeException(), isNull);

        final videoMessage = WKMsg()
          ..fromUID = 'u_me'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.video
          ..messageContent = (WKVideoContent()
            ..cover = '/uploads/narrow-cover.jpg'
            ..width = 1920
            ..height = 1080)
          ..status = WKSendMsgResult.sendSuccess;

        await tester.pumpWidget(host(videoMessage));

        bubbleWidth = tester
            .getSize(find.byKey(const ValueKey<String>('message-bubble-body')))
            .width;
        cachedMedia = tester.widget<CachedMediaImage>(
          find.byType(CachedMediaImage),
        );
        expect(cachedMedia.width, lessThan(200));
        expect(cachedMedia.width, lessThanOrEqualTo(bubbleWidth - 20 + 0.1));
        expect(cachedMedia.height, closeTo(cachedMedia.width! * 0.75, 0.1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('sticker bubble shrinks body to narrow Android lane', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.sticker
        ..messageContent = WKStickerContent(
          packId: 'narrow',
          stickerId: 'fallback',
          fallbackText: '[贴纸]',
        )
        ..status = WKSendMsgResult.sendSuccess;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_me'),
                participant: const MessageParticipantInfo(
                  displayName: 'Me',
                  avatarUrl: null,
                ),
              ),
            ),
          ),
        ),
      );

      final bubbleWidth = tester
          .getSize(find.byKey(const ValueKey<String>('message-bubble-body')))
          .width;
      final stickerBody = tester.widget<SizedBox>(
        find.byKey(const ValueKey<String>('message-sticker-body')),
      );
      expect(stickerBody.width, lessThan(160));
      expect(stickerBody.width, lessThanOrEqualTo(bubbleWidth - 20 + 0.1));
      expect(stickerBody.height, stickerBody.width);
      expect(tester.takeException(), isNull);
    });

    testWidgets('remote image bubble uses the shared media cache pipeline', (
      tester,
    ) async {
      final content = WKImageContent(918, 352)..url = '/uploads/panel.png';
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.image
        ..messageContent = content
        ..status = WKSendMsgResult.sendSuccess;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              participant: const MessageParticipantInfo(
                displayName: 'Me',
                avatarUrl: null,
              ),
            ),
          ),
        ),
      );

      final cachedImage = tester.widget<CachedMediaImage>(
        find.byType(CachedMediaImage),
      );
      expect(cachedImage.imageUrl, ApiConfig.resolveMediaUrl(content.url));
      expect(cachedImage.cacheKey, cachedImage.imageUrl);
    });

    testWidgets(
      'remote preview path in image localPath renders as network media',
      (tester) async {
        final content = WKImageContent(918, 352)
          ..localPath = '/v1/file/preview/chat/1/u_peer/demo.png';
        final message = WKMsg()
          ..fromUID = 'u_peer'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.image
          ..messageContent = content
          ..status = WKSendMsgResult.sendSuccess;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_me'),
                participant: const MessageParticipantInfo(
                  displayName: 'Peer',
                  avatarUrl: null,
                ),
              ),
            ),
          ),
        );

        final cachedImage = tester.widget<CachedMediaImage>(
          find.byType(CachedMediaImage),
        );
        expect(
          cachedImage.imageUrl,
          ApiConfig.resolveMediaUrl(content.localPath),
        );
        expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      },
    );

    testWidgets('video cover uses the shared media cache pipeline', (
      tester,
    ) async {
      final content = WKVideoContent()
        ..cover = '/uploads/video-cover.jpg'
        ..width = 1920
        ..height = 1080;
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.video
        ..messageContent = content;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              participant: const MessageParticipantInfo(
                displayName: 'Me',
                avatarUrl: null,
              ),
            ),
          ),
        ),
      );

      final cachedImage = tester.widget<CachedMediaImage>(
        find.byType(CachedMediaImage),
      );
      expect(cachedImage.imageUrl, ApiConfig.resolveMediaUrl(content.cover));
      expect(cachedImage.cacheKey, cachedImage.imageUrl);
      expect(cachedImage.width, 200);
      expect(cachedImage.height, 150);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('gif bubble uses shared media cache and readable badge', (
      tester,
    ) async {
      final content = WKGifContent(width: 800, height: 600)
        ..url = '/uploads/fun.gif';
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.gif
        ..messageContent = content;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              participant: const MessageParticipantInfo(
                displayName: 'Me',
                avatarUrl: null,
              ),
            ),
          ),
        ),
      );

      final cachedGif = tester.widget<CachedMediaImage>(
        find.byType(CachedMediaImage),
      );
      final expectedDecodeSize = (200 * tester.view.devicePixelRatio).round();
      expect(cachedGif.imageUrl, ApiConfig.resolveMediaUrl(content.url));
      expect(cachedGif.cacheKey, cachedGif.imageUrl);
      expect(cachedGif.width, 200);
      expect(cachedGif.height, 200);
      expect(cachedGif.maxWidth, expectedDecodeSize);
      expect(cachedGif.maxHeight, expectedDecodeSize);
      expect(find.text('\u52a8\u56fe'), findsOneWidget);
      expect(find.text('鍔ㄥ浘'), findsNothing);
    });

    test('media decode request matches rendered image demand', () {
      final request = resolveMediaDecodeRequest(
        devicePixelRatio: 3,
        logicalWidth: 200,
        logicalHeight: 200,
        intrinsicWidth: 1600,
        intrinsicHeight: 1600,
      );

      expect(request.cacheWidth, 600);
      expect(request.cacheHeight, 600);
    });

    test('media decode request avoids oversizing video covers', () {
      final request = resolveMediaDecodeRequest(
        devicePixelRatio: 3,
        logicalWidth: 200,
        logicalHeight: 150,
        intrinsicWidth: 1920,
        intrinsicHeight: 1080,
      );

      expect(request.cacheWidth, 600);
      expect(request.cacheHeight, 450);
    });

    testWidgets('system payload shows readable notice instead of raw json', (
      tester,
    ) async {
      final message = WKMsg()
        ..contentType = WkMessageContentType.unknown
        ..messageContent = WKUnknownContent()
        ..content =
            '{"content":"test2 invited {0}","creator":"0a13431ca09247439ba5aaafe8f93359","creator_name":"test2","extra":[{"uid":"u_10000","name":"userA"}],"type":1001,"version":1000001}';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_self'),
            ),
          ),
        ),
      );

      expect(find.textContaining('test2'), findsOneWidget);
      expect(find.textContaining('{"content"'), findsNothing);
    });

    testWidgets('card bubble handles taps', (tester) async {
      var tapped = false;
      final message = WKMsg()
        ..contentType = WkMessageContentType.card
        ..messageContent = WKCardContent('u_card', 'Card User')
        ..status = WKSendMsgResult.sendSuccess;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_self'),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('robot card bubble renders premium card shell', (tester) async {
      final message = WKMsg()
        ..fromUID = 'u_robot'
        ..channelType = WKChannelType.group
        ..contentType = MsgContentType.robotCard
        ..messageContent = (WKRobotCardContent()
          ..robotProvider = 'feishu'
          ..robotName = 'Weather Robot'
          ..title = 'Message Notice'
          ..body = 'feishu-link-test-001'
          ..badge = 'LINK'
          ..linkUrl = 'https://example.com/detail'
          ..plainText = 'Message Notice feishu-link-test-001')
        ..status = WKSendMsgResult.sendSuccess;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_self'),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('robot-message-card')),
        findsOneWidget,
      );
      expect(find.text('Message Notice'), findsOneWidget);
      expect(find.text('feishu-link-test-001'), findsOneWidget);
      expect(find.text('LINK'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('message-status-badge')),
        findsNothing,
      );
    });

    testWidgets(
      'robot card without link keeps visible card but disables whole-card tap',
      (tester) async {
        var tapped = false;
        final message = WKMsg()
          ..fromUID = 'u_robot'
          ..channelType = WKChannelType.group
          ..contentType = MsgContentType.robotCard
          ..messageContent = (WKRobotCardContent()
            ..robotProvider = 'dingtalk'
            ..robotName = 'Ops Robot'
            ..title = 'No Link Card'
            ..body = 'still-visible-001'
            ..badge = 'NOTICE'
            ..linkUrl = ''
            ..plainText = 'No Link Card still-visible-001')
          ..status = WKSendMsgResult.sendSuccess;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_self'),
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('robot-message-card')),
          findsOneWidget,
        );
        final card = tester.widget<InkWell>(
          find.byKey(const ValueKey<String>('robot-message-card')),
        );
        expect(card.onTap, isNull);

        await tester.tap(
          find.byKey(const ValueKey<String>('robot-message-card')),
        );
        await tester.pump();

        expect(tapped, isFalse);
      },
    );

    testWidgets(
      'card bubble mirrors Android divider footer and removes chevron',
      (tester) async {
        final message = WKMsg()
          ..contentType = WkMessageContentType.card
          ..messageContent = WKCardContent('u_card', 'Card User')
          ..status = WKSendMsgResult.sendSuccess
          ..wkMsgExtra = (WKMsgExtra()..readedCount = 1);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_self'),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('card-bubble-divider')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('card-bubble-footer')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('card-bubble-footer')),
            matching: find.text('\u4e2a\u4eba\u540d\u7247'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('card-bubble-footer')),
            matching: find.byKey(
              const ValueKey<String>('message-status-badge'),
            ),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      },
    );

    testWidgets(
      'unknown card payload falls back to Android-style card bubble',
      (tester) async {
        final message = WKMsg()
          ..contentType = WkMessageContentType.unknown
          ..messageContent = WKUnknownContent()
          ..content = '{"type":7,"name":"Card User","uid":"u_card"}';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_self'),
              ),
            ),
          ),
        );

        expect(find.text('Card User'), findsOneWidget);
        expect(find.text('\u4e2a\u4eba\u540d\u7247'), findsOneWidget);
        expect(find.text('[\u672a\u77e5\u6d88\u606f]'), findsNothing);
      },
    );

    testWidgets(
      'file bubble uses reference asset icon instead of material icon',
      (tester) async {
        final message = WKMsg()
          ..contentType = WkMessageContentType.unknown
          ..messageContent = WKUnknownContent()
          ..content =
              '{"type":${WkMessageContentType.file},"name":"产品手册.pdf","size":2048}';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_self'),
              ),
            ),
          ),
        );

        expect(find.text('产品手册.pdf'), findsOneWidget);
        expect(find.byIcon(Icons.insert_drive_file_rounded), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    WKReferenceAssets.chatFunctionFile,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'location bubble uses reference asset icon instead of material icon',
      (tester) async {
        final message = WKMsg()
          ..contentType = WkMessageContentType.unknown
          ..messageContent = WKUnknownContent()
          ..content =
              '{"type":${WkMessageContentType.location},"title":"公司定位","address":"上海市徐汇区"}';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_self'),
              ),
            ),
          ),
        );

        expect(find.text('公司定位'), findsOneWidget);
        expect(find.byIcon(Icons.location_on_rounded), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    WKReferenceAssets.chatFunctionLocation,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('location bubble fallback title is readable Chinese', (
      tester,
    ) async {
      final message = WKMsg()
        ..contentType = WkMessageContentType.location
        ..messageContent = (WKLocationContent()..address = '上海市徐汇区');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              model: ChatMessageMapper().map(message, currentUid: 'u_self'),
            ),
          ),
        ),
      );

      expect(find.text('\u4f4d\u7f6e'), findsOneWidget);
      expect(find.text('浣嶇疆'), findsNothing);
    });

    testWidgets(
      'robot card bubble renders premium card shell instead of plain text fallback',
      (tester) async {
        final message = WKMsg()
          ..fromUID = 'u_robot'
          ..channelType = WKChannelType.group
          ..contentType = MsgContentType.robotCard
          ..messageContent = (WKRobotCardContent()
            ..robotProvider = 'feishu'
            ..robotName = 'Feishu Robot'
            ..title = 'Message Notice'
            ..body = 'feishu-link-test-001'
            ..badge = 'LINK'
            ..linkUrl = 'https://example.com/detail'
            ..plainText = 'Message Notice feishu-link-test-001')
          ..status = WKSendMsgResult.sendSuccess;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                model: ChatMessageMapper().map(message, currentUid: 'u_self'),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('robot-message-card')),
          findsOneWidget,
        );
        expect(find.text('Message Notice'), findsOneWidget);
        expect(find.text('feishu-link-test-001'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('message-status-badge')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'file location card reply and system bubbles stay within narrow Android lane',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(280, 700);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final cases = <WKMsg>[
          WKMsg()
            ..fromUID = 'u_peer'
            ..channelType = WKChannelType.personal
            ..contentType = WkMessageContentType.unknown
            ..messageContent = WKUnknownContent()
            ..content =
                '{"type":${WkMessageContentType.file},"name":"extremely-long-product-manual-name-that-must-ellipsis.pdf","size":2048}',
          WKMsg()
            ..fromUID = 'u_peer'
            ..channelType = WKChannelType.personal
            ..contentType = WkMessageContentType.unknown
            ..messageContent = WKUnknownContent()
            ..content =
                '{"type":${WkMessageContentType.location},"title":"Very Long Location Title That Should Ellipsis","address":"Long address line that should wrap without overflowing the message lane"}',
          WKMsg()
            ..fromUID = 'u_peer'
            ..channelType = WKChannelType.personal
            ..contentType = WkMessageContentType.card
            ..messageContent = WKCardContent(
              'u_card',
              'Long Contact Display Name That Should Ellipsis Safely',
            ),
          WKMsg()
            ..fromUID = 'u_peer'
            ..channelType = WKChannelType.personal
            ..contentType = WkMessageContentType.text
            ..messageContent = (WKTextContent('reply body stays readable')
              ..reply = (WKReply()
                ..fromName = 'Reply Author With Long Name'
                ..payload = WKTextContent(
                  'quoted message text that should wrap safely',
                ))),
          WKMsg()
            ..fromUID = 'u_peer'
            ..channelType = WKChannelType.group
            ..contentType = WkMessageContentType.unknown
            ..messageContent = WKUnknownContent()
            ..content =
                '{"content":"Long system notice should render readable wrapped text instead of raw json","type":1001}',
        ];

        for (final message in cases) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 280,
                  child: MessageBubble(
                    model: ChatMessageMapper().map(
                      message,
                      currentUid: 'u_self',
                    ),
                    participant: const MessageParticipantInfo(
                      displayName: 'Peer',
                      avatarUrl: null,
                    ),
                  ),
                ),
              ),
            ),
          );

          final bubbleFinder = find.byKey(
            const ValueKey<String>('message-bubble-body'),
          );
          if (bubbleFinder.evaluate().isNotEmpty) {
            final bubbleWidth = tester.getSize(bubbleFinder).width;
            expect(bubbleWidth, lessThanOrEqualTo(280));
          }
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'robot card bubble constrains long badge in a narrow Android lane',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(260, 700);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final message = WKMsg()
          ..fromUID = 'u_robot'
          ..channelType = WKChannelType.group
          ..contentType = MsgContentType.robotCard
          ..messageContent = (WKRobotCardContent()
            ..robotProvider = 'feishu'
            ..robotName = 'Very Long Robot Name That Should Truncate'
            ..title = 'A long robot card title that should wrap safely'
            ..body = 'Long robot card body content that stays inside the card.'
            ..badge = 'EXTREMELY_LONG_NOTICE_BADGE_FOR_TESTING'
            ..linkUrl = 'https://example.com/detail'
            ..plainText = 'robot card narrow lane');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 260,
                child: MessageBubble(
                  model: ChatMessageMapper().map(message, currentUid: 'u_self'),
                  participant: const MessageParticipantInfo(
                    displayName: 'Robot',
                    avatarUrl: null,
                  ),
                ),
              ),
            ),
          ),
        );

        final bubbleWidth = tester
            .getSize(find.byKey(const ValueKey<String>('message-bubble-body')))
            .width;
        final cardWidth = tester
            .getSize(find.byKey(const ValueKey<String>('robot-message-card')))
            .width;

        expect(cardWidth, lessThanOrEqualTo(bubbleWidth + 0.1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('warm Web text bubble uses approved outgoing color', (
      tester,
    ) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('hello warm web')
        ..status = WKSendMsgResult.sendSuccess;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              webStyle: true,
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );

      final body = tester.widget<Container>(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      final decoration = body.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFEDD5));
    });

    testWidgets(
      'warm Web text bubble caps itself to the chat lane instead of the whole window',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1440, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final message = WKMsg()
          ..fromUID = 'u_me'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent(
            'This warm web message is intentionally long so the bubble has to wrap within the approved max width rather than stretching across the whole desktop workspace.',
          )
          ..status = WKSendMsgResult.sendSuccess;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                webStyle: true,
                model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              ),
            ),
          ),
        );

        expect(
          tester
              .getSize(
                find.byKey(const ValueKey<String>('message-bubble-body')),
              )
              .width,
          lessThanOrEqualTo(WKWebSizes.messageBubbleMaxWidth),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'warm Web outgoing text bubble uses dark readable content and metadata colors',
      (tester) async {
        final message = WKMsg()
          ..fromUID = 'u_me'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('readable warm web')
          ..timestamp = 1710000000
          ..wkMsgExtra = (WKMsgExtra()..isPinned = 1)
          ..status = WKSendMsgResult.sendSuccess;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                webStyle: true,
                model: ChatMessageMapper().map(message, currentUid: 'u_me'),
              ),
            ),
          ),
        );

        final body = tester.widget<Container>(
          find.byKey(const ValueKey<String>('message-bubble-body')),
        );
        final decoration = body.decoration! as BoxDecoration;
        expect(decoration.color, WKWebColors.actionSoft);

        final contentText = tester.widget<SelectableText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is SelectableText && widget.data == 'readable warm web',
          ),
        );
        expect(contentText.style?.color, WKWebColors.textPrimary);
        expect(contentText.style?.color, isNot(Colors.white));

        final pinnedText = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('message-pinned-indicator')),
            matching: find.text('\u7f6e\u9876'),
          ),
        );
        expect(pinnedText.style?.color, const Color(0xFF475569));
        expect(pinnedText.style?.color, isNot(Colors.white));

        final metadataText = tester.widget<Text>(
          find
              .descendant(
                of: find.byKey(const ValueKey<String>('message-status-badge')),
                matching: find.byType(Text),
              )
              .first,
        );
        expect(metadataText.style?.color, const Color(0xFF475569));
        expect(metadataText.style?.color, isNot(Colors.white));
      },
    );
  });
}
