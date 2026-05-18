import 'package:flutter_test/flutter_test.dart';
import 'package:juliang_monitor_shell_app/src/juliang_page_probe.dart';
import 'package:juliang_monitor_shell_app/src/juliang_runtime_snapshot_mapper.dart';
import 'package:juliang_monitor_shell_app/src/juliang_text_event_parser.dart';
import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';

void main() {
  test('reads sanitized DOM probe source candidates and text events', () {
    final probe = juliangPageProbeFromJson(<String, Object?>{
      'runtime_url': 'https://msg.juliang888.top/user',
      'page_title': 'Juliang',
      'body_text': 'Messages Alpha Source hello from aggregate',
      'observed_at': '2026-05-17T02:00:00Z',
      'has_forwardable_content': true,
      'source_candidates': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'source-alpha',
          'name': 'Alpha Source',
          'type': 'unknown',
          'last_message_preview': 'hello from aggregate',
        },
      ],
      'events': <Map<String, Object?>>[
        <String, Object?>{
          'event_id': 'event-alpha-1',
          'dedupe_key': 'source-alpha:msg-alpha-1',
          'conversation_id': 'source-alpha',
          'conversation_name': 'Alpha Source',
          'conversation_type': 'unknown',
          'message_id': 'msg-alpha-1',
          'sender_name': 'Alice',
          'message_type': 'text',
          'text': 'hello from aggregate',
          'observed_at': '2026-05-17T02:00:01Z',
          'capture_source': 'dom_probe',
        },
      ],
    });

    expect(probe.pageKind, JuliangPageKind.workspace);
    expect(probe.runtimeUrl, 'https://msg.juliang888.top/user');
    expect(
      probe.observedAt.toUtc().toIso8601String(),
      '2026-05-17T02:00:00.000Z',
    );
    expect(probe.conversations, hasLength(1));
    expect(probe.conversations.single.id, 'source-alpha');
    expect(probe.conversations.single.name, 'Alpha Source');
    expect(probe.events, hasLength(1));
    expect(probe.events.single.text, 'hello from aggregate');
  });

  test('normalizes DOM text events into shell message events', () {
    final events =
        normalizeJuliangProbeMessageEvents(const <JuliangProbeMessageEvent>[
          JuliangProbeMessageEvent(
            eventId: 'event-alpha-1',
            dedupeKey: 'source-alpha:msg-alpha-1',
            conversationId: 'source-alpha',
            conversationName: 'Alpha Source',
            conversationType: 'unknown',
            messageId: 'msg-alpha-1',
            senderName: 'Alice',
            messageType: 'text',
            text: '  hello from aggregate  ',
            observedAt: '2026-05-17T02:00:01Z',
            captureSource: 'dom_probe',
          ),
        ], observedAt: DateTime.utc(2026, 5, 17, 2));

    expect(events, hasLength(1));
    expect(events.single, isA<NormalizedMessageEvent>());
    expect(events.single.eventId, 'event-alpha-1');
    expect(events.single.dedupeKey, 'source-alpha:msg-alpha-1');
    expect(events.single.conversationId, 'source-alpha');
    expect(events.single.conversationName, 'Alpha Source');
    expect(events.single.senderName, 'Alice');
    expect(events.single.messageType, 'text');
    expect(events.single.text, 'hello from aggregate');
    expect(events.single.observedAt, '2026-05-17T02:00:01Z');
    expect(events.single.captureSource, 'dom_probe');
  });

  test('creates deterministic fallback conversation id from source name', () {
    final events =
        normalizeJuliangProbeMessageEvents(const <JuliangProbeMessageEvent>[
          JuliangProbeMessageEvent(
            eventId: '',
            dedupeKey: '',
            conversationId: '',
            conversationName: 'Alpha Source',
            conversationType: 'unknown',
            messageId: 'dom-msg-1',
            senderName: '',
            messageType: 'text',
            text: 'fallback source text',
            observedAt: '',
            captureSource: '',
          ),
        ], observedAt: DateTime.utc(2026, 5, 17, 2));

    expect(events, hasLength(1));
    expect(events.single.conversationId, 'fallback:Alpha Source');
    expect(events.single.conversationName, 'Alpha Source');
    expect(events.single.eventId, 'fallback:Alpha Source:dom-msg-1');
    expect(events.single.dedupeKey, 'fallback:Alpha Source:dom-msg-1');
    expect(events.single.observedAt, '2026-05-17T02:00:00.000Z');
    expect(events.single.captureSource, 'dom_probe');
  });

  test('ignores non-text events in the text-only MVP', () {
    final events =
        normalizeJuliangProbeMessageEvents(const <JuliangProbeMessageEvent>[
          JuliangProbeMessageEvent(
            eventId: 'image-event',
            dedupeKey: 'source-alpha:image-1',
            conversationId: 'source-alpha',
            conversationName: 'Alpha Source',
            conversationType: 'unknown',
            messageId: 'image-1',
            senderName: 'Alice',
            messageType: 'image',
            text: '[image]',
            observedAt: '2026-05-17T02:00:01Z',
            captureSource: 'dom_probe',
          ),
        ], observedAt: DateTime.utc(2026, 5, 17, 2));

    expect(events, isEmpty);
  });

  test('filters aggregate chrome and login text from workspace probe events', () {
    final events =
        normalizeJuliangProbeMessageEvents(const <JuliangProbeMessageEvent>[
          JuliangProbeMessageEvent(
            eventId: 'login-copy',
            dedupeKey: 'source-alpha:login-copy',
            conversationId: 'source-alpha',
            conversationName: 'Alpha Source',
            conversationType: 'unknown',
            messageId: 'login-copy',
            senderName: '',
            messageType: 'text',
            text: 'FEIPANEL欢迎回来登录以继续使用面板登录注册重置密码',
            observedAt: '2026-05-17T02:00:01Z',
            captureSource: 'dom_probe',
          ),
          JuliangProbeMessageEvent(
            eventId: 'nav-copy',
            dedupeKey: 'source-alpha:nav-copy',
            conversationId: 'source-alpha',
            conversationName: 'Alpha Source',
            conversationType: 'unknown',
            messageId: 'nav-copy',
            senderName: '',
            messageType: 'text',
            text: '用户前台 设置 退出',
            observedAt: '2026-05-17T02:00:02Z',
            captureSource: 'dom_probe',
          ),
          JuliangProbeMessageEvent(
            eventId: 'source-row',
            dedupeKey: 'source-alpha:source-row',
            conversationId: 'source-alpha',
            conversationName: 'Alpha Source',
            conversationType: 'unknown',
            messageId: 'source-row',
            senderName: '',
            messageType: 'text',
            text: 'Alpha Source 2026-05-16 18:39',
            observedAt: '2026-05-17T02:00:03Z',
            captureSource: 'dom_probe',
          ),
          JuliangProbeMessageEvent(
            eventId: 'market-message',
            dedupeKey: 'source-alpha:market-message',
            conversationId: 'source-alpha',
            conversationName: 'Alpha Source',
            conversationType: 'unknown',
            messageId: 'market-message',
            senderName: '',
            messageType: 'text',
            text: '日经225指数 61149.88 -1504.17 -2.40%',
            observedAt: '2026-05-17T02:00:04Z',
            captureSource: 'dom_probe',
          ),
        ], observedAt: DateTime.utc(2026, 5, 17, 2));

    expect(events.map((event) => event.text), <String>[
      '日经225指数 61149.88 -1504.17 -2.40%',
    ]);
  });

  test(
    'maps probe into shell snapshot with conversations and recent text events',
    () {
      final snapshot = mapJuliangRuntimeSnapshot(
        JuliangPageProbe(
          runtimeUrl: 'https://msg.juliang888.top/user',
          pageTitle: 'Juliang',
          bodyText: 'Messages',
          pageKind: JuliangPageKind.workspace,
          observedAt: DateTime.utc(2026, 5, 17, 2),
          conversations: const <JuliangProbeConversation>[
            JuliangProbeConversation(
              id: 'source-alpha',
              name: 'Alpha Source',
              type: 'unknown',
              lastMessagePreview: 'hello from aggregate',
            ),
          ],
          events: const <JuliangProbeMessageEvent>[
            JuliangProbeMessageEvent(
              eventId: 'event-alpha-1',
              dedupeKey: 'source-alpha:msg-alpha-1',
              conversationId: 'source-alpha',
              conversationName: 'Alpha Source',
              conversationType: 'unknown',
              messageId: 'msg-alpha-1',
              senderName: 'Alice',
              messageType: 'text',
              text: 'hello from aggregate',
              observedAt: '2026-05-17T02:00:01Z',
              captureSource: 'dom_probe',
            ),
          ],
        ),
        updatedAt: DateTime.utc(2026, 5, 17, 2, 0, 2),
      );

      expect(snapshot.shellState, 'online');
      expect(snapshot.hookState, 'healthy');
      expect(snapshot.loginState, 'logged_in');
      expect(snapshot.captureState, 'running');
      expect(snapshot.pageKind, 'workspace');
      expect(snapshot.runtimeUrl, 'https://msg.juliang888.top/user');
      expect(snapshot.observedConversations, hasLength(1));
      expect(snapshot.observedConversations.single.id, 'source-alpha');
      expect(snapshot.observedConversations.single.name, 'Alpha Source');
      expect(snapshot.recentEvents, hasLength(1));
      expect(snapshot.recentEvents.single.conversationId, 'source-alpha');
      expect(snapshot.recentEvents.single.text, 'hello from aggregate');
      expect(snapshot.messagesToday, 1);
      expect(
        snapshot.lastUpdatedAt.toUtc().toIso8601String(),
        '2026-05-17T02:00:02.000Z',
      );
    },
  );

  test(
    'login page probes do not persist DOM text as recent message events',
    () {
      final snapshot = mapJuliangRuntimeSnapshot(
        JuliangPageProbe(
          runtimeUrl: 'https://msg.juliang888.top/login',
          pageTitle: 'Juliang Login',
          bodyText: 'Login form text',
          pageKind: JuliangPageKind.login,
          observedAt: DateTime.utc(2026, 5, 17, 2),
          events: const <JuliangProbeMessageEvent>[
            JuliangProbeMessageEvent(
              eventId: 'login-page-text',
              dedupeKey: 'login-page-text',
              conversationId: '',
              conversationName: 'Juliang Login',
              conversationType: 'unknown',
              messageId: 'login-page-text',
              senderName: '',
              messageType: 'text',
              text: 'Login form text must not become a message',
              observedAt: '2026-05-17T02:00:01Z',
              captureSource: 'dom_probe',
            ),
          ],
        ),
        updatedAt: DateTime.utc(2026, 5, 17, 2, 0, 2),
      );

      expect(snapshot.loginState, 'login_required');
      expect(snapshot.captureState, 'stopped');
      expect(snapshot.observedConversations, isEmpty);
      expect(snapshot.recentEvents, isEmpty);
      expect(snapshot.messagesToday, 0);
    },
  );
}
