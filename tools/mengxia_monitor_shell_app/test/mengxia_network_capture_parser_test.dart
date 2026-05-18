import 'package:flutter_test/flutter_test.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_network_capture.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_network_capture_parser.dart';

void main() {
  test('parses Mengxia API response messages into normalized events', () {
    final event = MengxiaNetworkCaptureEvent(
      id: 'net-1',
      observedAt: DateTime.utc(2026, 5, 17, 1),
      source: MengxiaNetworkEventSource.httpResponse,
      url: 'https://mx.2026.naaifu.cn/3/api/group/messages?token=secret',
      method: 'GET',
      statusCode: 200,
      mimeType: 'application/json',
      payloadPreview: '''
{
  "data": {
    "list": [
      {
        "id": "msg-1",
        "group_id": "mx-alpha",
        "group_name": "Alpha",
        "user_id": "u-1",
        "nickname": "Alice",
        "content": "hello from network",
        "created_at": "2026-05-17T01:00:00Z"
      }
    ]
  }
}
''',
    );

    final messages = parseMengxiaNetworkMessageEvents(event);

    expect(messages, hasLength(1));
    expect(messages.single.conversationId, 'mx-alpha');
    expect(messages.single.conversationName, 'Alpha');
    expect(messages.single.messageId, 'msg-1');
    expect(messages.single.senderName, 'Alice');
    expect(messages.single.text, 'hello from network');
    expect(messages.single.captureSource, 'network_api');
    expect(messages.single.dedupeKey, contains('mx-alpha'));
  });

  test('parses websocket frame message payloads', () {
    final event = MengxiaNetworkCaptureEvent(
      id: 'ws-1',
      observedAt: DateTime.utc(2026, 5, 17, 1),
      source: MengxiaNetworkEventSource.webSocketFrame,
      url: 'wss://mx.2026.naaifu.cn/ws',
      method: 'WS_FRAME',
      statusCode: 0,
      mimeType: 'application/json',
      payloadPreview: '''
{
  "type": "message",
  "chat_id": "mx-beta",
  "chat_name": "Beta",
  "msg_id": "msg-2",
  "sender_name": "Bob",
  "message": {"text": "beta realtime"}
}
''',
    );

    final messages = parseMengxiaNetworkMessageEvents(event);

    expect(messages, hasLength(1));
    expect(messages.single.conversationId, 'mx-beta');
    expect(messages.single.text, 'beta realtime');
    expect(messages.single.captureSource, 'network_api');
  });

  test('ignores non-Mengxia and diagnostic-only HTTP request events', () {
    final request = MengxiaNetworkCaptureEvent(
      id: 'req-1',
      observedAt: DateTime.utc(2026, 5, 17, 1),
      source: MengxiaNetworkEventSource.httpRequest,
      url: 'https://mx.2026.naaifu.cn/3/api/group/messages',
      method: 'GET',
      statusCode: 0,
      mimeType: '',
      payloadPreview: '',
    );
    final otherHost = MengxiaNetworkCaptureEvent(
      id: 'other-1',
      observedAt: DateTime.utc(2026, 5, 17, 1),
      source: MengxiaNetworkEventSource.httpResponse,
      url: 'https://example.com/messages',
      method: 'GET',
      statusCode: 200,
      mimeType: 'application/json',
      payloadPreview: '{"content":"ignore"}',
    );

    expect(parseMengxiaNetworkMessageEvents(request), isEmpty);
    expect(parseMengxiaNetworkMessageEvents(otherHost), isEmpty);
  });
}
