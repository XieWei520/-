import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'shell_event_bus.dart';
import 'shell_store.dart';

class ShellServer {
  ShellServer({
    required this.store,
    required this.host,
    required this.port,
    required this.token,
    ShellEventBus? events,
  }) : events = events ?? ShellEventBus(),
       _ownsEvents = events == null;

  final ShellStore store;
  final InternetAddress host;
  final int port;
  final String token;
  final ShellEventBus events;
  final bool _ownsEvents;

  HttpServer? _server;
  final List<StreamSubscription<ShellEvent>> _eventSubscriptions =
      <StreamSubscription<ShellEvent>>[];
  final List<Future<void> Function()> _eventConnectionCleanups =
      <Future<void> Function()>[];

  int get activeEventSubscriptionCount => _eventSubscriptions.length;

  Future<HttpServer> start() async {
    final server = await HttpServer.bind(host, port);
    _server = server;
    server.listen((request) {
      unawaited(_handleRequestSafely(request));
    });
    return server;
  }

  Future<void> close() async {
    for (final cleanup in List<Future<void> Function()>.from(
      _eventConnectionCleanups,
    )) {
      await cleanup();
    }
    _eventSubscriptions.clear();
    _eventConnectionCleanups.clear();
    if (_ownsEvents) {
      await events.close();
    }
    await _server?.close(force: true);
  }

