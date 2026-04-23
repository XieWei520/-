import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/data/models/wk_robot_card_content.dart';
import 'package:wukong_im_app/modules/chat/chat_message_mapper.dart';
import 'package:wukong_im_app/widgets/message_bubble.dart';
import 'package:wukong_im_app/widgets/wk_emoji_text.dart';
import 'package:wukong_im_app/widgets/wk_reference_assets.dart';
import 'package:wukong_im_app/wukong_base/emoji/android_emoji_catalog.dart';
import 'package:wukong_im_app/wukong_base/msg/msg_content_type.dart';
import 'package:wukong_im_app/wukong_base/msg/widget/wk_message_reaction.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_card_content.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_sticker_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/model/wk_unknown_content.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('message bubble presentation', () {
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
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    'assets/stickers/sample_pack/typing.webp',
          ),
          findsOneWidget,
        );
      },
    );

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
  });
}
