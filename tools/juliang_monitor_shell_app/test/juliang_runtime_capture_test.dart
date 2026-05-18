import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:juliang_monitor_shell_app/src/juliang_page_probe.dart';
import 'package:juliang_monitor_shell_app/src/juliang_runtime_capture.dart';
import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';

void main() {
  test(
    'applies probe snapshot to store and publishes snapshot event',
    () async {
      final base = await Directory.systemTemp.createTemp(
        'juliang_runtime_capture_test_',
      );
      addTearDown(() async {
        if (await base.exists()) {
          await base.delete(recursive: true);
        }
      });
      final store = ShellStore(
        File('${base.path}${Platform.pathSeparator}status.json'),
      );
      final events = ShellEventBus();
      addTearDown(events.close);
      final capture = JuliangRuntimeCapture(store: store, events: events);
      final published = <ShellEvent>[];
      final subscription = events.stream.listen(published.add);
      addTearDown(subscription.cancel);

      final snapshot = await capture.applyProbe(
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
      await Future<void>.delayed(Duration.zero);

      final persisted = await store.load();
      expect(snapshot.recentEvents.single.text, 'hello from aggregate');
      expect(persisted.recentEvents.single.text, 'hello from aggregate');
      expect(persisted.observedConversations.single.id, 'source-alpha');
      expect(published, hasLength(1));
      expect(published.single.type, ShellEventType.snapshotUpdated);
      expect(published.single.reason, 'juliang_probe');
      expect(published.single.recentEventsCount, 1);
      expect(published.single.observedConversationsCount, 1);
    },
  );

  test('configured routing sources filter active text events', () async {
    final base = await Directory.systemTemp.createTemp(
      'juliang_runtime_capture_test_',
    );
    addTearDown(() async {
      if (await base.exists()) {
        await base.delete(recursive: true);
      }
    });
    final store = ShellStore(
      File('${base.path}${Platform.pathSeparator}status.json'),
    );
    await store.save(
      ShellSnapshot.initial().copyWith(
        probeDiagnostics: const <String, dynamic>{
          'configured_media_sources': <Map<String, String>>[
            <String, String>{
              'conversation_id': 'source-alpha',
              'conversation_name': 'Alpha Source',
            },
          ],
        },
      ),
    );
    final capture = JuliangRuntimeCapture(
      store: store,
      events: ShellEventBus(),
    );
    addTearDown(capture.close);

    final snapshot = await capture.applyProbe(
      JuliangPageProbe(
        runtimeUrl: 'https://msg.juliang888.top/user',
        pageTitle: 'Juliang',
        bodyText: 'Messages',
        pageKind: JuliangPageKind.workspace,
        observedAt: DateTime.utc(2026, 5, 17, 2),
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
            text: 'configured source text',
            observedAt: '2026-05-17T02:00:01Z',
            captureSource: 'dom_probe',
          ),
          JuliangProbeMessageEvent(
            eventId: 'event-beta-1',
            dedupeKey: 'source-beta:msg-beta-1',
            conversationId: 'source-beta',
            conversationName: 'Beta Source',
            conversationType: 'unknown',
            messageId: 'msg-beta-1',
            senderName: 'Bob',
            messageType: 'text',
            text: 'unconfigured source text',
            observedAt: '2026-05-17T02:00:02Z',
            captureSource: 'dom_probe',
          ),
        ],
      ),
      updatedAt: DateTime.utc(2026, 5, 17, 2, 0, 3),
    );

    expect(snapshot.recentEvents, hasLength(1));
    expect(snapshot.recentEvents.single.conversationId, 'source-alpha');
    expect(snapshot.recentEvents.single.text, 'configured source text');
  });

  test('merges duplicate events instead of appending replayed text', () async {
    final base = await Directory.systemTemp.createTemp(
      'juliang_runtime_capture_test_',
    );
    addTearDown(() async {
      if (await base.exists()) {
        await base.delete(recursive: true);
      }
    });
    final store = ShellStore(
      File('${base.path}${Platform.pathSeparator}status.json'),
    );
    final capture = JuliangRuntimeCapture(
      store: store,
      events: ShellEventBus(),
    );
    addTearDown(capture.close);
    final probe = JuliangPageProbe(
      runtimeUrl: 'https://msg.juliang888.top/user',
      pageTitle: 'Juliang',
      bodyText: 'Messages',
      pageKind: JuliangPageKind.workspace,
      observedAt: DateTime.utc(2026, 5, 17, 2),
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
          text: 'hello once',
          observedAt: '2026-05-17T02:00:01Z',
          captureSource: 'dom_probe',
        ),
      ],
    );

    await capture.applyProbe(
      probe,
      updatedAt: DateTime.utc(2026, 5, 17, 2, 0, 2),
    );
    final snapshot = await capture.applyProbe(
      probe,
      updatedAt: DateTime.utc(2026, 5, 17, 2, 0, 3),
    );

    expect(snapshot.recentEvents, hasLength(1));
    expect(snapshot.messagesToday, 1);
  });

  test(
    'login probe clears stale recent events and stores no login text',
    () async {
      final base = await Directory.systemTemp.createTemp(
        'juliang_runtime_capture_test_',
      );
      addTearDown(() async {
        if (await base.exists()) {
          await base.delete(recursive: true);
        }
      });
      final store = ShellStore(
        File('${base.path}${Platform.pathSeparator}status.json'),
      );
      await store.save(
        ShellSnapshot.initial().copyWith(
          recentEvents: const <NormalizedMessageEvent>[
            NormalizedMessageEvent(
              eventId: 'old-login-text',
              dedupeKey: 'old-login-text',
              accountId: '',
              conversationId: 'fallback:Login',
              conversationName: 'Login',
              conversationType: 'unknown',
              messageId: 'old-login-text',
              senderId: '',
              senderName: '',
              messageType: 'text',
              text: 'old login text',
              sentAt: '',
              observedAt: '2026-05-17T01:00:00Z',
              captureSource: 'dom_probe',
            ),
          ],
        ),
      );
      final capture = JuliangRuntimeCapture(
        store: store,
        events: ShellEventBus(),
      );
      addTearDown(capture.close);

      final snapshot = await capture.applyProbe(
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

  test(
    'updates /events/recent and /events SSE stream through shell server',
    () async {
      final base = await Directory.systemTemp.createTemp(
        'juliang_runtime_capture_test_',
      );
      addTearDown(() async {
        if (await base.exists()) {
          await base.delete(recursive: true);
        }
      });
      final store = ShellStore(
        File('${base.path}${Platform.pathSeparator}status.json'),
      );
      final events = ShellEventBus();
      final server = ShellServer(
        store: store,
        host: InternetAddress.loopbackIPv4,
        port: 0,
        token: 'test-token',
        events: events,
      );
      final boundServer = await server.start();
      addTearDown(server.close);
      final client = HttpClient();
      addTearDown(client.close);
      final baseUri = Uri.parse('http://127.0.0.1:${boundServer.port}');
      final streamRequest = await client.getUrl(baseUri.resolve('/events'));
      streamRequest.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer test-token',
      );
      final streamResponse = await streamRequest.close();
      final lines = <String>[];
      final streamSubscription = streamResponse
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(lines.add);
      addTearDown(streamSubscription.cancel);
      await _waitFor(() => lines.contains(': connected'), 'SSE connection');

      final capture = JuliangRuntimeCapture(store: store, events: events);
      await capture.applyProbe(
        JuliangPageProbe(
          runtimeUrl: 'https://msg.juliang888.top/user',
          pageTitle: 'Juliang',
          bodyText: 'Messages',
          pageKind: JuliangPageKind.workspace,
          observedAt: DateTime.utc(2026, 5, 17, 2),
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
              text: 'hello through server',
              observedAt: '2026-05-17T02:00:01Z',
              captureSource: 'dom_probe',
            ),
          ],
        ),
        updatedAt: DateTime.utc(2026, 5, 17, 2, 0, 2),
      );

      await _waitFor(
        () => lines.contains('event: snapshot_updated'),
        'snapshot_updated SSE',
      );
      final recentRequest = await client.getUrl(
        baseUri.resolve('/events/recent'),
      );
      recentRequest.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer test-token',
      );
      final recentResponse = await recentRequest.close();
      final recentBody = await utf8.decodeStream(recentResponse);
      final recentJson = jsonDecode(recentBody) as List<dynamic>;

      expect(streamResponse.statusCode, HttpStatus.ok);
      expect(recentResponse.statusCode, HttpStatus.ok);
      expect(recentJson, hasLength(1));
      expect(
        (recentJson.single as Map<String, dynamic>)['text'],
        'hello through server',
      );
      expect(
        lines.any(
          (line) =>
              line.startsWith('data: ') &&
              line.contains('"reason":"juliang_probe"') &&
              line.contains('"recent_events":1'),
        ),
        isTrue,
      );
    },
  );
}

Future<void> _waitFor(
  bool Function() condition,
  String description, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $description');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
