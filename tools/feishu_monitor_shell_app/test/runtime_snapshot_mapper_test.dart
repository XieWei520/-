import 'dart:io';

import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feishu_monitor_shell_app/main.dart';
import 'package:feishu_monitor_shell_app/src/feishu_page_probe.dart';
import 'package:feishu_monitor_shell_app/src/runtime_snapshot_mapper.dart';

void main() {
  test('default Feishu runtime url opens messenger directly', () {
    expect(defaultFeishuRuntimeUrl, 'https://www.feishu.cn/messenger/');
  });

  test('webview environment disables background throttling', () {
    final args = feishuShellWebviewAdditionalArguments();

    expect(args, contains('--disable-background-timer-throttling'));
    expect(args, contains('--disable-renderer-backgrounding'));
    expect(args, contains('--disable-backgrounding-occluded-windows'));
    expect(args, contains('CalculateNativeWinOcclusion'));
    expect(args, contains('IntensiveWakeUpThrottling'));
  });

  test('configured media keepalive waits for stale feed and cooldown', () {
    final now = DateTime.utc(2026, 5, 11, 7, 30);

    expect(
      shouldOpenConfiguredMediaFeedKeepAlive(
        sameFeedSignatureCount: 4,
        hasConfiguredMediaSources: true,
        pendingMediaNeedsExtraction: false,
        now: now,
      ),
      isFalse,
    );
    expect(
      shouldOpenConfiguredMediaFeedKeepAlive(
        sameFeedSignatureCount: 5,
        hasConfiguredMediaSources: true,
        pendingMediaNeedsExtraction: false,
        now: now,
      ),
      isTrue,
    );
    expect(
      shouldOpenConfiguredMediaFeedKeepAlive(
        sameFeedSignatureCount: 40,
        hasConfiguredMediaSources: true,
        pendingMediaNeedsExtraction: true,
        now: now,
      ),
      isFalse,
    );
    expect(
      shouldOpenConfiguredMediaFeedKeepAlive(
        sameFeedSignatureCount: 40,
        hasConfiguredMediaSources: true,
        pendingMediaNeedsExtraction: false,
        now: now,
        lastOpenedAt: now.subtract(const Duration(seconds: 30)),
      ),
      isFalse,
    );
  });

  test(
    'configured media keepalive cursor rotates through configured sources',
    () {
      expect(
        nextConfiguredMediaFeedKeepAliveCursor(currentIndex: 0, sourceCount: 2),
        1,
      );
      expect(
        nextConfiguredMediaFeedKeepAliveCursor(currentIndex: 1, sourceCount: 2),
        0,
      );
      expect(
        nextConfiguredMediaFeedKeepAliveCursor(currentIndex: 4, sourceCount: 0),
        0,
      );
    },
  );

  test('media preview signature includes pending feed key', () {
    expect(
      mediaPreviewExtractionSignature(
        domImageSignature: 'dom:image:stable',
        pendingMediaFeedKey: 'feed:new-image',
      ),
      'dom:image:stable\npending:feed:new-image',
    );
  });

  test(
    'media preview extraction signature changes when pending feed key changes',
    () {
      final previous = mediaPreviewExtractionSignature(
        domImageSignature: 'dom:image:stable',
        pendingMediaFeedKey: 'feed:old-image',
      );
      final next = mediaPreviewExtractionSignature(
        domImageSignature: 'dom:image:stable',
        pendingMediaFeedKey: 'feed:new-image',
      );

      expect(next, isNot(previous));
    },
  );

  test('media preview diagnostics prefer current Dart extraction signature', () {
    final diagnostics = mediaPreviewExtractionDiagnostics(
      <String, dynamic>{
        'opened': true,
        'signature': 'stale-js-signature',
      },
      extractionSignature: 'dom:image:stable\npending:feed:new-image',
      pendingMediaFeedKey: 'feed:new-image',
    );

    expect(diagnostics['opened'], isTrue);
    expect(
      diagnostics['signature'],
      'dom:image:stable\npending:feed:new-image',
    );
    expect(diagnostics['pending_key'], 'feed:new-image');
  });

  test('shell app visible copy stays readable Chinese', () {
    expect(feishuShellAppTitle, '飞书消息监控助手');
    expect(feishuShellRefreshTooltip, '刷新');
  });

  test('windows native window title uses unicode escapes', () {
    final mainCpp = File('windows/runner/main.cpp').readAsStringSync();

    expect(
      mainCpp,
      contains(r'L"\u98DE\u4E66\u6D88\u606F\u76D1\u63A7\u52A9\u624B"'),
    );
  });

  test('shell support directory stays stable after visible title rename', () {
    final renamedSupportDirectory = Directory(
      'C:\\app_support\\com.example\\飞书消息监控助手',
    );

    final stableDirectory = feishuShellStableSupportDirectoryFor(
      renamedSupportDirectory,
    );

    expect(
      stableDirectory.path,
      'C:\\app_support\\com.example\\feishu_monitor_shell_app',
    );
    expect(
      feishuShellSnapshotFileFor(stableDirectory).path,
      'C:\\app_support\\com.example\\feishu_monitor_shell_app'
      '\\feishu_monitor_shell\\status.json',
    );
  });

  test('worker runtime options parse worker id and port from arguments', () {
    final options = parseFeishuShellWorkerOptions(<String>[
      '--worker-id=worker-3',
      '--port=18768',
      '--profile-suffix=worker-3',
    ]);

    expect(options.workerId, 'worker-3');
    expect(options.port, 18768);
    expect(options.profileSuffix, 'worker-3');
    expect(options.titleSuffix, 'worker-3');
  });

  test('shell snapshot status json includes worker id', () {
    final snapshot = ShellSnapshot.initial().copyWith(workerId: 'worker-3');

    expect(snapshot.toJson()['worker_id'], 'worker-3');
    expect(
      ShellSnapshot.fromJsonString('{"worker_id":"worker-4"}').workerId,
      'worker-4',
    );
  });

  test('worker runtime options reject unsafe port and profile suffix', () {
    final options = parseFeishuShellWorkerOptions(<String>[
      '--worker-id=worker:3',
      '--port=70000',
      r'--profile-suffix=..\worker-3',
    ]);

    expect(options.workerId, 'worker-1');
    expect(options.port, 18766);
    expect(options.profileSuffix, isEmpty);
    expect(options.titleSuffix, 'worker-1');
  });

  test('main entrypoint parses Flutter app arguments for worker options', () {
    final mainDart = File('lib/main.dart').readAsStringSync();

    expect(mainDart, contains('Future<void> main(List<String> args)'));
    expect(mainDart, contains('parseFeishuShellWorkerOptions(args)'));
    expect(mainDart, isNot(contains('Platform.executableArguments')));
  });

  test('worker support directory is isolated by profile suffix', () {
    final base = Directory(r'C:\tmp\app_support');
    final defaultDir = feishuShellStableSupportDirectoryFor(base);
    final workerDir = feishuShellStableSupportDirectoryFor(
      base,
      profileSuffix: 'worker-3',
    );

    expect(defaultDir.path, isNot(workerDir.path));
    expect(workerDir.path, contains('feishu_monitor_shell_app_worker-3'));
  });

  test(
    'worker support directory does not migrate default status file',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'feishu_shell_worker_support_test_',
      );
      try {
        final renamedSupportDirectory = Directory(
          '${temp.path}${Platform.pathSeparator}com.example'
          '${Platform.pathSeparator}飞书消息监控助手',
        );
        final defaultStatus = feishuShellSnapshotFileFor(
          renamedSupportDirectory,
        );
        await defaultStatus.parent.create(recursive: true);
        await defaultStatus.writeAsString('{"capture_state":"running"}');

        final prepared = await prepareFeishuShellSupportDirectory(
          renamedSupportDirectory,
          profileSuffix: 'worker-3',
        );
        final workerStatus = feishuShellSnapshotFileFor(prepared);

        expect(prepared.path, contains('feishu_monitor_shell_app_worker-3'));
        expect(await workerStatus.exists(), isFalse);
      } finally {
        if (await temp.exists()) {
          await temp.delete(recursive: true);
        }
      }
    },
  );

  test('renamed shell support directory migrates newer status file', () async {
    final temp = await Directory.systemTemp.createTemp(
      'feishu_shell_support_test_',
    );
    try {
      final renamedSupportDirectory = Directory(
        '${temp.path}${Platform.pathSeparator}com.example'
        '${Platform.pathSeparator}飞书消息监控助手',
      );
      final stableDirectory = feishuShellStableSupportDirectoryFor(
        renamedSupportDirectory,
      );
      final sourceStatus = feishuShellSnapshotFileFor(renamedSupportDirectory);
      final targetStatus = feishuShellSnapshotFileFor(stableDirectory);
      await sourceStatus.parent.create(recursive: true);
      await targetStatus.parent.create(recursive: true);
      await sourceStatus.writeAsString('{"capture_state":"running"}');
      await targetStatus.writeAsString('{"capture_state":"stopped"}');
      await targetStatus.setLastModified(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
      await sourceStatus.setLastModified(DateTime.now());

      final prepared = await prepareFeishuShellSupportDirectory(
        renamedSupportDirectory,
      );

      expect(prepared.path, stableDirectory.path);
      expect(await targetStatus.readAsString(), '{"capture_state":"running"}');
    } finally {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  });

  test('deriveLoginState treats messenger url as logged in', () {
    expect(
      deriveLoginStateFromUrl('https://www.feishu.cn/messenger/'),
      'logged_in',
    );
  });

  test('deriveLoginState treats login url as needs login', () {
    expect(
      deriveLoginStateFromUrl('https://accounts.feishu.cn/login/scan'),
      'needs_login',
    );
  });

  test('applyRuntimeSignal merges runtime metadata into snapshot', () {
    final updated = applyRuntimeSignal(
      ShellSnapshot.initial(),
      runtimeUrl: 'https://www.feishu.cn/messenger/',
      pageTitle: '飞书',
      webviewAvailable: true,
      isLoading: false,
    );

    expect(updated.runtimeUrl, 'https://www.feishu.cn/messenger/');
    expect(updated.pageTitle, '飞书');
    expect(updated.webviewAvailable, isTrue);
    expect(updated.shellMode, 'desktop_shell');
    expect(updated.loginState, 'logged_in');
    expect(updated.hookState, 'healthy');
  });

  test('applyRuntimeSignal keeps externally started capture running', () {
    final updated = applyRuntimeSignal(
      ShellSnapshot.initial().copyWith(captureState: 'running'),
      runtimeUrl: 'https://www.feishu.cn/messenger/',
      pageTitle: '飞书',
      webviewAvailable: true,
      isLoading: false,
    );

    expect(updated.captureState, 'running');
  });

  test(
    'mergeExternalControlState preserves capture changes from shell API',
    () {
      final localUpdatedAt = DateTime.utc(2026, 5, 10, 3, 38, 20);
      final persistedUpdatedAt = DateTime.utc(2026, 5, 10, 3, 38, 30);
      final merged = mergeExternalControlState(
        localSnapshot: ShellSnapshot.initial().copyWith(
          captureState: 'stopped',
          runtimeUrl: 'https://www.feishu.cn/messenger/',
          lastUpdatedAt: localUpdatedAt,
        ),
        persistedSnapshot: ShellSnapshot.initial().copyWith(
          captureState: 'running',
          lastUpdatedAt: persistedUpdatedAt,
        ),
      );

      expect(merged.captureState, 'running');
      expect(merged.runtimeUrl, 'https://www.feishu.cn/messenger/');
    },
  );

  test(
    'mergeExternalControlState keeps newer local capture state over old persisted snapshot',
    () {
      final localUpdatedAt = DateTime.utc(2026, 5, 10, 3, 38, 40);
      final persistedUpdatedAt = DateTime.utc(2026, 5, 10, 3, 38, 30);
      final merged = mergeExternalControlState(
        localSnapshot: ShellSnapshot.initial().copyWith(
          captureState: 'running',
          runtimeUrl: 'https://www.feishu.cn/messenger/',
          lastUpdatedAt: localUpdatedAt,
        ),
        persistedSnapshot: ShellSnapshot.initial().copyWith(
          captureState: 'stopped',
          lastUpdatedAt: persistedUpdatedAt,
        ),
      );

      expect(merged.captureState, 'running');
    },
  );

  test('applyPageProbe merges probe metadata into snapshot', () {
    final updated = applyPageProbe(
      ShellSnapshot.initial(),
      FeishuPageProbe(
        runtimeUrl: 'https://www.feishu.cn/messenger/',
        pageTitle: 'Feishu',
        bodyText: 'messages',
        pageKind: 'messenger',
        observedAt: DateTime.utc(2026, 5, 9, 12),
        probeDiagnostics: const <String, dynamic>{
          'selector_hits': <Map<String, Object>>[
            <String, Object>{'selector': '[data-message-id]', 'count': 2},
          ],
        },
        observedConversations: <ObservedConversation>[
          ObservedConversation(
            id: 'oc_1',
            name: 'alpha-group',
            type: 'group',
            lastMessagePreview: 'hello',
            observedAt: '2026-05-09T12:00:00Z',
          ),
        ],
        observedMessages: const <ObservedMessageCandidate>[
          ObservedMessageCandidate(
            id: 'msg_1',
            conversationId: 'chat_1',
            conversationName: 'Alpha Group',
            senderName: 'Alice',
            messageType: 'text',
            text: 'hello from Feishu',
            observedAt: '2026-05-09T12:00:00Z',
            captureSource: 'dom_probe',
          ),
        ],
      ),
    );

    expect(updated.pageKind, 'messenger');
    expect(
      updated.probeObservedAt?.toUtc().toIso8601String(),
      '2026-05-09T12:00:00.000Z',
    );
    expect(updated.observedConversations, hasLength(1));
    expect(updated.observedConversations.first.name, 'alpha-group');
    expect(updated.observedMessages, hasLength(1));
    expect(updated.observedMessages.first.text, 'hello from Feishu');
    expect(updated.probeDiagnostics['selector_hits'], hasLength(1));
  });

  test(
    'applyPageProbe normalizes duplicate observed messages into recent events',
    () {
      final updated = applyPageProbe(
        ShellSnapshot.initial(),
        FeishuPageProbe(
          runtimeUrl: 'https://www.feishu.cn/messenger/',
          pageTitle: 'Feishu',
          bodyText: 'messages',
          pageKind: 'messenger',
          observedAt: DateTime.utc(2026, 5, 9, 12),
          observedConversations: const <ObservedConversation>[],
          observedMessages: const <ObservedMessageCandidate>[
            ObservedMessageCandidate(
              id: 'msg_1',
              conversationId: 'chat_1',
              conversationName: 'Alpha Group',
              senderName: 'Alice',
              messageType: 'text',
              text: 'hello from Feishu',
              observedAt: '2026-05-09T12:00:00Z',
              captureSource: 'feed_card_probe',
            ),
            ObservedMessageCandidate(
              id: 'msg_1',
              conversationId: 'chat_1',
              conversationName: 'Alpha Group',
              senderName: 'Alice',
              messageType: 'text',
              text: 'hello from Feishu',
              observedAt: '2026-05-09T12:00:00Z',
              captureSource: 'feed_card_probe',
            ),
          ],
        ),
      );

      expect(updated.recentEvents, hasLength(1));
      expect(updated.recentEvents.single.dedupeKey, 'chat_1:msg_1');
      expect(updated.recentEvents.single.messageId, 'msg_1');
      expect(updated.recentEvents.single.conversationName, 'Alpha Group');
      expect(updated.recentEvents.single.text, 'hello from Feishu');
      expect(updated.recentEvents.single.captureSource, 'feed_card_probe');
    },
  );

  test('applyPageProbe carries image attachments into recent events', () {
    final updated = applyPageProbe(
      ShellSnapshot.initial(),
      FeishuPageProbe(
        runtimeUrl: 'https://www.feishu.cn/messenger/',
        pageTitle: 'Feishu',
        bodyText: 'messages',
        pageKind: 'messenger',
        observedAt: DateTime.utc(2026, 5, 9, 12),
        observedConversations: const <ObservedConversation>[],
        observedMessages: const <ObservedMessageCandidate>[
          ObservedMessageCandidate(
            id: 'msg_image_1',
            conversationId: 'chat_1',
            conversationName: 'Alpha Group',
            senderName: 'Alice',
            messageType: 'image',
            text: '[鍥剧墖]',
            observedAt: '2026-05-09T12:00:00Z',
            captureSource: 'dom_probe',
            imageAttachments: <MessageImageAttachment>[
              MessageImageAttachment(
                sourceUrl: 'https://internal.feishu.cn/image-1.png',
                localPath: '',
                width: 640,
                height: 480,
              ),
            ],
          ),
        ],
      ),
    );

    expect(updated.recentEvents, hasLength(1));
    expect(updated.recentEvents.single.messageType, 'image');
    expect(updated.recentEvents.single.imageAttachments, hasLength(1));
    expect(
      updated.recentEvents.single.imageAttachments.single.sourceUrl,
      'https://internal.feishu.cn/image-1.png',
    );
  });

  test('applyNetworkForwardableImages merges network image events', () {
    final updated = applyNetworkForwardableImages(
      ShellSnapshot.initial(),
      const <NormalizedMessageEvent>[
        NormalizedMessageEvent(
          eventId: 'event_network_image_sha1alpha',
          dedupeKey: 'feed:alpha:network_image:sha1alpha',
          accountId: 'account-1',
          conversationId: 'feed:alpha',
          conversationName: 'Alpha Group',
          conversationType: 'group',
          messageId: 'network_image:sha1alpha',
          senderId: 'sender-1',
          senderName: 'Alice',
          messageType: 'image',
          text: '[Image]',
          sentAt: '2026-05-10T04:29:59Z',
          observedAt: '2026-05-10T04:30:02Z',
          captureSource: 'network_original_image',
          imageAttachments: <MessageImageAttachment>[
            MessageImageAttachment(
              sourceUrl: 'https://a.test/image?token=secret',
              localPath: r'C:\tmp\alpha.webp',
              width: 640,
              height: 480,
            ),
          ],
        ),
      ],
    );

    expect(updated.recentEvents, hasLength(1));
    expect(updated.recentEvents.single.captureSource, 'network_original_image');
    expect(
      updated.recentEvents.single.imageAttachments.single.localPath,
      r'C:\tmp\alpha.webp',
    );
  });

  test('applyNetworkForwardableImages leaves empty event list unchanged', () {
    final lastUpdatedAt = DateTime.utc(2026, 5, 10, 4);
    final initial = ShellSnapshot.initial().copyWith(
      lastUpdatedAt: lastUpdatedAt,
      recentEvents: const <NormalizedMessageEvent>[
        NormalizedMessageEvent(
          eventId: 'event_existing',
          dedupeKey: 'feed:alpha:msg_1',
          accountId: 'account-1',
          conversationId: 'feed:alpha',
          conversationName: 'Alpha Group',
          conversationType: 'group',
          messageId: 'msg_1',
          senderId: 'sender-1',
          senderName: 'Alice',
          messageType: 'text',
          text: 'hello',
          sentAt: '2026-05-10T03:59:59Z',
          observedAt: '2026-05-10T04:00:00Z',
          captureSource: 'feed_card_probe',
        ),
      ],
    );

    final updated = applyNetworkForwardableImages(
      initial,
      const <NormalizedMessageEvent>[],
    );

    expect(identical(updated, initial), isTrue);
    expect(updated.recentEvents, same(initial.recentEvents));
    expect(updated.lastUpdatedAt, lastUpdatedAt);
  });

  test(
    'applyNetworkForwardableImages updates timestamp for non-empty events',
    () {
      final lastUpdatedAt = DateTime.utc(2026, 5, 10, 4);
      final initial = ShellSnapshot.initial().copyWith(
        lastUpdatedAt: lastUpdatedAt,
      );

      final before = DateTime.now().toUtc();
      final updated =
          applyNetworkForwardableImages(initial, const <NormalizedMessageEvent>[
            NormalizedMessageEvent(
              eventId: 'event_network_image_sha1alpha',
              dedupeKey: 'feed:alpha:network_image:sha1alpha',
              accountId: 'account-1',
              conversationId: 'feed:alpha',
              conversationName: 'Alpha Group',
              conversationType: 'group',
              messageId: 'network_image:sha1alpha',
              senderId: 'sender-1',
              senderName: 'Alice',
              messageType: 'image',
              text: '[Image]',
              sentAt: '2026-05-10T04:29:59Z',
              observedAt: '2026-05-10T04:30:02Z',
              captureSource: 'network_original_image',
            ),
          ]);
      final after = DateTime.now().toUtc();

      expect(updated.lastUpdatedAt, isNot(lastUpdatedAt));
      expect(updated.lastUpdatedAt.compareTo(before), greaterThanOrEqualTo(0));
      expect(updated.lastUpdatedAt.compareTo(after), lessThanOrEqualTo(0));
    },
  );

  test(
    'applyNetworkForwardableImages replaces existing event with same dedupe key',
    () {
      final initial = ShellSnapshot.initial().copyWith(
        recentEvents: const <NormalizedMessageEvent>[
          NormalizedMessageEvent(
            eventId: 'event_old',
            dedupeKey: 'feed:alpha:network_image:sha1alpha',
            accountId: 'account-1',
            conversationId: 'feed:alpha',
            conversationName: 'Alpha Group',
            conversationType: 'group',
            messageId: 'network_image:sha1alpha',
            senderId: 'sender-1',
            senderName: 'Alice',
            messageType: 'image',
            text: '[Image]',
            sentAt: '2026-05-10T04:29:59Z',
            observedAt: '2026-05-10T04:30:00Z',
            captureSource: 'feed_card_probe',
            imageAttachments: <MessageImageAttachment>[
              MessageImageAttachment(
                sourceUrl: 'https://a.test/preview',
                localPath: '',
                width: 320,
                height: 240,
              ),
            ],
          ),
        ],
      );

      final updated = applyNetworkForwardableImages(
        initial,
        const <NormalizedMessageEvent>[
          NormalizedMessageEvent(
            eventId: 'event_new',
            dedupeKey: 'feed:alpha:network_image:sha1alpha',
            accountId: 'account-1',
            conversationId: 'feed:alpha',
            conversationName: 'Alpha Group',
            conversationType: 'group',
            messageId: 'network_image:sha1alpha',
            senderId: 'sender-1',
            senderName: 'Alice',
            messageType: 'image',
            text: '[Image]',
            sentAt: '2026-05-10T04:29:59Z',
            observedAt: '2026-05-10T04:30:02Z',
            captureSource: 'network_original_image',
            imageAttachments: <MessageImageAttachment>[
              MessageImageAttachment(
                sourceUrl: 'https://a.test/original',
                localPath: r'C:\tmp\alpha.webp',
                width: 640,
                height: 480,
              ),
            ],
          ),
        ],
      );

      expect(updated.recentEvents, hasLength(1));
      expect(updated.recentEvents.single.eventId, 'event_new');
      expect(
        updated.recentEvents.single.captureSource,
        'network_original_image',
      );
      expect(
        updated.recentEvents.single.imageAttachments.single.localPath,
        r'C:\tmp\alpha.webp',
      );
    },
  );

  test(
    'applyStorageProbeDiagnostic records and caps storage probe summaries',
    () {
      var snapshot = ShellSnapshot.initial();

      for (var index = 0; index < 22; index += 1) {
        snapshot = applyStorageProbeDiagnostic(snapshot, <String, Object?>{
          'kind': 'indexeddb',
          'observed_at':
              '2026-05-10T12:00:${index.toString().padLeft(2, '0')}Z',
          'has_image_hint': index == 21,
          'samples': <Map<String, Object?>>[
            <String, Object?>{
              'database_name': 'feishu-db',
              'store_name': 'messages',
              'tokens': <String>['image_key'],
            },
          ],
        });
      }

      expect(snapshot.probeDiagnostics['storage_probe_count'], 22);
      expect(snapshot.probeDiagnostics['storage_last_probe'], isA<Map>());
      expect(
        (snapshot.probeDiagnostics['storage_last_probe']!
            as Map)['has_image_hint'],
        isTrue,
      );
      final recent =
          snapshot.probeDiagnostics['storage_recent_probes']! as List<Object?>;
      expect(recent, hasLength(20));
      expect((recent.first! as Map)['observed_at'], '2026-05-10T12:00:02Z');
      expect((recent.last! as Map)['observed_at'], '2026-05-10T12:00:21Z');
    },
  );

  test(
    'applyPageProbe preserves storage probe diagnostics across page probes',
    () {
      final withStorage = applyStorageProbeDiagnostic(
        ShellSnapshot.initial(),
        const <String, Object?>{
          'kind': 'indexeddb',
          'observed_at': '2026-05-10T12:00:00Z',
          'has_image_hint': true,
        },
      );

      final updated = applyPageProbe(
        withStorage,
        FeishuPageProbe(
          runtimeUrl: 'https://www.feishu.cn/messenger/',
          pageTitle: 'Feishu',
          bodyText: 'messages',
          pageKind: 'messenger',
          observedAt: DateTime.utc(2026, 5, 10, 12, 1),
          probeDiagnostics: const <String, dynamic>{
            'selector_hits': <Object>[],
          },
          observedConversations: const <ObservedConversation>[],
          observedMessages: const <ObservedMessageCandidate>[],
        ),
      );

      expect(updated.probeDiagnostics['storage_probe_count'], 1);
      expect(updated.probeDiagnostics['storage_last_probe'], isA<Map>());
      expect(updated.probeDiagnostics['selector_hits'], isEmpty);
    },
  );

  test(
    'applyPageProbe preserves configured media sources across page probes',
    () {
      final initial = ShellSnapshot.initial().copyWith(
        probeDiagnostics: const <String, dynamic>{
          'configured_media_source_count': 1,
          'configured_media_sources': <Map<String, String>>[
            <String, String>{
              'conversation_id': 'feed:alpha',
              'conversation_name': 'Alpha Group',
            },
          ],
        },
      );

      final updated = applyPageProbe(
        initial,
        FeishuPageProbe(
          runtimeUrl: 'https://www.feishu.cn/messenger/',
          pageTitle: 'Feishu',
          bodyText: 'messages',
          pageKind: 'messenger',
          observedAt: DateTime.utc(2026, 5, 10, 12),
          probeDiagnostics: const <String, dynamic>{
            'selector_hits': <Object>[],
          },
          observedConversations: const <ObservedConversation>[],
          observedMessages: const <ObservedMessageCandidate>[],
        ),
      );

      expect(updated.probeDiagnostics['configured_media_source_count'], 1);
      expect(
        updated.probeDiagnostics['configured_media_sources'],
        <Map<String, String>>[
          <String, String>{
            'conversation_id': 'feed:alpha',
            'conversation_name': 'Alpha Group',
          },
        ],
      );
    },
  );

  test(
    'applyPageProbe drops configured-name dom text when feed id differs',
    () {
      final initial = ShellSnapshot.initial().copyWith(
        probeDiagnostics: const <String, dynamic>{
          'configured_media_source_count': 1,
          'configured_media_sources': <Map<String, String>>[
            <String, String>{
              'conversation_id': 'feed:2e500f14',
              'conversation_name': 'Alpha Group',
            },
          ],
        },
      );

      final updated = applyPageProbe(
        initial,
        FeishuPageProbe(
          runtimeUrl: 'https://www.feishu.cn/messenger/',
          pageTitle: 'Feishu',
          bodyText: 'messages',
          pageKind: 'messenger',
          observedAt: DateTime.utc(2026, 5, 12, 4, 30),
          observedConversations: const <ObservedConversation>[],
          observedMessages: const <ObservedMessageCandidate>[
            ObservedMessageCandidate(
              id: 'dom:text_good',
              conversationId: 'feed:ae500f14',
              conversationName: 'Alpha Group',
              senderName: 'Alice',
              messageType: 'text',
              text: 'joint-test-1212-A',
              observedAt: '2026-05-12T04:30:00Z',
              captureSource: 'dom_probe',
            ),
            ObservedMessageCandidate(
              id: 'dom:placeholder',
              conversationId: 'feed:ae500f14',
              conversationName: 'Alpha Group',
              senderName: 'Alice',
              messageType: 'image',
              text: '[Image]',
              observedAt: '2026-05-12T04:30:01Z',
              captureSource: 'dom_probe',
            ),
            ObservedMessageCandidate(
              id: 'dom:timestamp',
              conversationId: 'feed:ae500f14',
              conversationName: 'Alpha Group',
              senderName: 'Alice',
              messageType: 'text',
              text: '12:30',
              observedAt: '2026-05-12T04:30:02Z',
              captureSource: 'dom_probe',
            ),
            ObservedMessageCandidate(
              id: 'dom:sender',
              conversationId: 'feed:ae500f14',
              conversationName: 'Alpha Group',
              senderName: 'Alice',
              messageType: 'text',
              text: 'Alice',
              observedAt: '2026-05-12T04:30:03Z',
              captureSource: 'dom_probe',
            ),
          ],
        ),
      );

      expect(updated.recentEvents, isEmpty);
    },
  );

  test(
    'applyPageProbe keeps configured dom text when feed id is missing',
    () {
      final initial = ShellSnapshot.initial().copyWith(
        probeDiagnostics: const <String, dynamic>{
          'configured_media_source_count': 1,
          'configured_media_sources': <Map<String, String>>[
            <String, String>{
              'conversation_id': 'feed:2e500f14',
              'conversation_name': 'Alpha Group',
            },
          ],
        },
      );

      final updated = applyPageProbe(
        initial,
        FeishuPageProbe(
          runtimeUrl: 'https://www.feishu.cn/messenger/',
          pageTitle: 'Feishu',
          bodyText: 'messages',
          pageKind: 'messenger',
          observedAt: DateTime.utc(2026, 5, 12, 4, 30),
          observedConversations: const <ObservedConversation>[],
          observedMessages: const <ObservedMessageCandidate>[
            ObservedMessageCandidate(
              id: 'dom:text_good',
              conversationId: '',
              conversationName: 'Alpha Group',
              senderName: 'Alice',
              messageType: 'text',
              text: 'joint-test-1212-A',
              observedAt: '2026-05-12T04:30:00Z',
              captureSource: 'dom_probe',
            ),
          ],
        ),
      );

      expect(updated.recentEvents, hasLength(1));
      expect(updated.recentEvents.single.captureSource, 'dom_probe');
      expect(updated.recentEvents.single.conversationId, isEmpty);
      expect(updated.recentEvents.single.text, 'joint-test-1212-A');
    },
  );

  test(
    'applyPageProbe keeps only newest configured dom text body',
    () {
      final initial = ShellSnapshot.initial().copyWith(
        probeDiagnostics: const <String, dynamic>{
          'configured_media_sources': <Map<String, String>>[
            <String, String>{
              'conversation_id': 'feed:2e500f14',
              'conversation_name': 'Alpha Group',
            },
          ],
        },
      );

      final updated = applyPageProbe(
        initial,
        FeishuPageProbe(
          runtimeUrl: 'https://www.feishu.cn/messenger/',
          pageTitle: 'Feishu',
          bodyText: 'messages',
          pageKind: 'messenger',
          observedAt: DateTime.utc(2026, 5, 12, 4, 40),
          observedConversations: const <ObservedConversation>[],
          observedMessages: const <ObservedMessageCandidate>[
            ObservedMessageCandidate(
              id: '7638792752016149694',
              conversationId: 'feed:2e500f14',
              conversationName: 'Alpha Group',
              senderName: '',
              messageType: 'text',
              text: 'Alice\nold dom text',
              observedAt: '2026-05-12T04:40:00Z',
              captureSource: 'dom_probe',
            ),
            ObservedMessageCandidate(
              id: '7638827938972093634',
              conversationId: 'feed:2e500f14',
              conversationName: 'Alpha Group',
              senderName: '',
              messageType: 'text',
              text: 'Alice\nnew dom text',
              observedAt: '2026-05-12T04:40:00Z',
              captureSource: 'dom_probe',
            ),
          ],
        ),
      );

      expect(updated.recentEvents, hasLength(1));
      expect(updated.recentEvents.single.messageId, '7638827938972093634');
      expect(updated.recentEvents.single.text, 'new dom text');
    },
  );

  test('shell diagnostics merge preserves media queue diagnostics', () {
    final withQueue = applyRuntimeSignal(
      ShellSnapshot.initial().copyWith(
        probeDiagnostics: const <String, dynamic>{
          'media_queue_depth': 2,
          'media_queue_active_item': 'id:feed:alpha\nfeed:feed_card_alpha',
          'media_queue_forward_placeholder': false,
          'selector_hits': <Object>[],
        },
      ),
      runtimeUrl: 'https://www.feishu.cn/messenger/',
      pageTitle: 'Feishu',
      webviewAvailable: true,
      isLoading: false,
    );

    final mergedDiagnostics = persistentShellDiagnosticsForProbe(
      withQueue.probeDiagnostics,
      const <String, dynamic>{'selector_hits': <Object>[]},
    );

    expect(mergedDiagnostics['media_queue_depth'], 2);
    expect(
      mergedDiagnostics['media_queue_active_item'],
      'id:feed:alpha\nfeed:feed_card_alpha',
    );
    expect(mergedDiagnostics['media_queue_forward_placeholder'], isFalse);
  });

  test('shell diagnostics merge prefers fresh media queue diagnostics', () {
    final mergedDiagnostics = persistentShellDiagnosticsForProbe(
      const <String, dynamic>{
        'media_queue_depth': 1,
        'media_queue_active_item': 'id:feed:alpha\nfeed:fresh_card',
        'media_queue_forward_placeholder': false,
      },
      const <String, dynamic>{
        'media_queue_depth': 0,
        'media_queue_active_item': null,
        'media_queue_forward_placeholder': false,
        'selector_hits': <Object>[],
      },
    );

    expect(mergedDiagnostics['media_queue_depth'], 1);
    expect(
      mergedDiagnostics['media_queue_active_item'],
      'id:feed:alpha\nfeed:fresh_card',
    );
    expect(mergedDiagnostics['selector_hits'], isEmpty);
  });

  test(
    'applyPageProbe exposes media queue diagnostics for pending image feed',
    () {
      final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
        'page_kind': 'messenger',
        'observed_at': '2026-05-11T12:00:00Z',
        'probe_diagnostics': <String, dynamic>{
          'configured_media_sources': <Map<String, String>>[
            <String, String>{
              'conversation_id': 'feed:alpha',
              'conversation_name': 'Alpha Group',
            },
          ],
          'top_feed_card_summaries': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'feed_card_alpha_image',
              'text': 'Alpha Group 12:00 Alice: [Image]',
              'image_count': 0,
            },
          ],
        },
      });

      final updated = applyPageProbe(ShellSnapshot.initial(), probe);

      expect(updated.probeDiagnostics['media_queue_depth'], 1);
      expect(
        updated.probeDiagnostics['media_queue_forward_placeholder'],
        isFalse,
      );
      expect(
        updated.probeDiagnostics['media_queue_active_item'],
        allOf(isA<String>(), contains('feed:')),
      );
    },
  );

  test('applyPageProbe does not queue non-configured image feed', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-11T12:00:00Z',
      'probe_diagnostics': <String, dynamic>{
        'configured_media_sources': <Map<String, String>>[
          <String, String>{
            'conversation_id': 'feed:alpha',
            'conversation_name': 'Alpha Group',
          },
        ],
        'top_feed_card_summaries': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'feed_card_beta_image',
            'text': 'Beta Group 12:00 Bob: [Image]',
            'image_count': 0,
          },
        ],
      },
    });

    final updated = applyPageProbe(ShellSnapshot.initial(), probe);

    expect(updated.probeDiagnostics['media_queue_depth'], 0);
    expect(updated.probeDiagnostics['media_queue_active_item'], isNull);
    expect(
      updated.probeDiagnostics['media_queue_forward_placeholder'],
      isFalse,
    );
  });

  test(
    'applyPageProbe does not queue image feed without configured sources',
    () {
      final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
        'page_kind': 'messenger',
        'observed_at': '2026-05-11T12:00:00Z',
        'probe_diagnostics': <String, dynamic>{
          'top_feed_card_summaries': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'feed_card_alpha_image',
              'text': 'Alpha Group 12:00 Alice: [Image]',
              'image_count': 0,
            },
          ],
        },
      });

      final updated = applyPageProbe(ShellSnapshot.initial(), probe);

      expect(updated.probeDiagnostics['media_queue_depth'], 0);
      expect(updated.probeDiagnostics['media_queue_active_item'], isNull);
      expect(
        updated.probeDiagnostics['media_queue_forward_placeholder'],
        isFalse,
      );
    },
  );

  test(
    'normalizeObservedMessages drops dom text noise but keeps feed text',
    () {
      final events = normalizeObservedMessages(const <ObservedMessageCandidate>[
        ObservedMessageCandidate(
          id: 'dom:history_1',
          conversationId: 'feed:alpha',
          conversationName: 'Alpha Group',
          senderName: '',
          messageType: 'text',
          text: '自定义机器人\n机器人',
          observedAt: '2026-05-09T12:00:00Z',
          captureSource: 'dom_probe',
        ),
        ObservedMessageCandidate(
          id: 'feed:latest_1',
          conversationId: 'feed:alpha',
          conversationName: 'Alpha Group',
          senderName: 'Alice',
          messageType: 'text',
          text: 'hello from feed card',
          observedAt: '2026-05-09T12:00:01Z',
          captureSource: 'feed_card_probe',
        ),
      ]);

      expect(events, hasLength(1));
      expect(events.single.captureSource, 'feed_card_probe');
      expect(events.single.text, 'hello from feed card');
    },
  );

  test('normalizeObservedMessages keeps dom image candidates', () {
    final events = normalizeObservedMessages(const <ObservedMessageCandidate>[
      ObservedMessageCandidate(
        id: 'dom:image_1',
        conversationId: 'feed:alpha',
        conversationName: 'Alpha Group',
        senderName: '',
        messageType: 'image',
        text: '[图片]',
        observedAt: '2026-05-09T12:00:00Z',
        captureSource: 'dom_probe',
        imageAttachments: <MessageImageAttachment>[
          MessageImageAttachment(
            sourceUrl: 'data:image/png;base64,AQID',
            localPath: '',
            width: 1,
            height: 1,
          ),
        ],
      ),
    ]);

    expect(events, hasLength(1));
    expect(events.single.captureSource, 'dom_probe');
    expect(events.single.messageType, 'image');
    expect(events.single.imageAttachments, hasLength(1));
  });

  test('normalizeObservedMessages dedupes the same dom image candidate', () {
    final events = normalizeObservedMessages(const <ObservedMessageCandidate>[
      ObservedMessageCandidate(
        id: 'dom:first',
        conversationId: 'feed:alpha',
        conversationName: 'Alpha Group',
        senderName: '',
        messageType: 'image',
        text: 'Alice\n[图片]',
        observedAt: '2026-05-09T12:00:00Z',
        captureSource: 'dom_probe',
        imageAttachments: <MessageImageAttachment>[
          MessageImageAttachment(
            sourceUrl: 'data:image/png;base64,AQID',
            localPath: '',
            width: 500,
            height: 232,
          ),
        ],
      ),
      ObservedMessageCandidate(
        id: 'dom:second',
        conversationId: 'feed:alpha',
        conversationName: 'Alpha Group',
        senderName: '',
        messageType: 'image',
        text: 'Alice\n[图片]',
        observedAt: '2026-05-09T12:00:01Z',
        captureSource: 'dom_probe',
        imageAttachments: <MessageImageAttachment>[
          MessageImageAttachment(
            sourceUrl: 'data:image/png;base64,AQID',
            localPath: '',
            width: 500,
            height: 232,
          ),
        ],
      ),
    ]);

    expect(events, hasLength(1));
    expect(
      events.single.dedupeKey,
      startsWith('feed:alpha:dom_image:500x232:data:'),
    );
    expect(events.single.text, '[图片]');
    expect(events.single.observedAt, '2026-05-09T12:00:01Z');
  });

  test(
    'normalizeObservedMessages keeps same dom image content when message ids differ',
    () {
      final events = normalizeObservedMessages(const <ObservedMessageCandidate>[
        ObservedMessageCandidate(
          id: '7637915187458083785',
          conversationId: 'feed:alpha',
          conversationName: 'Alpha Group',
          senderName: '',
          messageType: 'image',
          text: '[图片]',
          observedAt: '2026-05-09T12:00:00Z',
          captureSource: 'dom_probe',
          imageAttachments: <MessageImageAttachment>[
            MessageImageAttachment(
              sourceUrl: 'data:image/png;base64,AQID',
              localPath: '',
              width: 500,
              height: 232,
            ),
          ],
        ),
        ObservedMessageCandidate(
          id: '7637940438023818196',
          conversationId: 'feed:alpha',
          conversationName: 'Alpha Group',
          senderName: '',
          messageType: 'image',
          text: '[图片]',
          observedAt: '2026-05-09T12:01:00Z',
          captureSource: 'dom_probe',
          imageAttachments: <MessageImageAttachment>[
            MessageImageAttachment(
              sourceUrl: 'data:image/png;base64,AQID',
              localPath: '',
              width: 500,
              height: 232,
            ),
          ],
        ),
      ]);

      expect(events, hasLength(2));
      expect(events.map((event) => event.dedupeKey).toSet(), <String>{
        'feed:alpha:7637915187458083785',
        'feed:alpha:7637940438023818196',
      });
    },
  );

  test(
    'normalizeObservedMessages keeps only newest dom image per conversation',
    () {
      final events = normalizeObservedMessages(const <ObservedMessageCandidate>[
        ObservedMessageCandidate(
          id: '7637973926353570758',
          conversationId: 'feed:alpha',
          conversationName: 'Alpha Group',
          senderName: '',
          messageType: 'image',
          text: '[图片]',
          observedAt: '2026-05-09T12:00:00Z',
          captureSource: 'dom_probe',
          imageAttachments: <MessageImageAttachment>[
            MessageImageAttachment(
              sourceUrl: 'data:image/png;base64,OLD',
              localPath: '',
              width: 241,
              height: 500,
            ),
          ],
        ),
        ObservedMessageCandidate(
          id: '7638063174163385529',
          conversationId: 'feed:alpha',
          conversationName: 'Alpha Group',
          senderName: '',
          messageType: 'image',
          text: '[图片]',
          observedAt: '2026-05-09T12:00:00Z',
          captureSource: 'dom_probe',
          imageAttachments: <MessageImageAttachment>[
            MessageImageAttachment(
              sourceUrl: 'data:image/png;base64,NEW',
              localPath: '',
              width: 750,
              height: 338,
            ),
          ],
        ),
      ]);

      expect(events, hasLength(1));
      expect(events.single.messageId, '7638063174163385529');
      expect(events.single.imageAttachments.single.width, 750);
    },
  );

  test(
    'normalizeObservedMessages prefers resolved dom image over blob twin',
    () {
      final events = normalizeObservedMessages(const <ObservedMessageCandidate>[
        ObservedMessageCandidate(
          id: 'dom:blob',
          conversationId: 'feed:alpha',
          conversationName: 'Alpha Group',
          senderName: '',
          messageType: 'image',
          text: '[图片]',
          observedAt: '2026-05-09T12:00:00Z',
          captureSource: 'dom_probe',
          imageAttachments: <MessageImageAttachment>[
            MessageImageAttachment(
              sourceUrl: 'blob:https://example.feishu.cn/image',
              localPath: '',
              width: 500,
              height: 232,
            ),
          ],
        ),
        ObservedMessageCandidate(
          id: 'dom:data',
          conversationId: 'feed:alpha',
          conversationName: 'Alpha Group',
          senderName: '',
          messageType: 'image',
          text: '[图片]',
          observedAt: '2026-05-09T12:00:01Z',
          captureSource: 'dom_probe',
          imageAttachments: <MessageImageAttachment>[
            MessageImageAttachment(
              sourceUrl: 'data:image/png;base64,AQID',
              localPath: '',
              width: 500,
              height: 232,
            ),
          ],
        ),
      ]);

      expect(events, hasLength(1));
      expect(
        events.single.imageAttachments.single.sourceUrl,
        startsWith('data:'),
      );
    },
  );

  test('applyPageProbe drops legacy dom image events from previous builds', () {
    final legacySnapshot = ShellSnapshot.initial().copyWith(
      recentEvents: const <NormalizedMessageEvent>[
        NormalizedMessageEvent(
          eventId: 'event_dom:old',
          dedupeKey: 'feed:alpha:dom:old',
          accountId: '',
          conversationId: 'feed:alpha',
          conversationName: 'Alpha Group',
          conversationType: 'unknown',
          messageId: 'dom:old',
          senderId: '',
          senderName: '',
          messageType: 'image',
          text: 'Alice\nold context\n[图片]',
          sentAt: '',
          observedAt: '2026-05-09T12:00:00Z',
          captureSource: 'dom_probe',
          imageAttachments: <MessageImageAttachment>[
            MessageImageAttachment(
              sourceUrl: 'data:image/png;base64,AQID',
              localPath: '',
              width: 500,
              height: 232,
            ),
          ],
        ),
      ],
    );

    final updated = applyPageProbe(
      legacySnapshot,
      FeishuPageProbe(
        runtimeUrl: 'https://www.feishu.cn/messenger/',
        pageTitle: 'Feishu',
        bodyText: 'messages',
        pageKind: 'messenger',
        observedAt: DateTime.utc(2026, 5, 9, 12, 1),
        observedConversations: const <ObservedConversation>[],
        observedMessages: const <ObservedMessageCandidate>[],
      ),
    );

    expect(updated.recentEvents, isEmpty);
  });

  test(
    'applyPageProbe replaces retained blob dom image when data image resolves',
    () {
      final blobSnapshot = ShellSnapshot.initial().copyWith(
        recentEvents: const <NormalizedMessageEvent>[
          NormalizedMessageEvent(
            eventId: 'event_dom:blob',
            dedupeKey: 'feed:alpha:dom_image:500x232:blob:old',
            accountId: '',
            conversationId: 'feed:alpha',
            conversationName: 'Alpha Group',
            conversationType: 'unknown',
            messageId: 'dom:blob',
            senderId: '',
            senderName: '',
            messageType: 'image',
            text: '[图片]',
            sentAt: '',
            observedAt: '2026-05-09T12:00:00Z',
            captureSource: 'dom_probe',
            imageAttachments: <MessageImageAttachment>[
              MessageImageAttachment(
                sourceUrl: 'blob:https://example.feishu.cn/image',
                localPath: '',
                width: 500,
                height: 232,
              ),
            ],
          ),
        ],
      );

      final updated = applyPageProbe(
        blobSnapshot,
        FeishuPageProbe(
          runtimeUrl: 'https://www.feishu.cn/messenger/',
          pageTitle: 'Feishu',
          bodyText: 'messages',
          pageKind: 'messenger',
          observedAt: DateTime.utc(2026, 5, 9, 12, 1),
          observedConversations: const <ObservedConversation>[],
          observedMessages: const <ObservedMessageCandidate>[
            ObservedMessageCandidate(
              id: 'dom:data',
              conversationId: 'feed:alpha',
              conversationName: 'Alpha Group',
              senderName: '',
              messageType: 'image',
              text: '[图片]',
              observedAt: '2026-05-09T12:00:01Z',
              captureSource: 'dom_probe',
              imageAttachments: <MessageImageAttachment>[
                MessageImageAttachment(
                  sourceUrl: 'data:image/png;base64,AQID',
                  localPath: '',
                  width: 500,
                  height: 232,
                ),
              ],
            ),
          ],
        ),
      );

      expect(updated.recentEvents, hasLength(1));
      expect(
        updated.recentEvents.single.imageAttachments.single.sourceUrl,
        startsWith('data:image/'),
      );
    },
  );

  test(
    'applyPageProbe dedupes stable message ids without conversation ids',
    () {
      final firstSnapshot = applyPageProbe(
        ShellSnapshot.initial(),
        FeishuPageProbe(
          runtimeUrl: 'https://www.feishu.cn/messenger/',
          pageTitle: 'Feishu',
          bodyText: 'messages',
          pageKind: 'messenger',
          observedAt: DateTime.utc(2026, 5, 9, 12),
          observedConversations: const <ObservedConversation>[],
          observedMessages: const <ObservedMessageCandidate>[
            ObservedMessageCandidate(
              id: 'msg_1',
              conversationId: '',
              conversationName: '',
              senderName: 'Alice',
              messageType: 'text',
              text: 'hello from Feishu',
              observedAt: '2026-05-09T12:00:00Z',
              captureSource: 'feed_card_probe',
            ),
          ],
        ),
      );

      final updated = applyPageProbe(
        firstSnapshot,
        FeishuPageProbe(
          runtimeUrl: 'https://www.feishu.cn/messenger/',
          pageTitle: 'Feishu',
          bodyText: 'messages',
          pageKind: 'messenger',
          observedAt: DateTime.utc(2026, 5, 9, 12, 1),
          observedConversations: const <ObservedConversation>[],
          observedMessages: const <ObservedMessageCandidate>[
            ObservedMessageCandidate(
              id: 'msg_1',
              conversationId: '',
              conversationName: '',
              senderName: 'Alice',
              messageType: 'text',
              text: 'hello from Feishu',
              observedAt: '2026-05-09T12:01:00Z',
              captureSource: 'feed_card_probe',
            ),
          ],
        ),
      );

      expect(updated.recentEvents, hasLength(1));
      expect(updated.recentEvents.single.dedupeKey, 'message:msg_1');
      expect(updated.recentEvents.single.observedAt, '2026-05-09T12:01:00Z');
    },
  );

  test(
    'applyPageProbe keeps feed card probe events stable across probe cycles',
    () {
      final firstSnapshot = applyPageProbe(
        ShellSnapshot.initial(),
        FeishuPageProbe.fromScriptResult(<String, dynamic>{
          'page_kind': 'messenger',
          'observed_at': '2026-05-09T12:00:00Z',
          'feed_cards': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'feed_card_1',
              'text': '1 账号安全中心 机器人 09:24 安全登录通知',
            },
          ],
        }),
      );

      final updated = applyPageProbe(
        firstSnapshot,
        FeishuPageProbe.fromScriptResult(<String, dynamic>{
          'page_kind': 'messenger',
          'observed_at': '2026-05-09T12:01:00Z',
          'feed_cards': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'feed_card_1',
              'text': '1 账号安全中心 机器人 09:24 安全登录通知',
            },
          ],
        }),
      );

      expect(updated.recentEvents, hasLength(1));
      expect(updated.recentEvents.single.conversationName, '账号安全中心');
      expect(updated.recentEvents.single.senderName, '机器人');
      expect(updated.recentEvents.single.text, '安全登录通知');
      expect(updated.recentEvents.single.captureSource, 'feed_card_probe');
      expect(updated.recentEvents.single.dedupeKey, startsWith('feed:'));
      expect(updated.recentEvents.single.observedAt, '2026-05-09T12:01:00Z');
    },
  );

  test('applyPageProbe separates image placeholders by feed card time', () {
    final firstSnapshot = applyPageProbe(
      ShellSnapshot.initial(),
      FeishuPageProbe.fromScriptResult(<String, dynamic>{
        'page_kind': 'messenger',
        'observed_at': '2026-05-09T12:00:00Z',
        'feed_cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '.a11y_feed_card_item:满满正能量 21:16 橘生淮南: [图片]',
            'text': '满满正能量 21:16 橘生淮南: [图片]',
          },
          <String, dynamic>{
            'id': '.a11y_feed_card_main:满满正能量 21:16 橘生淮南: [图片]',
            'text': '满满正能量 21:16 橘生淮南: [图片]',
          },
        ],
      }),
    );

    final updated = applyPageProbe(
      firstSnapshot,
      FeishuPageProbe.fromScriptResult(<String, dynamic>{
        'page_kind': 'messenger',
        'observed_at': '2026-05-09T12:03:00Z',
        'feed_cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '.a11y_feed_card_item:满满正能量 21:19 橘生淮南: [图片]',
            'text': '满满正能量 21:19 橘生淮南: [图片]',
          },
          <String, dynamic>{
            'id': '.a11y_feed_card_main:满满正能量 21:19 橘生淮南: [图片]',
            'text': '满满正能量 21:19 橘生淮南: [图片]',
          },
        ],
      }),
    );

    expect(firstSnapshot.recentEvents, hasLength(1));
    expect(updated.recentEvents, hasLength(2));
    expect(
      updated.recentEvents.map((event) => event.dedupeKey).toSet(),
      hasLength(2),
    );
    expect(updated.recentEvents.every((event) => event.text == '[图片]'), isTrue);
  });

  test(
    'applyPageProbe does not refresh extracted image placeholder observed time',
    () {
      final withForwardedImage = ShellSnapshot.initial().copyWith(
        recentEvents: const <NormalizedMessageEvent>[
          NormalizedMessageEvent(
            eventId: 'event_feed_placeholder',
            dedupeKey: 'feed:alpha:feed:placeholder',
            accountId: '',
            conversationId: 'feed:alpha',
            conversationName: 'Alpha Group',
            conversationType: 'unknown',
            messageId: 'feed:placeholder',
            senderId: '',
            senderName: 'Alice',
            messageType: 'text',
            text: '[图片]',
            sentAt: '',
            observedAt: '2026-05-09T12:00:00Z',
            captureSource: 'feed_card_probe',
          ),
          NormalizedMessageEvent(
            eventId: 'event_network_image',
            dedupeKey: 'feed:alpha:network_image:7638506295401663709:sha1',
            accountId: '',
            conversationId: 'feed:alpha',
            conversationName: 'Alpha Group',
            conversationType: 'unknown',
            messageId: 'network_image:7638506295401663709:sha1',
            senderId: '',
            senderName: 'Alice',
            messageType: 'image',
            text: '[Image]',
            sentAt: '',
            observedAt: '2026-05-09T12:00:02Z',
            captureSource: 'network_original_image',
            imageAttachments: <MessageImageAttachment>[
              MessageImageAttachment(
                sourceUrl: 'blob:https://example.feishu.cn/image',
                localPath: r'C:\tmp\image.jpg',
                width: 640,
                height: 480,
              ),
            ],
          ),
        ],
      );

      final updated = applyPageProbe(
        withForwardedImage,
        FeishuPageProbe.fromScriptResult(<String, dynamic>{
          'page_kind': 'messenger',
          'observed_at': '2026-05-09T12:03:00Z',
          'feed_cards': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'feed_card_image',
              'text': 'Alpha Group 12:00 Alice: [图片]',
            },
          ],
        }),
      );

      final placeholders = updated.recentEvents
          .where((event) => event.messageId == 'feed:placeholder')
          .toList(growable: false);
      expect(placeholders, hasLength(1));
      expect(placeholders.single.observedAt, '2026-05-09T12:00:00Z');
    },
  );

  test('pending media feed is resolved when network image already exists', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:03:00Z',
      'feed_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'feed_card_image',
          'text': 'Alpha Group 12:00 Alice: [Image]',
        },
      ],
    });
    final pendingFeedId = probePendingMediaFeedCardKey(
      probe,
    ).replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_').trim();
    final networkMessageId = 'network_image:$pendingFeedId:sha1';
    final snapshot = ShellSnapshot.initial().copyWith(
      recentEvents: <NormalizedMessageEvent>[
        NormalizedMessageEvent(
          eventId: 'event_network_image',
          dedupeKey: 'feed:alpha:$networkMessageId',
          accountId: '',
          conversationId: 'feed:alpha',
          conversationName: 'Alpha Group',
          conversationType: 'unknown',
          messageId: networkMessageId,
          senderId: '',
          senderName: 'Alice',
          messageType: 'image',
          text: '[Image]',
          sentAt: '',
          observedAt: '2026-05-09T12:00:02Z',
          captureSource: 'network_original_image',
          imageAttachments: <MessageImageAttachment>[
            MessageImageAttachment(
              sourceUrl: 'blob:https://example.feishu.cn/image',
              localPath: r'C:\tmp\image.jpg',
              width: 640,
              height: 480,
            ),
          ],
        ),
      ],
    );

    expect(probeHasPendingMediaFeedCard(probe), isTrue);
    expect(
      pendingMediaFeedNeedsOriginalExtraction(
        probe: probe,
        recentEvents: snapshot.recentEvents,
      ),
      isFalse,
    );
  });

  test(
    'pending media feed still needs extraction when network image is older',
    () {
      final snapshot = ShellSnapshot.initial().copyWith(
        recentEvents: const <NormalizedMessageEvent>[
          NormalizedMessageEvent(
            eventId: 'event_old_network_image',
            dedupeKey: 'feed:alpha:network_image:old:sha1',
            accountId: '',
            conversationId: 'feed:alpha',
            conversationName: 'Alpha Group',
            conversationType: 'unknown',
            messageId: 'network_image:old:sha1',
            senderId: '',
            senderName: 'Alice',
            messageType: 'image',
            text: '[Image]',
            sentAt: '',
            observedAt: '2026-05-09T12:00:02Z',
            captureSource: 'network_original_image',
            imageAttachments: <MessageImageAttachment>[
              MessageImageAttachment(
                sourceUrl: 'blob:https://example.feishu.cn/old-image',
                localPath: r'C:\tmp\old-image.jpg',
                width: 640,
                height: 480,
              ),
            ],
          ),
        ],
      );
      final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
        'page_kind': 'messenger',
        'observed_at': '2026-05-09T12:03:00Z',
        'feed_cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'feed_card_new_image',
            'text': 'Alpha Group 12:03 Alice: [图片]',
          },
        ],
      });

      expect(probeHasPendingMediaFeedCard(probe), isTrue);
      expect(
        pendingMediaFeedNeedsOriginalExtraction(
          probe: probe,
          recentEvents: snapshot.recentEvents,
        ),
        isTrue,
      );
    },
  );

  test(
    'pending media feed still needs extraction when newer network image lacks current feed id',
    () {
      final snapshot = ShellSnapshot.initial().copyWith(
        recentEvents: const <NormalizedMessageEvent>[
          NormalizedMessageEvent(
            eventId: 'event_other_network_image',
            dedupeKey: 'feed:alpha:network_image:feed_old_card:sha1',
            accountId: '',
            conversationId: 'feed:alpha',
            conversationName: 'Alpha Group',
            conversationType: 'unknown',
            messageId: 'network_image:feed_old_card:sha1',
            senderId: '',
            senderName: 'Alice',
            messageType: 'image',
            text: '[Image]',
            sentAt: '',
            observedAt: '2026-05-09T12:03:02Z',
            captureSource: 'network_original_image',
            imageAttachments: <MessageImageAttachment>[
              MessageImageAttachment(
                sourceUrl: 'blob:https://example.feishu.cn/other-image',
                localPath: r'C:\tmp\other-image.jpg',
                width: 640,
                height: 480,
              ),
            ],
          ),
        ],
      );
      final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
        'page_kind': 'messenger',
        'observed_at': '2026-05-09T12:03:00Z',
        'feed_cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'feed_card_new_image',
            'text': 'Alpha Group 12:03 Alice: [Image]',
          },
        ],
      });

      expect(probeHasPendingMediaFeedCard(probe), isTrue);
      expect(
        pendingMediaFeedNeedsOriginalExtraction(
          probe: probe,
          recentEvents: snapshot.recentEvents,
        ),
        isTrue,
      );
    },
  );

  test(
    'applyPageProbe keeps newer feed image placeholder with older network image',
    () {
      final snapshot = ShellSnapshot.initial().copyWith(
        recentEvents: const <NormalizedMessageEvent>[
          NormalizedMessageEvent(
            eventId: 'event_old_network_image',
            dedupeKey: 'feed:alpha:network_image:old:sha1',
            accountId: '',
            conversationId: 'feed:alpha',
            conversationName: 'Alpha Group',
            conversationType: 'unknown',
            messageId: 'network_image:old:sha1',
            senderId: '',
            senderName: 'Alice',
            messageType: 'image',
            text: '[Image]',
            sentAt: '',
            observedAt: '2026-05-09T12:00:02Z',
            captureSource: 'network_original_image',
            imageAttachments: <MessageImageAttachment>[
              MessageImageAttachment(
                sourceUrl: 'blob:https://example.feishu.cn/old-image',
                localPath: r'C:\tmp\old-image.jpg',
                width: 640,
                height: 480,
              ),
            ],
          ),
        ],
      );

      final updated = applyPageProbe(
        snapshot,
        FeishuPageProbe.fromScriptResult(<String, dynamic>{
          'page_kind': 'messenger',
          'observed_at': '2026-05-09T12:03:00Z',
          'feed_cards': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'feed_card_new_image',
              'text': 'Alpha Group 12:03 Alice: [图片]',
            },
          ],
        }),
      );

      expect(
        updated.recentEvents
            .where((event) => event.captureSource == 'feed_card_probe')
            .map((event) => event.text),
        contains('[图片]'),
      );
    },
  );

  test('applyPageProbe dedupes body text probe events by stable content', () {
    const bodyText = '下载飞书客户端 消息 知识问答 听M玛的话交流12群C-GH 账号安全中心 09:24 安全登录通知';

    final firstSnapshot = applyPageProbe(
      ShellSnapshot.initial(),
      FeishuPageProbe(
        runtimeUrl: 'https://www.feishu.cn/messenger/',
        pageTitle: '消息 - 飞书',
        bodyText: bodyText,
        pageKind: 'messenger',
        observedAt: DateTime.utc(2026, 5, 9, 12),
        observedConversations: const <ObservedConversation>[
          ObservedConversation(
            id: 'body:conversation',
            name: '听M玛的话交流12群C-GH',
            type: 'unknown',
            lastMessagePreview: bodyText,
            observedAt: '2026-05-09T12:00:00Z',
          ),
        ],
        observedMessages: const <ObservedMessageCandidate>[
          ObservedMessageCandidate(
            id: 'body:111',
            conversationId: 'body:conversation',
            conversationName: '听M玛的话交流12群C-GH',
            senderName: '',
            messageType: 'text',
            text: bodyText,
            observedAt: '2026-05-09T12:00:00Z',
            captureSource: 'body_text_probe',
          ),
        ],
      ),
    );

    final updated = applyPageProbe(
      firstSnapshot,
      FeishuPageProbe(
        runtimeUrl: 'https://www.feishu.cn/messenger/',
        pageTitle: '消息 - 飞书',
        bodyText: bodyText,
        pageKind: 'messenger',
        observedAt: DateTime.utc(2026, 5, 9, 12, 1),
        observedConversations: const <ObservedConversation>[
          ObservedConversation(
            id: 'body:conversation',
            name: '听M玛的话交流12群C-GH',
            type: 'unknown',
            lastMessagePreview: bodyText,
            observedAt: '2026-05-09T12:01:00Z',
          ),
        ],
        observedMessages: const <ObservedMessageCandidate>[
          ObservedMessageCandidate(
            id: 'body:999',
            conversationId: 'body:conversation',
            conversationName: '听M玛的话交流12群C-GH',
            senderName: '',
            messageType: 'text',
            text: bodyText,
            observedAt: '2026-05-09T12:01:00Z',
            captureSource: 'body_text_probe',
          ),
        ],
      ),
    );

    expect(updated.recentEvents, isEmpty);
  });
}
