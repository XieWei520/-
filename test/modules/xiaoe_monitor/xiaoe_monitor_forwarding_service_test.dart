import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_forwarding.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_models.dart';
import 'package:wukong_im_app/modules/xiaoe_monitor/xiaoe_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/xiaoe_monitor/xiaoe_monitor_shell_models.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('forwarding route round trips through json', () {
    final route = XiaoeMonitorForwardingRoute(
      id: 'route_1',
      enabled: true,
      sourceConversationId: 'circle-alpha',
      sourceConversationName: 'Alpha Circle',
      sourceConversationType: 'circle',
      targetGroupId: 'wk-alpha',
      targetGroupName: 'WuKong Alpha',
      relayDisplayName: 'Xiaoe Relay',
      relayAvatar: 'https://cdn.example.com/xiaoe.png',
      createdAt: DateTime.parse('2026-05-17T01:00:00Z'),
      updatedAt: DateTime.parse('2026-05-17T02:00:00Z'),
    );

    final decoded = XiaoeMonitorForwardingRoute.fromJson(route.toJson());

    expect(decoded.id, 'route_1');
    expect(decoded.enabled, isTrue);
    expect(decoded.sourceConversationId, 'circle-alpha');
    expect(decoded.sourceConversationName, 'Alpha Circle');
    expect(decoded.sourceConversationType, 'circle');
    expect(decoded.targetGroupId, 'wk-alpha');
    expect(decoded.targetGroupName, 'WuKong Alpha');
    expect(decoded.relayDisplayName, 'Xiaoe Relay');
    expect(decoded.relayAvatar, 'https://cdn.example.com/xiaoe.png');
    expect(decoded.relayIdentity().provider, 'xiaoe');
  });

  test(
    'findRouteForEvent prefers id and falls back to unique normalized name',
    () {
      final routes = <XiaoeMonitorForwardingRoute>[
        _route(
          id: 'route_alpha',
          sourceConversationId: 'circle-alpha',
          sourceConversationName: 'Alpha Circle',
          targetGroupId: 'wk-alpha',
        ),
        _route(
          id: 'route_beta',
          sourceConversationId: '',
          sourceConversationName: 'Beta   Course',
          targetGroupId: 'wk-beta',
        ),
      ];

      final byId = findXiaoeMonitorRouteForEvent(
        routes: routes,
        event: _event(
          conversationId: 'circle-alpha',
          conversationName: 'Wrong',
        ),
      );
      final byName = findXiaoeMonitorRouteForEvent(
        routes: routes,
        event: _event(conversationId: '', conversationName: ' beta course '),
      );
      final wrongId = findXiaoeMonitorRouteForEvent(
        routes: routes,
        event: _event(
          conversationId: 'circle-other',
          conversationName: 'Alpha Circle',
        ),
      );

      expect(byId?.targetGroupId, 'wk-alpha');
      expect(byName?.targetGroupId, 'wk-beta');
      expect(wrongId, isNull);
    },
  );

  test('findRouteForEvent rejects ambiguous enabled route names and ids', () {
    final duplicateNames = <XiaoeMonitorForwardingRoute>[
      _route(
        id: 'route_alpha_1',
        sourceConversationId: 'old-alpha-1',
        sourceConversationName: 'Alpha Circle',
        targetGroupId: 'wk-alpha-1',
      ),
      _route(
        id: 'route_alpha_2',
        sourceConversationId: 'old-alpha-2',
        sourceConversationName: ' alpha   circle ',
        targetGroupId: 'wk-alpha-2',
      ),
    ];
    final duplicateIds = <XiaoeMonitorForwardingRoute>[
      _route(id: 'route_1', sourceConversationId: 'circle-alpha'),
      _route(id: 'route_2', sourceConversationId: 'circle-alpha'),
    ];

    expect(
      findXiaoeMonitorRouteForEvent(
        routes: duplicateNames,
        event: _event(conversationId: '', conversationName: 'Alpha Circle'),
      ),
      isNull,
    );
    expect(
      findXiaoeMonitorRouteForEvent(
        routes: duplicateIds,
        event: _event(conversationId: 'circle-alpha'),
      ),
      isNull,
    );
  });

  test('settings store saves and loads isolated Xiaoe route list', () async {
    const store = SharedPreferencesXiaoeMonitorForwardingSettingsStore();
    final settings = XiaoeMonitorForwardingSettings(
      enabled: true,
      routes: <XiaoeMonitorForwardingRoute>[
        _route(sourceConversationId: 'circle-alpha', targetGroupId: 'wk-alpha'),
      ],
    );

    await store.save(settings);
    final loaded = await store.load();
    final prefs = await SharedPreferences.getInstance();

    expect(loaded.enabled, isTrue);
    expect(loaded.routes.single.sourceConversationId, 'circle-alpha');
    expect(prefs.containsKey(xiaoeMonitorForwardingSettingsStorageKey), isTrue);
    expect(prefs.getString('juliang_monitor_forwarding_settings_v1'), isNull);
  });

  test(
    'forwardRoutedRecentEvents sends matching live text individually',
    () async {
      final sender = _RecordingSender();
      final service = XiaoeMonitorForwardingService(
        sender: sender,
        dedupeStore: _MemoryDedupeStore(),
      );
      final settings = XiaoeMonitorForwardingSettings(
        enabled: true,
        routes: <XiaoeMonitorForwardingRoute>[
          _route(sourceConversationId: 'live-alpha', targetGroupId: 'wk-live'),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <XiaoeMonitorMessageEvent>[
          _event(
            eventId: 'live-1',
            dedupeKey: 'live-alpha:comment-1',
            conversationId: 'live-alpha',
            conversationType: 'live',
            messageId: 'comment-1',
            text: 'first live comment',
          ),
          _event(
            eventId: 'live-2',
            dedupeKey: 'live-alpha:comment-2',
            conversationId: 'live-alpha',
            conversationType: 'live',
            messageId: 'comment-2',
            text: 'second live comment',
          ),
        ],
      );

      expect(result.sent, 2);
      expect(result.failed, 0);
      expect(sender.sentTexts, <String>[
        'first live comment',
        'second live comment',
      ]);
      expect(sender.targetGroupIds, <String>['wk-live', 'wk-live']);
      expect(sender.channelTypes, <int>[
        WKChannelType.group,
        WKChannelType.group,
      ]);
      expect(sender.relayProviders, <String>['xiaoe', 'xiaoe']);
    },
  );

  test('forwardRoutedRecentEvents sends image attachments', () async {
    final sender = _RecordingSender();
    final service = XiaoeMonitorForwardingService(
      sender: sender,
      dedupeStore: _MemoryDedupeStore(),
    );
    final settings = XiaoeMonitorForwardingSettings(
      enabled: true,
      routes: <XiaoeMonitorForwardingRoute>[
        _route(sourceConversationId: 'circle-alpha', targetGroupId: 'wk-alpha'),
      ],
    );

    final result = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <XiaoeMonitorMessageEvent>[
        _event(
          messageType: 'image',
          text: '',
          imageAttachments: const <XiaoeMonitorImageAttachment>[
            XiaoeMonitorImageAttachment(
              sourceUrl: 'https://cdn.example.com/image.png',
              localPath: '',
              width: 640,
              height: 480,
            ),
          ],
        ),
      ],
    );

    expect(result.sent, 1);
    expect(sender.sentTexts, isEmpty);
    expect(
      sender.sentImages.single.sourceUrl,
      'https://cdn.example.com/image.png',
    );
    expect(sender.sentImages.single.width, 640);
  });

  test(
    'forwardRoutedRecentEvents sends file attachments under 20 MB',
    () async {
      final sender = _RecordingSender();
      final service = XiaoeMonitorForwardingService(
        sender: sender,
        dedupeStore: _MemoryDedupeStore(),
      );
      final settings = XiaoeMonitorForwardingSettings(
        enabled: true,
        routes: <XiaoeMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'course-alpha',
            targetGroupId: 'wk-course',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <XiaoeMonitorMessageEvent>[
          _event(
            conversationId: 'course-alpha',
            conversationType: 'course',
            messageType: 'file',
            text: 'lesson handout',
            fileAttachments: const <XiaoeMonitorFileAttachment>[
              XiaoeMonitorFileAttachment(
                sourceUrl: 'https://cdn.example.com/lesson.pdf',
                localPath: r'C:\tmp\lesson.pdf',
                fileName: 'lesson.pdf',
                mimeType: 'application/pdf',
                sizeBytes: 1024,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 1);
      expect(result.skippedOversizedFile, 0);
      expect(result.skippedUnsupportedFile, 0);
      expect(sender.sentFiles.single.fileName, 'lesson.pdf');
      expect(sender.sentFiles.single.sizeBytes, 1024);
      expect(sender.sentTexts, isEmpty);
    },
  );

  test('file preparer downloads http files into a local cache', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(
      server.forEach((request) {
        request.response.headers.contentType = ContentType.binary;
        request.response.add(<int>[1, 2, 3, 4]);
        request.response.close();
      }),
    );
    final tempDir = await Directory.systemTemp.createTemp('xiaoe_file_cache');
    addTearDown(() => tempDir.delete(recursive: true));

    final prepared = await prepareXiaoeMonitorFileForWkUpload(
      LocalMonitorForwardableFile(
        sourceUrl: 'http://127.0.0.1:${server.port}/lesson.pdf',
        localPath: '',
        fileName: 'lesson.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 0,
      ),
      fileDirectory: tempDir,
    );

    expect(prepared.localPath, isNotEmpty);
    expect(await File(prepared.localPath).readAsBytes(), <int>[1, 2, 3, 4]);
    expect(prepared.fileName, 'lesson.pdf');
    expect(prepared.sizeBytes, 4);
  });

  test(
    'forwardRoutedRecentEvents skips oversized files with diagnostics',
    () async {
      final sender = _RecordingSender();
      final service = XiaoeMonitorForwardingService(
        sender: sender,
        dedupeStore: _MemoryDedupeStore(),
      );
      final settings = XiaoeMonitorForwardingSettings(
        enabled: true,
        routes: <XiaoeMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'course-alpha',
            targetGroupId: 'wk-course',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <XiaoeMonitorMessageEvent>[
          _event(
            conversationId: 'course-alpha',
            messageType: 'file',
            fileAttachments: const <XiaoeMonitorFileAttachment>[
              XiaoeMonitorFileAttachment(
                sourceUrl: 'https://cdn.example.com/large.zip',
                localPath: '',
                fileName: 'large.zip',
                mimeType: 'application/zip',
                sizeBytes: xiaoeMonitorMaxForwardableFileBytes + 1,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedOversizedFile, 1);
      expect(result.diagnostics.single.code, 'file_too_large');
      expect(result.diagnostics.single.fileName, 'large.zip');
      expect(sender.sentFiles, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents skips duplicate events and persists keys',
    () async {
      final dedupeStore = _MemoryDedupeStore();
      final firstSender = _RecordingSender();
      final firstService = XiaoeMonitorForwardingService(
        sender: firstSender,
        dedupeStore: dedupeStore,
      );
      final settings = XiaoeMonitorForwardingSettings(
        enabled: true,
        routes: <XiaoeMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'circle-alpha',
            targetGroupId: 'wk-alpha',
          ),
        ],
      );
      final event = _event(dedupeKey: 'circle-alpha:msg-1');

      final first = await firstService.forwardRoutedRecentEvents(
        settings: settings,
        events: <XiaoeMonitorMessageEvent>[event, event],
      );
      final secondService = XiaoeMonitorForwardingService(
        sender: _RecordingSender(),
        dedupeStore: dedupeStore,
      );
      final second = await secondService.forwardRoutedRecentEvents(
        settings: settings,
        events: <XiaoeMonitorMessageEvent>[event],
      );

      expect(first.sent, 1);
      expect(first.skippedDuplicate, 1);
      expect(second.sent, 0);
      expect(second.skippedDuplicate, 1);
    },
  );

  test(
    'forwardRoutedRecentEvents counts disabled and unmatched routes',
    () async {
      final sender = _RecordingSender();
      final service = XiaoeMonitorForwardingService(
        sender: sender,
        dedupeStore: _MemoryDedupeStore(),
      );
      final settings = XiaoeMonitorForwardingSettings(
        enabled: true,
        routes: <XiaoeMonitorForwardingRoute>[
          _route(
            id: 'disabled',
            enabled: false,
            sourceConversationId: 'circle-disabled',
            targetGroupId: 'wk-disabled',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <XiaoeMonitorMessageEvent>[
          _event(conversationId: 'circle-disabled'),
          _event(conversationId: 'circle-missing'),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDisabled, 1);
      expect(result.skippedUnmatched, 1);
      expect(sender.sentTexts, isEmpty);
    },
  );
}

XiaoeMonitorForwardingRoute _route({
  String id = 'route_1',
  bool enabled = true,
  String sourceConversationId = 'circle-alpha',
  String sourceConversationName = 'Alpha Circle',
  String sourceConversationType = 'circle',
  String targetGroupId = 'wk-alpha',
  String targetGroupName = 'WuKong Alpha',
  String relayDisplayName = '',
  String relayAvatar = '',
}) {
  return XiaoeMonitorForwardingRoute(
    id: id,
    enabled: enabled,
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    sourceConversationType: sourceConversationType,
    targetGroupId: targetGroupId,
    targetGroupName: targetGroupName,
    relayDisplayName: relayDisplayName,
    relayAvatar: relayAvatar,
    createdAt: DateTime.parse('2026-05-17T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-17T01:00:00Z'),
  );
}

XiaoeMonitorMessageEvent _event({
  String eventId = 'event-1',
  String dedupeKey = 'circle-alpha:msg-1',
  String conversationId = 'circle-alpha',
  String conversationName = 'Alpha Circle',
  String conversationType = 'circle',
  String messageId = 'msg-1',
  String senderName = 'Alice',
  String messageType = 'text',
  String text = 'hello from Xiaoe',
  List<XiaoeMonitorImageAttachment> imageAttachments =
      const <XiaoeMonitorImageAttachment>[],
  List<XiaoeMonitorFileAttachment> fileAttachments =
      const <XiaoeMonitorFileAttachment>[],
}) {
  return XiaoeMonitorMessageEvent.fromLocal(
    LocalMonitorMessageEvent(
      eventId: eventId,
      dedupeKey: dedupeKey,
      accountId: '',
      conversationId: conversationId,
      conversationName: conversationName,
      conversationType: conversationType,
      messageId: messageId,
      senderId: '',
      senderName: senderName,
      messageType: messageType,
      text: text,
      sentAt: null,
      observedAt: DateTime.parse('2026-05-17T01:00:00Z'),
      captureSource: 'xiaoe_dom_probe',
      imageAttachments: imageAttachments,
      fileAttachments: fileAttachments,
    ),
  );
}

class _RecordingSender implements XiaoeMonitorMediaSender {
  final sentTexts = <String>[];
  final sentImages = <LocalMonitorForwardableImage>[];
  final sentFiles = <LocalMonitorForwardableFile>[];
  final targetGroupIds = <String>[];
  final channelTypes = <int>[];
  final relayProviders = <String>[];
  bool failTextSends = false;
  bool failImageSends = false;
  bool failFileSends = false;

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    LocalMonitorRelayIdentity? relayIdentity,
  }) async {
    if (failTextSends) {
      throw StateError('text send failed');
    }
    targetGroupIds.add(channelId);
    channelTypes.add(channelType);
    relayProviders.add(relayIdentity?.provider ?? '');
    sentTexts.add(text);
  }

  @override
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required LocalMonitorForwardableImage image,
    LocalMonitorRelayIdentity? relayIdentity,
  }) async {
    if (failImageSends) {
      throw StateError('image send failed');
    }
    targetGroupIds.add(channelId);
    channelTypes.add(channelType);
    relayProviders.add(relayIdentity?.provider ?? '');
    sentImages.add(image);
  }

  @override
  Future<void> sendFile({
    required String channelId,
    required int channelType,
    String? channelName,
    required LocalMonitorForwardableFile file,
    LocalMonitorRelayIdentity? relayIdentity,
  }) async {
    if (failFileSends) {
      throw StateError('file send failed');
    }
    targetGroupIds.add(channelId);
    channelTypes.add(channelType);
    relayProviders.add(relayIdentity?.provider ?? '');
    sentFiles.add(file);
  }
}

class _MemoryDedupeStore implements XiaoeMonitorForwardingDedupeStore {
  final keys = <String>[];

  @override
  Future<List<String>> loadSentKeys() async => List<String>.from(keys);

  @override
  Future<void> saveSentKeys(List<String> keys) async {
    this.keys
      ..clear()
      ..addAll(keys);
  }
}
