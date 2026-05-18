import 'package:flutter_test/flutter_test.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_page_observer.dart';

void main() {
  test('parses page observer messages from json', () {
    final message = MengxiaPageObserverMessage.fromJson(<String, Object?>{
      'type': 'mengxia_monitor_page_changed',
      'reason': 'navigation',
      'observed_at': '2026-05-17T00:00:00.000Z',
    });

    expect(message.isPageChanged, isTrue);
    expect(message.reason, 'navigation');
    expect(message.observedAt, DateTime.utc(2026, 5, 17));
  });

  test(
    'observer script installs manual wheel scrolling and visible scrollbars',
    () {
      expect(mengxiaPageObserverScript, contains('addEventListener(\'wheel\''));
      expect(
        mengxiaPageObserverScript,
        contains('__wukongMengxiaManualWheelScroll'),
      );
      expect(mengxiaPageObserverScript, contains('pointInside'));
      expect(
        mengxiaPageObserverScript,
        contains('containingVisibleScrollable'),
      );
      expect(mengxiaPageObserverScript, contains('node.scrollBy'));
      expect(mengxiaPageObserverScript, contains('::-webkit-scrollbar-thumb'));
      expect(
        mengxiaPageObserverScript,
        contains('wukong-mengxia-scroll-indicator__thumb'),
      );
    },
  );

  test(
    'probe script reports source candidates without automatic scrolling',
    () {
      expect(mengxiaPageProbeScript, contains('source_candidate_count'));
      expect(mengxiaPageProbeScript, isNot(contains('autoScrollDiscover')));
      expect(
        mengxiaPageProbeScript,
        isNot(contains('__wukongMengxiaAutoScroll')),
      );
      expect(mengxiaPageProbeScript, isNot(contains('auto_scroll_')));
    },
  );

  test(
    'manual wheel fallback script avoids only duplicate manual scrolling',
    () {
      final script = mengxiaManualWheelScrollFallbackScript(
        clientX: 12,
        clientY: 34,
        deltaX: 0,
        deltaY: 120,
      );

      expect(script, contains('__wukongMengxiaManualWheelScroll'));
      expect(script, contains('manual-wheel-already-handled'));
      expect(script, isNot(contains('native-wheel-already-handled')));
      expect(script, isNot(contains('helper.lastWheelAt')));
      expect(script, contains('helper.scrollAt(12.00, 34.00, 120.00, 0.00'));
      expect(script, isNot(contains('__wukongMengxiaAutoScroll')));
    },
  );

  test('probe script filters payment action labels from source candidates', () {
    expect(mengxiaPageProbeScript, contains("'开通'"));
    expect(mengxiaPageProbeScript, contains("'开通卡密'"));
  });

  test('probe script filters login and non-channel action labels', () {
    expect(mengxiaPageProbeScript, contains("'请输入账号'"));
    expect(mengxiaPageProbeScript, contains("'忘记密码'"));
    expect(mengxiaPageProbeScript, contains("'每日签到'"));
    expect(mengxiaPageProbeScript, contains("'搜索直播间名称'"));
    expect(mengxiaPageProbeScript, contains('loginLikePage ? []'));
    expect(mengxiaPageProbeScript, contains('login_like_page'));
    expect(mengxiaPageProbeScript, contains(r'\[图片\]'));
    expect(mengxiaPageProbeScript, contains(r'\\n|\\r'));
    expect(mengxiaPageProbeScript, contains('isLikelySourceColumn'));
  });

  test(
    'probe script has visible short-text fallback for channel discovery',
    () {
      expect(
        mengxiaPageProbeScript,
        contains('collectLeafSourceCandidateNodes'),
      );
      expect(
        mengxiaPageProbeScript,
        contains('fallback_source_candidate_count'),
      );
      expect(mengxiaPageProbeScript, contains('[data-channel-id]'));
      expect(mengxiaPageProbeScript, contains('[class*="channel"]'));
      expect(mengxiaPageProbeScript, contains('[class*="column"]'));
      expect(mengxiaPageProbeScript, contains('isInsideMessageLikeNode'));
      expect(
        mengxiaPageProbeScript,
        contains('sourceCandidates.length >= 320'),
      );
    },
  );

  test('probe script extracts image attachments from message nodes', () {
    expect(mengxiaPageProbeScript, contains('image_attachments'));
    expect(mengxiaPageProbeScript, contains('imageAttachmentsOf'));
    expect(mengxiaPageProbeScript, contains("querySelectorAll('img')"));
    expect(
      mengxiaPageProbeScript,
      contains(
        "message_type: imageAttachments.length > 0 && !text ? 'image' : 'text'",
      ),
    );
  });
}
