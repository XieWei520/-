import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_shell_models.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('forwarding route round-trips through json', () {
    final route = FeishuMonitorForwardingRoute(
      id: 'route_1',
      enabled: true,
      sourceConversationId: 'feed:alpha',
      sourceConversationName: 'Alpha Group',
      sourceConversationType: 'group',
      targetGroupId: 'wk_group_1',
      targetGroupName: '悟空 Alpha 群',
      createdAt: DateTime.parse('2026-05-09T01:02:03Z'),
      updatedAt: DateTime.parse('2026-05-09T04:05:06Z'),
    );

    final decoded = FeishuMonitorForwardingRoute.fromJson(route.toJson());

    expect(decoded.id, 'route_1');
    expect(decoded.enabled, isTrue);
    expect(decoded.sourceConversationId, 'feed:alpha');
    expect(decoded.sourceConversationName, 'Alpha Group');
    expect(decoded.sourceConversationType, 'group');
    expect(decoded.targetGroupId, 'wk_group_1');
    expect(decoded.targetGroupName, '悟空 Alpha 群');
    expect(decoded.createdAt, DateTime.parse('2026-05-09T01:02:03Z'));
    expect(decoded.updatedAt, DateTime.parse('2026-05-09T04:05:06Z'));
  });

  test(
    'findRouteForEvent prefers conversation id and falls back to normalized name',
    () {
      final routes = <FeishuMonitorForwardingRoute>[
        _route(
          id: 'route_alpha',
          sourceConversationId: 'feed:alpha',
          sourceConversationName: 'Alpha Group',
          targetGroupId: 'wk_alpha',
        ),
        _route(
          id: 'route_beta',
          sourceConversationId: '',
          sourceConversationName: 'Beta   Group',
          targetGroupId: 'wk_beta',
        ),
      ];

      final byId = findFeishuMonitorRouteForEvent(
        routes: routes,
        event: _event(
          conversationId: 'feed:alpha',
          conversationName: 'Wrong Name',
        ),
      );
      final byName = findFeishuMonitorRouteForEvent(
        routes: routes,
        event: _event(conversationId: '', conversationName: ' beta group '),
      );
      final unmatched = findFeishuMonitorRouteForEvent(
        routes: routes,
        event: _event(
          conversationId: 'feed:missing',
          conversationName: 'Missing',
        ),
      );

      expect(byId?.targetGroupId, 'wk_alpha');
      expect(byName?.targetGroupId, 'wk_beta');
      expect(unmatched, isNull);
    },
  );

  test(
    'findRouteForEvent falls back to name when observed conversation id drifts',
    () {
      final route = _route(
        sourceConversationId: 'feed:2e500f14',
        sourceConversationName: 'Alpha Group',
        targetGroupId: 'wk_alpha',
      );

      final matched = findFeishuMonitorRouteForEvent(
        routes: <FeishuMonitorForwardingRoute>[route],
        event: _event(
          conversationId: 'feed:ae500f14',
          conversationName: ' alpha   group ',
        ),
      );

      expect(matched?.targetGroupId, 'wk_alpha');
    },
  );

  test('disabled routes are ignored by matcher', () {
    final route = _route(
      enabled: false,
      sourceConversationId: 'feed:alpha',
      sourceConversationName: 'Alpha Group',
      targetGroupId: 'wk_alpha',
    );

    final matched = findFeishuMonitorRouteForEvent(
      routes: <FeishuMonitorForwardingRoute>[route],
      event: _event(conversationId: 'feed:alpha'),
    );

    expect(matched, isNull);
  });

  test('settings store saves and loads v2 route list', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const store = SharedPreferencesFeishuMonitorForwardingSettingsStore();
    final settings = FeishuMonitorForwardingSettings(
      enabled: true,
      routes: <FeishuMonitorForwardingRoute>[
        _route(
          id: 'route_alpha',
          sourceConversationId: 'feed:alpha',
          targetGroupId: 'wk_alpha',
          targetGroupName: '悟空 Alpha 群',
        ),
        _route(
          id: 'route_beta',
          sourceConversationId: 'feed:beta',
          sourceConversationName: 'Beta Group',
          targetGroupId: 'wk_beta',
          targetGroupName: '悟空 Beta 群',
        ),
      ],
      legacyTargetGroupId: '',
    );

    await store.save(settings);
    final loaded = await store.load();

    expect(loaded.enabled, isTrue);
    expect(loaded.routes, hasLength(2));
    expect(loaded.routes.first.sourceConversationId, 'feed:alpha');
    expect(loaded.routes.first.targetGroupId, 'wk_alpha');
    expect(loaded.routes.last.sourceConversationName, 'Beta Group');
    expect(loaded.routes.last.targetGroupName, '悟空 Beta 群');
  });

  test(
    'settings store migrates old single target as legacy hint only',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'feishu_monitor_forwarding_enabled': true,
        'feishu_monitor_target_group_id': 'old_group',
      });
      const store = SharedPreferencesFeishuMonitorForwardingSettingsStore();

      final loaded = await store.load();

      expect(loaded.enabled, isTrue);
      expect(loaded.routes, isEmpty);
      expect(loaded.legacyTargetGroupId, 'old_group');
    },
  );

  test(
    'settings targetGroupId remains legacy-only even with one scoped route',
    () {
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
        legacyTargetGroupId: '',
      );

      expect(settings.targetGroupId, '');
      expect(settings.toRule().targetGroupId, '');
    },
  );

  test(
    'settings targetGroupId preserves old constructor compatibility only as legacy hint',
    () {
      const settings = FeishuMonitorForwardingSettings(
        enabled: true,
        targetGroupId: 'old_group',
      );

      expect(settings.legacyTargetGroupId, 'old_group');
      expect(settings.targetGroupId, 'old_group');
      expect(settings.routes, isEmpty);
    },
  );

  test('settings store falls back safely when v2 json is corrupt', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'feishu_monitor_forwarding_settings_v2': '{broken-json',
      'feishu_monitor_forwarding_enabled': true,
      'feishu_monitor_target_group_id': 'legacy_after_corrupt',
    });
    const store = SharedPreferencesFeishuMonitorForwardingSettingsStore();

    final loaded = await store.load();

    expect(loaded.enabled, isTrue);
    expect(loaded.routes, isEmpty);
    expect(loaded.legacyTargetGroupId, 'legacy_after_corrupt');
  });

  test('formatFeishuMonitorEventForForward includes context and body', () {
    final text = formatFeishuMonitorEventForForward(_event());

    expect(text, contains('飞书群：Alpha Group'));
    expect(text, contains('发送人：Alice'));
    expect(text, contains('hello from Feishu'));
  });

  test(
    'WkIm sender uploads prepared image before sending media message',
    () async {
      final sentImages = <WKImageContent>[];
      final gateway = ApiChatSceneGateway(
        sendMessage: (content, channel) {
          sentImages.add(content as WKImageContent);
          expect(channel.channelID, 'wk_alpha');
        },
      );
      final sender = WkImFeishuMonitorTextSender(
        gateway: gateway,
        prepareImage: (image) async => FeishuMonitorImageAttachment(
          sourceUrl: image.sourceUrl,
          localPath: r'C:\tmp\feishu-image.png',
          width: image.width,
          height: image.height,
        ),
        uploadImage:
            ({
              required filePath,
              required channelId,
              required channelType,
            }) async {
              expect(filePath, r'C:\tmp\feishu-image.png');
              expect(channelId, 'wk_alpha');
              expect(channelType, 2);
              return 'https://cdn.example.com/feishu-image.png';
            },
      );

      await sender.sendImage(
        channelId: 'wk_alpha',
        channelType: 2,
        image: const FeishuMonitorImageAttachment(
          sourceUrl: 'https://internal.feishu.cn/image-1.png',
          localPath: '',
          width: 640,
          height: 480,
        ),
      );

      expect(sentImages, hasLength(1));
      expect(sentImages.single.localPath, r'C:\tmp\feishu-image.png');
      expect(sentImages.single.url, 'https://cdn.example.com/feishu-image.png');
      expect(sentImages.single.width, 640);
      expect(sentImages.single.height, 480);
    },
  );

  test(
    'WkIm sender rejects image sends when upload returns no remote url',
    () async {
      final sentImages = <WKImageContent>[];
      final gateway = ApiChatSceneGateway(
        sendMessage: (content, channel) {
          sentImages.add(content as WKImageContent);
        },
      );
      final sender = WkImFeishuMonitorTextSender(
        gateway: gateway,
        prepareImage: (image) async => FeishuMonitorImageAttachment(
          sourceUrl: image.sourceUrl,
          localPath: r'C:\tmp\feishu-image.png',
          width: image.width,
          height: image.height,
        ),
        uploadImage:
            ({
              required filePath,
              required channelId,
              required channelType,
            }) async => '',
      );

      await expectLater(
        sender.sendImage(
          channelId: 'wk_alpha',
          channelType: 2,
          image: const FeishuMonitorImageAttachment(
            sourceUrl: 'https://internal.feishu.cn/image-1.png',
            localPath: '',
            width: 640,
            height: 480,
          ),
        ),
        throwsStateError,
      );
      expect(sentImages, isEmpty);
    },
  );

  test(
    'WkIm sender rejects image sends when preparation has no local file',
    () async {
      final sentImages = <WKImageContent>[];
      final gateway = ApiChatSceneGateway(
        sendMessage: (content, channel) {
          sentImages.add(content as WKImageContent);
        },
      );
      final sender = WkImFeishuMonitorTextSender(
        gateway: gateway,
        prepareImage: (image) async => image,
      );

      await expectLater(
        sender.sendImage(
          channelId: 'wk_alpha',
          channelType: 2,
          image: const FeishuMonitorImageAttachment(
            sourceUrl: 'https://internal.feishu.cn/image-1.png',
            localPath: '',
            width: 640,
            height: 480,
          ),
        ),
        throwsStateError,
      );
      expect(sentImages, isEmpty);
    },
  );

  test('image preparer writes data url images to local temp file', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'feishu-data-image-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final prepared = await prepareFeishuMonitorImageForWkUpload(
      const FeishuMonitorImageAttachment(
        sourceUrl: 'data:image/png;base64,AQIDBAU=',
        localPath: '',
        width: 1,
        height: 1,
      ),
      imageDirectory: tempDir,
    );

    expect(prepared.localPath, isNotEmpty);
    expect(prepared.localPath.endsWith('.png'), isTrue);
    expect(await File(prepared.localPath).exists(), isTrue);
    expect(
      await File(prepared.localPath).readAsBytes(),
      base64Decode('AQIDBAU='),
    );
    expect(prepared.width, 1);
    expect(prepared.height, 1);
  });

  test(
    'forwardRecentEvents sends only unsent events in current runtime',
    () async {
      final sender = _RecordingSender()..failImageSends = true;
      final service = FeishuMonitorForwardingService(sender: sender);
      final rule = const FeishuMonitorForwardingRule(
        enabled: true,
        targetGroupId: 'group_1',
      );

      final first = await service.forwardRecentEvents(
        rule: rule,
        events: <FeishuMonitorMessageEvent>[_event()],
      );
      final second = await service.forwardRecentEvents(
        rule: rule,
        events: <FeishuMonitorMessageEvent>[_event()],
      );

      expect(first.sent, 1);
      expect(first.skipped, 0);
      expect(second.sent, 0);
      expect(second.skipped, 1);
      expect(sender.sentTexts, hasLength(1));
      expect(sender.sentTexts.single, contains('hello from Feishu'));
      expect(sender.targetGroupIds.single, 'group_1');
    },
  );

  test(
    'forwardRecentEvents skips when rule is disabled or target is empty',
    () async {
      final sender = _RecordingSender()..failImageSends = true;
      final service = FeishuMonitorForwardingService(sender: sender);

      final disabled = await service.forwardRecentEvents(
        rule: const FeishuMonitorForwardingRule(
          enabled: false,
          targetGroupId: 'group_1',
        ),
        events: <FeishuMonitorMessageEvent>[_event()],
      );
      final missingTarget = await service.forwardRecentEvents(
        rule: const FeishuMonitorForwardingRule(
          enabled: true,
          targetGroupId: '',
        ),
        events: <FeishuMonitorMessageEvent>[_event(messageId: 'msg_2')],
      );

      expect(disabled.sent, 0);
      expect(disabled.skipped, 1);
      expect(missingTarget.sent, 0);
      expect(missingTarget.skipped, 1);
      expect(sender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents sends each source to its configured target',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            id: 'route_alpha',
            sourceConversationId: 'feed:alpha',
            sourceConversationName: 'Alpha Group',
            targetGroupId: 'wk_alpha',
            targetGroupName: '悟空 Alpha 群',
          ),
          _route(
            id: 'route_beta',
            sourceConversationId: 'feed:beta',
            sourceConversationName: 'Beta Group',
            targetGroupId: 'wk_beta',
            targetGroupName: '悟空 Beta 群',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'msg_a',
            dedupeKey: 'dedupe_a',
            conversationId: 'feed:alpha',
            conversationName: 'Alpha Group',
          ),
          _event(
            messageId: 'msg_b',
            dedupeKey: 'dedupe_b',
            conversationId: 'feed:beta',
            conversationName: 'Beta Group',
          ),
          _event(
            messageId: 'msg_c',
            dedupeKey: 'dedupe_c',
            conversationId: 'feed:missing',
            conversationName: 'Missing Group',
          ),
        ],
      );

      expect(result.sent, 2);
      expect(result.skippedUnmatched, 1);
      expect(result.skippedDuplicate, 0);
      expect(result.failed, 0);
      expect(sender.targetGroupIds, <String>['wk_alpha', 'wk_beta']);
    },
  );

  test('forwardRoutedRecentEvents uses dedupe across routed sends', () async {
    final sender = _RecordingSender();
    final service = FeishuMonitorForwardingService(sender: sender);
    final settings = FeishuMonitorForwardingSettings(
      enabled: true,
      routes: <FeishuMonitorForwardingRoute>[
        _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
      ],
    );
    final event = _event(
      messageId: 'msg_a',
      dedupeKey: 'dedupe_a',
      conversationId: 'feed:alpha',
    );

    final first = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <FeishuMonitorMessageEvent>[event],
    );
    final second = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <FeishuMonitorMessageEvent>[event],
    );

    expect(first.sent, 1);
    expect(second.sent, 0);
    expect(second.skippedDuplicate, 1);
    expect(sender.targetGroupIds, <String>['wk_alpha']);
  });

  test('forwardRoutedRecentEvents dedupes concurrent routed sends', () async {
    final sender = _RecordingSender();
    final sendGate = Completer<void>();
    sender.beforeRecordTextSend = () => sendGate.future;
    final dedupeStore = _MemoryForwardingDedupeStore();
    final firstService = FeishuMonitorForwardingService(
      sender: sender,
      dedupeStore: dedupeStore,
    );
    final secondService = FeishuMonitorForwardingService(
      sender: sender,
      dedupeStore: dedupeStore,
    );
    final settings = FeishuMonitorForwardingSettings(
      enabled: true,
      routes: <FeishuMonitorForwardingRoute>[
        _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
      ],
    );
    final event = _event(
      messageId: 'feed:63262e78',
      dedupeKey: 'feed:alpha:feed:63262e78',
      conversationId: 'feed:alpha',
      conversationName: 'Alpha Group',
      text: '联合测试文本0931',
    );

    final first = firstService.forwardRoutedRecentEvents(
      settings: settings,
      events: <FeishuMonitorMessageEvent>[event],
    );
    await Future<void>.delayed(Duration.zero);
    final second = secondService.forwardRoutedRecentEvents(
      settings: settings,
      events: <FeishuMonitorMessageEvent>[event],
    );
    await Future<void>.delayed(Duration.zero);
    sendGate.complete();

    final results = await Future.wait(<Future<FeishuMonitorForwardingResult>>[
      first,
      second,
    ]);

    expect(results.fold<int>(0, (sum, item) => sum + item.sent), 1);
    expect(
      results.fold<int>(0, (sum, item) => sum + item.skippedDuplicate),
      1,
    );
    expect(sender.sentTexts, hasLength(1));
  });

  test('forwardRoutedRecentEvents retries after text send failure', () async {
    final sender = _RecordingSender()..failTextSends = true;
    final dedupeStore = _MemoryForwardingDedupeStore();
    final service = FeishuMonitorForwardingService(
      sender: sender,
      dedupeStore: dedupeStore,
    );
    final settings = FeishuMonitorForwardingSettings(
      enabled: true,
      routes: <FeishuMonitorForwardingRoute>[
        _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
      ],
    );
    final event = _event(
      messageId: 'feed:419641d2',
      dedupeKey: 'feed:alpha:feed:419641d2',
      conversationId: 'feed:alpha',
      conversationName: 'Alpha Group',
      text: '联合测试文本0931',
    );

    final first = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <FeishuMonitorMessageEvent>[event],
    );
    final keysAfterFailure = await dedupeStore.loadSentKeys();
    sender.failTextSends = false;
    final second = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <FeishuMonitorMessageEvent>[event],
    );

    expect(first.sent, 0);
    expect(first.failed, 1);
    expect(keysAfterFailure, isEmpty);
    expect(second.sent, 1);
    expect(second.skippedDuplicate, 0);
    expect(sender.sentTexts, hasLength(1));
  });

  test(
    'forwardRoutedRecentEvents treats repeated feed card observations as one message',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:first',
            dedupeKey: 'feed:alpha:feed:first',
            conversationId: 'feed:alpha',
            senderName: '橘生淮南',
            text: '同一条飞书消息',
          ),
          _event(
            messageId: 'feed:first',
            dedupeKey: 'feed:alpha:feed:first',
            conversationId: 'feed:alpha',
            senderName: '橘生淮南',
            text: '同一条飞书消息',
          ),
          _event(
            messageId: 'feed:first',
            dedupeKey: 'feed:alpha:feed:first',
            conversationId: 'feed:alpha',
            senderName: '橘生淮南',
            text: '同一条飞书消息',
          ),
        ],
      );

      expect(result.sent, 1);
      expect(result.skippedDuplicate, 2);
      expect(sender.sentTexts, hasLength(1));
    },
  );

  test(
    'forwardRoutedRecentEvents does not collapse separate feed card text messages',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:ack_1201',
            dedupeKey: 'feed:alpha:feed:ack_1201',
            conversationId: 'feed:alpha',
            senderName: 'Alice',
            text: '收到',
          ),
          _event(
            messageId: 'feed:ack_1202',
            dedupeKey: 'feed:alpha:feed:ack_1202',
            conversationId: 'feed:alpha',
            senderName: 'Alice',
            text: '收到',
          ),
        ],
      );

      expect(result.sent, 2);
      expect(result.skippedDuplicate, 0);
      expect(sender.sentTexts, hasLength(2));
    },
  );

  test(
    'forwardRoutedRecentEvents skips feed-card image placeholders without attachments',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );

      final first = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:first_image_card',
            dedupeKey: 'feed:alpha:feed:first_image_card',
            conversationId: 'feed:alpha',
            senderName: '橘生淮南',
            text: '[图片]',
          ),
        ],
      );
      final second = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:second_image_card',
            dedupeKey: 'feed:alpha:feed:second_image_card',
            conversationId: 'feed:alpha',
            senderName: '橘生淮南',
            text: '[图片]',
          ),
        ],
      );

      expect(first.sent, 0);
      expect(first.skippedDuplicate, 1);
      expect(second.sent, 0);
      expect(second.skippedDuplicate, 1);
      expect(sender.sentTexts, isEmpty);
      expect(sender.sentImages, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents sends real image attachment before text fallback',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:image_1',
            dedupeKey: 'feed:alpha:feed:image_1',
            conversationId: 'feed:alpha',
            text: '[鍥剧墖]',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'https://internal.feishu.cn/image-1.png',
                localPath: '',
                width: 640,
                height: 480,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 1);
      expect(result.failed, 0);
      expect(sender.sentTexts, isEmpty);
      expect(sender.sentImages, hasLength(1));
      expect(sender.sentImages.single.channelId, 'wk_alpha');
      expect(
        sender.sentImages.single.sourceUrl,
        'https://internal.feishu.cn/image-1.png',
      );
      expect(sender.sentImages.single.width, 640);
      expect(sender.sentImages.single.height, 480);
    },
  );

  test(
    'forwardRoutedRecentEvents does not send dom_probe image attachments',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'dom:image_alpha',
            dedupeKey: 'feed:alpha:dom:image_alpha',
            conversationId: 'feed:alpha',
            text: '[Image]',
            captureSource: 'dom_probe',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'data:image/webp;base64,SAME',
                localPath: '',
                width: 750,
                height: 338,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDuplicate, 1);
      expect(sender.sentImages, isEmpty);
      expect(sender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents does not send body_text_probe image attachments',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'body:image_alpha',
            dedupeKey: 'feed:alpha:body:image_alpha',
            conversationId: 'feed:alpha',
            text: '[Image]',
            captureSource: 'body_text_probe',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'https://internal.feishu.cn/body-image.png',
                localPath: '',
                width: 640,
                height: 480,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDuplicate, 1);
      expect(sender.sentImages, isEmpty);
      expect(sender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents skips dom text noise and dom images',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'feed:alpha',
            sourceConversationName: 'Alpha Group',
            targetGroupId: 'wk_alpha',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'dom:history_1',
            dedupeKey: 'feed:alpha:dom:history_1',
            conversationId: 'feed:alpha',
            senderName: '',
            text: '自定义机器人\n机器人\n5月8日\n自定义机器人\n机器人',
            captureSource: 'dom_probe',
          ),
          _event(
            messageId: 'dom:image_1',
            dedupeKey: 'feed:alpha:dom:image_1',
            conversationId: 'feed:alpha',
            senderName: '',
            text: '橘生淮南\n[图片]',
            captureSource: 'dom_probe',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'data:image/png;base64,AQIDBAU=',
                localPath: '',
                width: 500,
                height: 232,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDuplicate, 2);
      expect(sender.sentTexts, isEmpty);
      expect(sender.sentImages, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents falls back to text when image send fails',
    () async {
      final sender = _RecordingSender()..failImageSends = true;
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:image_1',
            dedupeKey: 'feed:alpha:feed:image_1',
            conversationId: 'feed:alpha',
            text: '[鍥剧墖]',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'https://internal.feishu.cn/image-1.png',
                localPath: '',
                width: 640,
                height: 480,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 1);
      expect(result.failed, 0);
      expect(sender.sentImages, isEmpty);
      expect(sender.sentTexts, hasLength(1));
      expect(sender.sentTexts.single, contains('[鍥剧墖]'));
    },
  );

  test(
    'forwardRoutedRecentEvents skips dom blob image placeholders',
    () async {
      final dedupeStore = _MemoryForwardingDedupeStore();
      final pendingSender = _RecordingSender()..failImageSends = true;
      final resolvedSender = _RecordingSender();
      final pendingService = FeishuMonitorForwardingService(
        sender: pendingSender,
        dedupeStore: dedupeStore,
      );
      final retryService = FeishuMonitorForwardingService(
        sender: resolvedSender,
        dedupeStore: dedupeStore,
      );
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );
      final imageEvent = _event(
        messageId: 'dom:image_retry',
        dedupeKey: 'feed:alpha:dom:image_retry',
        conversationId: 'feed:alpha',
        text: '[图片]',
        captureSource: 'dom_probe',
        imageAttachments: const <FeishuMonitorImageAttachment>[
          FeishuMonitorImageAttachment(
            sourceUrl: 'blob:https://example.feishu.cn/image-retry',
            localPath: '',
            width: 640,
            height: 480,
          ),
        ],
      );
      final resolvedImageEvent = _event(
        messageId: 'dom:image_retry',
        dedupeKey: 'feed:alpha:dom:image_retry',
        conversationId: 'feed:alpha',
        text: '[图片]',
        captureSource: 'dom_probe',
        imageAttachments: const <FeishuMonitorImageAttachment>[
          FeishuMonitorImageAttachment(
            sourceUrl: 'data:image/png;base64,AQIDBAU=',
            localPath: '',
            width: 640,
            height: 480,
          ),
        ],
      );

      FeishuMonitorForwardingResult? first;
      for (var i = 0; i < 5; i += 1) {
        first = await pendingService.forwardRoutedRecentEvents(
          settings: settings,
          events: <FeishuMonitorMessageEvent>[imageEvent],
        );
      }
      final fallback = await pendingService.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[imageEvent],
      );
      final third = await retryService.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[resolvedImageEvent],
      );
      final keysAfterResolve = await dedupeStore.loadSentKeys();

      expect(first?.sent, 0);
      expect(first?.skippedDuplicate, 1);
      expect(fallback.sent, 0);
      expect(fallback.skippedDuplicate, 1);
      expect(third.sent, 0);
      expect(third.skippedDuplicate, 1);
      expect(pendingSender.sentTexts, isEmpty);
      expect(pendingSender.sentImages, isEmpty);
      expect(resolvedSender.sentTexts, isEmpty);
      expect(resolvedSender.sentImages, isEmpty);
      expect(keysAfterResolve, isNot(contains('feed:alpha:dom:image_retry')));
      expect(
        keysAfterResolve,
        isNot(contains('feed:alpha:dom:image_retry:media')),
      );
    },
  );

  test(
    'forwardRoutedRecentEvents skips dom blob placeholder fallback',
    () async {
      final sender = _RecordingSender()..failImageSends = true;
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );
      final imageEvent = _event(
        messageId: 'dom:image_context',
        dedupeKey: 'feed:alpha:dom:image_context',
        conversationId: 'feed:alpha',
        text: 'Alice\nprevious message\nanother message\n01:42\nAlice',
        captureSource: 'dom_probe',
        imageAttachments: const <FeishuMonitorImageAttachment>[
          FeishuMonitorImageAttachment(
            sourceUrl: 'blob:https://example.feishu.cn/image-context',
            localPath: '',
            width: 640,
            height: 480,
          ),
        ],
      );

      for (var i = 0; i < 5; i += 1) {
        await service.forwardRoutedRecentEvents(
          settings: settings,
          events: <FeishuMonitorMessageEvent>[imageEvent],
        );
      }
      final fallback = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[imageEvent],
      );

      expect(fallback.sent, 0);
      expect(fallback.skippedDuplicate, 1);
      expect(sender.sentImages, isEmpty);
      expect(sender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents keeps media retry open after text fallback',
    () async {
      final dedupeStore = _MemoryForwardingDedupeStore();
      final failingSender = _RecordingSender()..failImageSends = true;
      final failingService = FeishuMonitorForwardingService(
        sender: failingSender,
        dedupeStore: dedupeStore,
      );
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );
      final imageEvent = _event(
        messageId: 'feed:image_retry',
        dedupeKey: 'feed:alpha:feed:image_retry',
        conversationId: 'feed:alpha',
        text: '[图片]',
        imageAttachments: const <FeishuMonitorImageAttachment>[
          FeishuMonitorImageAttachment(
            sourceUrl: 'https://internal.feishu.cn/image-retry.png',
            localPath: '',
            width: 640,
            height: 480,
          ),
        ],
      );

      final first = await failingService.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[imageEvent],
      );
      final keysAfterFallback = await dedupeStore.loadSentKeys();
      final succeedingSender = _RecordingSender();
      final succeedingService = FeishuMonitorForwardingService(
        sender: succeedingSender,
        dedupeStore: dedupeStore,
      );
      final second = await succeedingService.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[imageEvent],
      );
      final keysAfterImage = await dedupeStore.loadSentKeys();

      expect(first.sent, 1);
      expect(failingSender.sentTexts, hasLength(1));
      expect(keysAfterFallback, contains('feed:alpha:feed:image_retry'));
      expect(
        keysAfterFallback,
        isNot(contains('feed:alpha:feed:image_retry:media')),
      );
      expect(second.sent, 1);
      expect(second.skippedDuplicate, 0);
      expect(succeedingSender.sentImages, hasLength(1));
      expect(succeedingSender.sentTexts, isEmpty);
      expect(keysAfterImage, contains('feed:alpha:feed:image_retry:media'));
    },
  );

  test(
    'forwardRoutedRecentEvents retries real image after placeholder was deduped',
    () async {
      final dedupeStore = _MemoryForwardingDedupeStore();
      await dedupeStore.saveSentKeys(<String>[
        'feed_card_probe:feed:alpha:Alice:[图片]',
        'feed:alpha:feed:image_1',
      ]);
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(
        sender: sender,
        dedupeStore: dedupeStore,
      );
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:image_1',
            dedupeKey: 'feed:alpha:feed:image_1',
            conversationId: 'feed:alpha',
            senderName: 'Alice',
            text: '[图片]',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'https://internal.feishu.cn/image-1.png',
                localPath: '',
                width: 640,
                height: 480,
              ),
            ],
          ),
        ],
      );
      final second = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:image_1',
            dedupeKey: 'feed:alpha:feed:image_1',
            conversationId: 'feed:alpha',
            senderName: 'Alice',
            text: '[图片]',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'https://internal.feishu.cn/image-1.png',
                localPath: '',
                width: 640,
                height: 480,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 1);
      expect(result.skippedDuplicate, 0);
      expect(second.sent, 0);
      expect(second.skippedDuplicate, 1);
      expect(sender.sentImages, hasLength(1));
      expect(sender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents skips duplicate media fingerprints in same batch',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: '7638063174163385529',
            dedupeKey: 'feed:alpha:7638063174163385529',
            conversationId: 'feed:alpha',
            text: '[图片]',
            captureSource: 'dom_probe',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'data:image/webp;base64,SAME',
                localPath: '',
                width: 750,
                height: 338,
              ),
            ],
          ),
          _event(
            messageId: 'dom:duplicate',
            dedupeKey: 'feed:alpha:dom_image:750x338:data:same',
            conversationId: 'feed:alpha',
            text: '[图片]',
            captureSource: 'dom_probe',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'data:image/webp;base64,SAME',
                localPath: '',
                width: 750,
                height: 338,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDuplicate, 2);
      expect(sender.sentImages, isEmpty);
      expect(sender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents skips persisted duplicate media fingerprints across routes',
    () async {
      final dedupeStore = _MemoryForwardingDedupeStore();
      final firstSender = _RecordingSender();
      final firstService = FeishuMonitorForwardingService(
        sender: firstSender,
        dedupeStore: dedupeStore,
      );
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
          _route(
            sourceConversationId: 'feed:beta',
            sourceConversationName: 'Beta Group',
            targetGroupId: 'wk_beta',
          ),
        ],
      );
      const duplicateImage = FeishuMonitorImageAttachment(
        sourceUrl: 'data:image/webp;base64,SAME',
        localPath: '',
        width: 750,
        height: 338,
      );

      final first = await firstService.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'dom:image_alpha',
            dedupeKey: 'feed:alpha:dom:image_alpha',
            conversationId: 'feed:alpha',
            conversationName: 'Alpha Group',
            text: '[图片]',
            captureSource: 'dom_probe',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              duplicateImage,
            ],
          ),
        ],
      );
      final secondSender = _RecordingSender();
      final secondService = FeishuMonitorForwardingService(
        sender: secondSender,
        dedupeStore: dedupeStore,
      );
      final second = await secondService.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'dom:image_beta_old',
            dedupeKey: 'feed:beta:dom:image_beta_old',
            conversationId: 'feed:beta',
            conversationName: 'Beta Group',
            text: '[图片]',
            captureSource: 'dom_probe',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              duplicateImage,
            ],
          ),
        ],
      );

      expect(first.sent, 0);
      expect(first.skippedDuplicate, 1);
      expect(firstSender.sentImages, isEmpty);
      expect(second.sent, 0);
      expect(second.skippedDuplicate, 1);
      expect(secondSender.sentTexts, isEmpty);
      expect(secondSender.sentImages, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents persists dedupe keys across service restarts',
    () async {
      final dedupeStore = _MemoryForwardingDedupeStore();
      final firstSender = _RecordingSender();
      final firstService = FeishuMonitorForwardingService(
        sender: firstSender,
        dedupeStore: dedupeStore,
      );
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );
      final event = _event(
        messageId: 'feed:first',
        dedupeKey: 'feed:alpha:feed:first',
        conversationId: 'feed:alpha',
      );

      final first = await firstService.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[event],
      );
      final secondSender = _RecordingSender();
      final secondService = FeishuMonitorForwardingService(
        sender: secondSender,
        dedupeStore: dedupeStore,
      );
      final second = await secondService.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[event],
      );

      expect(first.sent, 1);
      expect(second.sent, 0);
      expect(second.skippedDuplicate, 1);
      expect(firstSender.sentTexts, hasLength(1));
      expect(secondSender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents skips all events when global forwarding is disabled',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);

      final result = await service.forwardRoutedRecentEvents(
        settings: FeishuMonitorForwardingSettings(
          enabled: false,
          routes: <FeishuMonitorForwardingRoute>[
            _route(
              sourceConversationId: 'feed:alpha',
              targetGroupId: 'wk_alpha',
            ),
          ],
        ),
        events: <FeishuMonitorMessageEvent>[
          _event(conversationId: 'feed:alpha'),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDisabled, 1);
      expect(sender.targetGroupIds, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents counts matching disabled route as skippedDisabled',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            enabled: false,
            sourceConversationId: 'feed:alpha',
            targetGroupId: 'wk_alpha',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(conversationId: 'feed:alpha'),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDisabled, 1);
      expect(result.skippedUnmatched, 0);
      expect(sender.targetGroupIds, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents counts matching empty target route as skippedDisabled',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: ''),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(conversationId: 'feed:alpha'),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDisabled, 1);
      expect(result.skippedUnmatched, 0);
      expect(sender.targetGroupIds, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents prefers enabled duplicate route over disabled duplicate',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            id: 'disabled_route',
            enabled: false,
            sourceConversationId: 'feed:alpha',
            targetGroupId: 'wk_disabled',
          ),
          _route(
            id: 'enabled_route',
            enabled: true,
            sourceConversationId: 'feed:alpha',
            targetGroupId: 'wk_enabled',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(conversationId: 'feed:alpha'),
        ],
      );

      expect(result.sent, 1);
      expect(result.skippedDisabled, 0);
      expect(result.skippedUnmatched, 0);
      expect(sender.targetGroupIds, <String>['wk_enabled']);
    },
  );
}

