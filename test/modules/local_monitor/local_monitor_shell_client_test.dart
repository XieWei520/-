import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_client.dart';

void main() {
  test('fetchStatus parses shared shell payload fields', () async {
    final dio = Dio()
      ..httpClientAdapter = _RoutingAdapter((options) {
        expect(options.method, 'GET');
        expect(options.uri.toString(), 'http://127.0.0.1:18866/status');
        expect(options.headers['Authorization'], 'Bearer shell-token');
        return _jsonResponse(<String, dynamic>{
          'shell_state': 'online',
          'capture_state': 'running',
          'login_state': 'logged_in',
          'hook_state': 'healthy',
          'runtime_url': 'https://example.test/app',
          'page_title': 'Monitor',
          'page_kind': 'messenger',
          'webview_available': true,
          'shell_mode': 'desktop_shell',
          'queue_depth': 3,
          'messages_today': 12,
          'deliveries_succeeded_today': 10,
          'deliveries_failed_today': 2,
          'last_updated_at': '2026-05-13T01:00:00Z',
          'probe_observed_at': '2026-05-13T01:00:01Z',
          'probe_diagnostics': <String, dynamic>{'worker_id': 'worker-2'},
          'observed_conversations': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'cid-alpha',
              'name': 'Alpha',
              'type': 'group',
              'last_message_preview': 'hello',
              'observed_at': '2026-05-13T01:00:02Z',
            },
          ],
          'observed_messages': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'msg-1',
              'conversation_id': 'cid-alpha',
              'conversation_name': 'Alpha',
              'sender_name': 'Alice',
              'message_type': 'text',
              'text': 'hello',
              'observed_at': '2026-05-13T01:00:03Z',
              'capture_source': 'dom_probe',
              'image_attachments': <Map<String, dynamic>>[
                <String, dynamic>{
                  'source_url': 'https://cdn.example.test/image.png',
                  'local_path': '',
                  'width': 640,
                  'height': 480,
                },
              ],
            },
          ],
          'recent_events': <Map<String, dynamic>>[
            <String, dynamic>{
              'event_id': 'event-1',
              'dedupe_key': 'cid-alpha:msg-1',
              'account_id': '',
              'conversation_id': 'cid-alpha',
              'conversation_name': 'Alpha',
              'conversation_type': 'group',
              'message_id': 'msg-1',
              'sender_id': 'uid-alice',
              'sender_name': 'Alice',
              'message_type': 'text',
              'text': 'hello',
              'sent_at': '',
              'observed_at': '2026-05-13T01:00:04Z',
              'capture_source': 'dom_probe',
            },
          ],
          'last_error': '',
        });
      });
    final client = LocalMonitorShellClient(
      dio: dio,
      baseUrl: 'http://127.0.0.1:18866',
      token: 'shell-token',
    );

    final status = await client.fetchStatus();

    expect(status.isOnline, isTrue);
    expect(status.isCapturing, isTrue);
    expect(status.workerId, 'worker-2');
    expect(status.observedConversations.single.id, 'cid-alpha');
    expect(status.observedMessages.single.imageAttachments.single.width, 640);
    expect(status.recentEvents.single.dedupeKey, 'cid-alpha:msg-1');
  });

  test('fetchHealth parses health payload', () async {
    final dio = Dio()
      ..httpClientAdapter = _RoutingAdapter((options) {
        expect(options.uri.path, '/health');
        return _jsonResponse(<String, dynamic>{
          'status': 'ok',
          'needs_login': false,
          'hook_healthy': true,
          'capture_running': true,
          'queue_depth': 4,
        });
      });
    final client = LocalMonitorShellClient(
      dio: dio,
      baseUrl: 'http://127.0.0.1:18866',
      token: 'shell-token',
    );

    final health = await client.fetchHealth();

    expect(health.status, 'ok');
    expect(health.needsLogin, isFalse);
    expect(health.hookHealthy, isTrue);
    expect(health.captureRunning, isTrue);
    expect(health.queueDepth, 4);
  });

  test(
    'syncConfiguredSources posts unique non-empty routing sources',
    () async {
      late Map<String, dynamic> body;
      final dio = Dio()
        ..httpClientAdapter = _RoutingAdapter((options) {
          expect(options.method, 'POST');
          expect(options.uri.path, '/routing/sources');
          body = jsonDecode(options.data as String) as Map<String, dynamic>;
          return _jsonResponse(<String, dynamic>{'ok': true});
        });
      final client = LocalMonitorShellClient(
        dio: dio,
        baseUrl: 'http://127.0.0.1:18866',
        token: 'shell-token',
      );

      await client.syncConfiguredSources(<LocalMonitorRoutingSource>[
        const LocalMonitorRoutingSource(
          conversationId: 'cid-alpha',
          conversationName: 'Alpha',
        ),
        const LocalMonitorRoutingSource(
          conversationId: 'cid-alpha',
          conversationName: 'Alpha',
        ),
        const LocalMonitorRoutingSource(
          conversationId: '',
          conversationName: '',
        ),
      ]);

      expect(body['sources'], <Map<String, String>>[
        <String, String>{
          'conversation_id': 'cid-alpha',
          'conversation_name': 'Alpha',
        },
      ]);
    },
  );

  test('watchEvents parses SSE frames and skips malformed frames', () async {
    final dio = Dio()
      ..httpClientAdapter = _RoutingAdapter((options) {
        expect(options.responseType, ResponseType.stream);
        return ResponseBody(
          Stream<Uint8List>.fromIterable(<Uint8List>[
            Uint8List.fromList(utf8.encode(': connected\n\n')),
            Uint8List.fromList(utf8.encode('event: snapshot_updated\n')),
            Uint8List.fromList(
              utf8.encode(
                'data: {"reason":"probe","updated_at":"2026-05-13T01:00:00Z","recent_events":1}\n\n',
              ),
            ),
            Uint8List.fromList(utf8.encode('event: malformed\n')),
            Uint8List.fromList(utf8.encode('data: []\n\n')),
          ]),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['text/event-stream'],
          },
        );
      });
    final client = LocalMonitorShellClient(
      dio: dio,
      baseUrl: 'http://127.0.0.1:18866',
      token: 'shell-token',
    );

    final events = await client.watchEvents().toList();

    expect(events, hasLength(1));
    expect(events.single.isSnapshotUpdated, isTrue);
    expect(events.single.reason, 'probe');
    expect(events.single.recentEvents, 1);
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
