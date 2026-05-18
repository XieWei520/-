import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/xiaoe_monitor/xiaoe_monitor_shell_client.dart';

void main() {
  test(
    'fetchStatus parses Xiaoe shell payload with file attachments',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _RoutingAdapter((options) {
          expect(options.method, 'GET');
          expect(options.uri.toString(), 'http://127.0.0.1:18806/status');
          expect(options.headers['Authorization'], 'Bearer xiaoe-token');
          return _jsonResponse(<String, dynamic>{
            'shell_state': 'online',
            'capture_state': 'running',
            'login_state': 'logged_in',
            'hook_state': 'healthy',
            'runtime_url': 'https://study.xiaoe-tech.com/#/muti_index',
            'page_title': 'XiaoeTech',
            'page_kind': 'circle',
            'webview_available': true,
            'shell_mode': 'desktop_shell',
            'queue_depth': 0,
            'messages_today': 3,
            'deliveries_succeeded_today': 0,
            'deliveries_failed_today': 0,
            'last_updated_at': '2026-05-17T01:00:00Z',
            'probe_observed_at': '2026-05-17T01:00:01Z',
            'observed_conversations': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'circle-alpha',
                'name': 'Alpha Circle',
                'type': 'circle',
                'last_message_preview': 'lesson file',
                'observed_at': '2026-05-17T01:00:02Z',
              },
            ],
            'recent_events': <Map<String, dynamic>>[
              <String, dynamic>{
                'event_id': 'event-1',
                'dedupe_key': 'circle-alpha:message-1',
                'account_id': '',
                'conversation_id': 'circle-alpha',
                'conversation_name': 'Alpha Circle',
                'conversation_type': 'circle',
                'message_id': 'message-1',
                'sender_id': 'u-alice',
                'sender_name': 'Alice',
                'message_type': 'file',
                'text': 'lesson file',
                'sent_at': '',
                'observed_at': '2026-05-17T01:00:03Z',
                'capture_source': 'xiaoe_dom_probe',
                'file_attachments': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'source_url': 'https://cdn.example.com/lesson.pdf',
                    'file_name': 'lesson.pdf',
                    'mime_type': 'application/pdf',
                    'size_bytes': 1024,
                  },
                ],
              },
            ],
            'last_error': '',
          });
        });
      final client = XiaoeMonitorShellClient(
        dio: dio,
        baseUrl: 'http://127.0.0.1:18806',
        token: 'xiaoe-token',
      );

      final status = await client.fetchStatus();

      expect(status.isOnline, isTrue);
      expect(status.isCapturing, isTrue);
      expect(status.runtimeUrl, 'https://study.xiaoe-tech.com/#/muti_index');
      expect(status.observedConversations.single.name, 'Alpha Circle');
      expect(status.recentEvents.single.hasFileAttachments, isTrue);
      expect(
        status.recentEvents.single.fileAttachments.single.fileName,
        'lesson.pdf',
      );
      expect(status.recentEvents.single.isForwardableText, isFalse);
    },
  );

  test(
    'syncConfiguredSources posts Xiaoe route sources without duplicates',
    () async {
      late Map<String, dynamic> body;
      final dio = Dio()
        ..httpClientAdapter = _RoutingAdapter((options) {
          expect(options.method, 'POST');
          expect(
            options.uri.toString(),
            'http://127.0.0.1:18806/routing/sources',
          );
          expect(options.headers['Authorization'], 'Bearer xiaoe-token');
          body = jsonDecode(options.data as String) as Map<String, dynamic>;
          return _jsonResponse(<String, dynamic>{'ok': true});
        });
      final client = XiaoeMonitorShellClient(
        dio: dio,
        baseUrl: 'http://127.0.0.1:18806',
        token: 'xiaoe-token',
      );

      await client.syncConfiguredSources(<XiaoeMonitorRoutingSource>[
        const XiaoeMonitorRoutingSource(
          conversationId: 'circle-alpha',
          conversationName: 'Alpha Circle',
        ),
        const XiaoeMonitorRoutingSource(
          conversationId: 'circle-alpha',
          conversationName: 'Alpha Circle',
        ),
      ]);

      expect(body['sources'], <Map<String, String>>[
        <String, String>{
          'conversation_id': 'circle-alpha',
          'conversation_name': 'Alpha Circle',
        },
      ]);
    },
  );

  test('watchEvents maps local monitor SSE events into Xiaoe events', () async {
    final dio = Dio()
      ..httpClientAdapter = _RoutingAdapter((options) {
        expect(options.method, 'GET');
        expect(options.uri.toString(), 'http://127.0.0.1:18806/events');
        expect(options.headers['Authorization'], 'Bearer xiaoe-token');
        return ResponseBody.fromBytes(
          utf8.encode(
            'event: snapshot_updated\n'
            'data: {"reason":"probe","recent_events":1,'
            '"observed_conversations":1,'
            '"updated_at":"2026-05-17T01:00:00Z"}\n\n',
          ),
          200,
        );
      });
    final client = XiaoeMonitorShellClient(
      dio: dio,
      baseUrl: 'http://127.0.0.1:18806',
      token: 'xiaoe-token',
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
