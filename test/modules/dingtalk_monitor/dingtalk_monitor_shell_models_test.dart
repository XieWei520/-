import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_shell_models.dart';

void main() {
  test('parses native host status json', () {
    final status = DingTalkMonitorShellStatus.fromJson(<String, dynamic>{
      'captureRunning': true,
      'serverTime': '2026-05-16T01:30:00Z',
      'version': 'm1',
      'shellState': 'Attached',
      'currentHwnd': '0x1320612',
      'message': 'attached',
      'lastWindowEventAt': '2026-05-16T01:29:59Z',
      'ocrEnabled': true,
      'conversationReadiness': 'Ready',
      'conversationReadinessMessage': 'message surface ready',
    });

    expect(status.isOnline, isTrue);
    expect(status.isCapturing, isTrue);
    expect(status.ocrEnabled, isTrue);
    expect(status.shellState, 'Attached');
    expect(status.currentHwnd, '0x1320612');
    expect(status.conversationReadiness, 'Ready');
    expect(status.serverTime, DateTime.parse('2026-05-16T01:30:00Z'));
  });

  test('parses camelCase OCR event as non auto-forwardable', () {
    final event = DingTalkMonitorMessageEvent.fromJson(<String, dynamic>{
      'eventId': 'screenshot-ocr:window:hash',
      'sourceConversationId': 'source:dingtalk-screenshot',
      'sourceConversationName': 'DingTalk Screenshot',
      'embeddedSourceName': '',
      'senderName': 'OCR',
      'observedAt': '2026-05-16T01:33:16.4753731Z',
      'text': 'forwardable body',
      'localImagePath': r'C:\captures\chat.png',
      'captureSource': 4,
      'contentHash': 'content-sha',
    });

    expect(event.eventId, 'screenshot-ocr:window:hash');
    expect(event.sourceConversationId, 'source:dingtalk-screenshot');
    expect(event.sourceConversationName, 'DingTalk Screenshot');
    expect(event.senderName, 'OCR');
    expect(event.text, 'forwardable body');
    expect(event.localImagePath, r'C:\captures\chat.png');
    expect(
      event.captureSource,
      DingTalkMonitorCaptureSource.chatAreaScreenshotOcr,
    );
    expect(event.contentHash, 'content-sha');
    expect(event.isForwardableText, isFalse);
  });

  test('parses string capture source and snake case fallback fields', () {
    final event = DingTalkMonitorMessageEvent.fromJson(<String, dynamic>{
      'event_id': 'uia-1',
      'source_conversation_id': 'windows:alpha',
      'source_conversation_name': 'Alpha',
      'embedded_source_name': 'Embedded Alpha',
      'sender_name': 'Alice',
      'observed_at': '2026-05-16T01:33:16Z',
      'text': 'hello',
      'local_image_path': '',
      'capture_source': 'UiaText',
      'content_hash': 'hash-1',
    });

    expect(event.eventId, 'uia-1');
    expect(event.embeddedSourceName, 'Embedded Alpha');
    expect(event.captureSource, DingTalkMonitorCaptureSource.uiaText);
    expect(event.isForwardableText, isTrue);
  });

  test('marks diagnostic UIA text sources as non-forwardable', () {
    final events = <DingTalkMonitorMessageEvent>[
      _event(
        sourceConversationId: 'source:unknown',
        sourceConversationName: '',
        text: '当前检测出钉钉异常，请点击确定',
      ),
      _event(
        sourceConversationId: 'source:advancedsearch',
        sourceConversationName: 'advancedSearch',
        text: 'AI 听记',
      ),
      _event(
        sourceConversationId: 'source:enter-alt-s发送-ctrl-enter',
        sourceConversationName: 'Enter/Alt+S发送，Ctrl+Enter',
        text: 'Enter/Alt+S发送',
      ),
      _event(
        sourceConversationId: 'source:alpha',
        sourceConversationName: 'Alpha',
        text: 'looks like a message but is only UIA diagnostic source',
      ),
    ];

    expect(
      events.map((event) => event.isForwardableText),
      everyElement(isFalse),
    );
  });

  test('allows stable native conversation source ids for UIA text', () {
    final event = _event(
      sourceConversationId: 'windows:fb61ccc7',
      sourceConversationName: 'Alpha',
      text: 'hello',
    );

    expect(event.isForwardableText, isTrue);
  });

  test('allows stable native source even when UIA window name is generic', () {
    final event = _event(
      sourceConversationId: 'windows:37dcbc65',
      sourceConversationName: 'AdvancedSearch',
      text: 'hello',
    );

    expect(event.isForwardableText, isTrue);
  });

  test('marks clipboard probe sentinel text as non-forwardable', () {
    final event = _event(
      sourceConversationId: 'windows:clipboard-active',
      sourceConversationName: 'DingTalk active clipboard',
      text: '__DINGTALK_HOST_CLIPBOARD_PROBE__abc123',
    );

    expect(event.isForwardableText, isFalse);
  });
}

DingTalkMonitorMessageEvent _event({
  String sourceConversationId = 'source:alpha',
  String sourceConversationName = 'Alpha',
  String text = 'hello',
}) {
  return DingTalkMonitorMessageEvent(
    eventId: 'event-1',
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    embeddedSourceName: '',
    senderName: 'Alice',
    observedAt: DateTime.parse('2026-05-16T01:33:16Z'),
    text: text,
    localImagePath: '',
    captureSource: DingTalkMonitorCaptureSource.uiaText,
    contentHash: 'hash-1',
  );
}
