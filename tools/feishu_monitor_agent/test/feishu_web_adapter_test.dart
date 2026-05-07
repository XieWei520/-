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

    test('normalizes Feishu chat names collected from conversation rows', () {
      final names = FeishuChatNameNormalizer.normalizeAll(<String>[
        '  飞书新闻群  09:31 ',
        '飞书新闻群',
        '置顶 产品交流群 昨天',
        '1 企业安全助手 机器人 10:16 举报已提交成功',
        '1 企业安全助手 机器人',
        '胖子2 外部 09:45 自定义机器人:',
        '胖子2 外部',
        '2 橘生淮南的飞书客服 官方 09:00 飞书客服: 猜您想问以下问题',
        '2 橘生淮南的飞书客服 官方',
        '满满正能量 4月23日 橘生淮南: 这是一条测试信息',
        '消息',
        '通讯录',
        '12345',
      ]);

      expect(names, <String>[
        '飞书新闻群',
        '产品交流群',
        '企业安全助手',
        '胖子2',
        '橘生淮南的飞书客服',
        '满满正能量',
      ]);
    });

    test('uses normalized Feishu chat key for deduplication', () {
      expect(
        FeishuChatNameNormalizer.dedupeKey('1 企业安全助手 机器人'),
        FeishuChatNameNormalizer.dedupeKey('企业安全助手'),
      );
      expect(
        FeishuChatNameNormalizer.dedupeKey('胖子2 外部'),
        FeishuChatNameNormalizer.dedupeKey('胖子2'),
      );
    });

    test('extracts the focused Feishu message from noisy page text', () {
      final text = '''
搜索 (Ctrl+K) 消息 87 知识问答 会议 日历 云文档 通讯录 邮箱 任务 工作台 下载飞书客户端 消息 知识问答
听M玛的话交流12群C-GH
满满正能量 11:40 橘生淮南: 飞书转发测试 2026-05-07 11:39
84 格兰裙 外部 11:36 格兰: 周策略都是讲得比较清楚的
企业安全助手 机器人 10:41 举报成立
''';

      expect(
        FeishuMessageTextExtractor.extractFocusedMessage(
          text,
          chatName: '满满正能量',
        ),
        '橘生淮南: 飞书转发测试 2026-05-07 11:39',
      );
    });



    test('extracts latest visible chat message rather than feed preview count', () {
      final text = '''
\u6a58\u751f\u6dee\u5357 https://docs.qq.com/doc/DWU9OaUJFakZTU292 docs.qq.com 0416\u624b\u52a8\u66f4\u65b0 \u968f\u65f6\u5237\u65b0\u67e5\u770b \u817e\u8baf\u6587\u6863-\u5728\u7ebf\u8868\u683c
\u6a58\u751f\u6dee\u5357 test
\u6a58\u751f\u6dee\u5357 test1
\u8fd9\u662f\u4e00\u6761\u6d4b\u8bd5\u4fe1\u606f
11:35
\u6a58\u751f\u6dee\u5357 \u98de\u4e66\u8f6c\u53d1\u6d4b\u8bd5 2026-05-07 11:35
''';

      expect(
        FeishuMessageTextExtractor.extractFocusedMessage(
          text,
          chatName: '\u6ee1\u6ee1\u6b63\u80fd\u91cf',
        ),
        '\u6a58\u751f\u6dee\u5357 \u98de\u4e66\u8f6c\u53d1\u6d4b\u8bd5 2026-05-07 11:35',
      );
    });

    test('rejects numeric unread count from feed preview as message', () {
      expect(
        FeishuMessageTextExtractor.extractFocusedMessage(
          '87',
          chatName: '\u6ee1\u6ee1\u6b63\u80fd\u91cf',
        ),
        isEmpty,
      );
    });

    test('rejects obvious Feishu navigation text as a message', () {
      expect(
        FeishuMessageTextExtractor.extractFocusedMessage(
          '搜索 (Ctrl+K) 消息 知识问答 会议 日历 云文档 通讯录 邮箱 工作台',
          chatName: '满满正能量',
        ),
        isEmpty,
      );
    });
  });
}
