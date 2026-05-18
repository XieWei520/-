import 'package:flutter_test/flutter_test.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_page_probe.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_runtime_snapshot_mapper.dart';

void main() {
  test('maps login page to login_required and stopped capture', () {
    final snapshot = mapMengxiaRuntimeSnapshot(
      MengxiaPageProbe(
        runtimeUrl: 'https://mengxia.example/login',
        pageTitle: 'Mengxia Login',
        pageKind: MengxiaPageKind.login,
        observedAt: DateTime.utc(2026, 5, 17),
      ),
    );

    expect(snapshot['shell_mode'], 'desktop_shell');
    expect(snapshot['login_state'], 'login_required');
    expect(snapshot['capture_state'], 'stopped');
    expect(snapshot['page_kind'], 'login');
    expect(snapshot['runtime_url'], 'https://mengxia.example/login');
  });

  test('maps non-login page to logged_in and running capture', () {
    final snapshot = mapMengxiaRuntimeSnapshot(
      MengxiaPageProbe(
        runtimeUrl: 'https://mengxia.example/messages',
        pageTitle: 'Messages',
        pageKind: MengxiaPageKind.workspace,
        observedAt: DateTime.utc(2026, 5, 17),
      ),
    );

    expect(snapshot['login_state'], 'logged_in');
    expect(snapshot['capture_state'], 'running');
    expect(snapshot['page_kind'], 'workspace');
  });

  test('maps probe conversations and events to shell snapshot lists', () {
    final snapshot = mapMengxiaRuntimeSnapshot(
      MengxiaPageProbe(
        runtimeUrl: 'https://mx.2026.naaifu.cn/#/pages/chat/index',
        pageTitle: '萌侠',
        pageKind: MengxiaPageKind.workspace,
        observedAt: DateTime.utc(2026, 5, 17),
        conversations: const <MengxiaProbeConversation>[
          MengxiaProbeConversation(
            id: 'mx-alpha',
            name: 'Alpha',
            type: 'group',
            lastMessagePreview: 'hello',
          ),
        ],
        events: const <MengxiaProbeMessageEvent>[
          MengxiaProbeMessageEvent(
            eventId: 'event-1',
            dedupeKey: 'mx-alpha:hello',
            conversationId: 'mx-alpha',
            conversationName: 'Alpha',
            conversationType: 'group',
            messageId: 'msg-1',
            senderName: 'Alice',
            messageType: 'text',
            text: 'hello',
            captureSource: 'dom_probe',
          ),
        ],
      ),
    );

    final conversations =
        snapshot['observed_conversations'] as List<Map<String, Object?>>;
    final events = snapshot['recent_events'] as List<Map<String, Object?>>;

    expect(conversations.single['id'], 'mx-alpha');
    expect(conversations.single['name'], 'Alpha');
    expect(events.single['conversation_id'], 'mx-alpha');
    expect(events.single['text'], 'hello');
  });

  test('maps image attachments from dom probe events', () {
    final snapshot = mapMengxiaRuntimeSnapshot(
      MengxiaPageProbe(
        runtimeUrl: 'https://mx.2026.naaifu.cn/#/',
        pageTitle: 'Mengxia',
        pageKind: MengxiaPageKind.workspace,
        observedAt: DateTime.utc(2026, 5, 17),
        events: const <MengxiaProbeMessageEvent>[
          MengxiaProbeMessageEvent(
            eventId: 'event-image-1',
            dedupeKey: 'fallback:Mengxia:event-image-1',
            conversationId: 'fallback:Mengxia',
            conversationName: 'Mengxia',
            conversationType: 'unknown',
            messageId: 'message-image-1',
            senderName: '',
            messageType: 'image',
            text: '',
            captureSource: 'dom_probe',
            imageAttachments: <MengxiaProbeImageAttachment>[
              MengxiaProbeImageAttachment(
                sourceUrl: 'data:image/png;base64,iVBORw0KGgo=',
                localPath: '',
                width: 320,
                height: 240,
              ),
            ],
          ),
        ],
      ),
    );

    final events = snapshot['recent_events'] as List<Map<String, Object?>>;
    final attachments = events.single['image_attachments'] as List<Object?>;
    final first = attachments.single as Map<String, Object?>;

    expect(events.single['message_type'], 'image');
    expect(first['source_url'], 'data:image/png;base64,iVBORw0KGgo=');
    expect(first['width'], 320);
    expect(first['height'], 240);
  });

  test('reads visible source candidates as probe conversations', () {
    final probe = mengxiaPageProbeFromJson(<String, Object?>{
      'runtime_url': 'https://mx.2026.naaifu.cn/#/',
      'page_title': '萌侠博客',
      'body_text': '萌侠博客',
      'has_forwardable_content': true,
      'observed_at': '2026-05-17T00:00:00.000Z',
      'source_candidates': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'fallback:藏龙岛',
          'name': '藏龙岛',
          'type': 'unknown',
          'last_message_preview': '藏龙岛',
        },
        <String, Object?>{
          'id': 'fallback:萌侠博客',
          'name': '萌侠博客',
          'type': 'unknown',
          'last_message_preview': '萌侠博客',
        },
      ],
    });

    expect(probe.conversations.map((item) => item.name), <String>[
      '藏龙岛',
      '萌侠博客',
    ]);
  });

  test(
    'creates fallback source conversation when dom events have only a page name',
    () {
      final snapshot = mapMengxiaRuntimeSnapshot(
        MengxiaPageProbe(
          runtimeUrl: 'https://mx.2026.naaifu.cn/#/',
          pageTitle: '萌侠博客',
          pageKind: MengxiaPageKind.workspace,
          observedAt: DateTime.utc(2026, 5, 17),
          events: const <MengxiaProbeMessageEvent>[
            MengxiaProbeMessageEvent(
              eventId: ':dom:ad568u:ad568u',
              dedupeKey: ':dom:ad568u:ad568u',
              conversationId: '',
              conversationName: '萌侠博客',
              conversationType: 'unknown',
              messageId: 'dom:ad568u',
              senderName: '',
              messageType: 'text',
              text: 'hello from dom',
              captureSource: 'dom_probe',
            ),
          ],
        ),
      );

      final conversations =
          snapshot['observed_conversations'] as List<Map<String, Object?>>;
      final events = snapshot['recent_events'] as List<Map<String, Object?>>;

      expect(conversations, hasLength(1));
      expect(conversations.single['id'], 'fallback:萌侠博客');
      expect(conversations.single['name'], '萌侠博客');
      expect(conversations.single['last_message_preview'], 'hello from dom');
      expect(events.single['conversation_id'], 'fallback:萌侠博客');
      expect(events.single['conversation_name'], '萌侠博客');
      expect(events.single['dedupe_key'], contains('fallback:萌侠博客'));
    },
  );

  test('derives login page kind from url, title, or body text', () {
    expect(
      deriveMengxiaPageKind(
        runtimeUrl: 'https://mengxia.example/passport',
        pageTitle: 'Welcome',
        bodyText: '',
        hasForwardableContent: false,
      ),
      MengxiaPageKind.login,
    );
    expect(
      deriveMengxiaPageKind(
        runtimeUrl: 'https://mengxia.example',
        pageTitle: 'Manual Login',
        bodyText: '',
        hasForwardableContent: false,
      ),
      MengxiaPageKind.login,
    );
    expect(
      deriveMengxiaPageKind(
        runtimeUrl: 'https://mengxia.example',
        pageTitle: 'Mengxia',
        bodyText: 'please scan qr code',
        hasForwardableContent: false,
      ),
      MengxiaPageKind.login,
    );
  });
}
