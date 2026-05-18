import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late ShellServer server;
  late HttpClient client;
  late Uri baseUri;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('local-shell-core-test-');
    server = ShellServer(
      store: ShellStore(
        File('${tempDir.path}/status.json'),
        clock: () => DateTime.parse('2026-05-10T12:00:00Z'),
      ),
      host: InternetAddress.loopbackIPv4,
      port: 0,
      token: 'test-token',
    );
    final httpServer = await server.start();
    baseUri = Uri.parse('http://127.0.0.1:${httpServer.port}');
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('GET /status returns stored shell snapshot', () async {
    final request = await client.getUrl(baseUri.resolve('/status'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body) as Map<String, dynamic>;

    expect(response.statusCode, HttpStatus.ok);
    expect(json['shell_state'], 'online');
    expect(json['capture_state'], 'stopped');
    expect(json['runtime_url'], '');
    expect(json['page_title'], '');
    expect(json['webview_available'], isFalse);
    expect(json['shell_mode'], 'service');
    expect(json['page_kind'], 'unknown');
    expect(json['probe_observed_at'], '');
    expect(json['probe_diagnostics'], isEmpty);
    expect(json['observed_conversations'], isEmpty);
    expect(json['observed_messages'], isEmpty);
    expect(json['recent_events'], isEmpty);
  });

  test(
    'GET /status returns initial snapshot when status file is invalid',
    () async {
      await File('${tempDir.path}/status.json').writeAsString('{broken-json');
      final request = await client.getUrl(baseUri.resolve('/status'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');

      final response = await request.close();
      final body = await utf8.decodeStream(response);
      final json = jsonDecode(body) as Map<String, dynamic>;

      expect(response.statusCode, HttpStatus.ok);
      expect(json['shell_state'], 'online');
      expect(json['observed_messages'], isEmpty);
    },
  );

  test('GET /health returns derived health payload', () async {
    final request = await client.getUrl(baseUri.resolve('/health'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body) as Map<String, dynamic>;

    expect(response.statusCode, HttpStatus.ok);
    expect(json['needs_login'], isTrue);
    expect(json['capture_running'], isFalse);
  });

  test('POST /capture/start updates capture state', () async {
    final request = await client.postUrl(baseUri.resolve('/capture/start'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body) as Map<String, dynamic>;

    expect(response.statusCode, HttpStatus.ok);
    expect(json['capture_state'], 'running');
    expect(json['hook_state'], 'healthy');
  });

  test('POST /routing/sources stores configured media sources', () async {
    final request = await client.postUrl(baseUri.resolve('/routing/sources'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode(<String, Object>{
        'sources': <Map<String, String>>[
          <String, String>{
            'conversation_id': 'feed:alpha',
            'conversation_name': 'Alpha Group',
          },
          <String, String>{
            'conversation_id': '',
            'conversation_name': 'Beta Group',
          },
          <String, String>{'conversation_id': '', 'conversation_name': ''},
        ],
      }),
    );

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body) as Map<String, dynamic>;
    final stored = await server.store.load();

    expect(response.statusCode, HttpStatus.ok);
    expect(json['configured_media_source_count'], 2);
    expect(stored.probeDiagnostics['configured_media_source_count'], 2);
    expect(
      stored.probeDiagnostics['configured_media_sources'],
      <Map<String, String>>[
        <String, String>{
          'conversation_id': 'feed:alpha',
          'conversation_name': 'Alpha Group',
        },
        <String, String>{
          'conversation_id': '',
          'conversation_name': 'Beta Group',
        },
      ],
    );
  });

  test(
    'store update preserves newer capture state during delayed saves',
    () async {
      final stale = (await server.store.load()).copyWith(
        captureState: 'stopped',
        runtimeUrl: 'https://www.feishu.cn/messenger/',
        lastUpdatedAt: DateTime.utc(2026, 5, 10, 11),
      );
      await server.store.update(
        (snapshot) => snapshot.copyWith(
          captureState: 'running',
          lastUpdatedAt: DateTime.utc(2026, 5, 10, 11, 0, 1),
        ),
        preserveCaptureState: false,
      );

      await server.store.update((snapshot) {
        return stale.copyWith(
          pageTitle: '消息 - 飞书',
          lastUpdatedAt: DateTime.utc(2026, 5, 10, 11, 0, 2),
        );
      });

      final restored = await server.store.load();
      expect(restored.captureState, 'running');
      expect(restored.pageTitle, '消息 - 飞书');
    },
  );

  test(
    'store update preserves explicit stopped state during delayed saves',
    () async {
      final stale = (await server.store.load()).copyWith(
        captureState: 'running',
        runtimeUrl: 'https://www.feishu.cn/messenger/',
        lastUpdatedAt: DateTime.utc(2026, 5, 10, 11),
      );
      await server.store.update(
        (snapshot) => snapshot.copyWith(
          captureState: 'stopped',
          lastUpdatedAt: DateTime.utc(2026, 5, 10, 11, 0, 1),
        ),
        preserveCaptureState: false,
      );

      await server.store.update((snapshot) {
        return stale.copyWith(
          pageTitle: '消息 - 飞书',
          lastUpdatedAt: DateTime.utc(2026, 5, 10, 11, 0, 2),
        );
      });

      final restored = await server.store.load();
      expect(restored.captureState, 'stopped');
      expect(restored.pageTitle, '消息 - 飞书');
    },
  );

  test('store load waits for in-flight snapshot update', () async {
    final snapshotFile = File('${tempDir.path}/slow-status.json');
    await snapshotFile.writeAsString(
      jsonEncode(
        ShellSnapshot.initial()
            .copyWith(pageTitle: 'old', lastUpdatedAt: DateTime.utc(2026))
            .toJson(),
      ),
    );
    final slowStore = _BlockingSaveShellStore(snapshotFile);

    final updateFuture = slowStore.update((snapshot) {
      return snapshot.copyWith(
        pageTitle: 'new',
        lastUpdatedAt: DateTime.utc(2026, 5, 10, 14),
      );
    });
    await slowStore.saveStarted.future;

    final loadFuture = slowStore.load();
    final completedEarly = await Future.any(<Future<bool>>[
      loadFuture.then((_) => true),
      Future<bool>.delayed(const Duration(milliseconds: 20), () => false),
    ]);
    expect(completedEarly, isFalse);

    slowStore.releaseSave.complete();
    await updateFuture;

    final loaded = await loadFuture;
    expect(loaded.pageTitle, 'new');
  });

  test(
    'store save retries when status file is temporarily locked',
    () async {
      final snapshotFile = File('${tempDir.path}/locked-status.json');
      await snapshotFile.writeAsString(
        jsonEncode(
          ShellSnapshot.initial()
              .copyWith(pageTitle: 'old', lastUpdatedAt: DateTime.utc(2026))
              .toJson(),
        ),
      );
      final lockedFile = await snapshotFile.open(mode: FileMode.append);
      await lockedFile.lock();
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 80), () async {
          await lockedFile.unlock();
          await lockedFile.close();
        }),
      );

      final store = ShellStore(snapshotFile);
      await store.save(
        ShellSnapshot.initial().copyWith(
          pageTitle: 'new',
          lastUpdatedAt: DateTime.utc(2026, 5, 12, 15),
        ),
      );

      final loaded = await store.load();
      expect(loaded.pageTitle, 'new');
    },
    skip: !Platform.isWindows,
  );

  test('store prunes local capture records older than retention', () async {
    final snapshotFile = File('${tempDir.path}/retention-status.json');
    final store = ShellStore(
      snapshotFile,
      clock: () => DateTime.parse('2026-05-10T12:00:00Z'),
    );

    await store.save(
      ShellSnapshot.initial().copyWith(
        observedMessages: const <ObservedMessageCandidate>[
          ObservedMessageCandidate(
            id: 'old_message',
            conversationId: 'chat_old',
            conversationName: 'Old Group',
            senderName: 'Alice',
            messageType: 'text',
            text: 'old',
            observedAt: '2026-05-09T11:59:59Z',
            captureSource: 'dom_probe',
          ),
          ObservedMessageCandidate(
            id: 'recent_message',
            conversationId: 'chat_recent',
            conversationName: 'Recent Group',
            senderName: 'Bob',
            messageType: 'text',
            text: 'recent',
            observedAt: '2026-05-09T12:00:00Z',
            captureSource: 'dom_probe',
          ),
          ObservedMessageCandidate(
            id: 'invalid_timestamp_message',
            conversationId: 'chat_unknown',
            conversationName: 'Unknown Group',
            senderName: 'Carol',
            messageType: 'text',
            text: 'keep invalid timestamp',
            observedAt: '',
            captureSource: 'dom_probe',
          ),
        ],
        recentEvents: const <NormalizedMessageEvent>[
          NormalizedMessageEvent(
            eventId: 'old_event',
            dedupeKey: 'chat_old:msg_old',
            accountId: '',
            conversationId: 'chat_old',
            conversationName: 'Old Group',
            conversationType: 'unknown',
            messageId: 'msg_old',
            senderId: '',
            senderName: 'Alice',
            messageType: 'text',
            text: 'old',
            sentAt: '',
            observedAt: '2026-05-09T11:59:59Z',
            captureSource: 'dom_probe',
          ),
          NormalizedMessageEvent(
            eventId: 'recent_event',
            dedupeKey: 'chat_recent:msg_recent',
            accountId: '',
            conversationId: 'chat_recent',
            conversationName: 'Recent Group',
            conversationType: 'unknown',
            messageId: 'msg_recent',
            senderId: '',
            senderName: 'Bob',
            messageType: 'text',
            text: 'recent',
            sentAt: '',
            observedAt: '2026-05-09T12:00:00Z',
            captureSource: 'dom_probe',
          ),
        ],
      ),
    );

    final loaded = await store.load();

    expect(loaded.observedMessages.map((message) => message.id), <String>[
      'recent_message',
      'invalid_timestamp_message',
    ]);
    expect(loaded.recentEvents.map((event) => event.eventId), <String>[
      'recent_event',
    ]);
  });

  test('GET /conversations returns observed conversation list', () async {
    final stored = await server.store.load();
    await server.store.save(
      stored.copyWith(
        observedConversations: const <ObservedConversation>[
          ObservedConversation(
            id: 'oc_1',
            name: '测试群A',
            type: 'group',
            lastMessagePreview: 'hello',
            observedAt: '2026-05-09T12:00:00Z',
          ),
        ],
      ),
    );
    final request = await client.getUrl(baseUri.resolve('/conversations'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body) as List<dynamic>;

    expect(response.statusCode, HttpStatus.ok);
    expect(json, hasLength(1));
    expect((json.first as Map<String, dynamic>)['name'], '测试群A');
  });
  test('GET /messages/recent returns observed message candidates', () async {
    final stored = await server.store.load();
    await server.store.save(
      stored.copyWith(
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
    final request = await client.getUrl(baseUri.resolve('/messages/recent'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body) as List<dynamic>;

    expect(response.statusCode, HttpStatus.ok);
    expect(json, hasLength(1));
    expect(json.first, <String, dynamic>{
      'id': 'msg_1',
      'conversation_id': 'chat_1',
      'conversation_name': 'Alpha Group',
      'sender_name': 'Alice',
      'message_type': 'text',
      'text': 'hello from Feishu',
      'observed_at': '2026-05-09T12:00:00Z',
      'capture_source': 'dom_probe',
      'image_attachments': <dynamic>[],
      'file_attachments': <dynamic>[],
    });
  });

  test('ShellSnapshot preserves probe diagnostics in status json', () {
    final snapshot = ShellSnapshot.initial().copyWith(
      probeDiagnostics: const <String, dynamic>{
        'selector_hits': <Map<String, Object>>[
          <String, Object>{'selector': '[data-message-id]', 'count': 2},
        ],
        'leaf_text_samples': <String>['hello from Feishu'],
      },
    );

    final json = snapshot.toJson();
    expect(json['probe_diagnostics'], isA<Map<String, dynamic>>());
    expect(
      (json['probe_diagnostics'] as Map<String, dynamic>)['selector_hits'],
      hasLength(1),
    );

    final restored = ShellSnapshot.fromJsonString(jsonEncode(json));
    expect(restored.probeDiagnostics['leaf_text_samples'], <String>[
      'hello from Feishu',
    ]);
  });

  test('GET /events/recent returns normalized message events', () async {
    final stored = await server.store.load();
    await server.store.save(
      stored.copyWith(
        recentEvents: const <NormalizedMessageEvent>[
          NormalizedMessageEvent(
            eventId: 'event_msg_1',
            dedupeKey: 'chat_1:msg_1',
            accountId: '',
            conversationId: 'chat_1',
            conversationName: 'Alpha Group',
            conversationType: 'unknown',
            messageId: 'msg_1',
            senderId: '',
            senderName: 'Alice',
            messageType: 'text',
            text: 'hello from Feishu',
            sentAt: '',
            observedAt: '2026-05-09T12:00:00Z',
            captureSource: 'dom_probe',
          ),
        ],
      ),
    );
    final statusRequest = await client.getUrl(baseUri.resolve('/status'));
    statusRequest.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer test-token',
    );

    final statusResponse = await statusRequest.close();
    final statusBody = await utf8.decodeStream(statusResponse);
    final statusJson = jsonDecode(statusBody) as Map<String, dynamic>;

    expect(statusResponse.statusCode, HttpStatus.ok);
    expect(statusJson['recent_events'], hasLength(1));

    final request = await client.getUrl(baseUri.resolve('/events/recent'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body) as List<dynamic>;

    expect(response.statusCode, HttpStatus.ok);
    expect(json, hasLength(1));
    expect(json.first, <String, dynamic>{
      'event_id': 'event_msg_1',
      'dedupe_key': 'chat_1:msg_1',
      'account_id': '',
      'conversation_id': 'chat_1',
      'conversation_name': 'Alpha Group',
      'conversation_type': 'unknown',
      'message_id': 'msg_1',
      'sender_id': '',
      'sender_name': 'Alice',
      'message_type': 'text',
      'text': 'hello from Feishu',
      'sent_at': '',
      'observed_at': '2026-05-09T12:00:00Z',
      'capture_source': 'dom_probe',
      'image_attachments': <dynamic>[],
      'file_attachments': <dynamic>[],
    });
  });

  test('GET /events rejects unauthorized clients', () async {
    final request = await client.getUrl(baseUri.resolve('/events'));

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body) as Map<String, dynamic>;

    expect(response.statusCode, HttpStatus.unauthorized);
    expect(json['error'], 'unauthorized');
  });

  test('GET /events streams published shell events', () async {
    final request = await client.getUrl(baseUri.resolve('/events'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');

    final responseFuture = request.close();
    final response = await responseFuture;
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.contentType?.mimeType, 'text/event-stream');

    final lines = <String>[];
    final subscription = response
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(lines.add);

    await _waitFor(() => lines.contains(': connected'), 'SSE connection frame');

    server.events.publish(
      ShellEvent(
        type: ShellEventType.snapshotUpdated,
        reason: 'test_probe',
        updatedAt: DateTime.parse('2026-05-09T13:00:00Z'),
        recentEventsCount: 2,
        observedConversationsCount: 3,
      ),
    );

    await _waitFor(
      () => lines.contains('event: snapshot_updated'),
      'snapshot_updated event frame',
    );
    await subscription.cancel();

    expect(lines, contains('event: snapshot_updated'));
    expect(
      lines.any(
        (line) =>
            line.startsWith('data: ') &&
            line.contains('"reason":"test_probe"') &&
            line.contains('"recent_events":2') &&
            line.contains('"observed_conversations":3'),
      ),
      isTrue,
    );
  });

  test('POST /capture/start publishes capture state event', () async {
    final events = <ShellEvent>[];
    final sub = server.events.stream.listen(events.add);

    final request = await client.postUrl(baseUri.resolve('/capture/start'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');
    final response = await request.close();
    await utf8.decodeStream(response);

    await _waitFor(() => events.isNotEmpty, 'capture start shell event');
    await sub.cancel();

    expect(response.statusCode, HttpStatus.ok);
    expect(events, hasLength(1));
    expect(events.single.type, ShellEventType.captureStateChanged);
    expect(events.single.reason, 'capture_start');
  });

  test('POST /runtime/reload publishes runtime reload request event', () async {
    final events = <ShellEvent>[];
    final sub = server.events.stream.listen(events.add);

    final request = await client.postUrl(baseUri.resolve('/runtime/reload'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');
    final response = await request.close();
    await utf8.decodeStream(response);

    await _waitFor(() => events.isNotEmpty, 'runtime reload shell event');
    await sub.cancel();

    expect(response.statusCode, HttpStatus.ok);
    expect(events, hasLength(1));
    expect(events.single.type, ShellEventType.runtimeReloadRequested);
    expect(events.single.reason, 'runtime_reload');
  });

  test(
    'POST /runtime/hard-reload publishes hard runtime reload request event',
    () async {
      final events = <ShellEvent>[];
      final sub = server.events.stream.listen(events.add);

      final request = await client.postUrl(
        baseUri.resolve('/runtime/hard-reload'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');
      final response = await request.close();
      await utf8.decodeStream(response);

      await _waitFor(
        () => events.isNotEmpty,
        'runtime hard reload shell event',
      );
      await sub.cancel();

      expect(response.statusCode, HttpStatus.ok);
      expect(events, hasLength(1));
      expect(events.single.type, ShellEventType.runtimeReloadRequested);
      expect(events.single.reason, 'runtime_hard_reload');
    },
  );

  test(
    'POST /runtime/session-reset publishes session reset request event',
    () async {
      final events = <ShellEvent>[];
      final sub = server.events.stream.listen(events.add);

      final request = await client.postUrl(
        baseUri.resolve('/runtime/session-reset'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');
      final response = await request.close();
      await utf8.decodeStream(response);

      await _waitFor(
        () => events.isNotEmpty,
        'runtime session reset shell event',
      );
      await sub.cancel();

      expect(response.statusCode, HttpStatus.ok);
      expect(events, hasLength(1));
      expect(events.single.type, ShellEventType.runtimeReloadRequested);
      expect(events.single.reason, 'runtime_session_reset');
    },
  );

  test('GET /events cleans up subscription when client disconnects', () async {
    final socket = await Socket.connect(baseUri.host, baseUri.port);
    final lines = <String>[];
    final socketSub = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(lines.add, onError: (_) {});

    socket.write(
      'GET /events HTTP/1.1\r\n'
      'Host: ${baseUri.host}:${baseUri.port}\r\n'
      'Authorization: Bearer test-token\r\n'
      '\r\n',
    );
    await socket.flush();

    await _waitFor(() => lines.contains(': connected'), 'SSE connection frame');
    expect(server.activeEventSubscriptionCount, 1);

    socket.destroy();
    await socketSub.cancel();
    server.events.publish(
      ShellEvent(
        type: ShellEventType.snapshotUpdated,
        reason: 'disconnect_probe',
        updatedAt: DateTime.parse('2026-05-09T13:00:00Z'),
      ),
    );

    await _waitFor(
      () => server.activeEventSubscriptionCount == 0,
      'SSE disconnect cleanup',
    );
  });

  test('close cleans up active SSE connections', () async {
    final socket = await Socket.connect(baseUri.host, baseUri.port);
    final lines = <String>[];
    final socketSub = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(lines.add, onError: (_) {});

    socket.write(
      'GET /events HTTP/1.1\r\n'
      'Host: ${baseUri.host}:${baseUri.port}\r\n'
      'Authorization: Bearer test-token\r\n'
      '\r\n',
    );
    await socket.flush();

    await _waitFor(
      () => lines.contains(': connected'),
      'SSE connection frame before server close',
    );
    expect(server.activeEventSubscriptionCount, 1);

    await server.close();

    await _waitFor(
      () => server.activeEventSubscriptionCount == 0,
      'SSE cleanup on server close',
    );

    await socketSub.cancel();
    socket.destroy();
  });

  test('close does not close externally supplied event bus', () async {
    final suppliedBus = ShellEventBus();
    final events = <ShellEvent>[];
    final sub = suppliedBus.stream.listen(events.add);
    final suppliedServer = ShellServer(
      store: ShellStore(File('${tempDir.path}/supplied-status.json')),
      host: InternetAddress.loopbackIPv4,
      port: 0,
      token: 'test-token',
      events: suppliedBus,
    );

    await suppliedServer.start();
    await suppliedServer.close();
    suppliedBus.publish(
      ShellEvent(
        type: ShellEventType.snapshotUpdated,
        reason: 'after_close',
        updatedAt: DateTime.parse('2026-05-09T13:00:00Z'),
      ),
    );

    await _waitFor(() => events.isNotEmpty, 'supplied bus event after close');
    expect(events.single.reason, 'after_close');

    await sub.cancel();
    await suppliedBus.close();
  });

  test('mergeRecentEvents dedupes by key, keeps newer event, and limits', () {
    const existing = <NormalizedMessageEvent>[
      NormalizedMessageEvent(
        eventId: 'event_old',
        dedupeKey: 'chat_1:msg_1',
        accountId: '',
        conversationId: 'chat_1',
        conversationName: 'Alpha Group',
        conversationType: 'unknown',
        messageId: 'msg_1',
        senderId: '',
        senderName: 'Alice',
        messageType: 'text',
        text: 'old text',
        sentAt: '',
        observedAt: '2026-05-09T11:00:00Z',
        captureSource: 'dom_probe',
      ),
      NormalizedMessageEvent(
        eventId: 'event_existing_2',
        dedupeKey: 'chat_2:msg_2',
        accountId: '',
        conversationId: 'chat_2',
        conversationName: 'Beta Group',
        conversationType: 'unknown',
        messageId: 'msg_2',
        senderId: '',
        senderName: 'Bob',
        messageType: 'text',
        text: 'second',
        sentAt: '',
        observedAt: '2026-05-09T10:00:00Z',
        captureSource: 'dom_probe',
      ),
    ];
    const incoming = <NormalizedMessageEvent>[
      NormalizedMessageEvent(
        eventId: 'event_msg_1',
        dedupeKey: 'chat_1:msg_1',
        accountId: '',
        conversationId: 'chat_1',
        conversationName: 'Alpha Group',
        conversationType: 'unknown',
        messageId: 'msg_1',
        senderId: '',
        senderName: 'Alice',
        messageType: 'text',
        text: 'hello from Feishu',
        sentAt: '',
        observedAt: '2026-05-09T12:00:00Z',
        captureSource: 'dom_probe',
      ),
      NormalizedMessageEvent(
        eventId: 'event_incoming_2',
        dedupeKey: 'chat_3:msg_3',
        accountId: '',
        conversationId: 'chat_3',
        conversationName: 'Gamma Group',
        conversationType: 'unknown',
        messageId: 'msg_3',
        senderId: '',
        senderName: 'Carol',
        messageType: 'text',
        text: 'third',
        sentAt: '',
        observedAt: '2026-05-09T09:00:00Z',
        captureSource: 'dom_probe',
      ),
      NormalizedMessageEvent(
        eventId: 'event_incoming_3',
        dedupeKey: 'chat_4:msg_4',
        accountId: '',
        conversationId: 'chat_4',
        conversationName: 'Delta Group',
        conversationType: 'unknown',
        messageId: 'msg_4',
        senderId: '',
        senderName: 'Dana',
        messageType: 'text',
        text: 'fourth',
        sentAt: '',
        observedAt: '2026-05-09T08:00:00Z',
        captureSource: 'dom_probe',
      ),
    ];

    final merged = mergeRecentEvents(existing, incoming, limit: 3);

    expect(merged, hasLength(3));
    expect(merged.map((event) => event.eventId), <String>[
      'event_msg_1',
      'event_existing_2',
      'event_incoming_2',
    ]);
    expect(merged.first.text, 'hello from Feishu');
  });

  test('mergeRecentEvents trims dedupe keys before deduping', () {
    const existing = <NormalizedMessageEvent>[
      NormalizedMessageEvent(
        eventId: 'event_old',
        dedupeKey: ' chat_1:msg_1 ',
        accountId: '',
        conversationId: 'chat_1',
        conversationName: 'Alpha Group',
        conversationType: 'unknown',
        messageId: 'msg_1',
        senderId: '',
        senderName: 'Alice',
        messageType: 'text',
        text: 'old text',
        sentAt: '',
        observedAt: '2026-05-09T11:00:00Z',
        captureSource: 'dom_probe',
      ),
    ];
    const incoming = <NormalizedMessageEvent>[
      NormalizedMessageEvent(
        eventId: 'event_new',
        dedupeKey: 'chat_1:msg_1',
        accountId: '',
        conversationId: 'chat_1',
        conversationName: 'Alpha Group',
        conversationType: 'unknown',
        messageId: 'msg_1',
        senderId: '',
        senderName: 'Alice',
        messageType: 'text',
        text: 'new text',
        sentAt: '',
        observedAt: '2026-05-09T12:00:00Z',
        captureSource: 'dom_probe',
      ),
    ];

    final merged = mergeRecentEvents(existing, incoming);

    expect(merged, hasLength(1));
    expect(merged.single.eventId, 'event_new');
  });

  test('mergeRecentEvents trims event id fallback before deduping', () {
    const existing = <NormalizedMessageEvent>[
      NormalizedMessageEvent(
        eventId: ' event_msg_1 ',
        dedupeKey: ' ',
        accountId: '',
        conversationId: 'chat_1',
        conversationName: 'Alpha Group',
        conversationType: 'unknown',
        messageId: 'msg_1',
        senderId: '',
        senderName: 'Alice',
        messageType: 'text',
        text: 'old text',
        sentAt: '',
        observedAt: '2026-05-09T11:00:00Z',
        captureSource: 'dom_probe',
      ),
    ];
    const incoming = <NormalizedMessageEvent>[
      NormalizedMessageEvent(
        eventId: 'event_msg_1',
        dedupeKey: '',
        accountId: '',
        conversationId: 'chat_1',
        conversationName: 'Alpha Group',
        conversationType: 'unknown',
        messageId: 'msg_1',
        senderId: '',
        senderName: 'Alice',
        messageType: 'text',
        text: 'new text',
        sentAt: '',
        observedAt: '2026-05-09T12:00:00Z',
        captureSource: 'dom_probe',
      ),
    ];

    final merged = mergeRecentEvents(existing, incoming);

    expect(merged, hasLength(1));
    expect(merged.single.eventId, 'event_msg_1');
  });
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

class _BlockingSaveShellStore extends ShellStore {
  _BlockingSaveShellStore(super.snapshotFile);

  final Completer<void> saveStarted = Completer<void>();
  final Completer<void> releaseSave = Completer<void>();
  var _blocked = false;

  @override
  Future<void> save(ShellSnapshot snapshot) async {
    if (!_blocked && snapshot.pageTitle == 'new') {
      _blocked = true;
      saveStarted.complete();
      await releaseSave.future;
    }
    await super.save(snapshot);
  }
}
