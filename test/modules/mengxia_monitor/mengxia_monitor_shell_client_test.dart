import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_shell_client.dart';

void main() {
  test('fetchStatus parses neutral shell payload as Mengxia status', () async {
    final dio = Dio()
      ..httpClientAdapter = _RoutingAdapter((options) {
        expect(options.method, 'GET');
        expect(options.uri.toString(), 'http://127.0.0.1:18786/status');
        expect(options.headers['Authorization'], 'Bearer mengxia-token');
        return _jsonResponse(<String, dynamic>{
          'shell_state': 'online',
          'capture_state': 'running',
          'login_state': 'logged_in',
          'hook_state': 'healthy',
          'runtime_url': 'https://mx.2026.naaifu.cn/#/pages/chat/index',
          'page_title': '萌侠',
          'page_kind': 'workspace',
          'webview_available': true,
          'shell_mode': 'desktop_shell',
          'queue_depth': 1,
          'messages_today': 2,
          'deliveries_succeeded_today': 0,
          'deliveries_failed_today': 0,
          'last_updated_at': '2026-05-16T01:00:00Z',
          'probe_observed_at': '2026-05-16T01:00:01Z',
          'observed_conversations': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'mx-alpha',
              'name': 'Alpha',
              'type': 'group',
              'last_message_preview': 'hello',
              'observed_at': '2026-05-16T01:00:02Z',
            },
          ],
          'recent_events': <Map<String, dynamic>>[
            <String, dynamic>{
              'event_id': 'event-1',
              'dedupe_key': 'mx-alpha:message-1',
              'account_id': '',
              'conversation_id': 'mx-alpha',
              'conversation_name': 'Alpha',
              'conversation_type': 'group',
              'message_id': 'message-1',
              'sender_id': 'u-alice',
              'sender_name': 'Alice',
              'message_type': 'text',
              'text': 'hello from Mengxia',
              'sent_at': '',
              'observed_at': '2026-05-16T01:00:03Z',
              'capture_source': 'network_api',
            },
          ],
          'last_error': '',
        });
      });
    final client = MengxiaMonitorShellClient(
      dio: dio,
      baseUrl: 'http://127.0.0.1:18786',
      token: 'mengxia-token',
    );

    final status = await client.fetchStatus();

    expect(status.isOnline, isTrue);
    expect(status.isCapturing, isTrue);
    expect(status.loginState, 'logged_in');
    expect(status.observedConversations.single.id, 'mx-alpha');
    expect(status.recentEvents.single.text, 'hello from Mengxia');
  });

  test('syncConfiguredSources posts enabled Mengxia route sources', () async {
    late Map<String, dynamic> body;
    final dio = Dio()
      ..httpClientAdapter = _RoutingAdapter((options) {
        expect(options.method, 'POST');
        expect(options.uri.path, '/routing/sources');
        body = jsonDecode(options.data as String) as Map<String, dynamic>;
        return _jsonResponse(<String, dynamic>{'ok': true});
      });
    final client = MengxiaMonitorShellClient(
      dio: dio,
      baseUrl: 'http://127.0.0.1:18786',
      token: 'mengxia-token',
    );

    await client.syncConfiguredSources(<MengxiaMonitorRoutingSource>[
      const MengxiaMonitorRoutingSource(
        conversationId: 'mx-alpha',
        conversationName: 'Alpha',
      ),
    ]);

    expect(body['sources'], <Map<String, String>>[
      <String, String>{
        'conversation_id': 'mx-alpha',
        'conversation_name': 'Alpha',
      },
    ]);
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
