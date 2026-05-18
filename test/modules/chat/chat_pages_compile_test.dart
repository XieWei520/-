import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_conversation_extra_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_pinned_message_banner.dart';
import 'package:wukong_im_app/modules/search/presentation/message_record_search_page.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';
import 'package:wukong_im_app/wukong_uikit/chat/message_long_press_menu.dart';
import 'package:wukong_im_app/wukong_uikit/user/user_detail_page.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';

import 'fakes/noop_chat_conversation_extra_gateway.dart';

void main() {
  testWidgets('chat page renders through shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageListProvider.overrideWith(
            (ref, session) => _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            ),
          ),
          chatSceneGatewayProvider.overrideWith(
            (ref, session) => _CompileSafeChatSceneGateway(),
          ),
          chatConversationExtraGatewayProvider.overrideWithValue(
            NoopChatConversationExtraGateway(),
          ),
        ],
        child: MaterialApp(
          home: ChatPage(
            channelId: 'u_demo',
            channelType: 1,
            channelName: 'Demo',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ChatPage), findsOneWidget);
    expect(find.byType(ChatPageShell), findsOneWidget);
  });

  testWidgets(
    'chat exports compile with the real forward page and long-press wrapper',
    (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(
        const ChatPage(
          channelId: 'u_demo',
          channelType: 1,
          channelName: 'Demo',
        ),
        isA<Widget>(),
      );
      expect(
        ForwardMessagePage(
          payloads: const <ForwardPayload>[],
          channelId: 'u_compile',
          channelType: 1,
        ),
        isA<ForwardMessagePage>(),
      );
      expect(const ContactPickerDialog(), isA<Widget>());
      expect(const UserDetailPage(uid: 'u_demo'), isA<Widget>());

      final menuFuture = showMessageLongPressMenu(
        context: capturedContext,
        position: Offset.zero,
        messageType: 'text',
        isFromMe: true,
        canRecall: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('回复'), findsOneWidget);
      expect(find.text('转发'), findsOneWidget);
      Navigator.of(capturedContext).pop();
      await menuFuture;
    },
  );

  testWidgets('legacy ChatSearchPage delegates to MessageRecordSearchPage', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ChatSearchPage(
            channelId: 'u_demo',
            channelType: 1,
            channelName: 'Demo',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MessageRecordSearchPage), findsOneWidget);
  });

  testWidgets(
    'pinned message banner uses liquid glass styling and keeps actions',
    (tester) async {
      var tapCount = 0;
      var clearCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPinnedMessageBanner(
              data: const ChatPinnedMessageBannerData(
                previewText: 'Pinned body',
                count: 2,
              ),
              onTap: () => tapCount += 1,
              onClearAll: () => clearCount += 1,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byKey(const ValueKey<String>('chat-pinned-banner')),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;

      expect(gradient.colors, <Color>[
        LiquidGlassColors.primary2.withValues(alpha: 0.10),
        LiquidGlassColors.primary.withValues(alpha: 0.08),
      ]);
      expect(decoration.borderRadius, LiquidGlassRadii.lg);
      expect(
        decoration.border,
        Border.all(color: LiquidGlassColors.primary2.withValues(alpha: 0.15)),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-pinned-banner')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-pinned-clear-all')),
      );

      expect(tapCount, 1);
      expect(clearCount, 1);
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

class _CompileSafeChatSceneGateway extends ChatSceneGateway {
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
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
    int? expireSeconds,
  }) async {}

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) async {}
}
