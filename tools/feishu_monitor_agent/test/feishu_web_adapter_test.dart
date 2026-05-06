import 'package:feishu_monitor_agent/src/agent_models.dart';
import 'package:feishu_monitor_agent/src/feishu_web_adapter.dart';
import 'package:test/test.dart';

void main() {
  group('FeishuWebAdapter helpers', () {
    test('classifies logged in text', () {
      expect(
        FeishuWebDomClassifier.classifyText(
          '\u6d88\u606f \u5de5\u4f5c\u53f0 \u4e91\u6587\u6863 \u98de\u4e66',
        ),
        BrowserLoginStatus.loggedIn,
      );
    });

    test('classifies login required text', () {
      expect(
        FeishuWebDomClassifier.classifyText(
          '\u626b\u7801\u767b\u5f55 \u8bf7\u4f7f\u7528\u98de\u4e66\u626b\u7801',
        ),
        BrowserLoginStatus.loginRequired,
      );
    });

    test('normalizes observed message text and hash', () {
      final message = FeishuObservedMessage.fromRaw(
        routeId: 'route_1',
        sourceChatName: '\u98de\u4e66\u65b0\u95fb\u7fa4',
        rawId: '',
        messageType: 'text',
        content: '  \u65b0\u95fb\u6b63\u6587\n\n\u65b0\u95fb\u6b63\u6587  ',
        observedAt: '2026-05-07T10:00:05Z',
        domOrder: 7,
      );

      expect(
        message.content,
        '\u65b0\u95fb\u6b63\u6587 \u65b0\u95fb\u6b63\u6587',
      );
      expect(message.sourceMessageId, startsWith('feishu_web_'));
    });

    test('keeps raw id when Feishu DOM exposes one', () {
      final message = FeishuObservedMessage.fromRaw(
        routeId: 'route_1',
        sourceChatName: '\u98de\u4e66\u65b0\u95fb\u7fa4',
        rawId: 'om_123',
        messageType: 'link',
        content: 'https://example.com',
        observedAt: '2026-05-07T10:00:05Z',
        domOrder: 1,
      );

      expect(message.sourceMessageId, 'om_123');
      expect(message.messageType, 'link');
    });
  });
}