FeishuMonitorMessageEvent _event({
  String messageId = 'msg_1',
  String dedupeKey = 'chat_1:msg_1',
  String conversationId = 'chat_1',
  String conversationName = 'Alpha Group',
  String senderName = 'Alice',
  String text = 'hello from Feishu',
  List<FeishuMonitorImageAttachment> imageAttachments =
      const <FeishuMonitorImageAttachment>[],
  String captureSource = 'feed_card_probe',
}) {
  return FeishuMonitorMessageEvent(
    eventId: 'event_$messageId',
    dedupeKey: dedupeKey,
    accountId: '',
    conversationId: conversationId,
    conversationName: conversationName,
    conversationType: 'unknown',
    messageId: messageId,
    senderId: '',
    senderName: senderName,
    messageType: 'text',
    text: text,
    imageAttachments: imageAttachments,
    sentAt: null,
    observedAt: DateTime.parse('2026-05-09T10:02:00Z'),
    captureSource: captureSource,
  );
}

FeishuMonitorForwardingRoute _route({
  String id = 'route_1',
  bool enabled = true,
  String sourceConversationId = 'chat_1',
  String sourceConversationName = 'Alpha Group',
  String sourceConversationType = 'group',
  String targetGroupId = 'group_1',
  String targetGroupName = 'Target Group',
}) {
  return FeishuMonitorForwardingRoute(
    id: id,
    enabled: enabled,
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    sourceConversationType: sourceConversationType,
    targetGroupId: targetGroupId,
    targetGroupName: targetGroupName,
    createdAt: DateTime.parse('2026-05-09T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-09T01:00:00Z'),
  );
}