  Future<void> _handleRequestSafely(HttpRequest request) async {
    try {
      await _handleRequest(request);
    } catch (_) {
      try {
        await request.response.close();
      } catch (_) {
        // The client may have disconnected before an error response was sent.
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!_isAuthorized(request)) {
      await _writeJson(
        request.response,
        HttpStatus.unauthorized,
        <String, dynamic>{'error': 'unauthorized'},
      );
      return;
    }

    final path = request.uri.path;
    if (request.method == 'GET' && path == '/status') {
      final snapshot = await store.load();
      await _writeJson(request.response, HttpStatus.ok, snapshot.toJson());
      return;
    }
    if (request.method == 'GET' && path == '/health') {
      final snapshot = await store.load();
      await _writeJson(
        request.response,
        HttpStatus.ok,
        snapshot.toHealthJson(),
      );
      return;
    }
    if (request.method == 'GET' && path == '/conversations') {
      final snapshot = await store.load();
      await _writeJson(
        request.response,
        HttpStatus.ok,
        snapshot.observedConversations
            .map((conversation) => conversation.toJson())
            .toList(growable: false),
      );
      return;
    }
    if (request.method == 'GET' && path == '/messages/recent') {
      final snapshot = await store.load();
      await _writeJson(
        request.response,
        HttpStatus.ok,
        snapshot.observedMessages
            .map((message) => message.toJson())
            .toList(growable: false),
      );
      return;
    }
    if (request.method == 'GET' && path == '/events/recent') {
      final snapshot = await store.load();
      await _writeJson(
        request.response,
        HttpStatus.ok,
        snapshot.recentEvents
            .map((event) => event.toJson())
            .toList(growable: false),
      );
      return;
    }
    if (request.method == 'GET' && path == '/events') {
      await _writeEventStream(request);
      return;
    }
    if (request.method == 'POST' && path == '/capture/start') {
      final next = await store.update(
        (snapshot) => snapshot.copyWith(
          captureState: 'running',
          hookState: 'healthy',
          shellState: 'online',
          lastUpdatedAt: DateTime.now().toUtc(),
        ),
        preserveCaptureState: false,
      );
      events.publish(
        ShellEvent(
          type: ShellEventType.captureStateChanged,
          reason: 'capture_start',
          updatedAt: next.lastUpdatedAt,
          recentEventsCount: next.recentEvents.length,
          observedConversationsCount: next.observedConversations.length,
        ),
      );
      await _writeJson(request.response, HttpStatus.ok, next.toJson());
      return;
    }
    if (request.method == 'POST' && path == '/routing/sources') {
      final sources = await _readConfiguredMediaSources(request);
      final next = await store.update((snapshot) {
        return snapshot.copyWith(
          probeDiagnostics: <String, dynamic>{
            ...snapshot.probeDiagnostics,
            'configured_media_sources': sources,
            'configured_media_source_count': sources.length,
          },
          lastUpdatedAt: DateTime.now().toUtc(),
        );
      });
      await _writeJson(request.response, HttpStatus.ok, <String, dynamic>{
        'configured_media_source_count': sources.length,
        'last_updated_at': next.lastUpdatedAt.toUtc().toIso8601String(),
      });
      return;
    }
    if (request.method == 'POST' && path == '/capture/stop') {
      final next = await store.update(
        (snapshot) => snapshot.copyWith(
          captureState: 'stopped',
          lastUpdatedAt: DateTime.now().toUtc(),
        ),
        preserveCaptureState: false,
      );
      events.publish(
        ShellEvent(
          type: ShellEventType.captureStateChanged,
          reason: 'capture_stop',
          updatedAt: next.lastUpdatedAt,
          recentEventsCount: next.recentEvents.length,
          observedConversationsCount: next.observedConversations.length,
        ),
      );
      await _writeJson(request.response, HttpStatus.ok, next.toJson());
      return;
    }
    if (request.method == 'POST' &&
        (path == '/runtime/reload' ||
            path == '/runtime/hard-reload' ||
            path == '/runtime/session-reset')) {
      final hardReload = path == '/runtime/hard-reload';
      final sessionReset = path == '/runtime/session-reset';
      final next = await store.update(
        (snapshot) => snapshot.copyWith(
          hookState: 'healthy',
          lastUpdatedAt: DateTime.now().toUtc(),
        ),
      );
      events.publish(
        ShellEvent(
          type: ShellEventType.runtimeReloadRequested,
          reason: sessionReset
              ? 'runtime_session_reset'
              : hardReload
              ? 'runtime_hard_reload'
              : 'runtime_reload',
          updatedAt: next.lastUpdatedAt,
          recentEventsCount: next.recentEvents.length,
          observedConversationsCount: next.observedConversations.length,
        ),
      );
      await _writeJson(request.response, HttpStatus.ok, next.toJson());
      return;
    }

    await _writeJson(request.response, HttpStatus.notFound, <String, dynamic>{
      'error': 'not_found',
    });
  }

  bool _isAuthorized(HttpRequest request) {
    final expected = 'Bearer $token';
    final actual = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    return actual.trim() == expected;
  }

  Future<List<Map<String, String>>> _readConfiguredMediaSources(
    HttpRequest request,
  ) async {
    final raw = await utf8.decodeStream(request);
    if (raw.trim().isEmpty) {
      return const <Map<String, String>>[];
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const <Map<String, String>>[];
    }
    if (decoded is! Map) {
      return const <Map<String, String>>[];
    }
    final sources = decoded['sources'];
    if (sources is! List) {
      return const <Map<String, String>>[];
    }
    final normalized = <Map<String, String>>[];
    final seen = <String>{};
    for (final source in sources) {
      if (source is! Map) {
        continue;
      }
      final conversationId = (source['conversation_id'] ?? '')
          .toString()
          .trim();
      final conversationName = (source['conversation_name'] ?? '')
          .toString()
          .trim();
      if (conversationId.isEmpty && conversationName.isEmpty) {
        continue;
      }
      final key = '$conversationId\n$conversationName';
      if (!seen.add(key)) {
        continue;
      }
      normalized.add(<String, String>{
        'conversation_id': conversationId,
        'conversation_name': conversationName,
      });
    }
    return List<Map<String, String>>.unmodifiable(normalized);
  }

  Future<void> _writeEventStream(HttpRequest request) async {
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.bufferOutput = false;
    response.headers
      ..contentType = ContentType('text', 'event-stream', charset: 'utf-8')
      ..set(HttpHeaders.cacheControlHeader, 'no-cache')
      ..set(HttpHeaders.connectionHeader, 'keep-alive');

    late final StreamSubscription<ShellEvent> subscription;
    StreamSubscription<List<int>>? socketSubscription;
    Socket? socket;
    var cleanedUp = false;

    late final Future<void> Function() cleanup;
    cleanup = () async {
      if (cleanedUp) {
        return;
      }
      cleanedUp = true;
      _eventSubscriptions.remove(subscription);
      _eventConnectionCleanups.remove(cleanup);
      await subscription.cancel();
      await socketSubscription?.cancel();
      try {
        final activeSocket = socket;
        if (activeSocket != null) {
          await activeSocket.close();
        } else {
          await response.close();
        }
      } catch (_) {
        // Client disconnects are expected for long-lived SSE streams.
      }
    };

    subscription = events.stream.listen(
      (event) {
        unawaited(_writeSseEvent(socket, event, () => cleanedUp, cleanup));
      },
      onDone: () {
        unawaited(cleanup());
      },
      onError: (_) {
        unawaited(cleanup());
      },
    );
    _eventSubscriptions.add(subscription);
    _eventConnectionCleanups.add(cleanup);

    try {
      socket = await response.detachSocket(writeHeaders: true);
    } catch (_) {
      await cleanup();
      return;
    }
    final detachedSocket = socket;
    socketSubscription = detachedSocket.listen(
      (_) {},
      onDone: cleanup,
      onError: (_) => unawaited(cleanup()),
      cancelOnError: true,
    );
    unawaited(
      detachedSocket.done.catchError((Object _) {}).whenComplete(cleanup),
    );
    await _writeSseChunk(
      detachedSocket,
      ': connected\n\n',
      () => cleanedUp,
      cleanup,
    );
  }

  Future<void> _writeSseEvent(
    Socket? socket,
    ShellEvent event,
    bool Function() isCleanedUp,
    Future<void> Function() cleanup,
  ) {
    return _writeSseChunk(
      socket,
      'event: ${event.type.wireName}\n'
      'data: ${jsonEncode(event.toJson())}\n\n',
      isCleanedUp,
      cleanup,
    );
  }

  Future<void> _writeSseChunk(
    Socket? socket,
    String chunk,
    bool Function() isCleanedUp,
    Future<void> Function() cleanup,
  ) async {
    final activeSocket = socket;
    if (isCleanedUp() || activeSocket == null) {
      return;
    }
    try {
      final data = utf8.encode(chunk);
      activeSocket.add(utf8.encode('${data.length.toRadixString(16)}\r\n'));
      activeSocket.add(data);
      activeSocket.add(utf8.encode('\r\n'));
      await activeSocket.flush();
    } catch (_) {
      // The client may disconnect between the cleanup check and the write.
      await cleanup();
    }
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Object? body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}
