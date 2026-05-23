import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:feishu_monitor_shell_app/main.dart' as shell_app;
import 'package:feishu_monitor_shell_app/src/feishu_page_observer.dart';
import 'package:feishu_monitor_shell_app/src/feishu_page_probe.dart';

void main() {
  test('keep alive script keeps the page foregrounded every five seconds', () {
    expect(feishuPageKeepAliveScript, contains('interval_ms: 5000'));
    expect(
      feishuPageKeepAliveScript,
      contains('setInterval(tick, state.interval_ms)'),
    );
    expect(feishuPageKeepAliveScript, contains("'focusin'"));
    expect(feishuPageKeepAliveScript, contains("'pageshow'"));
    expect(feishuPageKeepAliveScript, contains("'resume'"));
  });

  test(
    'shell app uses user-facing assistant name and no ready banner text',
    () {
      expect(shell_app.feishuShellAppTitle, '飞书消息监控助手');

      final mainSource = File('lib/main.dart').readAsStringSync();
      expect(mainSource, isNot(contains('本地壳程序已启动')));

      final windowsMain = File('windows/runner/main.cpp').readAsStringSync();
      expect(
        windowsMain,
        contains(r'L"\u98DE\u4E66\u6D88\u606F\u76D1\u63A7\u52A9\u624B"'),
      );
    },
  );

  test(
    'normalizes login probe payload when script does not report page kind',
    () {
      final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
        'runtime_url': 'https://accounts.feishu.cn/login/scan',
        'page_title': 'Feishu Login',
        'body_text': 'Scan QR code to sign in',
        'observed_at': '2026-05-09T12:00:00Z',
      });

      expect(probe.pageKind, 'login');
      expect(probe.runtimeUrl, 'https://accounts.feishu.cn/login/scan');
      expect(probe.pageTitle, 'Feishu Login');
      expect(probe.bodyText, 'Scan QR code to sign in');
      expect(
        probe.observedAt?.toUtc().toIso8601String(),
        '2026-05-09T12:00:00.000Z',
      );
      expect(probe.observedConversations, isEmpty);
    },
  );

  test('normalizes observed conversations from script payload', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:00:00Z',
      'observed_conversations': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'oc_1',
          'name': 'alpha-group',
          'type': 'group',
          'last_message_preview': 'hello',
          'observed_at': '2026-05-09T12:00:00Z',
        },
        <String, dynamic>{
          'id': '',
          'name': 'missing-id',
          'type': 'group',
          'last_message_preview': 'skip me',
          'observed_at': '2026-05-09T12:00:00Z',
        },
      ],
    });

    expect(probe.pageKind, 'messenger');
    expect(probe.observedConversations, hasLength(1));
    expect(probe.observedConversations.first.id, 'oc_1');
    expect(probe.observedConversations.first.name, 'alpha-group');
    expect(probe.observedConversations.first.lastMessagePreview, 'hello');
  });

  test('normalizes observed messages from script payload', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:00:00Z',
      'observed_messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'msg_1',
          'conversation_id': 'chat_1',
          'conversation_name': 'Alpha Group',
          'sender_name': 'Alice',
          'message_type': 'text',
          'text': 'hello from Feishu',
          'observed_at': '2026-05-09T12:00:00Z',
          'capture_source': 'dom_probe',
        },
        <String, dynamic>{
          'id': '',
          'conversation_id': 'chat_1',
          'conversation_name': 'Alpha Group',
          'sender_name': 'Bob',
          'message_type': 'text',
          'text': 'skip me',
          'observed_at': '2026-05-09T12:00:00Z',
          'capture_source': 'dom_probe',
        },
        <String, dynamic>{
          'id': 'msg_2',
          'conversation_id': 'chat_1',
          'conversation_name': 'Alpha Group',
          'sender_name': 'Carol',
          'message_type': 'text',
          'text': '',
          'observed_at': '2026-05-09T12:00:00Z',
          'capture_source': 'dom_probe',
        },
      ],
    });

    expect(probe.observedMessages, hasLength(1));
    expect(probe.observedMessages.first.text, 'hello from Feishu');
  });

  test('normalizes image attachments from script payload', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:00:00Z',
      'observed_messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'msg_image_1',
          'conversation_id': 'chat_1',
          'conversation_name': 'Alpha Group',
          'sender_name': 'Alice',
          'message_type': 'image',
          'text': '[图片]',
          'observed_at': '2026-05-09T12:00:00Z',
          'capture_source': 'dom_probe',
          'image_attachments': <Map<String, dynamic>>[
            <String, dynamic>{
              'source_url': 'https://internal.feishu.cn/image-1.png',
              'local_path': '',
              'width': 640,
              'height': 480,
            },
          ],
        },
      ],
    });

    expect(probe.observedMessages, hasLength(1));
    expect(probe.observedMessages.single.imageAttachments, hasLength(1));
    expect(
      probe.observedMessages.single.imageAttachments.single.sourceUrl,
      'https://internal.feishu.cn/image-1.png',
    );
  });

  test(
    'configured DOM image signature is stable for duplicate preview opens',
    () {
      final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
        'page_kind': 'messenger',
        'observed_at': '2026-05-11T10:16:27Z',
        'probe_diagnostics': <String, dynamic>{
          'configured_media_sources': <Map<String, dynamic>>[
            <String, dynamic>{
              'conversation_id': 'chat_alpha',
              'conversation_name': 'Alpha Group',
            },
          ],
        },
        'observed_messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'msg_image_1',
            'conversation_id': 'chat_alpha',
            'conversation_name': 'Alpha Group',
            'sender_name': 'Alice',
            'message_type': 'image',
            'text': '[图片]',
            'observed_at': '2026-05-11T10:16:27Z',
            'capture_source': 'dom_probe',
            'image_attachments': <Map<String, dynamic>>[
              <String, dynamic>{
                'source_url': 'blob:https://feishu.cn/image-old',
                'local_path': '',
                'width': 640,
                'height': 480,
              },
            ],
          },
        ],
      });

      expect(configuredDomImageSignature(probe), isNotEmpty);
      expect(
        configuredDomImageSignature(probe),
        configuredDomImageSignature(probe),
      );
    },
  );

  test(
    'configured DOM image signature changes when latest image message id changes',
    () {
      final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
        'page_kind': 'messenger',
        'observed_at': '2026-05-11T10:16:27Z',
        'probe_diagnostics': <String, dynamic>{
          'configured_media_sources': <Map<String, dynamic>>[
            <String, dynamic>{
              'conversation_id': 'chat_alpha',
              'conversation_name': 'Alpha Group',
            },
          ],
        },
        'observed_messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '7638487487815388360',
            'conversation_id': 'chat_alpha',
            'conversation_name': 'Alpha Group',
            'sender_name': 'Alice',
            'message_type': 'image',
            'text': '[图片]',
            'observed_at': '2026-05-11T10:15:27Z',
            'capture_source': 'dom_probe',
            'image_attachments': <Map<String, dynamic>>[
              <String, dynamic>{
                'source_url': 'data:image/webp;base64,SAME_PLACEHOLDER',
                'local_path': '',
                'width': 640,
                'height': 480,
              },
            ],
          },
          <String, dynamic>{
            'id': '7638506295401663709',
            'conversation_id': 'chat_alpha',
            'conversation_name': 'Alpha Group',
            'sender_name': 'Alice',
            'message_type': 'image',
            'text': '[图片]',
            'observed_at': '2026-05-11T10:16:27Z',
            'capture_source': 'dom_probe',
            'image_attachments': <Map<String, dynamic>>[
              <String, dynamic>{
                'source_url': 'data:image/webp;base64,SAME_PLACEHOLDER',
                'local_path': '',
                'width': 640,
                'height': 480,
              },
            ],
          },
        ],
      });

      expect(
        configuredDomImageSignature(probe),
        contains('7638506295401663709'),
      );
    },
  );

  test('probe script keeps image-only DOM messages', () {
    expect(feishuPageProbeScript, contains('imageAttachments.length === 0'));
    expect(feishuPageProbeScript, contains("text || '[图片]'"));
    expect(
      feishuPageProbeScript,
      contains("message_type: imageAttachments.length > 0 ? 'image' : 'text'"),
    );
    expect(feishuPageProbeScript, contains('activeFeedConversation?.name'));
  });

  test('probe script prioritizes real Feishu message item nodes', () {
    expect(feishuPageProbeScript, contains('.js-message-item'));
    expect(feishuPageProbeScript, contains('.message-item'));
    expect(
      feishuPageProbeScript.indexOf('.js-message-item'),
      lessThan(feishuPageProbeScript.indexOf('[class*="message"]')),
    );
  });

  test('probe script treats message item children as the parent message', () {
    expect(feishuPageProbeScript, contains('closestMessageNode'));
    expect(
      feishuPageProbeScript,
      contains(
        "querySelectorAll('[data-message-id],[data-msg-id],.js-message-item,.message-item')",
      ),
    );
  });

  test('probe script filters avatar images from message attachments', () {
    expect(
      feishuPageProbeScript,
      contains("normalizedUrl.includes('default-avatar')"),
    );
    expect(feishuPageProbeScript, contains("classContext.includes('avatar')"));
  });

  test('probe script samples media nodes and background images', () {
    expect(feishuPageProbeScript, contains('media_node_samples'));
    expect(feishuPageProbeScript, contains('backgroundImage'));
    expect(feishuPageProbeScript, contains('[style*="background"]'));
  });

  test('probe script converts blob image URLs to data URLs before export', () {
    expect(feishuPageProbeScript, contains('blobToDataUrl'));
    expect(feishuPageProbeScript, contains("sourceUrl.startsWith('blob:')"));
    expect(feishuPageProbeScript, contains('FileReader'));
    expect(feishuPageProbeScript, contains('readAsDataURL'));
  });

  test('open media feed script clicks the newest inactive media feed card', () {
    expect(feishuOpenLatestMediaFeedScript, contains('mediaPreviewTokens'));
    expect(feishuOpenLatestMediaFeedScript, contains('[图片]'));
    expect(feishuOpenLatestMediaFeedScript, contains('data-feed-active'));
    expect(feishuOpenLatestMediaFeedScript, contains('scrollIntoView'));
    expect(feishuOpenLatestMediaFeedScript, contains('target.click()'));
  });

  test('open media feed script can jump active chat to newest message', () {
    expect(
      feishuOpenLatestMediaFeedScript,
      contains('messageTip__toNewestTip'),
    );
  });

  test('open media feed script can target the selected pending feed card', () {
    expect(
      feishuOpenLatestMediaFeedScript,
      contains('__wukongFeishuMonitorPendingMediaTarget'),
    );
    expect(feishuOpenLatestMediaFeedScript, contains('pendingText'));
    expect(
      feishuOpenLatestMediaFeedScript,
      contains('pending_media_feed_not_found'),
    );
  });

  test('open media preview script clicks chat images instead of avatars', () {
    expect(
      feishuOpenLatestMediaPreviewScript,
      contains('messageImageSelectors'),
    );
    expect(feishuOpenLatestMediaPreviewScript, contains('default-avatar'));
    expect(feishuOpenLatestMediaPreviewScript, contains('target.click()'));
    expect(
      feishuOpenLatestMediaPreviewScript,
      contains('opened_media_preview_image'),
    );
  });

  test('open media preview script hashes full image source for retry keys', () {
    expect(
      feishuOpenLatestMediaPreviewScript,
      contains('hashString(sourceUrl)'),
    );
    expect(
      feishuOpenLatestMediaPreviewScript,
      isNot(contains('sourceUrl.slice(0, 220)')),
    );
  });

  test(
    'media preview original script clicks original or download controls',
    () {
      expect(
        feishuTriggerMediaPreviewOriginalScript,
        contains('originalControlTokens'),
      );
      expect(
        feishuTriggerMediaPreviewOriginalScript,
        contains('downloadControlTokens'),
      );
      expect(
        feishuTriggerMediaPreviewOriginalScript,
        contains('preview_control_samples'),
      );
      expect(
        feishuTriggerMediaPreviewOriginalScript,
        contains('clicked_media_preview_original_control'),
      );
      expect(
        feishuTriggerMediaPreviewOriginalScript,
        contains('clicked_media_preview_download_control'),
      );
      expect(
        feishuTriggerMediaPreviewOriginalScript,
        contains('clickMoreControls'),
      );
    },
  );

  test('media preview original script exports preview blob image bodies', () {
    expect(
      feishuTriggerMediaPreviewOriginalScript,
      contains('feishu_monitor_browser_image_body'),
    );
    expect(
      feishuTriggerMediaPreviewOriginalScript,
      contains('browser_preview_blob_body'),
    );
    expect(feishuTriggerMediaPreviewOriginalScript, contains('body_base64'));
    expect(feishuTriggerMediaPreviewOriginalScript, contains('source_url'));
    expect(
      feishuTriggerMediaPreviewOriginalScript,
      contains('fetch(sourceUrl)'),
    );
  });

  test('media preview original script ignores broad page containers', () {
    expect(
      feishuTriggerMediaPreviewOriginalScript,
      contains('isLikelyPreviewRoot'),
    );
    expect(
      feishuTriggerMediaPreviewOriginalScript,
      contains('no_media_preview_overlay'),
    );
    expect(
      feishuTriggerMediaPreviewOriginalScript,
      isNot(contains('[data-key],[class*="toolbar"]')),
    );
    expect(
      feishuTriggerMediaPreviewOriginalScript,
      contains('page-content-wrapper'),
    );
  });

  test(
    'latest feed script remains available but runtime policy keeps it disabled',
    () {
      expect(feishuOpenLatestFeedScript, contains('openNewestFeed'));
      expect(feishuOpenLatestFeedScript, contains('data-feed-active'));
      expect(feishuOpenLatestFeedScript, contains('target.click()'));
    },
  );

  test('configured media feed script opens only configured source names', () {
    expect(feishuOpenConfiguredMediaFeedScript, contains('configuredSources'));
    expect(feishuOpenConfiguredMediaFeedScript, contains('configured_names'));
    expect(feishuOpenConfiguredMediaFeedScript, contains('preferred_name'));
    expect(feishuOpenConfiguredMediaFeedScript, contains('matchingCards'));
    expect(feishuOpenConfiguredMediaFeedScript, contains('target.click()'));
    expect(
      feishuOpenConfiguredMediaFeedScript,
      contains('refreshed_active_configured_media_feed'),
    );
    expect(
      feishuOpenConfiguredMediaFeedScript,
      contains('configured_media_feed_not_found'),
    );
  });

  test(
    'active configured media feed can jump to newest outside keepalive cooldown',
    () {
      final probeSource = File('lib/src/feishu_page_probe.dart').readAsStringSync();
      final mainSource = File('lib/main.dart').readAsStringSync();

      expect(
        probeSource,
        contains('feishuJumpActiveConfiguredMediaFeedToNewestScript'),
      );
      expect(
        probeSource,
        contains('jumped_active_configured_media_feed_to_newest'),
      );
      expect(probeSource, contains('messageTip__toNewestTip'));
      expect(
        mainSource,
        contains('_jumpActiveConfiguredMediaFeedToNewestIfNeeded(probe)'),
      );
    },
  );

  test('active configured media feed jump also scrolls message pane to bottom', () {
    expect(
      feishuJumpActiveConfiguredMediaFeedToNewestScript,
      contains('scrollMessagePaneToBottom'),
    );
    expect(
      feishuJumpActiveConfiguredMediaFeedToNewestScript,
      contains('scrollTop = node.scrollHeight'),
    );
  });

  test('media preview can be closed after the same image was already handled', () {
    final probeSource = File('lib/src/feishu_page_probe.dart').readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(probeSource, contains('feishuCloseMediaPreviewScript'));
    expect(probeSource, contains('closed_media_preview'));
    expect(probeSource, contains('viewer-icon-close'));
    expect(mainSource, contains('_closeMediaPreviewIfOpen'));
  });

  test('configured media feed script defines normalizers before preferred source', () {
    expect(
      feishuOpenConfiguredMediaFeedScript.indexOf('const normalizedName'),
      lessThan(
        feishuOpenConfiguredMediaFeedScript.indexOf('const preferredName'),
      ),
    );
  });

  test('pending media source matching accepts configured ids and names', () {
    final diagnostics = const <String, dynamic>{
      'configured_media_sources': <Map<String, String>>[
        <String, String>{
          'conversation_id': 'feed:alpha',
          'conversation_name': 'Alpha Group',
        },
      ],
    };
    final sourceIds = configuredMediaSourceIdsFromDiagnostics(diagnostics);
    final sourceNames = configuredMediaSourceNamesFromDiagnostics(diagnostics);

    expect(
      pendingMediaFeedCardMatchesConfiguredSources(
        conversationId: 'feed:alpha',
        conversationName: 'Wrong Name',
        configuredSourceIds: sourceIds,
        configuredSourceNames: sourceNames,
      ),
      isTrue,
    );
    expect(
      pendingMediaFeedCardMatchesConfiguredSources(
        conversationId: 'feed:missing',
        conversationName: ' alpha   group ',
        configuredSourceIds: sourceIds,
        configuredSourceNames: sourceNames,
      ),
      isTrue,
    );
    expect(
      pendingMediaFeedCardMatchesConfiguredSources(
        conversationId: 'feed:missing',
        conversationName: 'Other Group',
        configuredSourceIds: sourceIds,
        configuredSourceNames: sourceNames,
      ),
      isFalse,
    );
  });

  test('detects pending media feed card that needs chat-pane extraction', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:00:00Z',
      'feed_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'feed_card_image',
          'text': 'Alpha Group 01:09 Alice: [图片]',
        },
      ],
    });

    expect(probeHasPendingMediaFeedCard(probe), isTrue);
  });

  test('does not mark unconfigured media feed card as pending', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:00:00Z',
      'probe_diagnostics': <String, dynamic>{
        'configured_media_sources': <Map<String, String>>[
          <String, String>{
            'conversation_id': '',
            'conversation_name': 'Alpha Group',
          },
        ],
      },
      'feed_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'feed_card_image',
          'text': 'Other Group 01:09 Alice: [Image]',
        },
      ],
    });

    expect(probeHasPendingMediaFeedCard(probe), isFalse);
    expect(probePendingMediaFeedCardKey(probe), isEmpty);
  });

  test('exposes pending media feed card text for targeted opening', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:00:00Z',
      'feed_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'feed_card_image',
          'text': 'Beta Group 12:01 Bob: [Image]',
        },
        <String, dynamic>{
          'id': 'feed_card_text',
          'text': 'Alpha Group 12:00 Alice: hello',
        },
      ],
    });

    expect(probeHasPendingMediaFeedCard(probe), isTrue);
    expect(
      probePendingMediaFeedCardText(probe),
      'Beta Group 12:01 Bob: [Image]',
    );
  });

  test(
    'keeps media feed card pending when chat pane only has older images',
    () {
      final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
        'page_kind': 'messenger',
        'observed_at': '2026-05-09T12:00:00Z',
        'observed_messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'old_image_1',
            'conversation_id': 'feed:alpha',
            'conversation_name': 'Alpha Group',
            'sender_name': 'Alice',
            'message_type': 'image',
            'text': '[图片]',
            'observed_at': '2026-05-09T11:59:00Z',
            'capture_source': 'dom_probe',
            'image_attachments': <Map<String, dynamic>>[
              <String, dynamic>{
                'source_url': 'data:image/png;base64,AQID',
                'local_path': '',
                'width': 320,
                'height': 240,
              },
            ],
          },
        ],
        'feed_cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'feed_card_new_image',
            'text': 'Alpha Group 12:00 Alice: [图片]',
          },
        ],
      });

      expect(probeHasPendingMediaFeedCard(probe), isTrue);
    },
  );

  test('does not auto-open media feed card after attachment is extracted', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:00:00Z',
      'observed_messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'msg_image_1',
          'conversation_id': 'feed:alpha',
          'conversation_name': 'Alpha Group',
          'sender_name': 'Alice',
          'message_type': 'image',
          'text': '[图片]',
          'observed_at': '2026-05-09T12:00:00Z',
          'capture_source': 'dom_probe',
          'image_attachments': <Map<String, dynamic>>[
            <String, dynamic>{
              'source_url': 'data:image/png;base64,AQID',
              'local_path': '',
              'width': 1,
              'height': 1,
            },
          ],
        },
      ],
    });

    expect(probeHasPendingMediaFeedCard(probe), isFalse);
  });

  test(
    'keeps same-conversation media feed pending when only DOM thumbnail is extracted',
    () {
      final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
        'page_kind': 'messenger',
        'observed_at': '2026-05-09T12:00:00Z',
        'observed_messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'msg_image_1',
            'conversation_id': 'feed:5a4ce4a',
            'conversation_name': 'Alpha Group',
            'sender_name': 'Alice',
            'message_type': 'image',
            'text': '[Image]',
            'observed_at': '2026-05-09T12:00:00Z',
            'capture_source': 'dom_probe',
            'image_attachments': <Map<String, dynamic>>[
              <String, dynamic>{
                'source_url': 'data:image/png;base64,AQID',
                'local_path': '',
                'width': 320,
                'height': 240,
              },
            ],
          },
        ],
        'feed_cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'feed_card_image',
            'text': 'Alpha Group 12:00 Alice: [Image]',
          },
        ],
      });

      expect(probeHasPendingMediaFeedCard(probe), isTrue);
      expect(probePendingMediaFeedCardKey(probe), isNotEmpty);
    },
  );

  test(
    'keeps latest media feed pending when only DOM thumbnail is extracted',
    () {
      final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
        'page_kind': 'messenger',
        'observed_at': '2026-05-10T03:45:11.329Z',
        'observed_messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'msg_image_energy',
            'conversation_id': 'feed:2e500f14',
            'conversation_name': '满满正能量',
            'sender_name': '橘生淮南',
            'message_type': 'image',
            'text': '[图片]',
            'observed_at': '2026-05-10T03:45:11.329Z',
            'capture_source': 'dom_probe',
            'image_attachments': <Map<String, dynamic>>[
              <String, dynamic>{
                'source_url': 'data:image/png;base64,AQID',
                'local_path': '',
                'width': 500,
                'height': 377,
              },
            ],
          },
        ],
        'feed_cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'feed_card_energy',
            'text': '满满正能量 11:27 橘生淮南: [图片]',
          },
          <String, dynamic>{
            'id': 'feed_card_foam',
            'text': '泡沫之家 09:06 橘生淮南: [图片]',
          },
        ],
      });

      expect(probeHasPendingMediaFeedCard(probe), isTrue);
      expect(probePendingMediaFeedCardKey(probe), isNotEmpty);
    },
  );

  test('does not chase older media card when newest feed item is text', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-10T04:05:42.882Z',
      'feed_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'feed_card_energy_text',
          'text': '满满正能量 12:05 橘生淮南: 哈哈哈',
        },
        <String, dynamic>{
          'id': 'feed_card_foam_image',
          'text': '泡沫之家 11:57 橘生淮南: [图片]',
        },
      ],
    });

    expect(probeHasPendingMediaFeedCard(probe), isFalse);
    expect(probePendingMediaFeedCardKey(probe), isEmpty);
  });

  test('keeps image-only message payloads that have no readable text', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:00:00Z',
      'observed_messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'msg_image_only_1',
          'conversation_id': 'chat_1',
          'conversation_name': 'Alpha Group',
          'sender_name': 'Alice',
          'message_type': '',
          'text': '',
          'observed_at': '2026-05-09T12:00:00Z',
          'capture_source': 'dom_probe',
          'image_attachments': <Map<String, dynamic>>[
            <String, dynamic>{
              'source_url': 'https://internal.feishu.cn/image-only.png',
              'local_path': '',
              'width': 320,
              'height': 240,
            },
          ],
        },
      ],
    });

    expect(probe.observedMessages, hasLength(1));
    expect(probe.observedMessages.single.messageType, 'image');
    expect(probe.observedMessages.single.text, '[图片]');
    expect(probe.observedMessages.single.imageAttachments, hasLength(1));
  });

  test('ignores oversized DOM container image payloads', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:00:00Z',
      'observed_messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'dom:whole_page',
          'conversation_id': '',
          'conversation_name': '',
          'sender_name': '',
          'message_type': 'image',
          'text':
              '搜索 消息 知识问答 会议 日历 云文档 通讯录 邮箱 任务 工作台 '
              '${'普通群 普通消息 '.padRight(900, 'x')}',
          'observed_at': '2026-05-09T12:00:00Z',
          'capture_source': 'dom_probe',
          'image_attachments': <Map<String, dynamic>>[
            <String, dynamic>{
              'source_url': 'https://internal.feishu.cn/page-icon.png',
              'local_path': '',
              'width': 32,
              'height': 32,
            },
          ],
        },
      ],
    });

    expect(probe.observedMessages, isEmpty);
  });

  test('falls back to feed cards when DOM image payload is bogus', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:00:00Z',
      'observed_messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'dom:whole_page',
          'conversation_id': '',
          'conversation_name': '',
          'sender_name': '',
          'message_type': 'image',
          'text':
              '搜索 消息 知识问答 会议 日历 云文档 通讯录 邮箱 任务 工作台 '
              '${'普通群 普通消息 '.padRight(900, 'x')}',
          'observed_at': '2026-05-09T12:00:00Z',
          'capture_source': 'dom_probe',
          'image_attachments': <Map<String, dynamic>>[
            <String, dynamic>{
              'source_url': 'https://internal.feishu.cn/page-icon.png',
              'local_path': '',
              'width': 32,
              'height': 32,
            },
          ],
        },
      ],
      'feed_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'feed_card_1',
          'text': 'Alpha Group 09:24 Alice: hello',
        },
      ],
    });

    expect(probe.observedMessages, hasLength(1));
    expect(probe.observedMessages.single.captureSource, 'feed_card_probe');
    expect(probe.observedMessages.single.conversationName, 'Alpha Group');
    expect(probe.observedMessages.single.messageType, 'text');
    expect(probe.observedMessages.single.imageAttachments, isEmpty);
  });

  test('derives observed messages from Feishu feed cards', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:00:00Z',
      'feed_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'feed_card_1',
          'text': '1 账号安全中心 机器人 09:24 安全登录通知',
        },
        <String, dynamic>{
          'id': 'feed_card_2',
          'text': '听M玛的话交流12群C-GH 外部 4月27日 MM12机器人: 1 今天盘中、 多空-来回拉锯强烈',
        },
        <String, dynamic>{'id': 'shortcut_1', 'text': '知识问答'},
      ],
    });

    expect(probe.observedMessages, hasLength(2));
    expect(probe.observedMessages.first.conversationName, '账号安全中心');
    expect(probe.observedMessages.first.senderName, '机器人');
    expect(probe.observedMessages.first.text, '安全登录通知');
    expect(probe.observedMessages.first.captureSource, 'feed_card_probe');
    expect(probe.observedMessages.last.conversationName, '听M玛的话交流12群C-GH');
    expect(probe.observedMessages.last.senderName, 'MM12机器人');
    expect(probe.observedMessages.last.text, '1 今天盘中、 多空-来回拉锯强烈');
    expect(probe.observedConversations, hasLength(2));
  });

  test('merges feed card messages with active DOM observations', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-10T01:49:30.307Z',
      'observed_messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': '7638063174163385529',
          'conversation_id': 'feed:cec2f034',
          'conversation_name': '泡沫之家',
          'sender_name': '橘生淮南',
          'message_type': 'image',
          'text': '[图片]',
          'observed_at': '2026-05-10T01:49:30.307Z',
          'capture_source': 'dom_probe',
          'image_attachments': <Map<String, dynamic>>[
            <String, dynamic>{
              'source_url': 'data:image/png;base64,aGVsbG8=',
              'local_path': '',
              'width': 500,
              'height': 232,
            },
          ],
        },
      ],
      'feed_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'feed_card_energy',
          'text': '满满正能量 09:49 橘生淮南: 联合测试文本0931',
        },
      ],
    });

    expect(probe.observedMessages, hasLength(2));
    expect(
      probe.observedMessages.map((message) => message.captureSource),
      containsAll(<String>['dom_probe', 'feed_card_probe']),
    );
    final feedMessage = probe.observedMessages.singleWhere(
      (message) => message.captureSource == 'feed_card_probe',
    );
    expect(feedMessage.conversationName, '满满正能量');
    expect(feedMessage.senderName, '橘生淮南');
    expect(feedMessage.text, '联合测试文本0931');
  });

  test(
    'excludes other-conversation DOM images while media feed is pending',
    () {
      final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
        'page_kind': 'messenger',
        'observed_at': '2026-05-10T01:49:30.307Z',
        'observed_messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '7638063174163385529',
            'conversation_id': 'feed:cec2f034',
            'conversation_name': '泡沫之家',
            'sender_name': '橘生淮南',
            'message_type': 'image',
            'text': '[图片]',
            'observed_at': '2026-05-10T01:49:30.307Z',
            'capture_source': 'dom_probe',
            'image_attachments': <Map<String, dynamic>>[
              <String, dynamic>{
                'source_url': 'data:image/png;base64,aGVsbG8=',
                'local_path': '',
                'width': 500,
                'height': 232,
              },
            ],
          },
        ],
        'feed_cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'feed_card_energy',
            'text': '满满正能量 09:49 橘生淮南: [图片]',
          },
        ],
      });

      expect(probeHasPendingMediaFeedCard(probe), isTrue);
      expect(
        probe.observedMessages.where(
          (message) => message.captureSource == 'dom_probe',
        ),
        isEmpty,
      );
      expect(
        probe.observedMessages
            .singleWhere(
              (message) => message.captureSource == 'feed_card_probe',
            )
            .conversationName,
        '满满正能量',
      );
    },
  );

  test('derives feed card messages from diagnostic top summaries', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-10T01:49:30.307Z',
      'probe_diagnostics': <String, dynamic>{
        'top_feed_card_summaries': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'feed_card_energy',
            'text': '满满正能量 09:49 橘生淮南: 联合测试文本0931',
            'active': false,
            'image_count': 0,
          },
        ],
      },
    });

    expect(probe.observedMessages, hasLength(1));
    expect(probe.observedMessages.single.captureSource, 'feed_card_probe');
    expect(probe.observedMessages.single.conversationName, '满满正能量');
    expect(probe.observedMessages.single.senderName, '橘生淮南');
    expect(probe.observedMessages.single.text, '联合测试文本0931');
  });

  test('ignores feed card avatar attachments for non-media previews', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:00:00Z',
      'feed_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'feed_card_1',
          'text': 'Alpha Group 09:24 Alice: hello',
          'image_attachments': <Map<String, dynamic>>[
            <String, dynamic>{
              'source_url':
                  'https://s1-imfile.feishucdn.com/static-resource/v1/default-avatar.png',
              'local_path': '',
              'width': 96,
              'height': 96,
            },
          ],
        },
      ],
    });

    expect(probe.observedMessages, hasLength(1));
    expect(probe.observedMessages.single.messageType, 'text');
    expect(probe.observedMessages.single.imageAttachments, isEmpty);
  });

  test('normalizes probe diagnostics from script payload', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:00:00Z',
      'probe_diagnostics': <String, dynamic>{
        'selector_hits': <Map<String, Object>>[
          <String, Object>{'selector': '[data-message-id]', 'count': 2},
        ],
        'leaf_text_samples': <String>['hello from Feishu'],
      },
    });

    expect(probe.probeDiagnostics['selector_hits'], hasLength(1));
    expect(probe.probeDiagnostics['leaf_text_samples'], <String>[
      'hello from Feishu',
    ]);
  });

  test('probe script exposes feed content freshness diagnostics', () {
    expect(feishuPageProbeScript, contains('feedContentSignature'));
    expect(feishuPageProbeScript, contains('feed_card_count'));
    expect(feishuPageProbeScript, contains('feed_content_signature'));
  });

  test('derives observations from messenger body text fallback', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'runtime_url': 'https://example.feishu.cn/next/messenger/',
      'page_title': '消息 - 飞书',
      'body_text':
          '开启读屏标签 搜索 (Ctrl+K) 消息 111 知识问答 会议 日历 云文档 通讯录 邮箱 任务 工作台 '
          '听M玛的话交流12群C-GH 1 账号安全中心 机器人 09:24 安全登录通知 '
          '满满正能量 昨天 橘生淮南: [图片]',
      'observed_at': '2026-05-09T12:00:00Z',
    });

    expect(probe.pageKind, 'messenger');
    expect(probe.observedConversations, isNotEmpty);
    expect(probe.observedConversations.first.name, '听M玛的话交流12群C-GH');
    expect(probe.observedMessages, isNotEmpty);
    expect(probe.observedMessages.first.text, contains('听M玛的话交流12群C-GH'));
  });

  test('parses feed cards with relative dates without polluting group name', () {
    final probe = FeishuPageProbe.fromScriptResult(<String, dynamic>{
      'page_kind': 'messenger',
      'observed_at': '2026-05-09T12:00:00Z',
      'feed_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'feed_card_1',
          'text': '泡沫之家 昨天 橘生淮南: [图片]',
        },
      ],
    });

    expect(probe.observedConversations, hasLength(1));
    expect(probe.observedConversations.first.name, '泡沫之家');
    expect(probe.observedMessages, hasLength(1));
    expect(probe.observedMessages.first.conversationName, '泡沫之家');
    expect(probe.observedMessages.first.senderName, '橘生淮南');
    expect(probe.observedMessages.first.text, '[图片]');
  });

  test('observer script posts Feishu monitor mutation messages', () {
    expect(feishuPageObserverScript, contains('MutationObserver'));
    expect(feishuPageObserverScript, contains('chrome.webview.postMessage'));
    expect(feishuPageObserverScript, contains('feishu_monitor_feed_changed'));
    expect(feishuPageObserverScript, contains('a11y_feed_card_item'));
  });

  test('observer script can reconnect body fallback to feed root', () {
    expect(feishuPageObserverScript, contains('body_fallback'));
    expect(feishuPageObserverScript, contains('root === document.body'));
    expect(feishuPageObserverScript, contains('existing.disconnect()'));
    expect(
      feishuPageObserverScript,
      contains('!existing.body_fallback || isBodyFallback'),
    );
  });

  test('observer script reconnects stale feed root nodes', () {
    expect(feishuPageObserverScript, contains('existing.root_node'));
    expect(
      feishuPageObserverScript,
      contains('existing.root_node.isConnected'),
    );
    expect(feishuPageObserverScript, contains('existing.root_node === root'));
    expect(feishuPageObserverScript, contains('root_node: root'));
  });

  test('observer script filters feed and card mutation notifications', () {
    expect(feishuPageObserverScript, contains('feedMutationSelectors'));
    expect(feishuPageObserverScript, contains('isRelevantMutation'));
    expect(feishuPageObserverScript, contains('node.matches?.(selector)'));
    expect(feishuPageObserverScript, contains('node.closest?.(selector)'));
    expect(
      feishuPageObserverScript,
      contains('!isBodyFallback && !mutations.some(isRelevantMutation)'),
    );
  });

  test('network image attribution script observes blobs and DOM images', () {
    expect(
      feishuNetworkImageAttributionScript,
      contains('__wukongFeishuNetworkImageAttribution'),
    );
    expect(
      feishuNetworkImageAttributionScript,
      contains('URL.createObjectURL'),
    );
    expect(feishuNetworkImageAttributionScript, contains('MutationObserver'));
    expect(
      feishuNetworkImageAttributionScript,
      contains('feishu_monitor_image_attribution'),
    );
  });

  test('storage probe script scans browser storage without DOM fallback', () {
    expect(feishuStorageProbeScript, contains('__wukongFeishuStorageProbe'));
    expect(feishuStorageProbeScript, contains('indexedDB.databases'));
    expect(feishuStorageProbeScript, contains('localStorage'));
    expect(feishuStorageProbeScript, contains('sessionStorage'));
    expect(feishuStorageProbeScript, contains('feishu_monitor_storage_probe'));
    expect(feishuStorageProbeScript, contains('image_key'));
    expect(feishuStorageProbeScript, contains('conversation_id'));
    expect(feishuStorageProbeScript, contains('sender_name'));
    expect(feishuStorageProbeScript, contains('database_name_hash'));
    expect(feishuStorageProbeScript, contains('store_name_hash'));
    expect(feishuStorageProbeScript, contains('totalRecordBudget'));
    expect(feishuStorageProbeScript, contains('directionSamples'));
    expect(feishuStorageProbeScript, contains('cursor.key'));
    expect(feishuStorageProbeScript, contains('field_paths'));
    expect(feishuStorageProbeScript, contains('<redacted>'));
    expect(feishuStorageProbeScript, isNot(contains('querySelectorAll')));
  });

  test(
    'network image attribution script falls back to active feed context',
    () {
      expect(feishuNetworkImageAttributionScript, contains('activeFeedCard'));
      expect(
        feishuNetworkImageAttributionScript,
        contains("data-feed-active=\"true\""),
      );
      expect(
        feishuNetworkImageAttributionScript,
        contains("hasFeedContext ? 'high' : hasActiveFeedContext ? 'medium'"),
      );
    },
  );

  test(
    'network image attribution script gives active feed a stable fallback id',
    () {
      expect(feishuNetworkImageAttributionScript, contains('stableHash'));
      expect(
        feishuNetworkImageAttributionScript,
        contains('feedIdentity = feedCardId(attributionCard) || stableHash'),
      );
      expect(
        feishuNetworkImageAttributionScript,
        contains(r'conversation_id: feedIdentity ? `feed:${feedIdentity}` :'),
      );
    },
  );

  test('network image attribution script drops low-context image noise', () {
    expect(
      feishuNetworkImageAttributionScript,
      contains('if (!hasFeedContext && !hasActiveFeedContext)'),
    );
  });

  test('observer script keeps Feishu web runtime visible and focused', () {
    expect(feishuPageKeepAliveScript, contains('keepAliveKey'));
    expect(feishuPageKeepAliveScript, contains("document, 'hidden'"));
    expect(feishuPageKeepAliveScript, contains("document, 'visibilityState'"));
    expect(
      feishuPageKeepAliveScript,
      contains('document.hasFocus = () => true'),
    );
    expect(feishuPageKeepAliveScript, contains("'focus'"));
    expect(feishuPageKeepAliveScript, contains("'visibilitychange'"));
    expect(feishuPageKeepAliveScript, contains('new Event(eventName)'));
    expect(
      feishuPageObserverScript,
      contains('__wukongFeishuMonitorKeepAlive'),
    );
  });

  test('parses Feishu monitor observer message', () {
    final message = FeishuPageObserverMessage.fromJson(<String, dynamic>{
      'type': 'feishu_monitor_feed_changed',
      'reason': 'mutation',
      'observed_at': '2026-05-09T13:00:00Z',
    });

    expect(message.isFeedChanged, isTrue);
    expect(message.isObserverInstalled, isFalse);
    expect(message.reason, 'mutation');
    expect(message.observedAt, DateTime.parse('2026-05-09T13:00:00Z'));
  });

  test('parses Feishu monitor observer message from raw JSON string', () {
    const rawString =
        '{"type":"feishu_monitor_feed_changed","reason":"mutation","observed_at":"2026-05-09T13:00:00Z"}';
    final decoded = jsonDecode(rawString) as Map<String, dynamic>;
    final message = FeishuPageObserverMessage.fromJson(decoded);

    expect(message.isFeedChanged, isTrue);
    expect(message.reason, 'mutation');
    expect(message.observedAt, DateTime.parse('2026-05-09T13:00:00Z'));
  });

  test('parses Feishu monitor image attribution message', () {
    final message = FeishuPageObserverMessage.fromJson(<String, dynamic>{
      'type': 'feishu_monitor_image_attribution',
      'source_url': 'blob:https://example.feishu.cn/abc?token=secret',
      'source_kind': 'blob',
      'blob_mime_type': 'image/webp',
      'blob_size': 12345,
      'conversation_id': 'feed:abc',
      'conversation_name': 'Alpha Group',
      'message_id': 'msg_1',
      'sender_name': 'Alice',
      'display_time': '14:29',
      'message_text': '[Image]',
      'feed_card_id': 'feed_card_1',
      'feed_card_text': 'Alpha Group 14:29 Alice: [Image]',
      'confidence': 0.92,
      'confidence_label': 'high',
      'reason': 'dom_img_src',
      'observed_at': '2026-05-10T06:29:00Z',
      'evidence': <String>['exact_dom_node', 'feed_card_context'],
    });

    expect(message.isImageAttribution, isTrue);
    expect(message.imageAttribution, isNotNull);
    expect(message.imageAttribution!.conversationName, 'Alpha Group');
    expect(
      message.imageAttribution!.sourceUrl,
      'blob:https://example.feishu.cn/abc?token=secret',
    );
  });
}
