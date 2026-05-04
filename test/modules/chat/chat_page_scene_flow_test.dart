import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/chat_session.dart';
import 'package:wukong_im_app/data/models/wk_custom_content.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_action_definition.dart';
import 'package:wukong_im_app/modules/chat/chat_action_dispatcher.dart';
import 'package:wukong_im_app/modules/chat/chat_composer_controller.dart';
import 'package:wukong_im_app/modules/chat/chat_desktop_drop_target.dart';
import 'package:wukong_im_app/modules/chat/chat_media_action_service.dart';
import 'package:wukong_im_app/modules/chat/chat_message_favorite_registry.dart';
import 'package:wukong_im_app/modules/chat/chat_mentions_controller.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_models.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukong_im_app/modules/chat/chat_voice_action_service.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry_provider.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukong_im_app/widgets/wk_reference_assets.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_entry.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/providers/slot_registry_provider.dart';
import 'package:wukong_im_app/wk_endpoint/slots/chat_slots.dart';
import 'package:wukong_im_app/wukong_base/endpoint/entity/chat_toolbar_menu.dart';
import 'package:wukong_im_app/wukong_base/msg/draft_manager.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukong_im_app/wukong_base/views/mention_suggestion.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_rich_text_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

Override _realtimeTelemetryNoTimerOverride() {
  return realtimeRolloutTelemetryProvider.overrideWith((ref) {
    final telemetry = RealtimeRolloutTelemetry(flushInterval: Duration.zero);
    ref.onDispose(telemetry.dispose);
    return telemetry;
  });
}

