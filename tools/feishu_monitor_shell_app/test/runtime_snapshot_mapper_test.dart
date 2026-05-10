import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feishu_monitor_shell_app/main.dart';
import 'package:feishu_monitor_shell_app/src/feishu_page_probe.dart';
import 'package:feishu_monitor_shell_app/src/runtime_snapshot_mapper.dart';

void main() {
  test('default Feishu runtime url opens messenger directly', () {
    expect(defaultFeishuRuntimeUrl, 'https://www.feishu.cn/messenger/');
  });

  test('shell app visible copy stays readable Chinese', () {
    expect(feishuShellRefreshTooltip, '刷新');
    expect(feishuShellReadyMessage, contains('本地壳程序已启动'));
    expect(feishuShellReadyMessage, contains('WuKongIM'));
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
      expect(updated.recentEvents.single.captureSource, 'network_original_image');
      expect(
        updated.recentEvents.single.imageAttachments.single.localPath,
        r'C:\tmp\alpha.webp',
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
