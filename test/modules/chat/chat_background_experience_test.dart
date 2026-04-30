import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/cache/media_cache_manager.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/chat_background_option.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/widgets/chat_background_surface.dart';
import 'package:wukong_im_app/widgets/wk_web_ui_tokens.dart';
import 'package:wukong_im_app/wukong_uikit/setting/setting_preferences.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
    await WKSettingPreferences.setSelectedChatBackground(
      const ChatBackgroundOption(
        cover: 'file/preview/common/chatbg/default/1_s.jpg',
        url: 'file/preview/common/chatbg/default/1_b.svg',
        isSvg: true,
        lightColors: <String>['a6B0CDEB', 'a69FB0EA', 'a6BBEAD5', 'a6B2E3DD'],
        darkColors: <String>['a6A4DBFF', 'a6009FDD', 'a6527BDD', 'a673B6DD'],
      ),
    );
  });

  testWidgets('chat page renders the selected chat background surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageListProvider.overrideWith(
            (ref, session) => _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            ),
          ),
        ],
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'u_background',
            channelType: 1,
            channelName: 'Background Chat',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-background-surface')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-background-gradient')),
      findsOneWidget,
    );
  });

  testWidgets(
    'chat page prefers a channel-scoped chat background over the global selection',
    (tester) async {
      await WKSettingPreferences.setChatBackgroundStyle(
        WKChatBackgroundStyle.paper,
      );
      await WKSettingPreferences.setSelectedChatBackground(
        const ChatBackgroundOption(
          cover: 'file/preview/common/chatbg/default/14_s.jpg',
          url: 'file/preview/common/chatbg/default/14_b.jpg',
          isSvg: false,
        ),
        channelId: 'u_background',
        channelType: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            messageListProvider.overrideWith(
              (ref, session) => _EmptyMessageListNotifier(
                session.channelId,
                session.channelType,
              ),
            ),
          ],
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_background',
              channelType: 1,
              channelName: 'Background Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chat-background-image')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-background-gradient')),
        findsNothing,
      );
    },
  );

  testWidgets('raster chat background uses the shared media cache pipeline', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 480,
          child: ChatBackgroundSurface(
            option: ChatBackgroundOption(
              cover: 'https://cdn.example.com/backgrounds/chat-thumb.jpg',
              url: 'https://cdn.example.com/backgrounds/chat.jpg',
              isSvg: false,
            ),
          ),
        ),
      ),
    );

    final cachedBackground = tester.widget<CachedMediaImage>(
      find.byKey(const ValueKey<String>('chat-background-image')),
    );

    expect(
      cachedBackground.imageUrl,
      'https://cdn.example.com/backgrounds/chat.jpg',
    );
    expect(cachedBackground.cacheKey, cachedBackground.imageUrl);
    expect(cachedBackground.fit, BoxFit.cover);
    expect(cachedBackground.maxWidth, greaterThan(0));
    expect(cachedBackground.maxHeight, greaterThan(0));
  });

  testWidgets('chat background surface supports a warm Web fallback color', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 480,
          child: ChatBackgroundSurface(fallbackColor: WKWebColors.pageWarm),
        ),
      ),
    );

    final fallback = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('chat-background-fallback')),
    );
    final decoration = fallback.decoration as BoxDecoration;
    expect(decoration.color, WKWebColors.pageWarm);
    expect(
      find.byKey(const ValueKey<String>('chat-background-gradient')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-background-image')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-background-svg')),
      findsNothing,
    );
  });

  testWidgets(
    'chat page uses a channel-scoped local style instead of the global server background selection',
    (tester) async {
      await WKSettingPreferences.setChatBackgroundStyle(
        WKChatBackgroundStyle.paper,
        channelId: 'u_background',
        channelType: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            messageListProvider.overrideWith(
              (ref, session) => _EmptyMessageListNotifier(
                session.channelId,
                session.channelType,
              ),
            ),
          ],
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_background',
              channelType: 1,
              channelName: 'Background Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chat-background-surface')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-background-gradient')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-background-image')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-background-svg')),
        findsNothing,
      );
    },
  );
}

class _EmptyMessageListNotifier extends MessageListNotifier {
  _EmptyMessageListNotifier(super.channelId, super.channelType);

  @override
  Future<void> loadMessages() async {
    state = <WKMsg>[];
  }

  @override
  Future<void> loadMore() async {}
}
