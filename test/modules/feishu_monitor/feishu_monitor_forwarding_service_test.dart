import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/robot_message_identity.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_shell_models.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';

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
      workerId: 'worker-2',
      relayDisplayName: '飞书转发助手',
      relayAvatar: 'https://cdn.example.com/feishu-relay.png',
      createdAt: DateTime.parse('2026-05-09T01:02:03Z'),
      updatedAt: DateTime.parse('2026-05-09T04:05:06Z'),
    );

    final json = route.toJson();
    final decoded = FeishuMonitorForwardingRoute.fromJson(json);

    expect(json['worker_id'], 'worker-2');
    expect(decoded.id, 'route_1');
    expect(decoded.enabled, isTrue);
    expect(decoded.sourceConversationId, 'feed:alpha');
    expect(decoded.sourceConversationName, 'Alpha Group');
    expect(decoded.sourceConversationType, 'group');
    expect(decoded.targetGroupId, 'wk_group_1');
    expect(decoded.targetGroupName, '悟空 Alpha 群');
    expect(decoded.workerId, 'worker-2');
    expect(decoded.relayDisplayName, '飞书转发助手');
    expect(decoded.relayAvatar, 'https://cdn.example.com/feishu-relay.png');
    expect(decoded.createdAt, DateTime.parse('2026-05-09T01:02:03Z'));
    expect(decoded.updatedAt, DateTime.parse('2026-05-09T04:05:06Z'));
  });

  test('forwarding route defaults worker id for old json', () {
    final route = FeishuMonitorForwardingRoute.fromJson(<String, dynamic>{
      'id': 'route_1',
      'enabled': true,
      'source_conversation_id': 'feed:alpha',
      'source_conversation_name': 'Alpha Group',
      'source_conversation_type': 'group',
      'target_group_id': 'wk_group_1',
      'target_group_name': '悟空 Alpha 群',
      'created_at': '2026-05-09T01:02:03Z',
      'updated_at': '2026-05-09T04:05:06Z',
    });

    expect(route.workerId, '');
  });

  test('forwarding route accepts camelCase workerId json', () {
    final route = FeishuMonitorForwardingRoute.fromJson(<String, dynamic>{
      'id': 'route_camel',
      'enabled': true,
      'source_conversation_id': 'feed:alpha',
      'source_conversation_name': 'Alpha Group',
      'source_conversation_type': 'group',
      'target_group_id': 'wk_alpha',
      'target_group_name': 'Alpha',
      'workerId': 'worker-3',
      'created_at': '2026-05-09T01:02:03Z',
      'updated_at': '2026-05-09T04:05:06Z',
    });

    expect(route.workerId, 'worker-3');
  });

  test('forwarding route copyWith preserves and updates worker id', () {
    final route = _route(
      sourceConversationId: 'feed:alpha',
      targetGroupId: 'wk_alpha',
      workerId: 'worker-2',
    );

    expect(route.copyWith(targetGroupName: 'Alpha').workerId, 'worker-2');
    expect(route.copyWith(workerId: 'worker-4').workerId, 'worker-4');
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
    'findRouteForEvent falls back to name when event has no conversation id',
    () {
      final route = _route(
        sourceConversationId: 'feed:2e500f14',
        sourceConversationName: 'Alpha Group',
        targetGroupId: 'wk_alpha',
      );

      final matched = findFeishuMonitorRouteForEvent(
        routes: <FeishuMonitorForwardingRoute>[route],
        event: _event(
          conversationId: '',
          conversationName: ' alpha   group ',
        ),
      );

      expect(matched?.targetGroupId, 'wk_alpha');
    },
  );

  test(
    'findRouteForEvent rejects name fallback when event has another source id',
    () {
      final route = _route(
        sourceConversationId: 'feed:alpha',
        sourceConversationName: 'Alpha Group',
        targetGroupId: 'wk_alpha',
      );

      final matched = findFeishuMonitorRouteForEvent(
        routes: <FeishuMonitorForwardingRoute>[route],
        event: _event(
          conversationId: 'feed:other',
          conversationName: 'Alpha Group',
        ),
      );

      expect(matched, isNull);
    },
  );

  test('findRouteForEvent rejects dom events with conflicting id and name', () {
    final routes = <FeishuMonitorForwardingRoute>[
      _route(
        id: 'route_alpha',
        sourceConversationId: 'feed:2e500f14',
        sourceConversationName: 'Alpha Group',
        targetGroupId: 'wk_alpha',
      ),
      _route(
        id: 'route_beta',
        sourceConversationId: 'feed:4ec2f034',
        sourceConversationName: 'Beta Group',
        targetGroupId: 'wk_beta',
      ),
    ];

    final matched = findFeishuMonitorRouteForEvent(
      routes: routes,
      event: _event(
        conversationId: 'feed:2e500f14',
        conversationName: 'Beta Group',
        captureSource: 'dom_probe',
      ),
    );

    expect(matched, isNull);
  });

  test(
    'findRouteForEvent rejects dom events with configured id but other name',
    () {
      final route = _route(
        id: 'route_alpha',
        sourceConversationId: 'feed:2e500f14',
        sourceConversationName: '满满正能量',
        targetGroupId: 'wk_alpha',
      );

      final matched = findFeishuMonitorRouteForEvent(
        routes: <FeishuMonitorForwardingRoute>[route],
        event: _event(
          conversationId: 'feed:2e500f14',
          conversationName: '企业安全助手',
          text: '举报成立',
          captureSource: 'dom_probe',
        ),
      );

      expect(matched, isNull);
    },
  );

  test('findRouteForEvent rejects ambiguous enabled source names', () {
    final routes = <FeishuMonitorForwardingRoute>[
      _route(
        id: 'route_alpha_1',
        sourceConversationId: 'feed:stale-alpha-1',
        sourceConversationName: 'Alpha Group',
        targetGroupId: 'wk_alpha_1',
      ),
      _route(
        id: 'route_alpha_2',
        sourceConversationId: 'feed:stale-alpha-2',
        sourceConversationName: ' alpha   group ',
        targetGroupId: 'wk_alpha_2',
      ),
    ];

    final matched = findFeishuMonitorRouteForEvent(
      routes: routes,
      event: _event(
        conversationId: 'feed:current-alpha',
        conversationName: 'Alpha Group',
      ),
    );

    expect(matched, isNull);
  });

  test('findRouteForEvent rejects duplicate enabled source ids', () {
    final routes = <FeishuMonitorForwardingRoute>[
      _route(
        id: 'route_alpha_1',
        sourceConversationId: 'feed:alpha',
        sourceConversationName: 'Alpha Group',
        targetGroupId: 'wk_alpha_1',
      ),
      _route(
        id: 'route_alpha_2',
        sourceConversationId: 'feed:alpha',
        sourceConversationName: 'Alpha Archive',
        targetGroupId: 'wk_alpha_2',
      ),
    ];

    final matched = findFeishuMonitorRouteForEvent(
      routes: routes,
      event: _event(
        conversationId: 'feed:alpha',
        conversationName: 'Alpha Group',
      ),
    );

    expect(matched, isNull);
  });

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
    'settings store assigns worker ids to old unsharded route lists',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const store = SharedPreferencesFeishuMonitorForwardingSettingsStore();
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: List<FeishuMonitorForwardingRoute>.generate(
          21,
          (index) => _route(
            id: 'route_$index',
            sourceConversationId: 'feed:$index',
            targetGroupId: 'wk_$index',
          ),
        ),
      );

      await store.save(settings);
      final loaded = await store.load();

      expect(loaded.routes[0].workerId, 'worker-1');
      expect(loaded.routes[19].workerId, 'worker-1');
      expect(loaded.routes[20].workerId, 'worker-2');
    },
  );

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

  test('formatFeishuMonitorEventForForward returns only message body', () {
    final text = formatFeishuMonitorEventForForward(_event());

    expect(text, 'hello from Feishu');
    expect(text, isNot(contains('Alpha Group')));
    expect(text, isNot(contains('Alice')));
  });

  test('formatFeishuMonitorEventForForward keeps empty placeholder', () {
    final text = formatFeishuMonitorEventForForward(_event(text: '   '));

    expect(text, '(空消息)');
  });

  test(
    'WkIm sender uploads prepared image before sending media message',
    () async {
      final sentImages = <WKImageContent>[];
      final expires = <int?>[];
      final gateway = ApiChatSceneGateway(
        sendMessageWithOptions: (content, channel, options) {
          sentImages.add(content as WKImageContent);
          expires.add(options?.expire);
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
      expect(expires, <int?>[feishuMonitorForwardedMessageExpireSeconds]);
    },
  );

  test('Feishu monitor image upload uses isolated retention prefix', () {
    final path = feishuMonitorForwardedImageUploadPath(
      channelId: 'group/alpha',
      channelType: 2,
      filePath: r'C:\tmp\image.PNG',
      now: DateTime.fromMillisecondsSinceEpoch(1710000000000, isUtc: true),
    );

    expect(path, '/feishu-monitor/2/group_alpha/1710000000000.png');
  });

  test('WkIm sender embeds relay identity in text payloads', () async {
    final sentTexts = <WKTextContent>[];
    final expires = <int?>[];
    final gateway = ApiChatSceneGateway(
      sendMessageWithOptions: (content, channel, options) {
        sentTexts.add(content as WKTextContent);
        expires.add(options?.expire);
        expect(channel.channelID, 'wk_alpha');
      },
    );
    final sender = WkImFeishuMonitorTextSender(gateway: gateway);

    await sender.sendText(
      channelId: 'wk_alpha',
      channelType: 2,
      text: 'hello from Feishu',
      relayIdentity: const FeishuMonitorRelayIdentity(
        provider: 'feishu',
        displayName: '飞书转发助手',
        avatar: 'https://cdn.example.com/feishu.png',
      ),
    );

    expect(sentTexts, hasLength(1));
    expect(sentTexts.single.content, 'hello from Feishu');
    final robot = parseRobotMessageIdentity(sentTexts.single.encodeJson());
    expect(robot?.provider, 'feishu');
    expect(robot?.displayName, '飞书转发助手');
    expect(robot?.displayAvatar, 'https://cdn.example.com/feishu.png');
    expect(expires, <int?>[feishuMonitorForwardedMessageExpireSeconds]);
  });

  test('WkIm sender embeds relay identity in image payloads', () async {
    final sentImages = <WKImageContent>[];
    final expires = <int?>[];
    final gateway = ApiChatSceneGateway(
      sendMessageWithOptions: (content, channel, options) {
        sentImages.add(content as WKImageContent);
        expires.add(options?.expire);
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
      relayIdentity: const FeishuMonitorRelayIdentity(
        provider: 'feishu',
        displayName: '飞书图片助手',
        avatar: 'https://cdn.example.com/feishu-image-bot.png',
      ),
    );

    expect(sentImages, hasLength(1));
    final robot = parseRobotMessageIdentity(sentImages.single.encodeJson());
    expect(robot?.provider, 'feishu');
    expect(robot?.displayName, '飞书图片助手');
    expect(
      robot?.displayAvatar,
      'https://cdn.example.com/feishu-image-bot.png',
    );
    expect(expires, <int?>[feishuMonitorForwardedMessageExpireSeconds]);
  });

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
    'image preparer cleans stale local temp images opportunistically',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'feishu-data-image-cleanup-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final stale = File('${tempDir.path}${Platform.pathSeparator}stale.png');
      final fresh = File('${tempDir.path}${Platform.pathSeparator}fresh.png');
      await stale.writeAsBytes(<int>[1]);
      await fresh.writeAsBytes(<int>[2]);
      await stale.setLastModified(DateTime.parse('2026-05-09T11:59:59Z'));
      await fresh.setLastModified(DateTime.parse('2026-05-09T12:00:00Z'));

      final deleted = await cleanupFeishuMonitorForwardedImageCache(
        imageDirectory: tempDir,
        now: DateTime.parse('2026-05-10T12:00:00Z'),
        retention: const Duration(hours: 24),
      );

      expect(deleted, 1);
      expect(await stale.exists(), isFalse);
      expect(await fresh.exists(), isTrue);
    },
  );

  test(
    'image preparer keeps current local file even when it is stale',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'feishu-data-image-current-file-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final current = File(
        '${tempDir.path}${Platform.pathSeparator}current.png',
      );
      await current.writeAsBytes(<int>[1]);
      await current.setLastModified(DateTime.parse('2026-05-09T11:59:59Z'));

      final prepared = await prepareFeishuMonitorImageForWkUpload(
        FeishuMonitorImageAttachment(
          sourceUrl: 'https://internal.feishu.cn/current.png',
          localPath: current.path,
          width: 1,
          height: 1,
        ),
        imageDirectory: tempDir,
      );

      expect(prepared.localPath, current.path);
      expect(await current.exists(), isTrue);
    },
  );

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

  test(
    'forwardRoutedRecentEvents does not send unconfigured source with matching name',
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
            messageId: 'msg_other',
            dedupeKey: 'feed:other:msg_other',
            conversationId: 'feed:other',
            conversationName: 'Alpha Group',
            text: 'message from unconfigured source',
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedUnmatched, 1);
      expect(result.failed, 0);
      expect(sender.targetGroupIds, isEmpty);
      expect(sender.sentTexts, isEmpty);
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
    expect(results.fold<int>(0, (sum, item) => sum + item.skippedDuplicate), 1);
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
    'forwardRoutedRecentEvents skips feed card after dom text was sent first',
    () async {
      final dedupeStore = _MemoryForwardingDedupeStore();
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(
        sender: sender,
        dedupeStore: dedupeStore,
      );
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            id: 'route_beta',
            sourceConversationId: 'feed:4ec2f034',
            sourceConversationName: 'Beta Group',
            targetGroupId: 'wk_beta',
          ),
        ],
      );

      final first = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: '7638986594929691836',
            dedupeKey: 'feed:4ec2f034:7638986594929691836',
            conversationId: 'feed:4ec2f034',
            conversationName: 'Beta Group',
            text: 'joint-test-dom-first',
            captureSource: 'dom_probe',
          ),
        ],
      );
      final second = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:7e793083',
            dedupeKey: 'feed:4ec2f034:feed:7e793083',
            conversationId: 'feed:4ec2f034',
            conversationName: 'Beta Group',
            text: 'joint-test-dom-first',
            captureSource: 'feed_card_probe',
          ),
        ],
      );

      expect(first.sent, 1);
      expect(second.sent, 0);
      expect(second.skippedDuplicate, 1);
      expect(sender.targetGroupIds, <String>['wk_beta']);
      expect(sender.sentTexts, <String>['joint-test-dom-first']);
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
    'forwardRoutedRecentEvents does not fall back to image placeholder text',
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
            messageId: 'network_image:feed_alpha:sha1',
            dedupeKey: 'feed:alpha:network_image:feed_alpha:sha1',
            conversationId: 'feed:alpha',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'blob:https://internal.feishu.cn/image-1',
                localPath: r'C:\tmp\image-1.webp',
                width: 640,
                height: 480,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.failed, 1);
      expect(sender.sentTexts, isEmpty);
      expect(sender.sentImages, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents passes route relay identity to text sender',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'feed:alpha',
            targetGroupId: 'wk_alpha',
            relayDisplayName: '飞书转发助手',
            relayAvatar: 'https://cdn.example.com/feishu.png',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:text_1',
            dedupeKey: 'feed:alpha:feed:text_1',
            conversationId: 'feed:alpha',
            text: 'content only',
          ),
        ],
      );

      expect(result.sent, 1);
      expect(sender.sentTexts, <String>['content only']);
      expect(sender.relayIdentities, hasLength(1));
      expect(sender.relayIdentities.single?.provider, 'feishu');
      expect(sender.relayIdentities.single?.displayName, '飞书转发助手');
      expect(
        sender.relayIdentities.single?.avatar,
        'https://cdn.example.com/feishu.png',
      );
    },
  );

  test(
    'forwardRoutedRecentEvents passes route relay identity to image sender',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'feed:alpha',
            targetGroupId: 'wk_alpha',
            relayDisplayName: '飞书图片助手',
            relayAvatar: 'https://cdn.example.com/feishu-image.png',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'network:image_1',
            dedupeKey: 'feed:alpha:network:image_1',
            conversationId: 'feed:alpha',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'https://internal.feishu.cn/original-image.png',
                localPath: r'C:\tmp\feishu-original-image.png',
                width: 1280,
                height: 720,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 1);
      expect(sender.sentImages, hasLength(1));
      expect(sender.relayIdentities, hasLength(1));
      expect(sender.relayIdentities.single?.provider, 'feishu');
      expect(sender.relayIdentities.single?.displayName, '飞书图片助手');
      expect(
        sender.relayIdentities.single?.avatar,
        'https://cdn.example.com/feishu-image.png',
      );
    },
  );

  test(
    'forwardRoutedRecentEvents sends network_original_image local files',
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
            messageId: 'network:image_1',
            dedupeKey: 'feed:alpha:network:image_1',
            conversationId: 'feed:alpha',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'https://internal.feishu.cn/original-image.png',
                localPath: r'C:\tmp\feishu-original-image.png',
                width: 1280,
                height: 720,
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
        'https://internal.feishu.cn/original-image.png',
      );
      expect(
        sender.sentImages.single.localPath,
        r'C:\tmp\feishu-original-image.png',
      );
      expect(sender.sentImages.single.width, 1280);
      expect(sender.sentImages.single.height, 720);
    },
  );

  test(
    'forwardRoutedRecentEvents sends distinct network images when message keys differ',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );
      const firstImage = FeishuMonitorImageAttachment(
        sourceUrl: 'blob:https://example.feishu.cn/repeated',
        localPath: r'C:\tmp\first-feishu-original-image.webp',
        width: 805,
        height: 393,
      );
      const secondImage = FeishuMonitorImageAttachment(
        sourceUrl: 'blob:https://example.feishu.cn/repeated',
        localPath: r'C:\tmp\second-feishu-original-image.webp',
        width: 805,
        height: 393,
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'network_image:feed_first:sha1same',
            dedupeKey: 'feed:alpha:network_image:feed_first:sha1same',
            conversationId: 'feed:alpha',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[firstImage],
          ),
          _event(
            messageId: 'network_image:feed_second:sha1same',
            dedupeKey: 'feed:alpha:network_image:feed_second:sha1same',
            conversationId: 'feed:alpha',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[secondImage],
          ),
        ],
      );

      expect(result.sent, 2);
      expect(result.skippedDuplicate, 0);
      expect(result.failed, 0);
      expect(sender.sentImages, hasLength(2));
      expect(sender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents sends one network image per local file in a batch',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'feed:ae500f14',
            sourceConversationName: 'Alpha Group',
            targetGroupId: 'wk_alpha',
          ),
        ],
      );
      const image = FeishuMonitorImageAttachment(
        sourceUrl: 'blob:https://example.feishu.cn/same-body-a',
        localPath: r'C:\tmp\same-network-body.webp',
        width: 500,
        height: 179,
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'network_image:7638827945485700314:sha_same',
            dedupeKey:
                'feed:ae500f14:network_image:7638827945485700314:sha_same',
            conversationId: 'feed:ae500f14',
            conversationName: 'Alpha Group',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[image],
          ),
          _event(
            messageId: 'network_image:ae500f14:sha_same',
            dedupeKey: 'feed:ae500f14:network_image:ae500f14:sha_same',
            conversationId: 'feed:ae500f14',
            conversationName: 'Alpha Group',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[image],
          ),
        ],
      );

      expect(result.sent, 1);
      expect(result.skippedDuplicate, 1);
      expect(result.failed, 0);
      expect(sender.sentImages, hasLength(1));
      expect(
        sender.sentImages.single.localPath,
        r'C:\tmp\same-network-body.webp',
      );
      expect(sender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents skips duplicate network image candidates for one feed card',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );
      const image = FeishuMonitorImageAttachment(
        sourceUrl: 'blob:https://example.feishu.cn/same-feed-card-image',
        localPath: r'C:\tmp\same-feed-card-image.webp',
        width: 2304,
        height: 1040,
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId:
                'network_image:feed_41005bb0:7638803494564187341:sha1same',
            dedupeKey:
                'feed:alpha:network_image:feed_41005bb0:7638803494564187341:sha1same',
            conversationId: 'feed:alpha',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[image],
          ),
          _event(
            messageId:
                'network_image:feed_41005bb0:7638803357255191766:sha1same',
            dedupeKey:
                'feed:alpha:network_image:feed_41005bb0:7638803357255191766:sha1same',
            conversationId: 'feed:alpha',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[image],
          ),
        ],
      );

      expect(result.sent, 1);
      expect(result.skippedDuplicate, 1);
      expect(result.failed, 0);
      expect(sender.sentImages, hasLength(1));
      expect(sender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents skips aliased replay of a sent network image',
    () async {
      final dedupeStore = _MemoryForwardingDedupeStore();
      await dedupeStore.saveSentKeys(<String>[
        'feed:alpha:network_image:7638441516213521627:sha1same',
        'feed:alpha:network_image:7638441516213521627:sha1same:media',
      ]);
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(
        sender: sender,
        dedupeStore: dedupeStore,
      );
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
            messageId: 'network_image:7638451220584778930:sha1same',
            dedupeKey:
                'feed:alias-alpha:network_image:7638451220584778930:sha1same',
            conversationId: 'feed:alpha',
            conversationName: 'Alpha Group',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'blob:https://example.feishu.cn/replayed',
                localPath: r'C:\tmp\same-feishu-original-image.webp',
                width: 805,
                height: 393,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDuplicate, 1);
      expect(result.failed, 0);
      expect(sender.sentImages, isEmpty);
      expect(sender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents skips replayed network image with new blob key',
    () async {
      final dedupeStore = _MemoryForwardingDedupeStore();
      final sender = _RecordingSender();
      final firstService = FeishuMonitorForwardingService(
        sender: sender,
        dedupeStore: dedupeStore,
      );
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'feed:cec2f034',
            sourceConversationName: 'Beta Group',
            targetGroupId: 'wk_beta',
          ),
        ],
      );

      final first = await firstService.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'network_image:7638908038270930137:23305f2c',
            dedupeKey:
                'feed:cec2f034:network_image:7638908038270930137:23305f2c',
            conversationId: 'feed:cec2f034',
            conversationName: 'Beta Group',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'blob:https://example.feishu.cn/old-blob',
                localPath: r'C:\tmp\same-reloaded-image.webp',
                width: 266,
                height: 500,
              ),
            ],
          ),
        ],
      );
      final secondService = FeishuMonitorForwardingService(
        sender: sender,
        dedupeStore: dedupeStore,
      );
      final second = await secondService.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'network_image:7638908038270930137:77ed56cb',
            dedupeKey:
                'feed:cec2f034:network_image:7638908038270930137:77ed56cb',
            conversationId: 'feed:cec2f034',
            conversationName: 'Beta Group',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'blob:https://example.feishu.cn/new-blob',
                localPath: r'C:\tmp\same-reloaded-image.webp',
                width: 266,
                height: 500,
              ),
            ],
          ),
        ],
      );

      expect(first.sent, 1);
      expect(second.sent, 0);
      expect(second.skippedDuplicate, 1);
      expect(second.failed, 0);
      expect(sender.sentImages, hasLength(1));
      expect(sender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents skips replayed network image across routes',
    () async {
      final dedupeStore = _MemoryForwardingDedupeStore();
      final sender = _RecordingSender();
      final firstService = FeishuMonitorForwardingService(
        sender: sender,
        dedupeStore: dedupeStore,
      );
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'feed:cec2f034',
            sourceConversationName: 'Beta Group',
            targetGroupId: 'wk_beta',
          ),
          _route(
            sourceConversationId: 'feed:ae500f14',
            sourceConversationName: 'Alpha Group',
            targetGroupId: 'wk_alpha',
          ),
        ],
      );

      final first = await firstService.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'network_image:7639011855205158086:d8803021',
            dedupeKey:
                'feed:cec2f034:network_image:7639011855205158086:d8803021',
            conversationId: 'feed:cec2f034',
            conversationName: 'Beta Group',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'blob:https://example.feishu.cn/beta-blob',
                localPath: r'C:\tmp\d8803021288778d87205ec660c57789b1.webp',
                width: 480,
                height: 476,
              ),
            ],
          ),
        ],
      );
      final secondService = FeishuMonitorForwardingService(
        sender: sender,
        dedupeStore: dedupeStore,
      );
      final second = await secondService.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'network_image:7639011756177624265:d8803021',
            dedupeKey:
                'feed:ae500f14:network_image:7639011756177624265:d8803021',
            conversationId: 'feed:ae500f14',
            conversationName: 'Alpha Group',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'blob:https://example.feishu.cn/alpha-blob',
                localPath: r'C:\tmp\d8803021288778d87205ec660c57789b1.webp',
                width: 480,
                height: 476,
              ),
            ],
          ),
        ],
      );

      expect(first.sent, 1);
      expect(second.sent, 0);
      expect(second.skippedDuplicate, 1);
      expect(second.failed, 0);
      expect(sender.sentImages, hasLength(1));
      expect(sender.targetGroupIds, <String>['wk_beta']);
      expect(sender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents rejects network_original_image without local file',
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
            messageId: 'network:image_without_file',
            dedupeKey: 'feed:alpha:network:image_without_file',
            conversationId: 'feed:alpha',
            text: '[Image]',
            captureSource: 'network_original_image',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'https://internal.feishu.cn/original-image.png',
                localPath: '',
                width: 1280,
                height: 720,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDuplicate, 1);
      expect(sender.sentTexts, isEmpty);
      expect(sender.sentImages, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents does not send dom_probe data image thumbnails',
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
    'forwardRoutedRecentEvents skips dom text noise and waits on dom images',
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
    'forwardRoutedRecentEvents skips loading placeholder dom text',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'feed:ae500f14',
            sourceConversationName: 'Alpha Group',
            targetGroupId: 'wk_alpha',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'network_image:feed:loading',
            dedupeKey: 'feed:ae500f14:network_image:feed:loading',
            conversationId: 'feed:ae500f14',
            conversationName: 'Alpha Group',
            senderName: '',
            text: '正在加载...',
            captureSource: 'dom_probe',
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDuplicate, 1);
      expect(result.failed, 0);
      expect(sender.sentTexts, isEmpty);
      expect(sender.sentImages, isEmpty);
    },
  );

  test('forwardRoutedRecentEvents skips Feishu system notice text', () async {
    final sender = _RecordingSender();
    final service = FeishuMonitorForwardingService(sender: sender);
    final settings = FeishuMonitorForwardingSettings(
      enabled: true,
      routes: <FeishuMonitorForwardingRoute>[
        _route(
          sourceConversationId: 'feed:2e500f14',
          sourceConversationName: '满满正能量',
          targetGroupId: 'wk_alpha',
        ),
        _route(
          sourceConversationId: 'feed:4ec2f034',
          sourceConversationName: '泡沫之家',
          targetGroupId: 'wk_beta',
        ),
      ],
    );

    final result = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <FeishuMonitorMessageEvent>[
        _event(
          messageId: 'dom:unread_separator',
          dedupeKey: 'feed:2e500f14:dom:unread_separator',
          conversationId: 'feed:2e500f14',
          conversationName: '满满正能量',
          senderName: '',
          text: '1 条新消息',
          captureSource: 'dom_probe',
        ),
        _event(
          messageId: 'feed:join_notice',
          dedupeKey: 'feed:4ec2f034:feed:join_notice',
          conversationId: 'feed:4ec2f034',
          conversationName: '泡沫之家',
          senderName: '',
          text: '蛋蛋脸 通过扫描 小浪～ 分享的二维码加入此群，新成员入群可查看所有历史消息',
          captureSource: 'feed_card_probe',
        ),
        _event(
          messageId: 'feed:join_notice_limited_history',
          dedupeKey: 'feed:4ec2f034:feed:join_notice_limited_history',
          conversationId: 'feed:4ec2f034',
          conversationName: '泡沫之家',
          senderName: '李丹',
          text: '通过 用户487029 分享的二维码加入此群，新成员仅可查看入群后的消息',
          captureSource: 'feed_card_probe',
        ),
        _event(
          messageId: 'feed:security_report_summary',
          dedupeKey: 'feed:4ec2f034:feed:security_report_summary',
          conversationId: 'feed:4ec2f034',
          conversationName: '泡沫之家',
          senderName: '机器人',
          text: '举报成立',
          captureSource: 'feed_card_probe',
        ),
        _event(
          messageId: 'dom:security_report_detail',
          dedupeKey: 'feed:4ec2f034:dom:security_report_detail',
          conversationId: 'feed:4ec2f034',
          conversationName: '泡沫之家',
          senderName: '机器人',
          text:
              '经飞书团队核实，你举报的群组涉嫌违规，我们已对该群进行处理。感谢你对飞书安全秩序的维护\n'
              '举报详情\n'
              '举报时间：2026-05-12 13:01:46\n'
              '举报对象：格兰裙 群\n'
              '举报理由：欺诈 - 网络兼职/返利刷单',
          captureSource: 'dom_probe',
        ),
        _event(
          messageId: 'dom:account_security_notice',
          dedupeKey: 'feed:2e500f14:dom:account_security_notice',
          conversationId: 'feed:2e500f14',
          conversationName: '满满正能量',
          senderName: '机器人',
          text: '安全登录通知',
          captureSource: 'dom_probe',
        ),
        _event(
          messageId: 'dom:contact_request_notice',
          dedupeKey: 'feed:2e500f14:dom:contact_request_notice',
          conversationId: 'feed:2e500f14',
          conversationName: '满满正能量',
          senderName: '机器人',
          text: '联系人申请',
          captureSource: 'dom_probe',
        ),
      ],
    );

    expect(result.sent, 0);
    expect(result.skippedDuplicate, 7);
    expect(result.failed, 0);
    expect(sender.sentTexts, isEmpty);
    expect(sender.sentImages, isEmpty);
  });

  test(
    'forwardRoutedRecentEvents forwards normalized dom text events',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'feed:ae500f14',
            sourceConversationName: 'Alpha Group',
            targetGroupId: 'wk_alpha',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'dom:text_good',
            dedupeKey: 'feed:ae500f14:dom:text_good',
            conversationId: 'feed:ae500f14',
            conversationName: 'Alpha Group',
            text: 'joint-test-1212-A',
            captureSource: 'dom_probe',
          ),
        ],
      );

      expect(result.sent, 1);
      expect(result.skippedDuplicate, 0);
      expect(sender.targetGroupIds, <String>['wk_alpha']);
      expect(sender.sentTexts, <String>['joint-test-1212-A']);
      expect(sender.sentImages, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents skips dom text when feed card already forwards it',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            id: 'route_alpha',
            sourceConversationId: 'feed:2e500f14',
            sourceConversationName: 'Alpha Group',
            targetGroupId: 'wk_alpha',
          ),
          _route(
            id: 'route_beta',
            sourceConversationId: 'feed:4ec2f034',
            sourceConversationName: 'Beta Group',
            targetGroupId: 'wk_beta',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:22324da1',
            dedupeKey: 'feed:2e500f14:feed:22324da1',
            conversationId: 'feed:2e500f14',
            conversationName: 'Alpha Group',
            text: 'joint-test-0512-A',
            captureSource: 'feed_card_probe',
          ),
          _event(
            messageId: '7638897940978912475',
            dedupeKey: 'feed:2e500f14:7638897940978912475',
            conversationId: 'feed:2e500f14',
            conversationName: 'Alpha Group',
            text: 'joint-test-0512-A',
            captureSource: 'dom_probe',
          ),
          _event(
            messageId: '7638897940978912475',
            dedupeKey: 'feed:2e500f14:7638897940978912475:again',
            conversationId: 'feed:2e500f14',
            conversationName: 'Alpha Group',
            text: 'joint-test-0512-A',
            captureSource: 'dom_probe',
          ),
        ],
      );

      expect(result.sent, 1);
      expect(result.skippedDuplicate, 2);
      expect(result.failed, 0);
      expect(sender.targetGroupIds, <String>['wk_alpha']);
      expect(sender.sentTexts, <String>['joint-test-0512-A']);
      expect(sender.sentImages, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents skips dom text when id and name match different routes',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            id: 'route_alpha',
            sourceConversationId: 'feed:2e500f14',
            sourceConversationName: 'Alpha Group',
            targetGroupId: 'wk_alpha',
          ),
          _route(
            id: 'route_beta',
            sourceConversationId: 'feed:4ec2f034',
            sourceConversationName: 'Beta Group',
            targetGroupId: 'wk_beta',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: '7638943600683912380',
            dedupeKey: 'feed:4ec2f034:7638943600683912380',
            conversationId: 'feed:4ec2f034',
            conversationName: 'Alpha Group',
            text: 'joint-test-conflicting-dom',
            captureSource: 'dom_probe',
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedUnmatched, 1);
      expect(sender.sentTexts, isEmpty);
      expect(sender.sentImages, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents skips dom text replayed under another route alias',
    () async {
      final dedupeStore = _MemoryForwardingDedupeStore();
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(
        sender: sender,
        dedupeStore: dedupeStore,
      );
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            id: 'route_alpha',
            sourceConversationId: 'feed:2e500f14',
            sourceConversationName: 'Alpha Group',
            targetGroupId: 'wk_alpha',
          ),
          _route(
            id: 'route_beta',
            sourceConversationId: 'feed:4ec2f034',
            sourceConversationName: 'Beta Group',
            targetGroupId: 'wk_beta',
          ),
        ],
      );

      final first = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: '7638986594929691836',
            dedupeKey: 'feed:4ec2f034:7638986594929691836',
            conversationId: 'feed:4ec2f034',
            conversationName: 'Beta Group',
            text: 'joint-test-alias-replay',
            captureSource: 'dom_probe',
          ),
        ],
      );
      final second = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: '7638986594929691836',
            dedupeKey: 'feed:2e500f14:7638986594929691836',
            conversationId: 'feed:2e500f14',
            conversationName: 'Alpha Group',
            text: 'joint-test-alias-replay',
            captureSource: 'dom_probe',
          ),
        ],
      );

      expect(first.sent, 1);
      expect(second.sent, 0);
      expect(second.skippedDuplicate, 1);
      expect(sender.targetGroupIds, <String>['wk_beta']);
      expect(sender.sentTexts, <String>['joint-test-alias-replay']);
    },
  );

  test(
    'forwardRoutedRecentEvents skips later dom text after feed card text was sent',
    () async {
      final dedupeStore = _MemoryForwardingDedupeStore();
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(
        sender: sender,
        dedupeStore: dedupeStore,
      );
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            id: 'route_alpha',
            sourceConversationId: 'feed:2e500f14',
            sourceConversationName: 'Alpha Group',
            targetGroupId: 'wk_alpha',
          ),
          _route(
            id: 'route_beta',
            sourceConversationId: 'feed:4ec2f034',
            sourceConversationName: 'Beta Group',
            targetGroupId: 'wk_beta',
          ),
        ],
      );

      final first = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:2ce5578f',
            dedupeKey: 'feed:2e500f14:feed:2ce5578f',
            conversationId: 'feed:2e500f14',
            conversationName: 'Alpha Group',
            text: 'joint-test-delayed-dom',
            captureSource: 'feed_card_probe',
          ),
        ],
      );
      final second = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: '7638919870804954309',
            dedupeKey: 'feed:2e500f14:7638919870804954309',
            conversationId: 'feed:2e500f14',
            conversationName: 'Alpha Group',
            text: 'joint-test-delayed-dom',
            captureSource: 'dom_probe',
          ),
        ],
      );

      expect(first.sent, 1);
      expect(second.sent, 0);
      expect(second.skippedDuplicate, 1);
      expect(sender.targetGroupIds, <String>['wk_alpha']);
      expect(sender.sentTexts, <String>['joint-test-delayed-dom']);
    },
  );

  test(
    'forwardRoutedRecentEvents skips dom text replayed under another route after feed card sent',
    () async {
      final dedupeStore = _MemoryForwardingDedupeStore();
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(
        sender: sender,
        dedupeStore: dedupeStore,
      );
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            id: 'route_alpha',
            sourceConversationId: 'feed:2e500f14',
            sourceConversationName: 'Alpha Group',
            targetGroupId: 'wk_alpha',
          ),
          _route(
            id: 'route_beta',
            sourceConversationId: 'feed:4ec2f034',
            sourceConversationName: 'Beta Group',
            targetGroupId: 'wk_beta',
          ),
        ],
      );

      final first = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:2f8a11fe',
            dedupeKey: 'feed:2e500f14:feed:2f8a11fe',
            conversationId: 'feed:2e500f14',
            conversationName: 'Alpha Group',
            text: 'joint-test-feed-dom-cross-route',
            captureSource: 'feed_card_probe',
          ),
        ],
      );
      final second = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: '7639001813986872525',
            dedupeKey: 'feed:4ec2f034:7639001813986872525',
            conversationId: 'feed:4ec2f034',
            conversationName: 'Beta Group',
            text: 'joint-test-feed-dom-cross-route',
            captureSource: 'dom_probe',
          ),
        ],
      );

      expect(first.sent, 1);
      expect(second.sent, 0);
      expect(second.skippedDuplicate, 1);
      expect(sender.targetGroupIds, <String>['wk_alpha']);
      expect(sender.sentTexts, <String>['joint-test-feed-dom-cross-route']);
    },
  );

  test(
    'forwardRoutedRecentEvents keeps same text from different feed groups',
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
          ),
          _route(
            id: 'route_beta',
            sourceConversationId: 'feed:beta',
            sourceConversationName: 'Beta Group',
            targetGroupId: 'wk_beta',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:alpha_same',
            dedupeKey: 'feed:alpha:feed:alpha_same',
            conversationId: 'feed:alpha',
            conversationName: 'Alpha Group',
            text: 'same text',
          ),
          _event(
            messageId: 'feed:beta_same',
            dedupeKey: 'feed:beta:feed:beta_same',
            conversationId: 'feed:beta',
            conversationName: 'Beta Group',
            text: 'same text',
          ),
        ],
      );

      expect(result.sent, 2);
      expect(result.skippedDuplicate, 0);
      expect(sender.targetGroupIds, <String>['wk_alpha', 'wk_beta']);
      expect(sender.sentTexts, <String>['same text', 'same text']);
    },
  );

  test(
    'forwardRoutedRecentEvents does not fall back to mojibake image placeholder',
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

      expect(result.sent, 0);
      expect(result.failed, 1);
      expect(sender.sentImages, isEmpty);
      expect(sender.sentTexts, isEmpty);
    },
  );

  test('forwardRoutedRecentEvents skips dom blob image placeholders', () async {
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
      messageId: 'network_image:sha1retry',
      dedupeKey: 'feed:alpha:network_image:sha1retry',
      conversationId: 'feed:alpha',
      text: '[图片]',
      captureSource: 'network_original_image',
      imageAttachments: const <FeishuMonitorImageAttachment>[
        FeishuMonitorImageAttachment(
          sourceUrl: 'https://internal.feishu.cn/original-image.png',
          localPath: r'C:\tmp\feishu-original-image.png',
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
    expect(third.sent, 1);
    expect(third.skippedDuplicate, 0);
    expect(pendingSender.sentTexts, isEmpty);
    expect(pendingSender.sentImages, isEmpty);
    expect(resolvedSender.sentTexts, isEmpty);
    expect(resolvedSender.sentImages, hasLength(1));
    expect(keysAfterResolve, contains('feed:alpha:network_image:sha1retry'));
    expect(
      keysAfterResolve,
      contains('feed:alpha:network_image:sha1retry:media'),
    );
  });

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
    'forwardRoutedRecentEvents keeps media retry open after image send failure',
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

      expect(first.sent, 0);
      expect(first.failed, 1);
      expect(failingSender.sentTexts, isEmpty);
      expect(keysAfterFallback, isNot(contains('feed:alpha:feed:image_retry')));
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
    'forwardRoutedRecentEvents skips dom image thumbnails in same batch',
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
    'forwardRoutedRecentEvents does not persist dom thumbnail media fingerprints',
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
  String workerId = '',
  String relayDisplayName = '',
  String relayAvatar = '',
}) {
  return FeishuMonitorForwardingRoute(
    id: id,
    enabled: enabled,
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    sourceConversationType: sourceConversationType,
    targetGroupId: targetGroupId,
    targetGroupName: targetGroupName,
    workerId: workerId,
    relayDisplayName: relayDisplayName,
    relayAvatar: relayAvatar,
    createdAt: DateTime.parse('2026-05-09T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-09T01:00:00Z'),
  );
}

class _RecordingSender implements FeishuMonitorTextSender {
  final sentTexts = <String>[];
  final targetGroupIds = <String>[];
  final sentImages = <_RecordedImageSend>[];
  final relayIdentities = <FeishuMonitorRelayIdentity?>[];
  Future<void> Function()? beforeRecordTextSend;
  bool failTextSends = false;
  bool failImageSends = false;

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    FeishuMonitorRelayIdentity? relayIdentity,
  }) async {
    if (failTextSends) {
      throw StateError('text send failed');
    }
    final beforeRecordTextSend = this.beforeRecordTextSend;
    if (beforeRecordTextSend != null) {
      await beforeRecordTextSend();
    }
    targetGroupIds.add(channelId);
    relayIdentities.add(relayIdentity);
    sentTexts.add(text);
  }

  @override
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required FeishuMonitorImageAttachment image,
    FeishuMonitorRelayIdentity? relayIdentity,
  }) async {
    if (failImageSends) {
      throw StateError('image send failed');
    }
    targetGroupIds.add(channelId);
    relayIdentities.add(relayIdentity);
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
