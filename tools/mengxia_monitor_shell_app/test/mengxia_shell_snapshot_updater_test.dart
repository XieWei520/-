import 'package:flutter_test/flutter_test.dart';
import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_page_probe.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_runtime_snapshot_mapper.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_shell_snapshot_updater.dart';

void main() {
  test(
    'applies workspace probe capture state over previous stopped snapshot',
    () {
      final probe = MengxiaPageProbe(
        runtimeUrl: 'https://mx.2026.naaifu.cn/#/',
        pageTitle: 'Mengxia',
        pageKind: MengxiaPageKind.workspace,
        observedAt: DateTime.utc(2026, 5, 17),
        events: const <MengxiaProbeMessageEvent>[
          MengxiaProbeMessageEvent(
            eventId: 'event-1',
            dedupeKey: 'source-1:event-1',
            conversationId: 'source-1',
            conversationName: 'Source 1',
            conversationType: 'group',
            messageId: 'message-1',
            senderName: 'Alice',
            messageType: 'text',
            text: 'live message',
            captureSource: 'dom_probe',
          ),
        ],
      );

      final next = applyMengxiaRuntimeSnapshot(
        current: ShellSnapshot.initial().copyWith(captureState: 'stopped'),
        snapshot: mapMengxiaRuntimeSnapshot(probe),
        probe: probe,
        updatedAt: DateTime.utc(2026, 5, 17, 1),
      );

      expect(next.captureState, 'running');
      expect(next.loginState, 'logged_in');
      expect(next.pageKind, 'workspace');
      expect(next.recentEvents.single.text, 'live message');
      expect(next.messagesToday, 1);
    },
  );

  test('preserves configured routing sources across probe updates', () {
    final current = ShellSnapshot.initial().copyWith(
      probeDiagnostics: const <String, dynamic>{
        'configured_media_sources': <Map<String, String>>[
          <String, String>{
            'conversation_id': 'mx-alpha',
            'conversation_name': 'Alpha',
          },
          <String, String>{
            'conversation_id': 'mx-beta',
            'conversation_name': 'Beta',
          },
        ],
        'configured_media_source_count': 2,
      },
    );
    final probe = MengxiaPageProbe(
      runtimeUrl: 'https://mx.2026.naaifu.cn/#/',
      pageTitle: 'Mengxia',
      pageKind: MengxiaPageKind.workspace,
      observedAt: DateTime.utc(2026, 5, 17),
      probeDiagnostics: const <String, Object?>{
        'conversation_count': 1,
        'source_candidate_count': 1,
        'event_count': 0,
      },
    );

    final next = applyMengxiaRuntimeSnapshot(
      current: current,
      snapshot: mapMengxiaRuntimeSnapshot(probe),
      probe: probe,
      updatedAt: DateTime.utc(2026, 5, 17, 1),
    );

    expect(next.probeDiagnostics['configured_media_source_count'], 2);
    expect(next.probeDiagnostics['configured_media_sources'], isA<List>());
    expect(next.probeDiagnostics['event_count'], 0);
  });

  test('keeps previously discovered source conversations across probes', () {
    final current = ShellSnapshot.initial().copyWith(
      observedConversations: const <ObservedConversation>[
        ObservedConversation(
          id: 'fallback:梅森投研',
          name: '梅森投研',
          type: 'unknown',
          lastMessagePreview: '梅森投研',
          observedAt: '2026-05-17T01:00:00.000Z',
        ),
      ],
    );
    final probe = MengxiaPageProbe(
      runtimeUrl: 'https://mx.2026.naaifu.cn/#/',
      pageTitle: '萌侠博客',
      pageKind: MengxiaPageKind.workspace,
      observedAt: DateTime.utc(2026, 5, 17, 1, 0, 2),
      conversations: const <MengxiaProbeConversation>[
        MengxiaProbeConversation(
          id: 'fallback:大师姐王爽',
          name: '大师姐王爽',
          type: 'unknown',
          lastMessagePreview: '大师姐王爽',
        ),
      ],
    );

    final next = applyMengxiaRuntimeSnapshot(
      current: current,
      snapshot: mapMengxiaRuntimeSnapshot(probe),
      probe: probe,
      updatedAt: DateTime.utc(2026, 5, 17, 1, 0, 2),
    );

    expect(
      next.observedConversations.map((item) => item.name),
      containsAll(<String>['梅森投研', '大师姐王爽']),
    );
  });

  test('clears discovered source conversations on login page', () {
    final current = ShellSnapshot.initial().copyWith(
      observedConversations: const <ObservedConversation>[
        ObservedConversation(
          id: 'fallback:梅森投研',
          name: '梅森投研',
          type: 'unknown',
          lastMessagePreview: '梅森投研',
          observedAt: '2026-05-17T01:00:00.000Z',
        ),
      ],
    );
    final probe = MengxiaPageProbe(
      runtimeUrl: 'https://mx.2026.naaifu.cn/#/pages/login/login',
      pageTitle: '萌侠登录',
      pageKind: MengxiaPageKind.login,
      observedAt: DateTime.utc(2026, 5, 17, 1, 1),
    );

    final next = applyMengxiaRuntimeSnapshot(
      current: current,
      snapshot: mapMengxiaRuntimeSnapshot(probe),
      probe: probe,
      updatedAt: DateTime.utc(2026, 5, 17, 1, 1),
    );

    expect(next.observedConversations, isEmpty);
    expect(next.loginState, 'login_required');
  });

  test('drops message-like source conversations from accumulated list', () {
    final current = ShellSnapshot.initial().copyWith(
      observedConversations: const <ObservedConversation>[
        ObservedConversation(
          id: r'fallback:\n回调主要还是前期涨太多了',
          name: r'\n回调主要还是前期涨太多了',
          type: 'unknown',
          lastMessagePreview: r'\n回调主要还是前期涨太多了',
          observedAt: '2026-05-17T01:00:00.000Z',
        ),
        ObservedConversation(
          id: 'fallback:梅森投研',
          name: '梅森投研',
          type: 'unknown',
          lastMessagePreview: '梅森投研',
          observedAt: '2026-05-17T01:00:00.000Z',
        ),
      ],
    );
    final probe = MengxiaPageProbe(
      runtimeUrl: 'https://mx.2026.naaifu.cn/#/',
      pageTitle: '萌侠博客',
      pageKind: MengxiaPageKind.workspace,
      observedAt: DateTime.utc(2026, 5, 17, 1, 0, 2),
    );

    final next = applyMengxiaRuntimeSnapshot(
      current: current,
      snapshot: mapMengxiaRuntimeSnapshot(probe),
      probe: probe,
      updatedAt: DateTime.utc(2026, 5, 17, 1, 0, 2),
    );

    expect(next.observedConversations.map((item) => item.name), <String>[
      '梅森投研',
    ]);
  });
}
