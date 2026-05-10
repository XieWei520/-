import 'dart:convert';

import 'package:feishu_monitor_shell_app/src/feishu_network_capture.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('network event redacts sensitive query values', () {
    final event = FeishuNetworkCaptureEvent(
      id: 'event-1',
      observedAt: DateTime.utc(2026, 5, 10, 4, 30),
      source: FeishuNetworkEventSource.httpResponse,
      url: 'https://[?token=secret&file_key=image_1',
      method: 'GET',
      statusCode: 200,
      mimeType: 'application/json',
      payloadPreview: '{"token":"secret","file_key":"image_1"}',
      bodyLocalPath: r'C:\Temp\wukong_feishu_monitor_images\abc.webp',
      bodySha1: 'abc123',
      bodySize: 12345,
      bodyMimeType: 'image/webp',
      bodyBase64Encoded: true,
      bodySaved: true,
      bodySaveError: '',
    );

    final json = event.toRedactedJson();

    expect(json, containsPair('id', 'event-1'));
    expect(json, containsPair('observed_at', '2026-05-10T04:30:00.000Z'));
    expect(json['url'], 'https://[?token=<redacted>&file_key=<redacted>');
    expect(json['url'].toString(), isNot(contains('secret')));
    expect(json['url'].toString(), isNot(contains('image_1')));
    expect(json['payload_preview'].toString(), contains('<redacted>'));
    expect(json['payload_preview'].toString(), isNot(contains('secret')));
    expect(json['payload_preview'].toString(), isNot(contains('image_1')));
    expect(json, containsPair('body_local_path', '<local-cache-file>'));
    expect(json, containsPair('body_sha1', 'abc123'));
    expect(json, containsPair('body_size', 12345));
    expect(json, containsPair('body_mime_type', 'image/webp'));
    expect(json, containsPair('body_base64_encoded', isTrue));
    expect(json, containsPair('body_saved', isTrue));
    expect(json, containsPair('body_save_error', ''));
  });

  test('image candidate summary preserves quality label', () {
    const groupName = '\u6ee1\u6ee1\u6b63\u80fd\u91cf';
    final candidate = FeishuNetworkImageCandidate(
      conversationId: 'conversation-1',
      conversationName: groupName,
      messageId: 'message-1',
      senderName: 'sender',
      resourceUrl:
          'https://internal-api.feishu.cn/messenger/resource?token=secret&file_key=image_1',
      resourceKey: 'image_1',
      width: 640,
      height: 480,
      quality: FeishuNetworkImageQuality.preview,
      observedAt: DateTime.utc(2026, 5, 10, 4, 31),
    );

    final json = candidate.toStatusJson();

    expect(json['quality'], 'preview');
    expect(json['conversation_name'], groupName);
  });

  test('parser extracts image candidate from json payload', () {
    const groupName = '\u6ee1\u6ee1\u6b63\u80fd\u91cf';
    const senderName = '\u6a58\u751f\u6dee\u5357';
    final event = FeishuNetworkCaptureEvent(
      id: 'evt_json',
      observedAt: DateTime.utc(2026, 5, 10, 6, 1),
      source: FeishuNetworkEventSource.httpResponse,
      url: 'https://internal-api.feishu.cn/messenger/messages',
      method: 'POST',
      statusCode: 200,
      mimeType: 'application/json',
      payloadPreview:
          '''
        {
          "conversation_id": "feed:2e500f14",
          "conversation_name": "$groupName",
          "message_id": "7638112798311976160",
          "sender_name": "$senderName",
          "image_key": "img_v3_abc",
          "image_url": "https://internal-api.feishu.cn/image/preview?token=secret",
          "width": 231,
          "height": 500
        }
      ''',
    );

    final candidates = parseFeishuNetworkImageCandidates(event);

    expect(candidates, hasLength(1));
    expect(candidates.single.conversationName, groupName);
    expect(candidates.single.messageId, '7638112798311976160');
    expect(candidates.single.quality, FeishuNetworkImageQuality.preview);
  });

  test('parser ignores payload without image resource fields', () {
    const groupName = '\u6ee1\u6ee1\u6b63\u80fd\u91cf';
    final event = FeishuNetworkCaptureEvent(
      id: 'evt_text',
      observedAt: DateTime.utc(2026, 5, 10, 6, 2),
      source: FeishuNetworkEventSource.webSocketFrame,
      url: 'wss://internal-api.feishu.cn/push',
      method: 'WS',
      statusCode: 0,
      mimeType: 'application/octet-stream',
      payloadPreview: '{"conversation_name":"$groupName","text":"hello"}',
    );

    expect(parseFeishuNetworkImageCandidates(event), isEmpty);
  });

  test('parser records direct image http responses as candidates', () {
    final event = FeishuNetworkCaptureEvent(
      id: 'evt_image_response',
      observedAt: DateTime.utc(2026, 5, 10, 6, 2),
      source: FeishuNetworkEventSource.httpResponse,
      url:
          'https://internal-api.feishu.cn/messenger/image/abc.webp?token=secret',
      method: 'GET',
      statusCode: 200,
      mimeType: 'image/webp',
      payloadPreview: '',
    );

    final candidates = parseFeishuNetworkImageCandidates(event);

    expect(candidates, hasLength(1));
    expect(candidates.single.resourceUrl, event.url);
    expect(candidates.single.messageId, event.id);
    expect(candidates.single.quality, FeishuNetworkImageQuality.unknown);
  });

  test('parser ignores direct frontend static image responses', () {
    final event = FeishuNetworkCaptureEvent(
      id: 'evt_static_image',
      observedAt: DateTime.utc(2026, 5, 10, 6, 2),
      source: FeishuNetworkEventSource.httpResponse,
      url:
          'https://sf1-scmcdn-cn.feishucdn.com/obj/feishu-static/ee/web-client-next/assets/img/logo.png',
      method: 'GET',
      statusCode: 200,
      mimeType: 'image/png',
      payloadPreview: '',
    );

    expect(parseFeishuNetworkImageCandidates(event), isEmpty);
  });

  test('parser ignores default avatar and inline data image responses', () {
    final avatar = FeishuNetworkCaptureEvent(
      id: 'evt_avatar',
      observedAt: DateTime.utc(2026, 5, 10, 6, 2),
      source: FeishuNetworkEventSource.httpResponse,
      url:
          'https://s1-imfile.feishucdn.com/static-resource/v1/default-avatar_abc~',
      method: 'GET',
      statusCode: 200,
      mimeType: 'image/webp',
      payloadPreview: '',
    );
    final inline = FeishuNetworkCaptureEvent(
      id: 'evt_inline',
      observedAt: DateTime.utc(2026, 5, 10, 6, 2),
      source: FeishuNetworkEventSource.httpResponse,
      url: 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///w==',
      method: 'GET',
      statusCode: 200,
      mimeType: 'image/gif',
      payloadPreview: '',
    );

    expect(parseFeishuNetworkImageCandidates(avatar), isEmpty);
    expect(parseFeishuNetworkImageCandidates(inline), isEmpty);
  });

  test('parser ignores generic url without image hints', () {
    const groupName = '\u6ee1\u6ee1\u6b63\u80fd\u91cf';
    final event = _eventWithPayload(
      'evt_generic_doc_url',
      '{"url":"https://example.com/docs/page","conversation_name":"$groupName"}',
    );

    expect(parseFeishuNetworkImageCandidates(event), isEmpty);
  });

  test('parser limits deep traversal without throwing', () {
    Object payload = <String, Object>{
      'image_url': 'https://internal-api.feishu.cn/image/preview',
    };
    for (var index = 0; index < 80; index += 1) {
      payload = <String, Object>{'child': payload};
    }
    final event = _eventWithPayload('evt_deep_payload', jsonEncode(payload));

    expect(() => parseFeishuNetworkImageCandidates(event), returnsNormally);
    expect(parseFeishuNetworkImageCandidates(event), isEmpty);
  });

  test('parser ignores malformed payload', () {
    final event = _eventWithPayload('evt_malformed', '{"image_key":');

    expect(parseFeishuNetworkImageCandidates(event), isEmpty);
  });
}

FeishuNetworkCaptureEvent _eventWithPayload(String id, String payloadPreview) {
  return FeishuNetworkCaptureEvent(
    id: id,
    observedAt: DateTime.utc(2026, 5, 10, 6, 3),
    source: FeishuNetworkEventSource.httpResponse,
    url: 'https://internal-api.feishu.cn/messenger/messages',
    method: 'POST',
    statusCode: 200,
    mimeType: 'application/json',
    payloadPreview: payloadPreview,
  );
}
