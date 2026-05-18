import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/juliang_monitor/juliang_monitor_shell_client.dart';

void main() {
  test('fetchStatus parses neutral shell payload as Juliang status', () async {
    final dio = Dio()
      ..httpClientAdapter = _RoutingAdapter((options) {
        expect(options.method, 'GET');
        expect(options.uri.toString(), 'http://127.0.0.1:18796/status');
        expect(options.headers['Authorization'], 'Bearer juliang-token');
        return _jsonResponse(<String, dynamic>{
          'shell_state': 'online',
          'capture_state': 'running',
          'login_state': 'logged_in',
          'hook_state': 'healthy',
          'runtime_url': 'https://msg.juliang888.top/',
          'page_title': '快飞面板',
          'page_kind': 'workspace',
          'webview_available': true,
          'shell_mode': 'desktop_shell',
          'queue_depth': 1,
          'messages_today': 2,
          'deliveries_succeeded_today': 0,
          'deliveries_failed_today': 0,
          'last_updated_at': '2026-05-17T01:00:00Z',
          'probe_observed_at': '2026-05-17T01:00:01Z',
          'observed_conversations': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'jl-alpha',
              'name': 'Alpha',
              'type': 'group',
              'last_message_preview': 'hello',
              'observed_at': '2026-05-17T01:00:02Z',
            },
          ],
          'recent_events': <Map<String, dynamic>>[
            <String, dynamic>{
              'event_id': 'event-1',
              'dedupe_key': 'jl-alpha:message-1',
              'account_id': '',
              'conversation_id': 'jl-alpha',
              'conversation_name': 'Alpha',
              'conversation_type': 'group',
              'message_id': 'message-1',
              'sender_id': 'u-alice',
              'sender_name': 'Alice',
              'message_type': 'text',
              'text': 'hello from Juliang',
              'sent_at': '',
              'observed_at': '2026-05-17T01:00:03Z',
              'capture_source': 'network_api',
            },
          ],
          'last_error': '',
        });
      });
    final client = JuliangMonitorShellClient(
      dio: dio,
      baseUrl: 'http://127.0.0.1:18796',
      token: 'juliang-token',
    );

    final status = await client.fetchStatus();

    expect(status.isOnline, isTrue);
    expect(status.isCapturing, isTrue);
    expect(status.loginState, 'logged_in');
    expect(status.runtimeUrl, 'https://msg.juliang888.top/');
    expect(status.pageTitle, '快飞面板');
    expect(status.observedConversations.single.id, 'jl-alpha');
    expect(status.observedConversations.single.name, 'Alpha');
    expect(status.recentEvents.single.text, 'hello from Juliang');
    expect(status.recentEvents.single.isForwardableText, isTrue);
  });

  test('syncConfiguredSources posts enabled Juliang route sources', () async {
    late Map<String, dynamic> body;
    final dio = Dio()
      ..httpClientAdapter = _RoutingAdapter((options) {
        expect(options.method, 'POST');
        expect(options.uri.toString(), 'http://127.0.0.1:18796/routing/sources');
        expect(options.headers['Authorization'], 'Bearer juliang-token');
        body = jsonDecode(options.data as String) as Map<String, dynamic>;
        return _jsonResponse(<String, dynamic>{'ok': true});
      });
    final client = JuliangMonitorShellClient(
      dio: dio,
      baseUrl: 'http://127.0.0.1:18796',
      token: 'juliang-token',
    );

    await client.syncConfiguredSources(<JuliangMonitorRoutingSource>[
      const JuliangMonitorRoutingSource(
        conversationId: 'jl-alpha',
        conversationName: 'Alpha',
      ),
      const JuliangMonitorRoutingSource(
        conversationId: 'jl-alpha',
        conversationName: 'Alpha',
      ),
    ]);

    expect(body['sources'], <Map<String, String>>[
      <String, String>{
        'conversation_id': 'jl-alpha',
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
