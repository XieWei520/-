import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/cache/media_cache_manager.dart';
import 'package:wukong_im_app/modules/chat/chat_message_view_model.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_message_list_item.dart';
import 'package:wukong_im_app/widgets/message_bubble.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('MediaCacheManager', () {
    test(
      'evicts least recently used entries when decoded byte budget is exceeded',
      () {
        final manager = MediaCacheManager.forTesting(maxL1Bytes: 100);
        final first = MemoryImage(Uint8List.fromList([1]));
        final second = MemoryImage(Uint8List.fromList([2]));
        final third = MemoryImage(Uint8List.fromList([3]));

        manager.putToL1('a', first, estimatedBytes: 40);
        manager.putToL1('b', second, estimatedBytes: 40);
        expect(manager.getFromL1('a'), same(first));

        manager.putToL1('c', third, estimatedBytes: 40);

        expect(manager.getFromL1('b'), isNull);
        expect(manager.getFromL1('a'), same(first));
        expect(manager.getFromL1('c'), same(third));
        expect(manager.l1Bytes, lessThanOrEqualTo(100));
      },
    );

    test('does not cache a single decoded image over the byte budget', () {
      final manager = MediaCacheManager.forTesting(maxL1Bytes: 100);
      final image = MemoryImage(Uint8List.fromList([1]));

      manager.putToL1('huge', image, estimatedBytes: 120);

      expect(manager.getFromL1('huge'), isNull);
      expect(manager.l1Size, 0);
      expect(manager.l1Bytes, 0);
    });

    test('bypasses Dart image cache for browser-rendered web media', () {
      expect(
        MediaCacheManager.shouldUseBrowserNetworkImageForTesting(isWeb: true),
        isTrue,
      );
      expect(
        MediaCacheManager.shouldUseBrowserNetworkImageForTesting(isWeb: false),
        isFalse,
      );
    });

    testWidgets('CachedMediaImage switches rendering path by platform flag', (
      tester,
    ) async {
      final widget = CachedMediaImage(
        imageUrl: 'https://example.test/image.jpg',
        cacheKey: 'image-key',
        width: 100,
        height: 80,
        maxWidth: 320,
        maxHeight: 240,
      );

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: widget.buildForTesting(isWeb: true))),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: widget.buildForTesting(isWeb: false))),
      );
      final cached = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(cached.imageUrl, 'https://example.test/image.jpg');
      expect(cached.memCacheWidth, 320);
      expect(cached.memCacheHeight, 240);
    });
  });

  group('chat list media decode limits', () {
    testWidgets('caps chat image bubble decode request', (tester) async {
      final message = _imageMessage(
        localPath: File('assets/emoji/android/default/0_0.png').absolute.path,
      )..timestamp = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 4),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: MessageBubble(
                  model: ChatMessageViewModel(
                    identity: 'image-test',
                    message: message,
                    preview: '',
                    system: false,
                    self: false,
                    structured: null,
                    revision: '1',
                  ),
                  participant: const MessageParticipantInfo(
                    displayName: 'Alice',
                    avatarUrl: null,
                  ),
                  webStyle: false,
                ),
              ),
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('message-bubble-body')),
          matching: find.byType(Image),
        ),
      );
      final provider = image.image;
      expect(provider, isA<ResizeImage>());
      final resize = provider as ResizeImage;
      expect(resize.width, greaterThan(0));
      expect(resize.height, greaterThan(0));
      expect(resize.width, lessThan(4000));
      expect(resize.height, lessThan(3000));
    });

    test('leaves non-list preview decode helper uncapped for larger cards', () {
      final request = resolveMediaDecodeRequest(
        devicePixelRatio: 3,
        logicalWidth: 260,
        logicalHeight: 132,
      );

      expect(request.cacheWidth, 780);
      expect(request.cacheHeight, 396);
    });
  });

  group('MessageHeightEstimator keep-alive policy', () {
    test('keeps media-heavy message types alive only', () {
      expect(
        MessageHeightEstimator.shouldKeepAlive(WkMessageContentType.image),
        isTrue,
      );
      expect(
        MessageHeightEstimator.shouldKeepAlive(WkMessageContentType.video),
        isTrue,
      );
      expect(
        MessageHeightEstimator.shouldKeepAlive(WkMessageContentType.gif),
        isTrue,
      );
      expect(
        MessageHeightEstimator.shouldKeepAlive(WkMessageContentType.file),
        isTrue,
      );
    });

    test('does not keep text and system notices alive', () {
      expect(
        MessageHeightEstimator.shouldKeepAlive(WkMessageContentType.text),
        isFalse,
      );
      expect(MessageHeightEstimator.shouldKeepAlive(1001), isFalse);
    });

    testWidgets('ChatMessageListItem applies keepAlive for media-heavy rows', (
      tester,
    ) async {
      for (final contentType in const <int>[
        WkMessageContentType.image,
        WkMessageContentType.video,
        WkMessageContentType.gif,
        WkMessageContentType.file,
      ]) {
        await _pumpListItem(
          tester,
          keepAlive: MessageHeightEstimator.shouldKeepAlive(contentType),
        );
        final state = tester.state(find.byType(ChatMessageListItem)) as dynamic;
        expect(state.wantKeepAlive, isTrue);
      }
    });

    testWidgets('ChatMessageListItem does not keep text or system rows alive', (
      tester,
    ) async {
      for (final contentType in const <int>[WkMessageContentType.text, 1001]) {
        await _pumpListItem(
          tester,
          keepAlive: MessageHeightEstimator.shouldKeepAlive(contentType),
        );
        final state = tester.state(find.byType(ChatMessageListItem)) as dynamic;
        expect(state.wantKeepAlive, isFalse);
      }
    });

    testWidgets(
      'ChatMessageListItem refreshes keepAlive when row type changes',
      (tester) async {
        await _pumpListItem(tester, keepAlive: false);
        var state = tester.state(find.byType(ChatMessageListItem)) as dynamic;
        expect(state.wantKeepAlive, isFalse);

        await _pumpListItem(tester, keepAlive: true);
        state = tester.state(find.byType(ChatMessageListItem)) as dynamic;
        expect(state.wantKeepAlive, isTrue);
      },
    );
  });
}

WKMsg _imageMessage({required String localPath}) {
  final content = WKImageContent(4000, 3000)
    ..localPath = localPath
    ..url = '';
  return WKMsg()
    ..fromUID = 'alice'
    ..channelID = 'chat-1'
    ..channelType = WKChannelType.personal
    ..contentType = WkMessageContentType.image
    ..messageContent = content
    ..content = content.encodeJson().toString();
}

Future<void> _pumpListItem(
  WidgetTester tester, {
  required bool keepAlive,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChatMessageListItem(
        itemKey: const ValueKey<String>('list-item'),
        keepAlive: keepAlive,
        child: const SizedBox.shrink(),
      ),
    ),
  );
}
