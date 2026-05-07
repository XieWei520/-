import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/config/im_config.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/chat_session.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/data/models/wk_custom_content.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/data/providers/user_provider.dart';
import 'package:wukong_im_app/modules/conversation/conversation_activity_registry.dart';
import 'package:wukong_im_app/modules/chat/chat_flame_message_runtime.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/chat/chat_action_dispatcher.dart';
import 'package:wukong_im_app/modules/chat/chat_gif_panel_service.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukong_im_app/modules/chat/chat_typing_gateway.dart';
import 'package:wukong_im_app/modules/chat/expression/chat_expression_models.dart';
import 'package:wukong_im_app/modules/chat/expression/chat_expression_registry.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_emoji_panel.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_expression_panel.dart';
import 'package:wukong_im_app/modules/location/location_view_page.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry_provider.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';
import 'package:wukong_im_app/widgets/wk_reference_assets.dart';
import 'package:wukong_im_app/widgets/wk_web_ui_tokens.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_entry.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/providers/slot_registry_provider.dart';
import 'package:wukong_im_app/wk_endpoint/slots/chat_slots.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_handler.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_manager.dart';
import 'package:wukong_im_app/wukong_base/endpoint/entity/chat_toolbar_menu.dart';
import 'package:wukong_im_app/wukong_base/emoji/android_emoji_catalog.dart';
import 'package:wukong_im_app/wukong_base/endpoint/menu/endpoint_menu.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukong_im_app/wukong_base/views/image_viewer.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukong_im_app/wukong_uikit/user/user_detail_page.dart';
import 'package:wukong_im_app/wukong_robot/robot_service.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/cmd.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_gif_content.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_rich_text_content.dart';
import 'package:wukongimfluttersdk/model/wk_sticker_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

