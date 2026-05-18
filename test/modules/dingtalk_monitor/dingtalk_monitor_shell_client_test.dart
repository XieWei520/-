import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_shell_client.dart';

void main() {
  test('fetchStatus uses DingTalk host token header', () async {
    final dio = Dio()
      ..httpClientAdapter = _RoutingAdapter((options) {
        expect(options.method, 'GET');
        expect(options.uri.toString(), 'http://127.0.0.1:17651/status');
        expect(options.headers['X-DingTalk-Host-Token'], 'local-dev-token');
        return _jsonResponse(<String, dynamic>{
          'captureRunning': true,
          'shellState': 'Attached',
          'conversationReadiness': 'Ready',
        });
      });
    final client = DingTalkMonitorShellClient(dio: dio);

    final status = await client.fetchStatus();

    expect(status.isOnline, isTrue);
    expect(status.isCapturing, isTrue);
  });

  test('fetchForwardableRecentEvents parses native event list', () async {
    final dio = Dio()
      ..httpClientAdapter = _RoutingAdapter((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/events/forwardable-recent');
        expect(options.uri.queryParameters['limit'], '25');
        expect(options.headers['X-DingTalk-Host-Token'], 'host-token');
        return _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'eventId': 'event-1',
            'sourceConversationId': 'source:alpha',
            'sourceConversationName': 'Alpha',
            'embeddedSourceName': '',
            'senderName': 'Alice',
            'observedAt': '2026-05-16T01:33:16Z',
            'text': 'hello from DingTalk',
            'localImagePath': '',
            'captureSource': 'UiaText',
            'contentHash': 'hash-1',
          },
        ]);
      });
    final client = DingTalkMonitorShellClient(dio: dio, token: 'host-token');

    final events = await client.fetchForwardableRecentEvents(limit: 25);

    expect(events, hasLength(1));
    expect(events.single.eventId, 'event-1');
    expect(events.single.text, 'hello from DingTalk');
  });

  test('control endpoints map to native host paths', () async {
    final paths = <String>[];
    final dio = Dio()
      ..httpClientAdapter = _RoutingAdapter((options) {
        paths.add(options.uri.path);
        expect(options.method, 'POST');
        expect(options.headers['X-DingTalk-Host-Token'], 'local-dev-token');
        return _jsonResponse(<String, dynamic>{'ok': true});
      });
    final client = DingTalkMonitorShellClient(dio: dio);

    await client.startCapture();
    await client.stopCapture();
    await client.reloadRuntime();
    await client.probeLatest();

    expect(paths, <String>[
      '/control/start',
      '/control/stop',
      '/control/reload',
      '/control/probe-latest',
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

ResponseBody _jsonListResponse(List<Map<String, dynamic>> json) {
  return ResponseBody.fromString(
    jsonEncode(json),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
