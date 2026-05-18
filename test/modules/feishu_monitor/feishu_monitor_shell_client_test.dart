import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_shell_client.dart';

void main() {
  test(
    'recommended client group targets six local shell workers for 120 routes',
    () async {
      final requestedUris = <Uri>[];
      final adapter = _RoutingAdapter((options) {
        requestedUris.add(options.uri);
        final workerNumber = options.uri.port - 18765;
        return _jsonResponse(<String, dynamic>{
          'shell_state': 'online',
          'capture_state': 'running',
          'worker_id': 'worker-$workerNumber',
        });
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final group = FeishuMonitorShellClientGroup.recommendedForRouteCount(
        120,
        dio: dio,
        token: 'local-shell-token',
      );

      final statuses = await group.fetchStatuses();

      expect(group.clients.map((client) => client.workerId), <String>[
        'worker-1',
        'worker-2',
        'worker-3',
        'worker-4',
        'worker-5',
        'worker-6',
      ]);
      expect(requestedUris.map((uri) => uri.port), <int>[
        18766,
        18767,
        18768,
        18769,
        18770,
        18771,
      ]);
      expect(statuses.map((status) => status.workerId), <String>[
        'worker-1',
        'worker-2',
        'worker-3',
        'worker-4',
        'worker-5',
        'worker-6',
      ]);
    },
  );

  test('fetchStatuses can be scoped to workers with assigned routes', () async {
    final requestedPorts = <int>[];
    final adapter = _RoutingAdapter((options) {
      requestedPorts.add(options.uri.port);
      final workerNumber = options.uri.port - 18765;
      return _jsonResponse(<String, dynamic>{
        'shell_state': 'online',
        'capture_state': 'running',
        'worker_id': 'worker-$workerNumber',
      });
    });
    final dio = Dio()..httpClientAdapter = adapter;
    final group = FeishuMonitorShellClientGroup.recommendedForRouteCount(
      120,
      dio: dio,
      token: 'local-shell-token',
    );

    final statuses = await group.fetchStatuses(
      workerIds: const <String>{'worker-1'},
    );

    expect(requestedPorts, <int>[18766]);
    expect(statuses.map((status) => status.workerId), <String>['worker-1']);
  });

  test('syncConfiguredMediaSources only contacts assigned workers', () async {
    final requestedPorts = <int>[];
    final adapter = _RoutingAdapter((options) {
      requestedPorts.add(options.uri.port);
      expect(options.method, 'POST');
      expect(options.uri.path, '/routing/sources');
      return _jsonResponse(<String, dynamic>{'ok': true});
    });
    final dio = Dio()..httpClientAdapter = adapter;
    final group = FeishuMonitorShellClientGroup.recommendedForRouteCount(
      120,
      dio: dio,
      token: 'local-shell-token',
    );

    await group.syncConfiguredMediaSources(<FeishuMonitorForwardingRoute>[
      _route(
        sourceConversationId: 'feed:a',
        targetGroupId: 'wk_a',
        workerId: 'worker-1',
      ),
    ]);

    expect(requestedPorts, <int>[18766]);
  });

  test('fetchStatus parses shell snapshot', () async {
    final adapter = _RoutingAdapter((options) {
      expect(options.headers['Authorization'], 'Bearer local-shell-token');
      expect(options.uri.path, '/status');
      return _jsonResponse(<String, dynamic>{
        'shell_state': 'online',
        'capture_state': 'running',
        'login_state': 'logged_in',
        'hook_state': 'healthy',
        'runtime_url': 'https://feishu.cn/messenger',
        'page_title': '椋炰功',
        'page_kind': 'chat',
        'webview_available': true,
        'shell_mode': 'desktop_shell',
        'queue_depth': 3,
        'messages_today': 12,
        'deliveries_succeeded_today': 10,
        'deliveries_failed_today': 2,
        'last_updated_at': '2026-05-09T10:00:00Z',
        'probe_observed_at': '2026-05-09T10:01:00Z',
        'observed_conversations': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'oc_1',
            'name': 'Alpha',
            'type': 'group',
            'last_message_preview': 'hello',
            'observed_at': '2026-05-09T10:01:02Z',
          },
          <String, dynamic>{
            'id': 'oc_2',
            'name': 'Bravo',
            'type': 'user',
            'last_message_preview': '',
            'observed_at': '',
          },
        ],
        'observed_messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'msg_1',
            'conversation_id': 'oc_1',
            'conversation_name': 'Alpha',
            'sender_name': 'Alice',
            'message_type': 'text',
            'text': 'hello from Feishu',
            'observed_at': '2026-05-09T10:01:03Z',
            'capture_source': 'dom_probe',
          },
        ],
        'recent_events': <Map<String, dynamic>>[
          <String, dynamic>{
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
            'observed_at': '2026-05-09T10:02:00Z',
            'capture_source': 'dom_probe',
          },
        ],
        'last_error': '',
      });
    });
    final dio = Dio()..httpClientAdapter = adapter;
    final client = FeishuMonitorShellClient(
      dio: dio,
      baseUrl: 'http://127.0.0.1:18766',
      token: 'local-shell-token',
    );

    final status = await client.fetchStatus();

    expect(status.isOnline, isTrue);
    expect(status.isCapturing, isTrue);
    expect(status.runtimeUrl, 'https://feishu.cn/messenger');
    expect(status.pageTitle, '椋炰功');
    expect(status.pageKind, 'chat');
    expect(status.webviewAvailable, isTrue);
    expect(status.shellMode, 'desktop_shell');
    expect(status.queueDepth, 3);
    expect(status.messagesToday, 12);
    expect(status.probeObservedAt, DateTime.parse('2026-05-09T10:01:00Z'));
    expect(status.observedConversations, hasLength(2));
    expect(status.observedConversations.first.id, 'oc_1');
    expect(status.observedConversations.first.name, 'Alpha');
    expect(status.observedConversations.first.type, 'group');
    expect(status.observedConversations.first.lastMessagePreview, 'hello');
    expect(
      status.observedConversations.first.observedAt,
      DateTime.parse('2026-05-09T10:01:02Z'),
    );
    expect(status.observedConversations.last.id, 'oc_2');
    expect(status.observedConversations.last.observedAt, isNull);
    expect(status.observedMessages.first.text, 'hello from Feishu');
    expect(status.recentEvents.first.dedupeKey, 'chat_1:msg_1');
  });

  test('fetchStatus tolerates missing probe fields', () async {
    final adapter = _RoutingAdapter((options) {
      expect(options.uri.path, '/status');
      return _jsonResponse(<String, dynamic>{
        'shell_state': 'offline',
        'capture_state': 'stopped',
        'probe_observed_at': '',
      });
    });
    final dio = Dio()..httpClientAdapter = adapter;
    final client = FeishuMonitorShellClient(dio: dio);

    final status = await client.fetchStatus();

    expect(status.pageKind, '');
    expect(status.probeObservedAt, isNull);
    expect(status.observedConversations, isEmpty);
    expect(status.observedMessages, isEmpty);
    expect(status.recentEvents, isEmpty);
  });

  test('fetchStatus tolerates invalid observed messages payload', () async {
    final adapter = _RoutingAdapter((options) {
      expect(options.uri.path, '/status');
      return _jsonResponse(<String, dynamic>{
        'shell_state': 'offline',
        'capture_state': 'stopped',
        'observed_messages': 'not-a-list',
        'recent_events': 'not-a-list',
      });
    });
    final dio = Dio()..httpClientAdapter = adapter;
    final client = FeishuMonitorShellClient(dio: dio);

    final status = await client.fetchStatus();

    expect(status.observedMessages, isEmpty);
    expect(status.recentEvents, isEmpty);
  });

  test('startCapture posts to local shell action endpoint', () async {
    final adapter = _RoutingAdapter((options) {
      expect(options.method, 'POST');
      expect(options.uri.path, '/capture/start');
      return _jsonResponse(<String, dynamic>{'ok': true});
    });
    final dio = Dio()..httpClientAdapter = adapter;
    final client = FeishuMonitorShellClient(dio: dio);

    await client.startCapture();
  });

  test('watchEvents streams parsed shell events from SSE frames', () async {
    final adapter = _RoutingAdapter((options) {
      expect(options.method, 'GET');
      expect(options.uri.path, '/events');
      expect(options.headers['Authorization'], 'Bearer local-shell-token');
      expect(options.responseType, ResponseType.stream);
      return _sseResponse('''
: connected

event: snapshot_updated
data: {"reason":"poll","updated_at":"2026-05-09T10:02:00Z","recent_events":2,"observed_conversations":3}

event: malformed
data: []

event: shell_error
data: {"error":"capture failed"}

''');
    });
    final dio = Dio()..httpClientAdapter = adapter;
    final client = FeishuMonitorShellClient(
      dio: dio,
      baseUrl: 'http://127.0.0.1:18766',
      token: 'local-shell-token',
    );

    final events = await client.watchEvents().toList();

    expect(events, hasLength(2));
    expect(events.first.type, 'snapshot_updated');
    expect(events.first.isSnapshotUpdated, isTrue);
    expect(events.first.reason, 'poll');
    expect(events.first.updatedAt, DateTime.parse('2026-05-09T10:02:00Z'));
    expect(events.first.recentEvents, 2);
    expect(events.first.observedConversations, 3);
    expect(events.last.type, 'shell_error');
    expect(events.last.isShellError, isTrue);
    expect(events.last.error, 'capture failed');
  });
}

class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this._handler);

  final ResponseBody Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }
}

ResponseBody _jsonResponse(Map<String, dynamic> json) {
  return ResponseBody.fromString(
    jsonEncode(json),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

ResponseBody _sseResponse(String raw) {
  return ResponseBody.fromString(
    raw,
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['text/event-stream'],
    },
  );
}

FeishuMonitorForwardingRoute _route({
  required String sourceConversationId,
  required String targetGroupId,
  required String workerId,
}) {
  return FeishuMonitorForwardingRoute(
    id: 'route_$sourceConversationId',
    enabled: true,
    sourceConversationId: sourceConversationId,
    sourceConversationName: 'Alpha',
    sourceConversationType: 'unknown',
    targetGroupId: targetGroupId,
    targetGroupName: 'Target',
    workerId: workerId,
    createdAt: DateTime.parse('2026-05-09T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-09T01:00:00Z'),
  );
}