class _RecordingSender implements FeishuMonitorTextSender {
  final sentTexts = <String>[];
  final targetGroupIds = <String>[];
  final sentImages = <_RecordedImageSend>[];
  Future<void> Function()? beforeRecordTextSend;
  bool failTextSends = false;
  bool failImageSends = false;

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
  }) async {
    if (failTextSends) {
      throw StateError('text send failed');
    }
    final beforeRecordTextSend = this.beforeRecordTextSend;
    if (beforeRecordTextSend != null) {
      await beforeRecordTextSend();
    }
    targetGroupIds.add(channelId);
    sentTexts.add(text);
  }

  @override
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required FeishuMonitorImageAttachment image,
  }) async {
    if (failImageSends) {
      throw StateError('image send failed');
    }
    targetGroupIds.add(channelId);
    sentImages.add(
      _RecordedImageSend(
        channelId: channelId,
        channelType: channelType,
        sourceUrl: image.sourceUrl,
        localPath: image.localPath,
        width: image.width,
        height: image.height,
      ),
    );
  }
}

class _RecordedImageSend {
  const _RecordedImageSend({
    required this.channelId,
    required this.channelType,
    required this.sourceUrl,
    required this.localPath,
    required this.width,
    required this.height,
  });

  final String channelId;
  final int channelType;
  final String sourceUrl;
  final String localPath;
  final int width;
  final int height;
}

class _MemoryForwardingDedupeStore
    implements FeishuMonitorForwardingDedupeStore {
  final _keys = <String>[];

  @override
  Future<List<String>> loadSentKeys() async => List<String>.from(_keys);

  @override
  Future<void> saveSentKeys(List<String> keys) async {
    _keys
      ..clear()
      ..addAll(keys);
  }
}