Override _testRealtimeTelemetryOverride() {
  return realtimeRolloutTelemetryProvider.overrideWith((ref) {
    final telemetry = RealtimeRolloutTelemetry(flushInterval: Duration.zero);
    ref.onDispose(telemetry.dispose);
    return telemetry;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('desktop chat pages use the warm workbench style on Windows', () {
    final previousOverride = debugDefaultTargetPlatformOverride;
    addTearDown(() => debugDefaultTargetPlatformOverride = previousOverride);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    expect(shouldUseWarmWorkbenchStyle(), isTrue);
  });

  setUpAll(() async {
    WKAvatar.setBytesLoaderForTesting((_) async => null);
    SharedPreferences.setMockInitialValues({});
    await StorageUtils.init();
    await StorageUtils.setUid('u_self');
    ApiClient.instance.dio.httpClientAdapter = _ImmediateSuccessAdapter();
  });

  tearDownAll(() {
    WKAvatar.setBytesLoaderForTesting(null);
  });

  setUp(() {
    RobotService.instance.clearCache();
  });

  Widget wrapWithApp(
    Widget child, {
    NavigatorObserver? navigatorObserver,
    ChatTypingGateway typingGateway = const _NoopTypingGateway(),
    List<Override> overrides = const <Override>[],
  }) {
    return ProviderScope(
      overrides: [
        _testRealtimeTelemetryOverride(),
        messageListProvider.overrideWith(
          (ref, session) =>
              _EmptyMessageListNotifier(session.channelId, session.channelType),
        ),
        chatTypingGatewayProvider.overrideWithValue(typingGateway),
        ...overrides,
      ],
      child: MaterialApp(
        home: child,
        navigatorObservers: navigatorObserver == null
            ? const <NavigatorObserver>[]
            : <NavigatorObserver>[navigatorObserver],
      ),
    );
  }

  Future<void> pumpChatPage(
    WidgetTester tester, {
    required String channelId,
    required int channelType,
    required String channelName,
    String? channelCategory,
    int initialVipLevel = 0,
    NavigatorObserver? navigatorObserver,
    ChatTypingGateway typingGateway = const _NoopTypingGateway(),
    List<Override> overrides = const <Override>[],
  }) async {
    await tester.pumpWidget(
      wrapWithApp(
        ChatPage(
          channelId: channelId,
          channelType: channelType,
          channelName: channelName,
          channelCategory: channelCategory,
          initialVipLevel: initialVipLevel,
        ),
        navigatorObserver: navigatorObserver,
        typingGateway: typingGateway,
        overrides: overrides,
      ),
    );
    await tester.pump();
    expect(find.byType(ChatPageShell), findsOneWidget);
  }

  Future<bool> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration step = const Duration(milliseconds: 100),
    int maxTicks = 20,
  }) async {
    for (var tick = 0; tick < maxTicks; tick += 1) {
      await tester.pump(step);
      if (finder.evaluate().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> runWithAndroidPhoneViewport(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    final previousOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = previousOverride;
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    }
  }

  testWidgets('Android chat header tints the legacy white back icon', (
    tester,
  ) async {
    await runWithAndroidPhoneViewport(tester, () async {
      await pumpChatPage(
        tester,
        channelId: 'fileHelper',
        channelType: WKChannelType.personal,
        channelName: 'Android Back',
      );
      await tester.pump(const Duration(milliseconds: 350));

      final backButton = find.byKey(const ValueKey<String>('chat-back-button'));
      expect(backButton, findsOneWidget);

      final image = tester.widget<Image>(
        find.descendant(of: backButton, matching: find.byType(Image)).first,
      );
      expect(image.color, WKWebColors.textPrimary);
    });
  });

  testWidgets('Android composer aligns action buttons with the input field', (
    tester,
  ) async {
    await runWithAndroidPhoneViewport(tester, () async {
      await pumpChatPage(
        tester,
        channelId: 'fileHelper',
        channelType: WKChannelType.personal,
        channelName: 'Android Composer',
      );
      await tester.pump(const Duration(milliseconds: 350));

      final inputFinder = find.byKey(
        const ValueKey<String>('chat-input-field'),
      );
      final addFinder = find.byKey(
        const ValueKey<String>('chat-compose-plus-button'),
      );
      final sendFinder = find.byKey(const ValueKey<String>('chat-send-button'));
      final sendMotionFinder = find.byKey(
        const ValueKey<String>('chat-send-button-motion'),
      );

      expect(inputFinder, findsOneWidget);
      expect(addFinder, findsOneWidget);
      expect(sendFinder, findsOneWidget);
      expect(sendMotionFinder, findsOneWidget);

      final inputRect = tester.getRect(inputFinder);
      final addRect = tester.getRect(addFinder);
      final sendRect = tester.getRect(sendFinder);
      final sendMotion = tester.widget<AnimatedScale>(sendMotionFinder);
      final sendLayoutHeight = sendRect.height / sendMotion.scale;

      expect(addRect.height, greaterThanOrEqualTo(44));
      expect(sendLayoutHeight, greaterThanOrEqualTo(44));
      expect(
        (addRect.center.dy - inputRect.center.dy).abs(),
        lessThanOrEqualTo(1),
      );
      expect(
        (sendRect.center.dy - inputRect.center.dy).abs(),
        lessThanOrEqualTo(1),
      );

      final disabledSendIcon = tester.widget<Image>(
        find.descendant(of: sendFinder, matching: find.byType(Image)).first,
      );
      expect(disabledSendIcon.color, WKWebColors.action);
    });
  });

  testWidgets(
    'robot chat shows Android menu button and sends bot commands with robot id',
    (tester) async {
      final originalAdapter = ApiClient.instance.dio.httpClientAdapter;
      ApiClient.instance.dio.httpClientAdapter = _RobotSyncAdapter();
      addTearDown(() {
        ApiClient.instance.dio.httpClientAdapter = originalAdapter;
      });

      final gateway = _RecordingChatSceneGateway();
      final channel = WKChannel('u_robot_menu', WKChannelType.personal)
        ..channelName = 'Robot Menu'
        ..robot = 1;
      WKIM.shared.channelManager.addOrUpdateChannel(channel);

      await pumpChatPage(
        tester,
        channelId: 'u_robot_menu',
        channelType: WKChannelType.personal,
        channelName: 'Robot Menu',
        overrides: <Override>[
          chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byKey(const ValueKey<String>('chat-robot-menu-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-robot-menu-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wave hello'), findsOneWidget);

      await tester.tap(find.text('Wave hello'));
      await tester.pumpAndSettle();

      expect(gateway.sentContents, hasLength(1));
      final content = gateway.sentContents.single as WKTextContent;
      expect(content.content, '/wave');
      expect(content.robotID, 'u_robot_menu');
      expect(content.entities, hasLength(1));
      expect(content.entities!.single.type, 'bot_command');
      expect(content.entities!.single.offset, 0);
      expect(content.entities!.single.length, '/wave'.length);
    },
  );

  testWidgets(
    'typing @gif query lazily syncs robot username and shows Android gif panel',
    (tester) async {
      final originalAdapter = ApiClient.instance.dio.httpClientAdapter;
      ApiClient.instance.dio.httpClientAdapter = _RobotSyncAdapter();
      addTearDown(() {
        ApiClient.instance.dio.httpClientAdapter = originalAdapter;
      });

      await pumpChatPage(
        tester,
        channelId: 'u_friend_gif_panel',
        channelType: WKChannelType.personal,
        channelName: 'Robot GIF',
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '@gif cat');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byKey(const ValueKey<String>('chat-robot-gif-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-robot-gif-item-0')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'typing @gif with trailing space shows Android robot placeholder hint',
    (tester) async {
      final originalAdapter = ApiClient.instance.dio.httpClientAdapter;
      ApiClient.instance.dio.httpClientAdapter = _RobotSyncAdapter();
      addTearDown(() {
        ApiClient.instance.dio.httpClientAdapter = originalAdapter;
      });

      await pumpChatPage(
        tester,
        channelId: 'u_friend_gif_placeholder',
        channelType: WKChannelType.personal,
        channelName: 'Robot GIF',
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '@gif ');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byKey(const ValueKey<String>('chat-robot-placeholder')),
        findsOneWidget,
      );
      expect(find.text('Search GIFs'), findsOneWidget);
    },
  );

  testWidgets('tapping Android gif panel result sends gif content', (
    tester,
  ) async {
    final originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.dio.httpClientAdapter = _RobotSyncAdapter();
    addTearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    final gateway = _RecordingChatSceneGateway();
    await pumpChatPage(
      tester,
      channelId: 'u_friend_gif_send',
      channelType: WKChannelType.personal,
      channelName: 'Robot GIF',
      overrides: <Override>[
        chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
      ],
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '@gif cat');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-robot-gif-item-0')),
    );
    await tester.pumpAndSettle();

    expect(gateway.sentContents, hasLength(1));
    final content = gateway.sentContents.single as WKGifContent;
    expect(content.url, 'https://example.com/cat.gif');
    expect(content.width, 120);
    expect(content.height, 120);
  });

  testWidgets(
    'chat page shows Android calling participants bar under the title area',
    (tester) async {
      final registry = ConversationActivityRegistry.instance;
      registry.clearAll();
      addTearDown(registry.clearAll);

      final cmd = WKCMD()
        ..cmd = 'sync_channel_state'
        ..param = <String, dynamic>{
          'channel_id': 'u_self',
          'channel_type': WKChannelType.personal,
          'from_uid': 'u_calling',
          'call_info': <String, dynamic>{
            'room_name': 'room-42',
            'calling_participants': <Map<String, String>>[
              <String, String>{'uid': 'u_calling', 'name': 'Alice'},
              <String, String>{'uid': 'u_friend', 'name': 'Bob'},
            ],
          },
        };
      await registry.handleCommand(cmd, currentUid: 'u_self');

      await pumpChatPage(
        tester,
        channelId: 'u_calling',
        channelType: WKChannelType.personal,
        channelName: 'Calling Demo',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chat-calling-participants-bar')),
        findsOneWidget,
      );
      expect(
        find.text('Alice\u3001Bob \u6b63\u5728\u901a\u8bdd'),
        findsOneWidget,
      );
      expect(find.text('room-42'), findsOneWidget);
    },
  );

  testWidgets(
    'typing updates composer state without rebuilding the viewport subtree',
    (tester) async {
      final session = ChatSession(
        channelId: 'u_kernel',
        channelType: WKChannelType.personal,
      );
      final message = WKMsg()
        ..messageID = 'm_kernel'
        ..channelID = session.channelId
        ..channelType = session.channelType
        ..fromUID = 'u_other'
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('hello kernel');
      final container = ProviderContainer(
        overrides: [
          _testRealtimeTelemetryOverride(),
          conversationPatchTelemetryProvider.overrideWithValue(
            _NoopConversationPatchTelemetry(),
          ),
          messageListProvider.overrideWith(
            (ref, providedSession) => _StaticMessageListNotifier(
              providedSession.channelId,
              providedSession.channelType,
              providedSession == session ? <WKMsg>[message] : const <WKMsg>[],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      var viewportBuilds = 0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChatPageShell(
              channelId: session.channelId,
              channelType: session.channelType,
              channelName: 'Kernel',
              onViewportBuild: () {
                viewportBuilds += 1;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final baselineBuilds = viewportBuilds;
      expect(container.read(chatComposerProvider(session)).text, isEmpty);

      await tester.enterText(find.byType(TextField).first, 'hello kernel');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        container.read(chatComposerProvider(session)).text,
        'hello kernel',
      );
      expect(viewportBuilds, baselineBuilds);
    },
  );

  testWidgets('keyboard inset changes translate without rebuilding viewport', (
    tester,
  ) async {
    final previousOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final session = ChatSession(
        channelId: 'u_keyboard_rebuild',
        channelType: WKChannelType.personal,
      );
      final message = WKMsg()
        ..messageID = 'm_keyboard_rebuild'
        ..channelID = session.channelId
        ..channelType = session.channelType
        ..fromUID = 'u_other'
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('keyboard rebuild guard');
      final container = ProviderContainer(
        overrides: [
          _testRealtimeTelemetryOverride(),
          conversationPatchTelemetryProvider.overrideWithValue(
            _NoopConversationPatchTelemetry(),
          ),
          messageListProvider.overrideWith(
            (ref, providedSession) => _StaticMessageListNotifier(
              providedSession.channelId,
              providedSession.channelType,
              providedSession == session ? <WKMsg>[message] : const <WKMsg>[],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      var viewportBuilds = 0;
      final chatShell = UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ChatPageShell(
            channelId: session.channelId,
            channelType: session.channelType,
            channelName: 'Keyboard Rebuild',
            onViewportBuild: () {
              viewportBuilds += 1;
            },
          ),
        ),
      );
      await tester.pumpWidget(
        MediaQuery(data: const MediaQueryData(), child: chatShell),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final baselineBuilds = viewportBuilds;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 280)),
          child: chatShell,
        ),
      );
      await tester.pump();

      final keyboardTransform = tester.widget<Transform>(
        find.byKey(const ValueKey<String>('chat-keyboard-inset-transform')),
      );
      expect(keyboardTransform.transform.getTranslation().y, -280);
      expect(viewportBuilds, baselineBuilds);
    } finally {
      debugDefaultTargetPlatformOverride = previousOverride;
    }
  });

  testWidgets(
    'chat page marks visible foreign messages read once and typing does not resubmit',
    (tester) async {
      final session = ChatSession(
        channelId: 'u_read_once',
        channelType: WKChannelType.personal,
      );
      final message = WKMsg()
        ..messageID = 'm_read_once'
        ..channelID = session.channelId
        ..channelType = session.channelType
        ..fromUID = 'u_other'
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('read me');
      final readCalls = <List<String>>[];
      final container = ProviderContainer(
        overrides: [
          _testRealtimeTelemetryOverride(),
          conversationPatchTelemetryProvider.overrideWithValue(
            _NoopConversationPatchTelemetry(),
          ),
          messageListProvider.overrideWith(
            (ref, providedSession) => _StaticMessageListNotifier(
              providedSession.channelId,
              providedSession.channelType,
              providedSession == session ? <WKMsg>[message] : const <WKMsg>[],
            ),
          ),
          chatMarkConversationReadProvider.overrideWithValue((
            chatSession,
            messageIds,
          ) async {
            readCalls.add(List<String>.from(messageIds));
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChatPageShell(
              channelId: session.channelId,
              channelType: session.channelType,
              channelName: 'Read Once',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(readCalls, const <List<String>>[
        <String>['m_read_once'],
      ]);

      await tester.enterText(find.byType(TextField).first, 'still typing');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(readCalls, const <List<String>>[
        <String>['m_read_once'],
      ]);
    },
  );

  testWidgets(
    'chat page sweeps viewed flame messages on open and close like Android',
    (tester) async {
      final session = ChatSession(
        channelId: 'fileHelper',
        channelType: WKChannelType.personal,
      );
      final flameRuntime = _SpyChatFlameMessageRuntime();
      final container = ProviderContainer(
        overrides: [
          _testRealtimeTelemetryOverride(),
          messageListProvider.overrideWith(
            (ref, providedSession) => _EmptyMessageListNotifier(
              providedSession.channelId,
              providedSession.channelType,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChatPageShell(
              channelId: session.channelId,
              channelType: session.channelType,
              channelName: 'File Helper',
              flameRuntime: flameRuntime,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(flameRuntime.sweepCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(flameRuntime.sweepCalls, 2);
    },
  );

  testWidgets(
    'chat page follows Android typing throttle and reports at most once per 5 seconds',
    (tester) async {
      final session = ChatSession(
        channelId: 'u_typing_report',
        channelType: WKChannelType.personal,
      );
      final typingGateway = _RecordingTypingGateway();
      var nowSeconds = 100;

      final container = ProviderContainer(
        overrides: [
          _testRealtimeTelemetryOverride(),
          messageListProvider.overrideWith(
            (ref, providedSession) => _EmptyMessageListNotifier(
              providedSession.channelId,
              providedSession.channelType,
            ),
          ),
          chatTypingGatewayProvider.overrideWithValue(typingGateway),
          chatTypingNowProvider.overrideWithValue(() => nowSeconds),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChatPageShell(
              channelId: session.channelId,
              channelType: session.channelType,
              channelName: 'Typing Report',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.enterText(find.byType(TextField).first, 'h');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(typingGateway.calls, const <_TypingGatewayCall>[
        _TypingGatewayCall(channelId: 'u_typing_report', channelType: 1),
      ]);

      await tester.enterText(find.byType(TextField).first, 'he');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(typingGateway.calls, const <_TypingGatewayCall>[
        _TypingGatewayCall(channelId: 'u_typing_report', channelType: 1),
      ]);

      nowSeconds += 5;
      await tester.enterText(find.byType(TextField).first, 'hel');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(typingGateway.calls, const <_TypingGatewayCall>[
        _TypingGatewayCall(channelId: 'u_typing_report', channelType: 1),
        _TypingGatewayCall(channelId: 'u_typing_report', channelType: 1),
      ]);
    },
  );

  testWidgets(
    'image bubble tap opens Android-style image viewer with viewer actions',
    (tester) async {
      final endpointManager = EndpointManager.getInstance();
      endpointManager.clear();
      endpointManager.setMethod(
        ChatMenuIDs.parseQrCode,
        '',
        0,
        VoidFunctionHandler(([dynamic _]) {}),
      );
      addTearDown(endpointManager.clear);

      final session = ChatSession(
        channelId: 'u_image_preview',
        channelType: WKChannelType.personal,
      );
      final imageContent = WKImageContent(480, 360)
        ..url = 'media/chat/image.jpg';
      final message = WKMsg()
        ..messageID = 'm_image_preview'
        ..messageSeq = 101
        ..orderSeq = 101000
        ..channelID = session.channelId
        ..channelType = session.channelType
        ..fromUID = 'u_other'
        ..contentType = WkMessageContentType.image
        ..content = jsonEncode(<String, Object>{
          'type': WkMessageContentType.image,
          'width': 480,
          'height': 360,
          'url': 'media/chat/image.jpg',
        })
        ..messageContent = imageContent;
      final container = ProviderContainer(
        overrides: [
          _testRealtimeTelemetryOverride(),
          conversationPatchTelemetryProvider.overrideWithValue(
            _NoopConversationPatchTelemetry(),
          ),
          messageListProvider.overrideWith(
            (ref, providedSession) => _StaticMessageListNotifier(
              providedSession.channelId,
              providedSession.channelType,
              providedSession == session ? <WKMsg>[message] : const <WKMsg>[],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChatPageShell(
              channelId: session.channelId,
              channelType: session.channelType,
              channelName: 'Image Preview',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ImageViewer), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('image-viewer-action-forward')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('image-viewer-action-favorite')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('image-viewer-action-show-in-chat')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('image-viewer-action-scan-qrcode')),
        findsOneWidget,
      );
    },
  );

  testWidgets('long press uses Android labels in Android order', (
    tester,
  ) async {
    final message = WKMsg()
      ..messageID = 'mid:android'
      ..messageSeq = 1
      ..clientMsgNO = 'client:android'
      ..channelID = 'u_android'
      ..channelType = WKChannelType.personal
      ..fromUID = 'u_self'
      ..contentType = WkMessageContentType.text
      ..messageContent = WKTextContent('hello action sheet');

    await pumpChatPage(
      tester,
      channelId: 'u_android',
      channelType: WKChannelType.personal,
      channelName: 'Android Parity',
      overrides: <Override>[
        messageListProvider.overrideWith(
          (ref, session) => _StaticMessageListNotifier(
            session.channelId,
            session.channelType,
            session.channelId == 'u_android'
                ? <WKMsg>[message]
                : const <WKMsg>[],
          ),
        ),
        chatMarkConversationReadProvider.overrideWithValue(
          (session, messageIds) async {},
        ),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.longPress(
      find.byKey(const ValueKey<String>('message-bubble-body')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    final labels = tiles
        .map((tile) => ((tile.title as Text).data ?? '').trim())
        .toList(growable: false);
    expect(labels, const <String>[
      '\u56de\u590d',
      '\u8f6c\u53d1',
      '\u590d\u5236',
      '\u7f16\u8f91',
      '\u6536\u85cf',
      '\u591a\u9009',
      '\u64a4\u56de',
      '\u8868\u60c5\u56de\u5e94',
      '\u7f6e\u9876',
    ]);
    /*
    expect((tiles[0].title as Text).data, '鍥炲');
    expect((tiles[1].title as Text).data, '杞彂');
    expect((tiles[2].title as Text).data, '鏀惰棌');
    expect((tiles[3].title as Text).data, '澶氶€?);
    expect((tiles[4].title as Text).data, '鎾ゅ洖');
    expect((tiles[5].title as Text).data, '琛ㄦ儏鍥炲簲');
  });

    */
  });

  testWidgets(
    'Android long press shows emoji strip and keeps react action as overflow picker',
    (tester) async {
      final message = WKMsg()
        ..messageID = 'mid:parity-reaction'
        ..clientMsgNO = 'client:parity-reaction'
        ..channelID = 'u_android'
        ..channelType = WKChannelType.personal
        ..fromUID = 'u_self'
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('reaction parity');

      await pumpChatPage(
        tester,
        channelId: 'u_android',
        channelType: WKChannelType.personal,
        channelName: 'Android Parity',
        overrides: <Override>[
          messageListProvider.overrideWith(
            (ref, session) => _StaticMessageListNotifier(
              session.channelId,
              session.channelType,
              session.channelId == 'u_android'
                  ? <WKMsg>[message]
                  : const <WKMsg>[],
            ),
          ),
          chatMarkConversationReadProvider.overrideWithValue(
            (session, messageIds) async {},
          ),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.longPress(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.byKey(const ValueKey<String>('reaction-picker-\u{1F44D}')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('message-reaction-add')),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('chat-action-react')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('chat-action-react')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey<String>('chat-reaction-picker-popup')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('reaction-picker-\u{1F44D}')),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.longPress(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey<String>('reaction-picker-\u{1F44D}')),
        findsOneWidget,
      );
    },
  );

  testWidgets('selection mode shows Android batch toolbar copy', (
    tester,
  ) async {
    final message = WKMsg()
      ..messageID = 'mid:select'
      ..clientMsgNO = 'client:select'
      ..channelID = 'u_select'
      ..channelType = WKChannelType.personal
      ..contentType = WkMessageContentType.text
      ..messageContent = WKTextContent('batch mode');

    await pumpChatPage(
      tester,
      channelId: 'u_select',
      channelType: WKChannelType.personal,
      channelName: 'Selection Parity',
      overrides: <Override>[
        messageListProvider.overrideWith(
          (ref, session) => _StaticMessageListNotifier(
            session.channelId,
            session.channelType,
            session.channelId == 'u_select'
                ? <WKMsg>[message]
                : const <WKMsg>[],
          ),
        ),
        chatMarkConversationReadProvider.overrideWithValue(
          (session, messageIds) async {},
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey<String>('message-bubble-body')),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('chat-action-select')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('chat-action-select')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-selection-toolbar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-selection-forward')),
      findsOneWidget,
    );
  });

  testWidgets(
    'file helper chat uses Android fixed title and hides call actions',
    (tester) async {
      await pumpChatPage(
        tester,
        channelId: 'fileHelper',
        channelType: WKChannelType.personal,
        channelName: 'Temporary Alias',
      );

      expect(find.text('\u6587\u4ef6\u4f20\u8f93\u52a9\u624b'), findsOneWidget);
      expect(find.text('Temporary Alias'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('chat-call-audio-button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-call-video-button')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'system team chat uses Android fixed title and hides call actions',
    (tester) async {
      await pumpChatPage(
        tester,
        channelId: 'u_10000',
        channelType: WKChannelType.personal,
        channelName: 'Temporary Alias',
      );

      expect(find.text('\u7cfb\u7edf\u901a\u77e5'), findsOneWidget);
      expect(find.text('Temporary Alias'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('chat-call-audio-button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-call-video-button')),
        findsNothing,
      );
    },
  );

  testWidgets('normal personal chat keeps Android call actions', (
    tester,
  ) async {
    final channel = WKChannel('u_alice', WKChannelType.personal)
      ..channelName = 'Alice';
    WKIM.shared.channelManager.addOrUpdateChannel(channel);

    await pumpChatPage(
      tester,
      channelId: 'u_alice',
      channelType: WKChannelType.personal,
      channelName: 'Alice',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-call-audio-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-call-video-button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'personal chat places call actions in the composer toolbar without narrow-screen overflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final channel = WKChannel('u_toolbar_calls', WKChannelType.personal)
        ..channelName = 'Alice With An Extra Long Display Name';
      WKIM.shared.channelManager.addOrUpdateChannel(channel);

      await pumpChatPage(
        tester,
        channelId: 'u_toolbar_calls',
        channelType: WKChannelType.personal,
        channelName: 'Alice With An Extra Long Display Name',
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final toolbarRow = find.byKey(
        const ValueKey<String>('chat-composer-toolbar-row'),
      );
      final appBar = find.byType(AppBar);
      final audioButton = find.byKey(
        const ValueKey<String>('chat-call-audio-button'),
      );
      final videoButton = find.byKey(
        const ValueKey<String>('chat-call-video-button'),
      );

      expect(toolbarRow, findsOneWidget);
      expect(audioButton, findsOneWidget);
      expect(videoButton, findsOneWidget);
      expect(
        find.descendant(of: toolbarRow, matching: audioButton),
        findsOneWidget,
      );
      expect(
        find.descendant(of: toolbarRow, matching: videoButton),
        findsOneWidget,
      );
      expect(find.descendant(of: appBar, matching: audioButton), findsNothing);
      expect(find.descendant(of: appBar, matching: videoButton), findsNothing);

      final audioDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey<String>('chat-call-audio-decoration')),
      );
      final videoDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey<String>('chat-call-video-decoration')),
      );
      expect((audioDecoration.decoration as BoxDecoration).gradient, isNotNull);
      expect((videoDecoration.decoration as BoxDecoration).gradient, isNotNull);
    },
  );

  testWidgets(
    'chat composer toolbar action artwork uses the call action visual size',
    (tester) async {
      await pumpChatPage(
        tester,
        channelId: 'u_toolbar_visual_size',
        channelType: WKChannelType.personal,
        channelName: 'Toolbar Visual Size',
      );
      await tester.pumpAndSettle();

      final callVisualSize = tester.getSize(
        find.byKey(const ValueKey<String>('chat-call-audio-decoration')),
      );

      expect(callVisualSize, const Size(38, 38));
      for (final asset in <String>[
        WKReferenceAssets.chatToolbarEmoji,
        WKReferenceAssets.chatToolbarAlbum,
        WKReferenceAssets.chatToolbarMore,
      ]) {
        expect(
          tester.getSize(_assetFinder(asset).first),
          callVisualSize,
          reason: '$asset should visually match the voice/video call buttons',
        );
      }
    },
  );

  testWidgets('chat page shows Android official category tag', (tester) async {
    final channel = WKChannel('u_official', WKChannelType.personal)
      ..channelName = 'Official Account'
      ..category = 'system';
    WKIM.shared.channelManager.addOrUpdateChannel(channel);

    await pumpChatPage(
      tester,
      channelId: 'u_official',
      channelType: WKChannelType.personal,
      channelName: 'Official Account',
    );
    await tester.pumpAndSettle();

    expect(find.text('\u5b98\u65b9'), findsOneWidget);
  });

  testWidgets('personal chat shows vip badge in title area for vip friend', (
    tester,
  ) async {
    await pumpChatPage(
      tester,
      channelId: 'u_vip',
      channelType: WKChannelType.personal,
      channelName: 'VIP Alice',
      overrides: <Override>[
        friendListProvider.overrideWith(
          (ref) => _StaticFriendListNotifier([
            Friend.fromJson({
              'uid': 'u_vip',
              'name': 'VIP Alice',
              'vip_level': 1,
            }),
          ]),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-header-vip-badge')),
      findsOneWidget,
    );

    final titleFinder = find.text('VIP Alice');
    final badgeFinder = find.byKey(
      const ValueKey<String>('chat-header-vip-badge'),
    );
    final titleWidget = tester.widget<Text>(titleFinder);
    final titleRect = tester.getRect(titleFinder);
    final badgeRect = tester.getRect(badgeFinder);
    final textPainter = TextPainter(
      text: TextSpan(text: titleWidget.data, style: titleWidget.style),
      maxLines: titleWidget.maxLines,
      textDirection: TextDirection.ltr,
    )..layout();

    final gap = badgeRect.left - (titleRect.left + textPainter.width);
    expect(gap, lessThanOrEqualTo(20));
  });

  testWidgets(
    'chat page shows Android customer service and robot category tags',
    (tester) async {
      final channel = WKChannel('u_robot_service', WKChannelType.personal)
        ..channelName = 'Service Bot'
        ..category = 'customerService'
        ..robot = 1;
      WKIM.shared.channelManager.addOrUpdateChannel(channel);

      await pumpChatPage(
        tester,
        channelId: 'u_robot_service',
        channelType: WKChannelType.personal,
        channelName: 'Service Bot',
      );
      await tester.pumpAndSettle();

      expect(find.text('\u5ba2\u670d'), findsOneWidget);
      expect(find.byType(AnimatedSize), findsOneWidget);
    },
  );

  testWidgets(
    'chat page shows customer service tag when category is supplied by service entry',
    (tester) async {
      await pumpChatPage(
        tester,
        channelId: 'cs_001',
        channelType: WKChannelType.personal,
        channelName: 'Support',
        channelCategory: 'customerService',
      );
      await tester.pumpAndSettle();

      expect(find.text('\u5ba2\u670d'), findsOneWidget);
    },
  );

  testWidgets(
    'customer service chat shows vip merchant badge from conversation entry',
    (tester) async {
      final channel = WKChannel('u_vip_customer', WKChannelType.customerService)
        ..channelName = 'VIP Alice';
      WKIM.shared.channelManager.addOrUpdateChannel(channel);

      await pumpChatPage(
        tester,
        channelId: 'u_vip_customer',
        channelType: WKChannelType.customerService,
        channelName: 'VIP Alice',
        initialVipLevel: 1,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chat-header-vip-badge')),
        findsOneWidget,
      );
    },
  );

  testWidgets('customer service channel title tap is blocked like Android', (
    tester,
  ) async {
    final channel = WKChannel('cs_001', WKChannelType.customerService)
      ..channelName = '瀹㈡湇浼氳瘽';
    WKIM.shared.channelManager.addOrUpdateChannel(channel);
    final observer = _TestNavigatorObserver();

    await pumpChatPage(
      tester,
      channelId: 'cs_001',
      channelType: WKChannelType.customerService,
      channelName: '瀹㈡湇浼氳瘽',
      navigatorObserver: observer,
    );
    await tester.pumpAndSettle();

    final initialPushCount = observer.pushCount;
    await tester.tap(find.text('瀹㈡湇浼氳瘽'));
    await tester.pumpAndSettle();

    expect(observer.pushCount, initialPushCount);
  });

  testWidgets(
    'personal chat shows Android online subtitle from channel presence',
    (tester) async {
      final channel = WKChannel('u_online_web', WKChannelType.personal)
        ..channelName = 'Web Alice'
        ..online = 1
        ..deviceFlag = IMConfig.deviceFlagWeb;
      WKIM.shared.channelManager.addOrUpdateChannel(channel);

      await pumpChatPage(
        tester,
        channelId: 'u_online_web',
        channelType: WKChannelType.personal,
        channelName: 'Web Alice',
      );
      await tester.pumpAndSettle();

      expect(find.text('Web\u5728\u7ebf'), findsOneWidget);
    },
  );

  testWidgets('personal chat shows Android recent offline subtitle', (
    tester,
  ) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final channel = WKChannel('u_recent_offline', WKChannelType.personal)
      ..channelName = 'Recent Bob'
      ..lastOffline = nowSeconds - (5 * 60);
    WKIM.shared.channelManager.addOrUpdateChannel(channel);

    await pumpChatPage(
      tester,
      channelId: 'u_recent_offline',
      channelType: WKChannelType.personal,
      channelName: 'Recent Bob',
    );
    await tester.pumpAndSettle();

    expect(find.text('5\u5206\u949f'), findsOneWidget);
  });

  testWidgets('group chat shows Android member and online count subtitles', (
    tester,
  ) async {
    final channel = WKChannel('g_parity', WKChannelType.group)
      ..channelName = 'Parity Group'
      ..remoteExtraMap = <String, dynamic>{
        'member_count': 12,
        'online_count': 3,
      };
    WKIM.shared.channelManager.addOrUpdateChannel(channel);

    await pumpChatPage(
      tester,
      channelId: 'g_parity',
      channelType: WKChannelType.group,
      channelName: 'Parity Group',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('12'), findsOneWidget);
    expect(find.textContaining('3'), findsOneWidget);
  });
  testWidgets(
    'chat page resolves function panel entries from shared slot registry',
    (tester) async {
      final registry = SlotRegistry();
      registry.register(
        chatFunctionSlot,
        SlotEntry<ChatToolbarSlotContext, ChatFunctionMenu>(
          id: 'chat_function.custom_action',
          priority: 110,
          build: (_) => ChatFunctionMenu(
            sid: 'customAction',
            icon: WKReferenceAssets.chatFunctionCard,
            text: 'Custom action',
          ),
        ),
      );

      await pumpChatPage(
        tester,
        channelId: 'u_custom_function_panel',
        channelType: WKChannelType.personal,
        channelName: 'Custom Function Panel',
        overrides: <Override>[slotRegistryProvider.overrideWithValue(registry)],
      );
      await tester.pumpAndSettle();

      await tester.tap(_assetFinder(WKReferenceAssets.chatToolbarMore));
      await tester.pumpAndSettle();

      expect(find.text('Custom action'), findsOneWidget);
    },
  );

  testWidgets(
    'chat composer keeps Android input row above toolbar row and rich text stays inside the input lane',
    (tester) async {
      await pumpChatPage(
        tester,
        channelId: 'u_android_composer_rows',
        channelType: WKChannelType.personal,
        channelName: 'Android Composer Rows',
      );
      await tester.pumpAndSettle();

      final inputRow = find.byKey(
        const ValueKey<String>('chat-composer-input-row'),
      );
      final toolbarRow = find.byKey(
        const ValueKey<String>('chat-composer-toolbar-row'),
      );
      final richButton = find.byKey(
        const ValueKey<String>('chat-compose-rich-text-button'),
      );

      expect(inputRow, findsOneWidget);
      expect(toolbarRow, findsOneWidget);
      expect(richButton, findsOneWidget);

      final inputRect = tester.getRect(inputRow);
      final toolbarRect = tester.getRect(toolbarRow);
      final richRect = tester.getRect(richButton);

      expect(toolbarRect.top, greaterThan(inputRect.bottom));
      expect(inputRect.contains(richRect.center), isTrue);
      expect(
        find.descendant(
          of: toolbarRow,
          matching: find.byKey(
            const ValueKey<String>('chat-toolbar-wk_chat_toolbar_emoji'),
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'chat toolbar keeps Android colorful assets without tint overlays',
    (tester) async {
      await pumpChatPage(
        tester,
        channelId: 'u_toolbar_assets',
        channelType: WKChannelType.personal,
        channelName: 'Toolbar Assets',
      );
      await tester.pumpAndSettle();

      expect(
        _assetImage(tester, WKReferenceAssets.chatToolbarEmoji).color,
        isNull,
      );
      expect(
        _assetImage(tester, WKReferenceAssets.chatToolbarVoice).color,
        isNull,
      );
      expect(
        _assetImage(tester, WKReferenceAssets.chatToolbarAlbum).color,
        isNull,
      );
      expect(
        _assetImage(tester, WKReferenceAssets.chatToolbarMore).color,
        isNull,
      );
    },
  );

  testWidgets('flame chats hide rich-text button in the input row', (
    tester,
  ) async {
    final flameChannel = WKChannel('fileHelper', WKChannelType.personal)
      ..channelName = 'File Helper'
      ..localExtra = <String, dynamic>{'flame': 1, 'flame_second': 20}
      ..remoteExtraMap = <String, dynamic>{'flame': 1, 'flame_second': 20};
    WKIM.shared.channelManager.addOrUpdateChannel(flameChannel);

    await pumpChatPage(
      tester,
      channelId: 'fileHelper',
      channelType: WKChannelType.personal,
      channelName: 'File Helper',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-compose-rich-text-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-flame-toggle-button')),
      findsOneWidget,
    );
  });

  testWidgets('group chat toolbar shows Android mention button ordering', (
    tester,
  ) async {
    await pumpChatPage(
      tester,
      channelId: 'g_toolbar_mention',
      channelType: WKChannelType.group,
      channelName: 'Group Toolbar Mention',
    );
    await tester.pumpAndSettle();

    final voiceButton = find.byKey(
      const ValueKey<String>('chat-toolbar-wk_chat_toolbar_voice'),
    );
    final emojiButton = find.byKey(
      const ValueKey<String>('chat-toolbar-wk_chat_toolbar_emoji'),
    );
    final albumButton = find.byKey(
      const ValueKey<String>('chat-toolbar-wk_chat_toolbar_album'),
    );
    final mentionButton = find.byKey(
      const ValueKey<String>('chat-toolbar-wk_chat_toolbar_mention'),
    );
    final moreButton = find.byKey(
      const ValueKey<String>('chat-toolbar-wk_chat_toolbar_more'),
    );

    expect(voiceButton, findsOneWidget);
    expect(emojiButton, findsOneWidget);
    expect(albumButton, findsOneWidget);
    expect(mentionButton, findsOneWidget);
    expect(moreButton, findsOneWidget);

    expect(
      tester.getCenter(voiceButton).dx,
      lessThan(tester.getCenter(emojiButton).dx),
    );
    expect(
      tester.getCenter(emojiButton).dx,
      lessThan(tester.getCenter(albumButton).dx),
    );
    expect(
      tester.getCenter(albumButton).dx,
      lessThan(tester.getCenter(mentionButton).dx),
    );
    expect(
      tester.getCenter(mentionButton).dx,
      lessThan(tester.getCenter(moreButton).dx),
    );
  });

  testWidgets('personal chat toolbar hides Android mention button', (
    tester,
  ) async {
    await pumpChatPage(
      tester,
      channelId: 'u_toolbar_no_mention',
      channelType: WKChannelType.personal,
      channelName: 'Toolbar No Mention',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>('chat-toolbar-wk_chat_toolbar_mention'),
      ),
      findsNothing,
    );
  });

  testWidgets('group mention toolbar inserts @ at current cursor', (
    tester,
  ) async {
    await pumpChatPage(
      tester,
      channelId: 'g_mention_insert',
      channelType: WKChannelType.group,
      channelName: 'Group Mention Insert',
    );
    await tester.pumpAndSettle();

    final textFieldFinder = find.byType(TextField).first;
    await tester.enterText(textFieldFinder, 'hello');
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(textFieldFinder);
    final controller = textField.controller!;
    controller.selection = const TextSelection.collapsed(offset: 2);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('chat-toolbar-wk_chat_toolbar_mention'),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.text, 'he@llo');
    expect(controller.selection.baseOffset, 3);
    expect(controller.selection.extentOffset, 3);
  });

  testWidgets('mention toolbar exits voice mode and inserts @', (tester) async {
    await pumpChatPage(
      tester,
      channelId: 'g_mention_voice_mode',
      channelType: WKChannelType.group,
      channelName: 'Mention Voice Mode',
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-toolbar-wk_chat_toolbar_voice')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-voice-record-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('chat-toolbar-wk_chat_toolbar_mention'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-voice-record-button')),
      findsNothing,
    );
    expect(find.byType(TextField), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField).first);
    final controller = textField.controller!;
    expect(controller.text, '@');
    expect(controller.selection.baseOffset, 1);
    expect(controller.selection.extentOffset, 1);
  });

  testWidgets(
    'input-row rich-text button sends WKRichTextContent via current send path',
    (tester) async {
      var composeRichTextCalls = 0;
      final richTextContent = WKRichTextContent(
        title: 'Compose Title',
        body: 'Compose Body',
      );
      final dispatcher = ChatActionDispatcher(
        pickImage: (_) async => null,
        pickFile: (_) async => null,
        pickLocation: (_) async => null,
        pickCard: (_) async => null,
        pickRichText: (_) async {
          composeRichTextCalls += 1;
          return richTextContent;
        },
      );
      final gateway = _RecordingChatSceneGateway();

      await pumpChatPage(
        tester,
        channelId: 'u_compose_rich_text_dispatch',
        channelType: WKChannelType.personal,
        channelName: 'Compose Rich Text Dispatch',
        overrides: <Override>[
          chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
          chatActionDispatcherProvider.overrideWithValue(dispatcher),
        ],
      );
      await tester.pumpAndSettle();

      final richTextButton = find.byKey(
        const ValueKey<String>('chat-compose-rich-text-button'),
      );
      expect(richTextButton, findsOneWidget);

      await tester.tap(richTextButton);
      await tester.pumpAndSettle();

      expect(composeRichTextCalls, 1);
      expect(gateway.sentContents, hasLength(1));
      final sentContent = gateway.sentContents.single as WKRichTextContent;
      expect(sentContent.title, 'Compose Title');
      expect(sentContent.body, 'Compose Body');
    },
  );

  testWidgets('more panel matches Android default function entries', (
    tester,
  ) async {
    await pumpChatPage(
      tester,
      channelId: 'u_function_panel',
      channelType: WKChannelType.personal,
      channelName: 'Function Panel',
    );
    await tester.pumpAndSettle();

    await tester.tap(_assetFinder(WKReferenceAssets.chatToolbarMore));
    await tester.pumpAndSettle();

    expect(find.text('\u56fe\u7247'), findsOneWidget);
    expect(find.text('\u540d\u7247'), findsOneWidget);
    expect(find.text('\u4f4d\u7f6e'), findsOneWidget);
    expect(find.text('\u6587\u4ef6'), findsOneWidget);
    expect(find.text('\u5bcc\u6587\u672c'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('chat-function-composeRichText')),
      findsNothing,
    );
    expect(find.text('\u5c0f\u89c6\u9891'), findsNothing);
    expect(find.text('\u6536\u85cf'), findsNothing);
  });

  testWidgets('more panel renders default function entries as colorful icons', (
    tester,
  ) async {
    await pumpChatPage(
      tester,
      channelId: 'u_function_colorful_icons',
      channelType: WKChannelType.personal,
      channelName: 'Function Colorful Icons',
    );
    await tester.pumpAndSettle();

    await tester.tap(_assetFinder(WKReferenceAssets.chatToolbarMore));
    await tester.pumpAndSettle();

    for (final sid in <String>[
      'chooseImg',
      'chooseFile',
      'sendLocation',
      'chooseCard',
    ]) {
      final decoration = tester.widget<DecoratedBox>(
        find.byKey(ValueKey<String>('chat-function-$sid-icon')),
      );
      final boxDecoration = decoration.decoration as BoxDecoration;

      expect(boxDecoration.gradient, isNotNull, reason: sid);
      expect(boxDecoration.borderRadius, isNotNull, reason: sid);
      expect(boxDecoration.boxShadow, isNotEmpty, reason: sid);
    }
  });

  testWidgets(
    'expression panel exposes Android asset cells and inserts the matched tag',
    (tester) async {
      final firstEmoji = androidEmojiCatalog.lookupById('0_0')!;

      await pumpChatPage(
        tester,
        channelId: 'u_emoji_panel',
        channelType: WKChannelType.personal,
        channelName: 'Emoji Panel',
        overrides: <Override>[
          chatExpressionRegistryProvider.overrideWithValue(
            _FakeChatExpressionRegistry(),
          ),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chat-toolbar-wk_chat_toolbar_emoji'),
        ),
      );
      final expressionShellFinder = find.byKey(
        const ValueKey<String>('chat-expression-panel-shell'),
      );
      final expressionShellFound = await pumpUntilFound(
        tester,
        expressionShellFinder,
      );
      if (!expressionShellFound) {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ChatPageShell)),
        );
        final composerState = container.read(
          chatComposerProvider(
            const ChatSession(
              channelId: 'u_emoji_panel',
              channelType: WKChannelType.personal,
            ),
          ),
        );
        final errorVisible = find
            .byKey(const ValueKey<String>('chat-expression-panel-error'))
            .evaluate()
            .isNotEmpty;
        final panelNoneVisible = find
            .byKey(const ValueKey<String>('panel-none'))
            .evaluate()
            .isNotEmpty;
        final expressionPanelVisible = find
            .byType(ChatExpressionPanel)
            .evaluate()
            .isNotEmpty;
        final legacyEmojiPanelVisible = find
            .byType(ChatEmojiPanel)
            .evaluate()
            .isNotEmpty;
        final spinnerCount = find
            .byType(CircularProgressIndicator)
            .evaluate()
            .length;
        fail(
          'Expression panel did not open: '
          'showFacePanel=${composerState.showFacePanel}, '
          'showFunctionPanel=${composerState.showFunctionPanel}, '
          'errorVisible=$errorVisible, '
          'panelNoneVisible=$panelNoneVisible, '
          'expressionPanelVisible=$expressionPanelVisible, '
          'legacyEmojiPanelVisible=$legacyEmojiPanelVisible, '
          'spinnerCount=$spinnerCount',
        );
      }

      expect(expressionShellFinder, findsOneWidget);
      final emojiItemFinder = find.byKey(
        ValueKey<String>('chat-expression-emoji-${firstEmoji.id}'),
      );
      expect(emojiItemFinder, findsOneWidget);
      expect(
        find.descendant(
          of: emojiItemFinder,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName == firstEmoji.assetPath,
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(emojiItemFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, contains(firstEmoji.tag));
    },
  );

  testWidgets('tapping a bundled sticker cell sends WKStickerContent', (
    tester,
  ) async {
    final gateway = _RecordingChatSceneGateway();

    await pumpChatPage(
      tester,
      channelId: 'u_panel_sticker_send',
      channelType: WKChannelType.personal,
      channelName: 'Sticker Send',
      overrides: <Override>[
        chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
        chatExpressionRegistryProvider.overrideWithValue(
          _FakeChatExpressionRegistry(),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-toolbar-wk_chat_toolbar_emoji')),
    );
    final stickerCategoryFinder = find.byKey(
      const ValueKey<String>(
        'chat-expression-category-sticker:android_sample_motion',
      ),
    );
    final stickerCategoryFound = await pumpUntilFound(
      tester,
      stickerCategoryFinder,
    );
    if (!stickerCategoryFound) {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatPageShell)),
      );
      final composerState = container.read(
        chatComposerProvider(
          const ChatSession(
            channelId: 'u_panel_sticker_send',
            channelType: WKChannelType.personal,
          ),
        ),
      );
      final errorVisible = find
          .byKey(const ValueKey<String>('chat-expression-panel-error'))
          .evaluate()
          .isNotEmpty;
      final panelNoneVisible = find
          .byKey(const ValueKey<String>('panel-none'))
          .evaluate()
          .isNotEmpty;
      final expressionPanelVisible = find
          .byType(ChatExpressionPanel)
          .evaluate()
          .isNotEmpty;
      final legacyEmojiPanelVisible = find
          .byType(ChatEmojiPanel)
          .evaluate()
          .isNotEmpty;
      final spinnerCount = find
          .byType(CircularProgressIndicator)
          .evaluate()
          .length;
      fail(
        'Sticker category did not appear: '
        'showFacePanel=${composerState.showFacePanel}, '
        'showFunctionPanel=${composerState.showFunctionPanel}, '
        'errorVisible=$errorVisible, '
        'panelNoneVisible=$panelNoneVisible, '
        'expressionPanelVisible=$expressionPanelVisible, '
        'legacyEmojiPanelVisible=$legacyEmojiPanelVisible, '
        'spinnerCount=$spinnerCount',
      );
    }

    await tester.tap(stickerCategoryFinder);
    final stickerCellFinder = find.byKey(
      const ValueKey<String>('chat-expression-sticker-typing'),
    );
    await pumpUntilFound(tester, stickerCellFinder);

    await tester.tap(stickerCellFinder);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(gateway.sentContents.single, isA<WKStickerContent>());
    final content = gateway.sentContents.single as WKStickerContent;
    expect(content.packId, 'android_sample_motion');
    expect(content.stickerId, 'typing');
    expect(content.animationKey, 'assets/stickers/sample_pack/typing.webp');
  });

  testWidgets(
    'GIF category search stays inside the same expression panel and sends WKGifContent',
    (tester) async {
      final gateway = _RecordingChatSceneGateway();
      final gifService = _FakeChatGifPanelService(
        results: const <ChatGifPanelResult>[
          ChatGifPanelResult(
            url: 'https://example.com/panel-cat.gif',
            width: 120,
            height: 120,
            title: 'cat',
          ),
        ],
      );

      await pumpChatPage(
        tester,
        channelId: 'u_panel_gif_send',
        channelType: WKChannelType.personal,
        channelName: 'GIF Send',
        overrides: <Override>[
          chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
          chatExpressionRegistryProvider.overrideWithValue(
            _FakeChatExpressionRegistry(),
          ),
          chatGifPanelServiceProvider.overrideWithValue(gifService),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chat-toolbar-wk_chat_toolbar_emoji'),
        ),
      );
      final shellFinder = find.byKey(
        const ValueKey<String>('chat-expression-panel-shell'),
      );
      final shellFound = await pumpUntilFound(tester, shellFinder);
      if (!shellFound) {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ChatPageShell)),
        );
        final composerState = container.read(
          chatComposerProvider(
            const ChatSession(
              channelId: 'u_panel_gif_send',
              channelType: WKChannelType.personal,
            ),
          ),
        );
        final errorVisible = find
            .byKey(const ValueKey<String>('chat-expression-panel-error'))
            .evaluate()
            .isNotEmpty;
        final panelNoneVisible = find
            .byKey(const ValueKey<String>('panel-none'))
            .evaluate()
            .isNotEmpty;
        final expressionPanelVisible = find
            .byType(ChatExpressionPanel)
            .evaluate()
            .isNotEmpty;
        final legacyEmojiPanelVisible = find
            .byType(ChatEmojiPanel)
            .evaluate()
            .isNotEmpty;
        final spinnerCount = find
            .byType(CircularProgressIndicator)
            .evaluate()
            .length;
        fail(
          'GIF expression shell did not open: '
          'showFacePanel=${composerState.showFacePanel}, '
          'showFunctionPanel=${composerState.showFunctionPanel}, '
          'errorVisible=$errorVisible, '
          'panelNoneVisible=$panelNoneVisible, '
          'expressionPanelVisible=$expressionPanelVisible, '
          'legacyEmojiPanelVisible=$legacyEmojiPanelVisible, '
          'spinnerCount=$spinnerCount',
        );
      }

      expect(shellFinder, findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-expression-category-gif')),
      );
      final gifSearchFieldFinder = find.byKey(
        const ValueKey<String>('chat-expression-gif-search-field'),
      );
      await pumpUntilFound(tester, gifSearchFieldFinder);

      expect(shellFinder, findsOneWidget);

      await tester.enterText(gifSearchFieldFinder, 'cat');
      final gifItemFinder = find.byKey(
        const ValueKey<String>('chat-expression-gif-item-0'),
      );
      await pumpUntilFound(tester, gifItemFinder);

      await tester.tap(gifItemFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(gateway.sentContents.single, isA<WKGifContent>());
      final content = gateway.sentContents.single as WKGifContent;
      expect(content.url, 'https://example.com/panel-cat.gif');
      expect(content.width, 120);
      expect(content.height, 120);
    },
  );

  testWidgets('location bubble tap opens the location detail page', (
    tester,
  ) async {
    final observer = _TestNavigatorObserver();
    final location = WKLocationContent()
      ..latitude = 31.2304
      ..longitude = 121.4737
      ..title = '涓婃捣'
      ..address = '涓婃捣甯傞粍娴﹀尯';
    final message = WKMsg()
      ..messageID = 'm_location_open'
      ..channelID = 'u_location_open'
      ..channelType = WKChannelType.personal
      ..fromUID = 'u_other'
      ..contentType = WkMessageContentType.location
      ..messageContent = location;

    await pumpChatPage(
      tester,
      channelId: 'u_location_open',
      channelType: WKChannelType.personal,
      channelName: 'Location Open',
      navigatorObserver: observer,
      overrides: <Override>[
        messageListProvider.overrideWith(
          (ref, session) => _StaticMessageListNotifier(
            session.channelId,
            session.channelType,
            session.channelId == 'u_location_open'
                ? <WKMsg>[message]
                : const <WKMsg>[],
          ),
        ),
        chatMarkConversationReadProvider.overrideWithValue(
          (session, messageIds) async {},
        ),
      ],
    );
    await tester.pumpAndSettle();

    final initialPushCount = observer.pushCount;
    await tester.tap(find.byKey(const ValueKey<String>('message-bubble-body')));
    await tester.pumpAndSettle();

    expect(observer.pushCount, greaterThan(initialPushCount));
    expect(find.byType(LocationViewPage), findsOneWidget);
  });

  testWidgets('card bubble tap opens the user detail page', (tester) async {
    final observer = _TestNavigatorObserver();
    final message = WKMsg()
      ..messageID = 'm_card_open'
      ..channelID = 'u_card_open'
      ..channelType = WKChannelType.personal
      ..fromUID = 'u_other'
      ..contentType = WkMessageContentType.card
      ..messageContent = WKCardContent('u_card_target', '鍚嶇墖鐢ㄦ埛');

    await pumpChatPage(
      tester,
      channelId: 'u_card_open',
      channelType: WKChannelType.personal,
      channelName: 'Card Open',
      navigatorObserver: observer,
      overrides: <Override>[
        messageListProvider.overrideWith(
          (ref, session) => _StaticMessageListNotifier(
            session.channelId,
            session.channelType,
            session.channelId == 'u_card_open'
                ? <WKMsg>[message]
                : const <WKMsg>[],
          ),
        ),
        chatMarkConversationReadProvider.overrideWithValue(
          (session, messageIds) async {},
        ),
      ],
    );
    await tester.pumpAndSettle();

    final initialPushCount = observer.pushCount;
    await tester.tap(find.byKey(const ValueKey<String>('message-bubble-body')));
    await tester.pumpAndSettle();

    expect(observer.pushCount, greaterThan(initialPushCount));
    expect(find.byType(UserDetailPage), findsOneWidget);
  });

  testWidgets('mounted search action opens the scene search mode bar', (
    tester,
  ) async {
    await pumpChatPage(
      tester,
      channelId: 'u_search_shell',
      channelType: WKChannelType.personal,
      channelName: 'Search Shell',
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
}

Finder _assetFinder(String assetName) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == assetName,
  );
}

Image _assetImage(WidgetTester tester, String assetName) {
  return tester.widget<Image>(_assetFinder(assetName).first);
}

class _ImmediateSuccessAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
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

class _StaticFriendListNotifier extends FriendListNotifier {
  _StaticFriendListNotifier(List<Friend> friends) : super(loadOnInit: false) {
    state = AsyncValue.data(List<Friend>.from(friends, growable: false));
  }
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

class _TestNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    pushCount += 1;
  }
}

class _RobotSyncAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/v1/robot/sync') {
      final targets = _resolvePayloadList(options.data);
      final wantsGifRobot = targets.any(
        (item) => item['username']?.toString().toLowerCase() == 'gif',
      );
      return ResponseBody.fromString(
        jsonEncode(
          wantsGifRobot
              ? <Map<String, dynamic>>[
                  <String, dynamic>{
                    'robot_id': 'giphy',
                    'username': 'gif',
                    'placeholder': 'Search GIFs',
                    'inline_on': 1,
                    'status': 1,
                    'version': 1,
                    'menus': const <Map<String, dynamic>>[],
                  },
                ]
              : <Map<String, dynamic>>[
                  <String, dynamic>{
                    'robot_id': 'u_robot_menu',
                    'username': 'robot_menu',
                    'status': 1,
                    'version': 1,
                    'menus': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'robot_id': 'u_robot_menu',
                        'cmd': '/wave',
                        'remark': 'Wave hello',
                        'type': 'command',
                      },
                    ],
                  },
                ],
        ),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }

    if (options.path == '/v1/robot/inline_query') {
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'inline_query_sid': 'sid-gif',
          'results': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'gif',
              'id': 'gif-1',
              'url': 'https://example.com/cat.gif',
              'extra': <String, dynamic>{'width': 120, 'height': 120},
            },
          ],
          'next_offset': '',
        }),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  List<Map<String, dynamic>> _resolvePayloadList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }
    return const <Map<String, dynamic>>[];
  }
}

class _RecordingChatSceneGateway extends ChatSceneGateway {
  final List<WKMessageContent> sentContents = <WKMessageContent>[];

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
  }) async {
    sentContents.add(content);
  }

  @override
  List<MessageReaction> prepareReactions(WKMsg message) {
    return const <MessageReaction>[];
  }

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) async {}

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
  Stream<ReactionUpdate> watchReactionUpdates() {
    return const Stream<ReactionUpdate>.empty();
  }
}

class _RecordingTypingGateway implements ChatTypingGateway {
  final List<_TypingGatewayCall> calls = <_TypingGatewayCall>[];

  @override
  Future<void> sendIfAllowed({
    required String channelId,
    required int channelType,
  }) async {
    calls.add(
      _TypingGatewayCall(channelId: channelId, channelType: channelType),
    );
  }
}

class _NoopTypingGateway implements ChatTypingGateway {
  const _NoopTypingGateway();

  @override
  Future<void> sendIfAllowed({
    required String channelId,
    required int channelType,
  }) async {}
}

class _TypingGatewayCall {
  const _TypingGatewayCall({
    required this.channelId,
    required this.channelType,
  });

  final String channelId;
  final int channelType;

  @override
  bool operator ==(Object other) {
    return other is _TypingGatewayCall &&
        other.channelId == channelId &&
        other.channelType == channelType;
  }

  @override
  int get hashCode => Object.hash(channelId, channelType);
}

class _FakeChatExpressionRegistry extends ChatExpressionRegistry {
  _FakeChatExpressionRegistry();

  static const ChatStickerDefinition _sampleSticker = ChatStickerDefinition(
    packId: 'android_sample_motion',
    stickerId: 'typing',
    title: 'Typing',
    previewKey: 'assets/stickers/sample_pack/typing.webp',
    animationKey: 'assets/stickers/sample_pack/typing.webp',
    mimeType: 'image/webp',
    width: 512,
    height: 512,
    loopCount: 0,
    fallbackText: '[贴纸]',
  );

  @override
  Future<ChatExpressionRegistrySnapshot> load() async {
    return ChatExpressionRegistrySnapshot(
      categories: <ChatExpressionCategory>[
        const ChatExpressionCategory(
          id: 'recent',
          kind: ChatExpressionKind.emoji,
          label: '最近',
          iconKey: 'recent',
          emojiTags: <String>[],
          stickers: <ChatStickerDefinition>[],
          recents: <ChatExpressionRecentRecord>[],
        ),
        for (final groupId in androidEmojiCatalog.groupIds)
          ChatExpressionCategory(
            id: 'emoji:$groupId',
            kind: ChatExpressionKind.emoji,
            label: groupId,
            iconKey: 'emoji:$groupId',
            emojiTags: androidEmojiCatalog
                .entriesForGroup(groupId)
                .map((item) => item.tag)
                .toList(growable: false),
            stickers: const <ChatStickerDefinition>[],
            recents: const <ChatExpressionRecentRecord>[],
          ),
        const ChatExpressionCategory(
          id: 'sticker:android_sample_motion',
          kind: ChatExpressionKind.sticker,
          label: '示例贴纸',
          iconKey: 'assets/stickers/sample_pack/group.webp',
          emojiTags: <String>[],
          stickers: <ChatStickerDefinition>[_sampleSticker],
          recents: <ChatExpressionRecentRecord>[],
        ),
        const ChatExpressionCategory(
          id: 'gif',
          kind: ChatExpressionKind.gif,
          label: '动图',
          iconKey: 'gif',
          emojiTags: <String>[],
          stickers: <ChatStickerDefinition>[],
          recents: <ChatExpressionRecentRecord>[],
          isGif: true,
        ),
      ],
    );
  }

  @override
  Future<void> rememberEmoji(AndroidEmojiEntry entry) async {}

  @override
  Future<void> rememberSticker(ChatStickerDefinition sticker) async {}

  @override
  Future<void> rememberGif({
    required String title,
    required String url,
    required int width,
    required int height,
  }) async {}

  @override
  Future<void> rememberRecent(ChatExpressionRecentRecord record) async {}
}

class _FakeChatGifPanelService extends ChatGifPanelService {
  _FakeChatGifPanelService({required this.results});

  final List<ChatGifPanelResult> results;

  @override
  Future<List<ChatGifPanelResult>> search(
    String query, {
    required ChatSession session,
  }) async {
    return results;
  }
}

class _NoopConversationPatchTelemetry implements ConversationPatchTelemetry {
  @override
  void recordConversationPatchApply(Duration duration) {}
}

class _SpyChatFlameMessageRuntime extends ChatFlameMessageRuntime {
  int sweepCalls = 0;

  @override
  Future<void> sweepViewedMessages() async {
    sweepCalls += 1;
  }
}