void main() {
  testWidgets('reply, search, and selection are scene-driven in the shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, session) => _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            ),
          ),
        ],
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'u_scene',
            channelType: 1,
            channelName: 'Scene Chat',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-open-search')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('chat-open-search')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-search-mode-field')),
      findsOneWidget,
    );
  });

  testWidgets('chat shell includes a guarded desktop file drop target', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, session) => _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            ),
          ),
        ],
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'u_drop',
            channelType: WKChannelType.personal,
            channelName: 'Drop Chat',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChatDesktopDropTarget), findsOneWidget);
  });

  testWidgets('android keyboard inset is animated by the chat body', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _realtimeTelemetryNoTimerOverride(),
            messageListProvider.overrideWith(
              (ref, session) => _EmptyMessageListNotifier(
                session.channelId,
                session.channelType,
              ),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(viewInsets: const EdgeInsets.only(bottom: 280)),
                child: child!,
              );
            },
            home: const ChatPage(
              channelId: 'u_keyboard_inset',
              channelType: WKChannelType.personal,
              channelName: 'Keyboard Inset',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.resizeToAvoidBottomInset, isFalse);

      final padding = tester.widget<AnimatedPadding>(
        find.byKey(const ValueKey<String>('chat-keyboard-inset-padding')),
      );
      expect(padding.padding, const EdgeInsets.only(bottom: 280));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('send button uses compact motion states for composer feedback', (
    tester,
  ) async {
    final gateway = _FakeChatSceneGateway();
    addTearDown(gateway.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, session) => _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            ),
          ),
          chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
        ],
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'u_send_motion',
            channelType: WKChannelType.personal,
            channelName: 'Send Motion',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final motionFinder = find.byKey(
      const ValueKey<String>('chat-send-button-motion'),
    );
    expect(motionFinder, findsOneWidget);
    expect(tester.widget<AnimatedScale>(motionFinder).scale, lessThan(1));

    final input = find.byKey(const ValueKey<String>('chat-input-field'));
    await tester.enterText(input, 'micro interaction');
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(motionFinder).scale, 1);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('chat-send-button'))),
    );
    await tester.pump();
    expect(tester.widget<AnimatedScale>(motionFinder).scale, lessThan(1));
    await gesture.up();
  });

  testWidgets('overflow route returns without breaking shell actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, session) => _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            ),
          ),
        ],
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'u_scene',
            channelType: 1,
            channelName: 'Scene Chat',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('chat-open-more')));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-open-search')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-open-more')),
      findsOneWidget,
    );
  });

  testWidgets(
    'selection mode shows the batch toolbar and cancel restores normal',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, session) => _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      const session = ChatSession(channelId: 'u_scene', channelType: 1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_scene',
              channelType: 1,
              channelName: 'Scene Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      container
          .read(chatSelectionControllerProvider(session).notifier)
          .seed('mid:m1');
      container
          .read(chatSceneControllerProvider(session).notifier)
          .enterSelectionMode(seedIdentity: 'mid:m1');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chat-selection-toolbar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-selection-count')),
        findsOneWidget,
      );
      expect(
        container.read(chatSelectionControllerProvider(session)).selectedCount,
        1,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-selection-forward')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-selection-cancel')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-selection-cancel')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chat-selection-toolbar')),
        findsNothing,
      );
      expect(
        container.read(chatSceneControllerProvider(session)).mode,
        ChatSceneMode.normal,
      );
    },
  );

  testWidgets('long press opens the scene message action sheet', (
    tester,
  ) async {
    final message = WKMsg()
      ..messageID = 'mid:m1'
      ..messageSeq = 1
      ..channelID = 'u_scene'
      ..channelType = 1
      ..contentType = WkMessageContentType.text
      ..messageContent = WKTextContent('hello action sheet');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, session) => _StaticMessageListNotifier(
              session.channelId,
              session.channelType,
              session.channelId == 'u_scene'
                  ? <WKMsg>[message]
                  : const <WKMsg>[],
            ),
          ),
          chatMarkConversationReadProvider.overrideWithValue(
            (session, messageIds) async {},
          ),
        ],
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'u_scene',
            channelType: 1,
            channelName: 'Scene Chat',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey<String>('message-bubble-body')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-action-reply')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-action-forward')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-action-favorite')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-action-select')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-action-react')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-action-pin')),
      findsOneWidget,
    );
    expect(find.text('\u7f6e\u9876'), findsOneWidget);
  });

  testWidgets('desktop secondary tap opens an anchored message context menu', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final message = WKMsg()
        ..messageID = 'mid:desktop-menu'
        ..messageSeq = 1
        ..channelID = 'u_scene'
        ..channelType = 1
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('hello desktop context menu');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _realtimeTelemetryNoTimerOverride(),
            messageListProvider.overrideWith(
              (ref, session) => _StaticMessageListNotifier(
                session.channelId,
                session.channelType,
                session.channelId == 'u_scene'
                    ? <WKMsg>[message]
                    : const <WKMsg>[],
              ),
            ),
            chatMarkConversationReadProvider.overrideWithValue(
              (session, messageIds) async {},
            ),
          ],
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_scene',
              channelType: 1,
              channelName: 'Scene Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('message-bubble-body')),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chat-context-action-reply')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-action-reply')),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'pinned banner opens sheet and pinned selection jumps around order seq',
    (tester) async {
      const session = ChatSession(
        channelId: 'u_scene',
        channelType: WKChannelType.personal,
      );
      final tracker = _TrackingMessageListNotifier(
        session.channelId,
        session.channelType,
      );
      final pinnedSyncMessage = WKSyncMsg()
        ..messageID = 'mid:pinned'
        ..messageSeq = 42
        ..channelID = session.channelId
        ..channelType = session.channelType
        ..fromUID = 'u_other'
        ..payload = <String, dynamic>{
          'type': WkMessageContentType.text,
          'content': 'Pinned body',
        };
      final gateway = _FakeChatSceneGateway(
        pinnedSnapshot: PinnedMessageSyncSnapshot(
          pinnedMessages: const <PinnedMessageEntry>[
            PinnedMessageEntry(
              messageId: 'mid:pinned',
              messageSeq: 42,
              channelId: 'u_scene',
              channelType: WKChannelType.personal,
              isDeleted: 0,
              version: 7,
              createdAt: '2026-04-16T00:00:00Z',
              updatedAt: '2026-04-16T00:00:00Z',
            ),
          ],
          messages: <WKSyncMsg>[pinnedSyncMessage],
        ),
      );
      addTearDown(gateway.dispose);
      final container = ProviderContainer(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, providedSession) => providedSession == session
                ? tracker
                : _EmptyMessageListNotifier(
                    providedSession.channelId,
                    providedSession.channelType,
                  ),
          ),
          chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
          chatMarkConversationReadProvider.overrideWithValue(
            (session, messageIds) async {},
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChatPage(
              channelId: session.channelId,
              channelType: session.channelType,
              channelName: 'Scene Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chat-pinned-banner')),
        findsOneWidget,
      );
      expect(find.text('Pinned body'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-pinned-banner')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chat-pinned-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-pinned-sheet-item-mid:pinned')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-pinned-sheet-item-mid:pinned')),
      );
      await tester.pumpAndSettle();

      expect(tracker.loadAroundOrderSeqCalls, <int>[
        pinnedSyncMessage.getWKMsg().orderSeq,
      ]);
    },
  );

  testWidgets(
    'favorite action shows success feedback and deduplicates repeated taps after known success',
    (tester) async {
      const session = ChatSession(
        channelId: 'u_scene',
        channelType: WKChannelType.personal,
      );
      final message = WKMsg()
        ..messageID = 'mid:favorite-success'
        ..clientMsgNO = 'client:favorite-success'
        ..channelID = session.channelId
        ..channelType = session.channelType
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('favorite once');
      final gateway = _FakeChatSceneGateway();
      final favoriteRegistry = _FakeFavoriteRegistry();
      addTearDown(gateway.dispose);
      final container = ProviderContainer(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, providedSession) => _StaticMessageListNotifier(
              providedSession.channelId,
              providedSession.channelType,
              providedSession == session ? <WKMsg>[message] : const <WKMsg>[],
            ),
          ),
          chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
          chatMessageFavoriteRegistryProvider.overrideWithValue(
            favoriteRegistry,
          ),
          chatMarkConversationReadProvider.overrideWithValue(
            (session, messageIds) async {},
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChatPage(
              channelId: session.channelId,
              channelType: session.channelType,
              channelName: 'Scene Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-action-favorite')),
      );
      await tester.pumpAndSettle();

      expect(find.text('\u5df2\u6536\u85cf'), findsOneWidget);
      expect(gateway.favoriteCalls, <String>['mid:favorite-success']);
      expect(favoriteRegistry.snapshot(), contains('mid:mid:favorite-success'));
      expect(
        favoriteRegistry.snapshot(),
        contains('cid:client:favorite-success'),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('\u5df2\u6536\u85cf'), findsNothing);

      await tester.longPress(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-action-favorite')),
      );
      await tester.pumpAndSettle();

      expect(find.text('\u5df2\u6536\u85cf'), findsOneWidget);
      expect(gateway.favoriteCalls, <String>['mid:favorite-success']);
      expect(
        container
            .read(chatMessageActionControllerProvider(session))
            .knownFavoriteKeys,
        contains('mid:mid:favorite-success'),
      );
    },
  );

  testWidgets(
    'favorite failure shows failure feedback and does not persist fake favorite state',
    (tester) async {
      const session = ChatSession(
        channelId: 'u_scene',
        channelType: WKChannelType.personal,
      );
      final message = WKMsg()
        ..messageID = 'mid:favorite-failure'
        ..clientMsgNO = 'client:favorite-failure'
        ..channelID = session.channelId
        ..channelType = session.channelType
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('favorite fails');
      final gateway = _FakeChatSceneGateway(
        failingFavoriteMessageIds: const <String>{'mid:favorite-failure'},
      );
      final favoriteRegistry = _FakeFavoriteRegistry();
      addTearDown(gateway.dispose);
      final container = ProviderContainer(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, providedSession) => _StaticMessageListNotifier(
              providedSession.channelId,
              providedSession.channelType,
              providedSession == session ? <WKMsg>[message] : const <WKMsg>[],
            ),
          ),
          chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
          chatMessageFavoriteRegistryProvider.overrideWithValue(
            favoriteRegistry,
          ),
          chatMarkConversationReadProvider.overrideWithValue(
            (session, messageIds) async {},
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChatPage(
              channelId: session.channelId,
              channelType: session.channelType,
              channelName: 'Scene Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-action-favorite')),
      );
      await tester.pumpAndSettle();

      expect(find.text('\u6536\u85cf\u5931\u8d25'), findsOneWidget);
      expect(gateway.favoriteCalls, <String>['mid:favorite-failure']);
      expect(favoriteRegistry.snapshot(), isEmpty);
      expect(
        container
            .read(chatMessageActionControllerProvider(session))
            .knownFavoriteKeys,
        isNot(contains('mid:mid:favorite-failure')),
      );
    },
  );

  testWidgets(
    'long press shows emoji strip, applies emoji, and chip retap cancels',
    (tester) async {
      final message = WKMsg()
        ..messageID = 'mid:reaction'
        ..clientMsgNO = 'client:reaction'
        ..channelID = 'u_scene'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('react to me');
      final gateway = _FakeChatSceneGateway();
      addTearDown(gateway.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _realtimeTelemetryNoTimerOverride(),
            messageListProvider.overrideWith(
              (ref, session) => _StaticMessageListNotifier(
                session.channelId,
                session.channelType,
                session.channelId == 'u_scene'
                    ? <WKMsg>[message]
                    : const <WKMsg>[],
              ),
            ),
            chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
            chatMarkConversationReadProvider.overrideWithValue(
              (session, messageIds) async {},
            ),
          ],
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_scene',
              channelType: WKChannelType.personal,
              channelName: 'Scene Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('reaction-picker-\u{1F44D}')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('reaction-picker-\u{1F389}')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('reaction-picker-\u{1F389}')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('message-reaction-chip-\u{1F389}')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('message-reaction-chip-\u{1F389}')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('message-reaction-chip-\u{1F389}')),
        findsNothing,
      );
      expect(gateway.reactionCalls, <String>[
        'mid:reaction:\u{1F389}',
        'mid:reaction:\u{1F389}',
      ]);
    },
  );

  testWidgets(
    'long press emoji strip highlights existing reaction and applies picker selection',
    (tester) async {
      final message = WKMsg()
        ..messageID = 'mid:add'
        ..clientMsgNO = 'client:add'
        ..channelID = 'u_scene'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('open picker');
      final gateway = _FakeChatSceneGateway(
        initialReactionsByMessageId: const <String, List<MessageReaction>>{
          'mid:add': <MessageReaction>[
            MessageReaction(
              type: 0x2764,
              emoji: '\u2764',
              count: 1,
              isMe: true,
              userIds: <String>['u_self'],
              usernames: <String>['Self'],
            ),
          ],
        },
      );
      addTearDown(gateway.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _realtimeTelemetryNoTimerOverride(),
            messageListProvider.overrideWith(
              (ref, session) => _StaticMessageListNotifier(
                session.channelId,
                session.channelType,
                session.channelId == 'u_scene'
                    ? <WKMsg>[message]
                    : const <WKMsg>[],
              ),
            ),
            chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
            chatMarkConversationReadProvider.overrideWithValue(
              (session, messageIds) async {},
            ),
          ],
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_scene',
              channelType: WKChannelType.personal,
              channelName: 'Scene Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      await tester.pumpAndSettle();

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
      final selectedDecoration = selectedCell.decoration as BoxDecoration;
      expect(selectedDecoration.border, isNotNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('reaction-picker-\u{1F389}')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('message-reaction-chip-\u{1F389}')),
        findsOneWidget,
      );
      expect(gateway.reactionCalls, <String>['mid:add:\u{1F389}']);
    },
  );

  testWidgets(
    'tapping highlighted normalized sheet emoji removes the stored reaction',
    (tester) async {
      final message = WKMsg()
        ..messageID = 'mid:add-normalized'
        ..clientMsgNO = 'client:add-normalized'
        ..channelID = 'u_scene'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('normalized removal');
      final gateway = _FakeChatSceneGateway(
        initialReactionsByMessageId: const <String, List<MessageReaction>>{
          'mid:add-normalized': <MessageReaction>[
            MessageReaction(
              type: 0x2764,
              emoji: '\u2764',
              count: 1,
              isMe: true,
              userIds: <String>['u_self'],
              usernames: <String>['Self'],
            ),
          ],
        },
      );
      addTearDown(gateway.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _realtimeTelemetryNoTimerOverride(),
            messageListProvider.overrideWith(
              (ref, session) => _StaticMessageListNotifier(
                session.channelId,
                session.channelType,
                session.channelId == 'u_scene'
                    ? <WKMsg>[message]
                    : const <WKMsg>[],
              ),
            ),
            chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
            chatMarkConversationReadProvider.overrideWithValue(
              (session, messageIds) async {},
            ),
          ],
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_scene',
              channelType: WKChannelType.personal,
              channelName: 'Scene Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      await tester.pumpAndSettle();

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
      final selectedDecoration = selectedCell.decoration as BoxDecoration;
      expect(selectedDecoration.border, isNotNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('reaction-picker-\u2764\uFE0F')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('message-reaction-chip-\u2764')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('message-reaction-chip-\u2764\uFE0F'),
        ),
        findsNothing,
      );
      expect(gateway.reactionCalls, <String>['mid:add-normalized:\u2764']);
    },
  );

  testWidgets(
    'forward action opens the real forward page and clears transient state on return',
    (tester) async {
      final message = WKMsg()
        ..messageID = 'mid:f1'
        ..clientMsgNO = 'client:f1'
        ..channelID = 'u_scene'
        ..channelType = 1
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('forward this message');
      final gateway = _FakeChatSceneGateway(
        targets: const <ForwardTarget>[
          ForwardTarget(
            channelId: 'u_target',
            channelType: 1,
            name: 'Target Chat',
            subtitle: 'Direct chat',
          ),
        ],
      );
      addTearDown(gateway.dispose);
      final container = ProviderContainer(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, session) => _StaticMessageListNotifier(
              session.channelId,
              session.channelType,
              session.channelId == 'u_scene'
                  ? <WKMsg>[message]
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
      const session = ChatSession(channelId: 'u_scene', channelType: 1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_scene',
              channelType: 1,
              channelName: 'Scene Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('chat-action-forward')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-action-forward')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('forward-search-field')),
        findsOneWidget,
      );
      expect(find.text('Target Chat'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(
        container
            .read(chatMessageActionControllerProvider(session))
            .forwardRequest,
        isNull,
      );
    },
  );

  testWidgets(
    'selection forward success clears selection and returns normal mode',
    (tester) async {
      final message = WKMsg()
        ..messageID = 'mid:s1'
        ..clientMsgNO = 'client:s1'
        ..channelID = 'u_scene'
        ..channelType = 1
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('select then forward');
      final gateway = _FakeChatSceneGateway(
        targets: const <ForwardTarget>[
          ForwardTarget(
            channelId: 'g_target',
            channelType: 2,
            name: 'Group Target',
            subtitle: 'Group chat',
            isGroup: true,
          ),
        ],
      );
      addTearDown(gateway.dispose);

      final container = ProviderContainer(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, session) => _StaticMessageListNotifier(
              session.channelId,
              session.channelType,
              session.channelId == 'u_scene'
                  ? <WKMsg>[message]
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
      const session = ChatSession(channelId: 'u_scene', channelType: 1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_scene',
              channelType: 1,
              channelName: 'Scene Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('chat-action-select')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-action-select')),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(chatSelectionControllerProvider(session)).selectedCount,
        1,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-selection-toolbar')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-selection-forward')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Group Target'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('forward-submit')));
      await tester.pumpAndSettle();

      expect(
        container.read(chatSceneControllerProvider(session)).mode,
        ChatSceneMode.normal,
      );
      expect(
        container
            .read(chatMessageActionControllerProvider(session))
            .forwardRequest,
        isNull,
      );
      expect(
        container.read(chatSelectionControllerProvider(session)).selectedCount,
        0,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-selection-toolbar')),
        findsNothing,
      );
      expect(gateway.forwardedTargets, hasLength(1));
    },
  );

  testWidgets(
    'selection forward cancel preserves selection mode and selected count',
    (tester) async {
      final message = WKMsg()
        ..messageID = 'mid:s2'
        ..clientMsgNO = 'client:s2'
        ..channelID = 'u_scene'
        ..channelType = 1
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('select then cancel forward');
      final gateway = _FakeChatSceneGateway(
        targets: const <ForwardTarget>[
          ForwardTarget(
            channelId: 'g_target',
            channelType: 2,
            name: 'Group Target',
            subtitle: 'Group chat',
            isGroup: true,
          ),
        ],
      );
      addTearDown(gateway.dispose);
      final container = ProviderContainer(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, session) => _StaticMessageListNotifier(
              session.channelId,
              session.channelType,
              session.channelId == 'u_scene'
                  ? <WKMsg>[message]
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
      const session = ChatSession(channelId: 'u_scene', channelType: 1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_scene',
              channelType: 1,
              channelName: 'Scene Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('chat-action-select')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-action-select')),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(chatSelectionControllerProvider(session)).selectedCount,
        1,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-selection-toolbar')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-selection-forward')),
      );
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(
        container.read(chatSceneControllerProvider(session)).mode,
        ChatSceneMode.selecting,
      );
      expect(
        container.read(chatSelectionControllerProvider(session)).selectedCount,
        1,
      );
      expect(
        container
            .read(chatMessageActionControllerProvider(session))
            .forwardRequest,
        isNull,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-selection-toolbar')),
        findsOneWidget,
      );
      expect(gateway.forwardedTargets, isEmpty);
    },
  );

  testWidgets('typing @ shows mention suggestions and inserts the selection', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        _realtimeTelemetryNoTimerOverride(),
        messageListProvider.overrideWith(
          (ref, session) =>
              _EmptyMessageListNotifier(session.channelId, session.channelType),
        ),
        chatMentionsControllerProvider.overrideWith(
          (ref, _) => ChatMentionsController(
            loadSuggestions: () async => <MentionSuggestion>[
              MentionSuggestion(id: 'u1', name: 'Alice'),
              MentionSuggestion(id: 'u2', name: 'Bob'),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    const session = ChatSession(
      channelId: 'g_mentions',
      channelType: WKChannelType.group,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'g_mentions',
            channelType: WKChannelType.group,
            channelName: 'Mention Group',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'hello @a');
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));

    expect(container.read(chatComposerProvider(session)).text, 'hello @Alice ');
  });

  testWidgets(
    'send button submits reply and mention payloads then clears composer',
    (tester) async {
      final replyMessage = WKMsg()
        ..messageID = 'mid:reply'
        ..clientMsgNO = 'client:reply'
        ..channelID = 'g_send'
        ..channelType = WKChannelType.group
        ..fromUID = 'u_other'
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('quoted source');
      final gateway = _FakeChatSceneGateway();
      addTearDown(gateway.dispose);
      final container = ProviderContainer(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, session) => _StaticMessageListNotifier(
              session.channelId,
              session.channelType,
              session.channelId == 'g_send'
                  ? <WKMsg>[replyMessage]
                  : const <WKMsg>[],
            ),
          ),
          chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
          chatMentionsControllerProvider.overrideWith(
            (ref, _) => ChatMentionsController(
              loadSuggestions: () async => <MentionSuggestion>[
                MentionSuggestion(id: 'u1', name: 'Alice'),
              ],
            ),
          ),
          chatMarkConversationReadProvider.overrideWithValue(
            (session, messageIds) async {},
          ),
        ],
      );
      addTearDown(container.dispose);
      const session = ChatSession(
        channelId: 'g_send',
        channelType: WKChannelType.group,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'g_send',
              channelType: WKChannelType.group,
              channelName: 'Send Group',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      container
          .read(chatComposerProvider(session).notifier)
          .setPendingReply(messageId: 'mid:reply', preview: 'quoted source');
      container
          .read(chatSceneControllerProvider(session).notifier)
          .enterReplyMode();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'hello @a');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byKey(const ValueKey<String>('chat-send-button')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));

      expect(gateway.sentContents, hasLength(1));
      final sent = gateway.sentContents.single as WKTextContent;
      expect(sent.content, 'hello @Alice');
      expect(sent.reply, isNotNull);
      expect(sent.reply!.messageId, 'mid:reply');
      expect(sent.mentionInfo, isNotNull);
      expect(sent.mentionInfo!.uids, <String>['u1']);
      expect(container.read(chatComposerProvider(session)).text, isEmpty);
      expect(
        container.read(chatComposerProvider(session)).pendingReplyMessageId,
        isNull,
      );
      expect(
        container.read(chatSceneControllerProvider(session)).mode,
        ChatSceneMode.normal,
      );
    },
  );

  testWidgets('send failure keeps composer text and shows retry feedback', (
    tester,
  ) async {
    final gateway = _FakeChatSceneGateway(sendError: Exception('offline'));
    addTearDown(gateway.dispose);
    final container = ProviderContainer(
      overrides: [
        _realtimeTelemetryNoTimerOverride(),
        messageListProvider.overrideWith(
          (ref, session) => _StaticMessageListNotifier(
            session.channelId,
            session.channelType,
            const <WKMsg>[],
          ),
        ),
        chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
        _memoryChatComposerOverride(),
        chatMarkConversationReadProvider.overrideWithValue(
          (session, messageIds) async {},
        ),
      ],
    );
    addTearDown(container.dispose);
    const session = ChatSession(
      channelId: 'g_send_failure',
      channelType: WKChannelType.group,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'g_send_failure',
            channelType: WKChannelType.group,
            channelName: 'Send Failure',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey<String>('chat-input-field'));
    await tester.enterText(input, 'retry this message');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('chat-send-button')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));

    expect(gateway.sentContents, hasLength(1));
    expect(
      container.read(chatComposerProvider(session)).text,
      'retry this message',
    );
    expect(find.text('发送失败，消息已保留，请检查网络后重试'), findsOneWidget);
  });

  testWidgets('in-flight send ignores repeated button and Enter submits', (
    tester,
  ) async {
    final sendCompleter = Completer<void>();
    final gateway = _FakeChatSceneGateway(sendCompleter: sendCompleter);
    addTearDown(gateway.dispose);
    final container = ProviderContainer(
      overrides: [
        _realtimeTelemetryNoTimerOverride(),
        messageListProvider.overrideWith(
          (ref, session) => _StaticMessageListNotifier(
            session.channelId,
            session.channelType,
            const <WKMsg>[],
          ),
        ),
        chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
        _memoryChatComposerOverride(),
        chatMarkConversationReadProvider.overrideWithValue(
          (session, messageIds) async {},
        ),
      ],
    );
    addTearDown(container.dispose);
    const session = ChatSession(
      channelId: 'g_send_dedup',
      channelType: WKChannelType.group,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'g_send_dedup',
            channelType: WKChannelType.group,
            channelName: 'Send Dedup',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey<String>('chat-input-field'));
    await tester.tap(input);
    await tester.enterText(input, 'send exactly once');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('chat-send-button')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.tap(find.byKey(const ValueKey<String>('chat-send-button')));
    await tester.pump();

    expect(gateway.sentContents, hasLength(1));

    sendCompleter.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));

    expect(container.read(chatComposerProvider(session)).text, isEmpty);
  });

  testWidgets('hardware Enter sends composer text and clears the input', (
    tester,
  ) async {
    final gateway = _FakeChatSceneGateway();
    addTearDown(gateway.dispose);
    final container = ProviderContainer(
      overrides: [
        _realtimeTelemetryNoTimerOverride(),
        messageListProvider.overrideWith(
          (ref, session) => _StaticMessageListNotifier(
            session.channelId,
            session.channelType,
            const <WKMsg>[],
          ),
        ),
        chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
        _memoryChatComposerOverride(),
        chatMarkConversationReadProvider.overrideWithValue(
          (session, messageIds) async {},
        ),
      ],
    );
    addTearDown(container.dispose);
    const session = ChatSession(
      channelId: 'g_keyboard_send',
      channelType: WKChannelType.group,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'g_keyboard_send',
            channelType: WKChannelType.group,
            channelName: 'Keyboard Send',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey<String>('chat-input-field'));
    await tester.tap(input);
    await tester.enterText(input, 'desktop enter send');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));

    expect(gateway.sentContents, hasLength(1));
    final sent = gateway.sentContents.single as WKTextContent;
    expect(sent.content, 'desktop enter send');
    expect(container.read(chatComposerProvider(session)).text, isEmpty);
  });

  testWidgets('Shift Enter inserts a newline without sending', (tester) async {
    final gateway = _FakeChatSceneGateway();
    addTearDown(gateway.dispose);
    final container = ProviderContainer(
      overrides: [
        _realtimeTelemetryNoTimerOverride(),
        messageListProvider.overrideWith(
          (ref, session) => _StaticMessageListNotifier(
            session.channelId,
            session.channelType,
            const <WKMsg>[],
          ),
        ),
        chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
        _memoryChatComposerOverride(),
        chatMarkConversationReadProvider.overrideWithValue(
          (session, messageIds) async {},
        ),
      ],
    );
    addTearDown(container.dispose);
    const session = ChatSession(
      channelId: 'g_keyboard_newline',
      channelType: WKChannelType.group,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'g_keyboard_newline',
            channelType: WKChannelType.group,
            channelName: 'Keyboard Newline',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey<String>('chat-input-field'));
    await tester.tap(input);
    await tester.enterText(input, 'line one');
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(input);
    expect(textField.controller?.text, 'line one\n');
    expect(container.read(chatComposerProvider(session)).text, 'line one\n');
    expect(gateway.sentContents, isEmpty);
    await tester.pump(const Duration(milliseconds: 350));
  });

  testWidgets(
    'album toolbar sends the picked image content through the scene gateway',
    (tester) async {
      final gateway = _FakeChatSceneGateway();
      final imageContent = WKImageContent(320, 180)
        ..localPath = 'C:/tmp/album.png';
      final mediaService = _FakeChatMediaActionService(
        imageContent: imageContent,
      );
      addTearDown(gateway.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _realtimeTelemetryNoTimerOverride(),
            messageListProvider.overrideWith(
              (ref, session) => _EmptyMessageListNotifier(
                session.channelId,
                session.channelType,
              ),
            ),
            chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
            chatMediaActionServiceProvider.overrideWithValue(mediaService),
          ],
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_media',
              channelType: WKChannelType.personal,
              channelName: 'Media Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chat-toolbar-wk_chat_toolbar_album'),
        ),
      );
      await tester.pumpAndSettle();

      expect(gateway.sentContents, hasLength(1));
      expect(gateway.sentContents.single, same(imageContent));
      expect(gateway.sentChannels.single, '1:u_media');
    },
  );

  testWidgets(
    'more panel sends attachments and composer rich text through the scene gateway',
    (tester) async {
      final gateway = _FakeChatSceneGateway();
      final imageContent = WKImageContent(640, 360)
        ..localPath = 'C:/tmp/panel.png';
      final fileContent = WKFileContent()
        ..localPath = 'C:/tmp/spec.pdf'
        ..name = 'spec.pdf'
        ..size = 4096
        ..suffix = 'pdf';
      final locationContent = WKLocationContent()
        ..latitude = 31.2304
        ..longitude = 121.4737
        ..title = 'Shanghai'
        ..address = 'Shanghai, China';
      final cardContent = WKCardContent('u_card', 'Alice');
      final richTextContent = WKRichTextContent(
        title: 'Release Notes',
        body: 'Rich text body',
      );
      final mediaService = _FakeChatMediaActionService(
        imageContent: imageContent,
        fileContent: fileContent,
        locationContent: locationContent,
        cardContent: cardContent,
        richTextContent: richTextContent,
      );
      addTearDown(gateway.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _realtimeTelemetryNoTimerOverride(),
            messageListProvider.overrideWith(
              (ref, session) => _EmptyMessageListNotifier(
                session.channelId,
                session.channelType,
              ),
            ),
            chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
            chatMediaActionServiceProvider.overrideWithValue(mediaService),
          ],
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_media',
              channelType: WKChannelType.personal,
              channelName: 'Media Chat',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> openMorePanel() async {
        await tester.tap(
          find.byKey(
            const ValueKey<String>('chat-toolbar-wk_chat_toolbar_more'),
          ),
        );
        await tester.pumpAndSettle();
      }

      await openMorePanel();
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-function-chooseImg')),
      );
      await tester.pumpAndSettle();

      await openMorePanel();
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-function-chooseFile')),
      );
      await tester.pumpAndSettle();

      await openMorePanel();
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-function-sendLocation')),
      );
      await tester.pumpAndSettle();

      await openMorePanel();
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-function-chooseCard')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-compose-rich-text-button')),
      );
      await tester.pumpAndSettle();

      expect(gateway.sentContents, hasLength(5));
      expect(gateway.sentContents[0], same(imageContent));
      expect(gateway.sentContents[1], same(fileContent));
      expect(gateway.sentContents[2], same(locationContent));
      expect(gateway.sentContents[3], same(cardContent));
      expect(gateway.sentContents[4], same(richTextContent));
      expect(gateway.sentChannels, everyElement(equals('1:u_media')));
    },
  );

  testWidgets('more panel extension item invokes its onClick callback', (
    tester,
  ) async {
    final tappedSids = <String>[];
    final slotRegistry = SlotRegistry();
    slotRegistry.register(
      chatFunctionSlot,
      SlotEntry<ChatToolbarSlotContext, ChatFunctionMenu>(
        id: 'chat_function.extension.action',
        priority: 1,
        build: (_) => ChatFunctionMenu(
          sid: 'extensionAction',
          text: 'Extension Action',
          onClick: tappedSids.add,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, session) => _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            ),
          ),
          slotRegistryProvider.overrideWithValue(slotRegistry),
        ],
        child: const MaterialApp(
          home: ChatPage(
            channelId: 'u_extension',
            channelType: WKChannelType.personal,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-toolbar-wk_chat_toolbar_more')),
    );
    await tester.pumpAndSettle();

    final extensionItem = find.byKey(
      const ValueKey<String>('chat-function-extensionAction'),
    );
    expect(extensionItem, findsOneWidget);

    await tester.tap(extensionItem);
    await tester.pumpAndSettle();

    expect(tappedSids, <String>['extensionAction']);
  });

  testWidgets(
    'more panel routes attachments and composer rich text through dispatcher',
    (tester) async {
      final gateway = _FakeChatSceneGateway();
      final imageContent = WKImageContent(640, 360)
        ..localPath = 'C:/tmp/dispatcher-image.png';
      final fileContent = WKFileContent()
        ..localPath = 'C:/tmp/spec.pdf'
        ..name = 'spec.pdf'
        ..size = 4096
        ..suffix = 'pdf';
      final locationContent = WKLocationContent()
        ..latitude = 31.2304
        ..longitude = 121.4737
        ..title = 'Shanghai'
        ..address = 'Shanghai, China';
      final cardContent = WKCardContent('u_card_dispatcher', 'Dispatcher User');
      final richTextContent = WKRichTextContent(
        title: 'Dispatcher Rich',
        body: 'Routed through dispatcher',
      );
      final dispatcher = _FakeChatActionDispatcher(
        resultsById: <ChatActionId, ChatActionDispatchResult>{
          ChatActionId.chooseImage: ChatActionMessageResult(imageContent),
          ChatActionId.chooseFile: ChatActionMessageResult(fileContent),
          ChatActionId.sendLocation: ChatActionMessageResult(locationContent),
          ChatActionId.chooseCard: ChatActionMessageResult(cardContent),
          ChatActionId.composeRichText: ChatActionMessageResult(
            richTextContent,
          ),
        },
      );
      addTearDown(gateway.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _realtimeTelemetryNoTimerOverride(),
            messageListProvider.overrideWith(
              (ref, session) => _EmptyMessageListNotifier(
                session.channelId,
                session.channelType,
              ),
            ),
            chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
            chatActionDispatcherProvider.overrideWithValue(dispatcher),
          ],
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_media',
              channelType: WKChannelType.personal,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> tapAction(String sid) async {
        await tester.tap(
          find.byKey(
            const ValueKey<String>('chat-toolbar-wk_chat_toolbar_more'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey<String>('chat-function-$sid')));
        await tester.pumpAndSettle();
      }

      await tapAction('chooseImg');
      await tapAction('chooseFile');
      await tapAction('sendLocation');
      await tapAction('chooseCard');
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-compose-rich-text-button')),
      );
      await tester.pumpAndSettle();

      expect(dispatcher.requestedIds, <ChatActionId>[
        ChatActionId.chooseImage,
        ChatActionId.chooseFile,
        ChatActionId.sendLocation,
        ChatActionId.chooseCard,
        ChatActionId.composeRichText,
      ]);
      expect(gateway.sentContents, hasLength(5));
      expect(gateway.sentContents[0], same(imageContent));
      expect(gateway.sentContents[1], same(fileContent));
      expect(gateway.sentContents[2], same(locationContent));
      expect(gateway.sentContents[3], same(cardContent));
      expect(gateway.sentContents[4], same(richTextContent));
      expect(gateway.sentChannels, everyElement(equals('1:u_media')));
    },
  );

  testWidgets(
    'dispatcher attachment send keeps reply info and clears pending reply state',
    (tester) async {
      final replyMessage = WKMsg()
        ..messageID = 'mid:reply-attachment'
        ..clientMsgNO = 'client:reply-attachment'
        ..channelID = 'g_reply_attachment'
        ..channelType = WKChannelType.group
        ..fromUID = 'u_other'
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('quoted source');
      final gateway = _FakeChatSceneGateway();
      addTearDown(gateway.dispose);
      final fileContent = WKFileContent()
        ..localPath = 'C:/tmp/reply-spec.pdf'
        ..name = 'reply-spec.pdf'
        ..size = 2048
        ..suffix = 'pdf';
      final dispatcher = _FakeChatActionDispatcher(
        resultsById: <ChatActionId, ChatActionDispatchResult>{
          ChatActionId.chooseFile: ChatActionMessageResult(fileContent),
        },
      );
      final container = ProviderContainer(
        overrides: [
          _realtimeTelemetryNoTimerOverride(),
          messageListProvider.overrideWith(
            (ref, session) => _StaticMessageListNotifier(
              session.channelId,
              session.channelType,
              session.channelId == 'g_reply_attachment'
                  ? <WKMsg>[replyMessage]
                  : const <WKMsg>[],
            ),
          ),
          chatMarkConversationReadProvider.overrideWithValue(
            (session, messageIds) async {},
          ),
          chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
          chatActionDispatcherProvider.overrideWithValue(dispatcher),
        ],
      );
      addTearDown(container.dispose);
      const session = ChatSession(
        channelId: 'g_reply_attachment',
        channelType: WKChannelType.group,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'g_reply_attachment',
              channelType: WKChannelType.group,
              channelName: 'Reply Attachment Group',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      container
          .read(chatComposerProvider(session).notifier)
          .setPendingReply(
            messageId: 'mid:reply-attachment',
            preview: 'quoted source',
          );
      container
          .read(chatSceneControllerProvider(session).notifier)
          .enterReplyMode();
      await tester.pumpAndSettle();

      expect(
        container.read(chatComposerProvider(session)).pendingReplyMessageId,
        'mid:reply-attachment',
      );
      expect(
        container.read(chatSceneControllerProvider(session)).mode,
        ChatSceneMode.replying,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-toolbar-wk_chat_toolbar_more')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-function-chooseFile')),
      );
      await tester.pumpAndSettle();

      expect(dispatcher.requestedIds.single, ChatActionId.chooseFile);
      expect(gateway.sentContents, hasLength(1));
      final sent = gateway.sentContents.single as WKFileContent;
      expect(sent.reply, isNotNull);
      expect(sent.reply!.messageId, 'mid:reply-attachment');
      expect(
        container.read(chatComposerProvider(session)).pendingReplyMessageId,
        isNull,
      );
      expect(
        container.read(chatSceneControllerProvider(session)).mode,
        ChatSceneMode.normal,
      );
    },
  );

  testWidgets(
    'press hold release sends voice content through the shell gateway',
    (tester) async {
      final gateway = _FakeChatSceneGateway();
      final voiceContent = WKVoiceContent(2)..localPath = 'C:/tmp/demo.m4a';
      final voiceService = _FakeChatVoiceActionService(
        stopResult: ChatVoiceReadyResult(
          content: voiceContent,
          duration: const Duration(seconds: 2),
        ),
      );
      addTearDown(gateway.dispose);
      addTearDown(voiceService.dispose);

      await _pumpVoiceScene(
        tester,
        gateway: gateway,
        voiceService: voiceService,
      );

      expect(
        find.byKey(const ValueKey<String>('chat-voice-record-button')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chat-toolbar-wk_chat_toolbar_voice'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('chat-voice-record-button')),
        findsOneWidget,
      );

      await tester.longPress(
        find.byKey(const ValueKey<String>('chat-voice-record-button')),
      );
      await tester.pumpAndSettle();

      expect(voiceService.startCalls, 1);
      expect(voiceService.stopCalls, 1);
      expect(voiceService.stopShouldSendValues, <bool>[true]);
      expect(gateway.sentContents, hasLength(1));
      expect(gateway.sentContents.single, same(voiceContent));
      expect(gateway.sentChannels.single, '1:u_voice');
    },
  );

  testWidgets('dragging upward into the cancel zone discards the recording', (
    tester,
  ) async {
    final gateway = _FakeChatSceneGateway();
    final voiceService = _FakeChatVoiceActionService(
      stopResult: const ChatVoiceDiscardedResult(
        ChatVoiceDiscardReason.cancelled,
      ),
    );
    addTearDown(gateway.dispose);
    addTearDown(voiceService.dispose);

    await _pumpVoiceScene(tester, gateway: gateway, voiceService: voiceService);

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-toolbar-wk_chat_toolbar_voice')),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey<String>('chat-voice-record-button')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, -110));
    await tester.pump(const Duration(milliseconds: 80));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(voiceService.cancelZoneValues, contains(true));
    expect(voiceService.stopShouldSendValues, <bool>[false]);
    expect(gateway.sentContents, isEmpty);
  });

  testWidgets('disposing the voice scene cancels an active recording safely', (
    tester,
  ) async {
    final gateway = _FakeChatSceneGateway();
    final voiceService = _FakeChatVoiceActionService();
    addTearDown(gateway.dispose);
    addTearDown(voiceService.dispose);

    await voiceService.startRecording();
    await _pumpVoiceScene(tester, gateway: gateway, voiceService: voiceService);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(voiceService.cancelCalls, 1);
    expect(
      voiceService.recordingStateListenable.value.phase,
      ChatVoiceRecordingPhase.idle,
    );
  });

  testWidgets('permission denied keeps timeline clean and shows feedback', (
    tester,
  ) async {
    final gateway = _FakeChatSceneGateway();
    final voiceService = _FakeChatVoiceActionService(
      startResult: false,
      failedStartState: const ChatVoiceRecordingState(
        phase: ChatVoiceRecordingPhase.permissionDenied,
        errorMessage:
            '\u9700\u8981\u5141\u8bb8\u9ea6\u514b\u98ce\u6743\u9650\u540e\u624d\u80fd\u53d1\u9001\u8bed\u97f3',
      ),
    );
    addTearDown(gateway.dispose);
    addTearDown(voiceService.dispose);

    await _pumpVoiceScene(tester, gateway: gateway, voiceService: voiceService);

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-toolbar-wk_chat_toolbar_voice')),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey<String>('chat-voice-record-button')),
    );
    await tester.pumpAndSettle();

    expect(gateway.sentContents, isEmpty);
    expect(voiceService.stopCalls, 0);
    expect(voiceService.stopShouldSendValues, isEmpty);
    expect(
      find.text(
        '\u9700\u8981\u5141\u8bb8\u9ea6\u514b\u98ce\u6743\u9650\u540e\u624d\u80fd\u53d1\u9001\u8bed\u97f3',
      ),
      findsOneWidget,
    );
  });

  testWidgets('too short recording keeps timeline clean and shows feedback', (
    tester,
  ) async {
    final gateway = _FakeChatSceneGateway();
    final voiceService = _FakeChatVoiceActionService(
      stopResult: const ChatVoiceDiscardedResult(
        ChatVoiceDiscardReason.tooShort,
      ),
    );
    addTearDown(gateway.dispose);
    addTearDown(voiceService.dispose);

    await _pumpVoiceScene(tester, gateway: gateway, voiceService: voiceService);

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-toolbar-wk_chat_toolbar_voice')),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey<String>('chat-voice-record-button')),
    );
    await tester.pumpAndSettle();

    expect(gateway.sentContents, isEmpty);
    expect(find.text('\u5f55\u97f3\u65f6\u95f4\u592a\u77ed'), findsOneWidget);
  });

  testWidgets('stop failure keeps timeline clean and shows error feedback', (
    tester,
  ) async {
    final gateway = _FakeChatSceneGateway();
    final voiceService = _FakeChatVoiceActionService(
      stopResult: const ChatVoiceStopFailure(
        '\u8bed\u97f3\u5f55\u5236\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5',
      ),
    );
    addTearDown(gateway.dispose);
    addTearDown(voiceService.dispose);

    await _pumpVoiceScene(tester, gateway: gateway, voiceService: voiceService);

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-toolbar-wk_chat_toolbar_voice')),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey<String>('chat-voice-record-button')),
    );
    await tester.pumpAndSettle();

    expect(gateway.sentContents, isEmpty);
    expect(
      find.text('\u8bed\u97f3\u5f55\u5236\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpVoiceScene(
  WidgetTester tester, {
  required _FakeChatSceneGateway gateway,
  required _FakeChatVoiceActionService voiceService,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        _realtimeTelemetryNoTimerOverride(),
        messageListProvider.overrideWith(
          (ref, session) =>
              _EmptyMessageListNotifier(session.channelId, session.channelType),
        ),
        chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
        chatVoiceActionServiceProvider.overrideWithValue(voiceService),
      ],
      child: const MaterialApp(
        home: ChatPage(
          channelId: 'u_voice',
          channelType: WKChannelType.personal,
          channelName: 'Voice Chat',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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

class _TrackingMessageListNotifier extends MessageListNotifier {
  _TrackingMessageListNotifier(super.channelId, super.channelType);

  final List<int> loadAroundOrderSeqCalls = <int>[];

  @override
  Future<void> loadMessages() async {
    state = <WKMsg>[];
  }

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> loadAroundOrderSeq(int aroundOrderSeq) async {
    loadAroundOrderSeqCalls.add(aroundOrderSeq);
    state = <WKMsg>[];
  }
}

class _FakeFavoriteRegistry implements ChatMessageFavoriteRegistry {
  _FakeFavoriteRegistry({Set<String> seedKeys = const <String>{}})
    : _keys = {...seedKeys};

  final Set<String> _keys;

  @override
  bool contains(String key) => _keys.contains(key);

  @override
  Future<void> markFavorited(String key) async {
    _keys.add(key);
  }

  @override
  Set<String> snapshot() => Set<String>.unmodifiable(_keys);
}

class _FakeChatMediaActionService implements ChatMediaActionService {
  _FakeChatMediaActionService({
    this.imageContent,
    this.fileContent,
    this.locationContent,
    this.cardContent,
    this.richTextContent,
  });

  final WKImageContent? imageContent;
  final WKFileContent? fileContent;
  final WKLocationContent? locationContent;
  final WKCardContent? cardContent;
  final WKRichTextContent? richTextContent;

  @override
  Future<WKMessageContent?> buildDroppedFile(
    ChatDroppedFileSelection selection,
  ) async => null;

  @override
  Future<WKCardContent?> pickCard(BuildContext context) async => cardContent;

  @override
  Future<WKFileContent?> pickFile(
    BuildContext context, {
    String channelId = '',
    int channelType = 0,
  }) async => fileContent;

  @override
  Future<WKImageContent?> pickImage(
    BuildContext context, {
    String channelId = '',
    int channelType = 0,
  }) async => imageContent;

  @override
  Future<WKLocationContent?> pickLocation(BuildContext context) async =>
      locationContent;

  @override
  Future<WKRichTextContent?> pickRichText(BuildContext context) async =>
      richTextContent;
}

class _FakeChatActionDispatcher extends ChatActionDispatcher {
  _FakeChatActionDispatcher({
    Map<ChatActionId, ChatActionDispatchResult>? resultsById,
  }) : _resultsById = resultsById == null
           ? const <ChatActionId, ChatActionDispatchResult>{}
           : Map<ChatActionId, ChatActionDispatchResult>.unmodifiable(
               resultsById,
             ),
       super(
         pickImage: _pickImageUnused,
         pickFile: _pickFileUnused,
         pickLocation: _pickLocationUnused,
         pickCard: _pickCardUnused,
         pickRichText: _pickRichTextUnused,
       );

  final Map<ChatActionId, ChatActionDispatchResult> _resultsById;
  final List<ChatActionId> requestedIds = <ChatActionId>[];

  @override
  Future<ChatActionDispatchResult> dispatch(
    ChatActionId id,
    ChatActionDispatchContext context,
  ) async {
    requestedIds.add(id);
    return _resultsById[id] ?? const ChatActionNoopResult();
  }

  static Future<WKImageContent?> _pickImageUnused(
    ChatActionDispatchContext context,
  ) async => null;

  static Future<WKFileContent?> _pickFileUnused(
    ChatActionDispatchContext context,
  ) async => null;

  static Future<WKLocationContent?> _pickLocationUnused(
    ChatActionDispatchContext context,
  ) async => null;

  static Future<WKCardContent?> _pickCardUnused(
    ChatActionDispatchContext context,
  ) async => null;

  static Future<WKRichTextContent?> _pickRichTextUnused(
    ChatActionDispatchContext context,
  ) async => null;
}

class _FakeChatVoiceActionService implements ChatVoiceActionService {
  _FakeChatVoiceActionService({
    this.startResult = true,
    this.stopResult,
    ChatVoiceRecordingState? failedStartState,
  }) : _failedStartState =
           failedStartState ??
           const ChatVoiceRecordingState(
             phase: ChatVoiceRecordingPhase.permissionDenied,
             errorMessage:
                 '\u9700\u8981\u5141\u8bb8\u9ea6\u514b\u98ce\u6743\u9650\u540e\u624d\u80fd\u53d1\u9001\u8bed\u97f3',
           );

  final bool startResult;
  final ChatVoiceStopResult? stopResult;
  final ChatVoiceRecordingState _failedStartState;
  final ValueNotifier<ChatVoiceRecordingState> _stateNotifier =
      ValueNotifier<ChatVoiceRecordingState>(
        const ChatVoiceRecordingState.idle(),
      );

  final List<bool> cancelZoneValues = <bool>[];
  final List<bool> stopShouldSendValues = <bool>[];

  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  ValueListenable<ChatVoiceRecordingState> get recordingStateListenable =>
      _stateNotifier;

  @override
  Future<void> cancelRecording() async {
    cancelCalls++;
    _stateNotifier.value = const ChatVoiceRecordingState.idle();
  }

  @override
  void dispose() {
    _stateNotifier.dispose();
  }

  @override
  void setCancelCandidate(bool value) {
    cancelZoneValues.add(value);
    final current = _stateNotifier.value;
    if (current.phase != ChatVoiceRecordingPhase.recording &&
        current.phase != ChatVoiceRecordingPhase.cancelCandidate) {
      return;
    }
    _stateNotifier.value = current.copyWith(
      phase: value
          ? ChatVoiceRecordingPhase.cancelCandidate
          : ChatVoiceRecordingPhase.recording,
    );
  }

  @override
  Future<bool> startRecording() async {
    startCalls++;
    if (!startResult) {
      _stateNotifier.value = _failedStartState;
      return false;
    }
    _stateNotifier.value = const ChatVoiceRecordingState(
      phase: ChatVoiceRecordingPhase.recording,
    );
    return true;
  }

  @override
  Future<ChatVoiceStopResult> stopRecording({required bool shouldSend}) async {
    stopCalls++;
    stopShouldSendValues.add(shouldSend);

    final ChatVoiceStopResult resolved;
    if (!shouldSend) {
      resolved = const ChatVoiceDiscardedResult(
        ChatVoiceDiscardReason.cancelled,
      );
    } else if (!startResult &&
        _stateNotifier.value.phase ==
            ChatVoiceRecordingPhase.permissionDenied) {
      resolved = const ChatVoiceDiscardedResult(
        ChatVoiceDiscardReason.permissionDenied,
      );
    } else {
      resolved =
          stopResult ??
          const ChatVoiceStopFailure(
            '\u8bed\u97f3\u5f55\u5236\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5',
          );
    }

    switch (resolved) {
      case ChatVoiceReadyResult():
        _stateNotifier.value = const ChatVoiceRecordingState(
          phase: ChatVoiceRecordingPhase.sendReady,
        );
        break;
      case ChatVoiceDiscardedResult():
        _stateNotifier.value = ChatVoiceRecordingState(
          phase: resolved.reason == ChatVoiceDiscardReason.tooShort
              ? ChatVoiceRecordingPhase.tooShort
              : ChatVoiceRecordingPhase.idle,
        );
        break;
      case ChatVoiceStopFailure():
        _stateNotifier.value = ChatVoiceRecordingState(
          phase: ChatVoiceRecordingPhase.sendFailed,
          errorMessage: resolved.message,
        );
        break;
    }
    return resolved;
  }
}

class _FakeChatSceneGateway extends ChatSceneGateway {
  _FakeChatSceneGateway({
    this.targets = const <ForwardTarget>[],
    this.pinnedSnapshot = const PinnedMessageSyncSnapshot(
      pinnedMessages: <PinnedMessageEntry>[],
      messages: <WKSyncMsg>[],
    ),
    this.sendCompleter,
    this.sendError,
    Set<String> failingFavoriteMessageIds = const <String>{},
    Map<String, List<MessageReaction>> initialReactionsByMessageId =
        const <String, List<MessageReaction>>{},
  }) : _failingFavoriteMessageIds = {...failingFavoriteMessageIds} {
    initialReactionsByMessageId.forEach((messageId, reactions) {
      _reactionCache[messageId] = List<MessageReaction>.from(
        reactions,
        growable: false,
      );
    });
  }

  final List<ForwardTarget> targets;
  final PinnedMessageSyncSnapshot pinnedSnapshot;
  final Completer<void>? sendCompleter;
  final Object? sendError;
  final List<Object> sentContents = <Object>[];
  final List<String> sentChannels = <String>[];
  final List<List<ForwardTarget>> forwardedTargets = <List<ForwardTarget>>[];
  final List<String> favoriteCalls = <String>[];
  final List<String> pinnedToggleCalls = <String>[];
  final List<String> pinnedClearCalls = <String>[];
  final List<String> pinnedSyncCalls = <String>[];
  final List<String> reactionCalls = <String>[];
  final Set<String> _failingFavoriteMessageIds;
  final Map<String, List<MessageReaction>> _reactionCache =
      <String, List<MessageReaction>>{};
  final StreamController<ReactionUpdate> _reactionController =
      StreamController<ReactionUpdate>.broadcast();

  void dispose() {
    _reactionController.close();
  }

  @override
  Future<void> addFavorite(WKMsg message) async {
    final messageId = message.messageID.trim();
    favoriteCalls.add(
      messageId.isNotEmpty ? messageId : message.clientMsgNO.trim(),
    );
    if (messageId.isNotEmpty &&
        _failingFavoriteMessageIds.contains(messageId)) {
      throw Exception('favorite failed for $messageId');
    }
  }

  @override
  Future<void> editMessage(WKMsg message, WKTextContent content) async {}

  @override
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  }) async {
    return targets;
  }

  @override
  Future<void> recallMessage(WKMsg message) async {}

  @override
  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
  }) async {
    sentContents.add(content);
    sentChannels.add('$channelType:$channelId');
    final completer = sendCompleter;
    if (completer != null) {
      await completer.future;
    }
    final error = sendError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {
    forwardedTargets.add(List<ForwardTarget>.from(targets, growable: false));
  }

  @override
  Future<void> togglePinnedMessage(WKMsg message) async {
    pinnedToggleCalls.add(message.messageID);
  }

  @override
  Future<PinnedMessageSyncSnapshot> syncPinnedMessages({
    required String channelId,
    required int channelType,
    int version = 0,
  }) async {
    pinnedSyncCalls.add('$channelType:$channelId:$version');
    return pinnedSnapshot;
  }

  @override
  Future<void> clearPinnedMessages({
    required String channelId,
    required int channelType,
  }) async {
    pinnedClearCalls.add('$channelType:$channelId');
  }

  @override
  List<MessageReaction> prepareReactions(WKMsg message) {
    return List<MessageReaction>.from(
      _reactionCache[message.messageID] ?? const <MessageReaction>[],
      growable: false,
    );
  }

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) async {
    reactionCalls.add('${message.messageID}:$emoji');
    final current = List<MessageReaction>.from(
      _reactionCache[message.messageID] ?? const <MessageReaction>[],
    );
    final existingMineIndex = current.indexWhere((reaction) => reaction.isMe);
    if (existingMineIndex != -1 && current[existingMineIndex].emoji == emoji) {
      current.removeAt(existingMineIndex);
    } else {
      if (existingMineIndex != -1) {
        current.removeAt(existingMineIndex);
      }
      current.add(
        MessageReaction(
          type: emoji.runes.isNotEmpty ? emoji.runes.first : 0,
          emoji: emoji,
          count: 1,
          isMe: true,
          userIds: const <String>['u_self'],
          usernames: const <String>['Self'],
        ),
      );
    }
    _reactionCache[message.messageID] = current;
    _reactionController.add(
      ReactionUpdate(
        messageId: message.messageID,
        reactions: List<MessageReaction>.unmodifiable(current),
      ),
    );
  }

  @override
  Stream<ReactionUpdate> watchReactionUpdates() => _reactionController.stream;
}

class _MemoryDraftStore implements DraftStore {
  final Map<String, MessageDraft> _drafts = <String, MessageDraft>{};

  @override
  MessageDraft? getDraft(String channelId, int channelType) {
    return _drafts['${channelType}_$channelId'];
  }

  @override
  Future<void> saveDraft({
    required String channelId,
    required int channelType,
    required String content,
    String? replyMsgId,
    String? replyContent,
  }) async {
    final key = '${channelType}_$channelId';
    final normalizedReplyMsgId = _normalizeNullable(replyMsgId);
    final normalizedReplyContent = _normalizeNullable(replyContent);
    if (content.trim().isEmpty && normalizedReplyMsgId == null) {
      _drafts.remove(key);
      return;
    }
    _drafts[key] = MessageDraft(
      channelId: channelId,
      channelType: channelType,
      content: content,
      updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      replyMsgId: normalizedReplyMsgId,
      replyContent: normalizedReplyContent,
    );
  }

  String? _normalizeNullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

Override _memoryChatComposerOverride() {
  final draftStore = _MemoryDraftStore();
  return chatComposerProvider.overrideWith((ref, session) {
    final controller = ChatComposerController(
      channelId: session.channelId,
      channelType: session.channelType,
      draftStore: draftStore,
    );
    unawaited(controller.initialize());
    return controller;
  });
}

SlotRegistry buildExtendedChatFunctionRegistryLegacyReference() {
  final registry = SlotRegistry();
  registry.register(
    chatFunctionSlot,
    SlotEntry<ChatToolbarSlotContext, ChatFunctionMenu>(
      id: 'chat_function.choose_file',
      priority: 99,
      build: (_) => ChatFunctionMenu(
        sid: 'chooseFile',
        icon: WKReferenceAssets.chatFunctionFile,
        text: '鏂囦欢',
      ),
    ),
  );
  registry.register(
    chatFunctionSlot,
    SlotEntry<ChatToolbarSlotContext, ChatFunctionMenu>(
      id: 'chat_function.send_location',
      priority: 97,
      build: (_) => ChatFunctionMenu(
        sid: 'sendLocation',
        icon: WKReferenceAssets.chatFunctionLocation,
        text: '浣嶇疆',
      ),
    ),
  );
  return registry;
}
