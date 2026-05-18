import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';
import 'package:xiaoe_monitor_shell_app/src/xiaoe_page_probe.dart';
import 'package:xiaoe_monitor_shell_app/src/xiaoe_runtime_capture.dart';

void main() {
  test(
    'applyProbe stores normalized events and publishes snapshot update',
    () async {
      final base = await Directory.systemTemp.createTemp(
        'xiaoe_runtime_capture_test_',
      );
      addTearDown(() async {
        if (await base.exists()) {
          await base.delete(recursive: true);
        }
      });
      final store = ShellStore(File('${base.path}/status.json'));
      final events = ShellEventBus();
      addTearDown(events.close);
      final published = <ShellEvent>[];
      final subscription = events.stream.listen(published.add);
      addTearDown(subscription.cancel);
      final capture = XiaoeRuntimeCapture(store: store, events: events);
      final probe = XiaoePageProbe.fromScriptResult(<String, Object?>{
        'runtime_url': 'https://study.xiaoe-tech.com/#/live/room/live-1',
        'page_title': '五月直播 - 小鹅通',
        'observed_at': '2026-05-17T09:00:00Z',
        'source': <String, Object?>{
          'id': 'live:live-1',
          'name': '五月直播',
          'type': 'live',
        },
        'comment_candidates': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'comment-1',
            'sender_name': 'Alice',
            'text': '第一条直播评论',
          },
        ],
        'probe_diagnostics': <String, Object?>{'selector_hits': 3},
      });

      final snapshot = await capture.applyProbe(
        probe,
        updatedAt: DateTime.parse('2026-05-17T09:00:01Z'),
      );

      expect(snapshot.shellState, 'online');
      expect(snapshot.captureState, 'running');
      expect(snapshot.loginState, 'logged_in');
      expect(snapshot.pageKind, 'live');
      expect(snapshot.runtimeUrl, probe.runtimeUrl);
      expect(snapshot.observedConversations, hasLength(1));
      expect(snapshot.observedConversations.single.id, 'live:live-1');
      expect(snapshot.observedMessages, hasLength(1));
      expect(snapshot.observedMessages.single.text, '第一条直播评论');
      expect(snapshot.recentEvents, hasLength(1));
      expect(snapshot.recentEvents.single.dedupeKey, 'live:live-1:comment-1');
      expect(snapshot.messagesToday, 1);
      expect(snapshot.probeDiagnostics['selector_hits'], 3);

      await _waitFor(() => published.isNotEmpty, 'snapshot_updated event');
      expect(published.single.type, ShellEventType.snapshotUpdated);
      expect(published.single.reason, 'xiaoe_probe');
      expect(published.single.recentEventsCount, 1);
      expect(published.single.observedConversationsCount, 1);
    },
  );

  test('applyProbe merges duplicate events across probe cycles', () async {
    final base = await Directory.systemTemp.createTemp(
      'xiaoe_runtime_capture_test_',
    );
    addTearDown(() async {
      if (await base.exists()) {
        await base.delete(recursive: true);
      }
    });
    final capture = XiaoeRuntimeCapture(
      store: ShellStore(File('${base.path}/status.json')),
      events: ShellEventBus(),
    );
    addTearDown(capture.close);
    final probe = XiaoePageProbe.fromScriptResult(<String, Object?>{
      'runtime_url': 'https://study.xiaoe-tech.com/#/course/interaction/1',
      'page_title': '课程互动',
      'observed_at': '2026-05-17T09:10:00Z',
      'source': <String, Object?>{
        'id': 'course:lesson-1',
        'name': '课程互动',
        'type': 'course',
      },
      'comment_candidates': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'comment-1',
          'sender_name': 'Bob',
          'text': '同一条课程互动',
        },
      ],
    });

    await capture.applyProbe(probe);
    final snapshot = await capture.applyProbe(probe);

    expect(snapshot.recentEvents, hasLength(1));
    expect(snapshot.observedMessages, hasLength(1));
    expect(snapshot.messagesToday, 1);
  });

  test('applyProbe excludes noisy candidates from observed messages', () async {
    final base = await Directory.systemTemp.createTemp(
      'xiaoe_runtime_capture_test_',
    );
    addTearDown(() async {
      if (await base.exists()) {
        await base.delete(recursive: true);
      }
    });
    final capture = XiaoeRuntimeCapture(
      store: ShellStore(File('${base.path}/status.json')),
      events: ShellEventBus(),
    );
    addTearDown(capture.close);
    final probe = XiaoePageProbe.fromScriptResult(<String, Object?>{
      'runtime_url': 'https://study.xiaoe-tech.com/#/circle/topic/alpha',
      'page_title': '训练营圈子',
      'observed_at': '2026-05-17T09:20:00Z',
      'source': <String, Object?>{
        'id': 'circle:alpha',
        'name': '训练营圈子',
        'type': 'circle',
      },
      'comment_candidates': <Map<String, Object?>>[
        <String, Object?>{'id': 'nav', 'text': '首页 课程 圈子 订单 设置'},
        <String, Object?>{
          'id': 'comment-1',
          'sender_name': 'Alice',
          'text': '有效互动',
        },
      ],
    });

    final snapshot = await capture.applyProbe(probe);

    expect(snapshot.observedMessages, hasLength(1));
    expect(snapshot.observedMessages.single.text, '有效互动');
    expect(snapshot.recentEvents, hasLength(1));
    expect(snapshot.recentEvents.single.messageId, 'comment-1');
  });
}

Future<void> _waitFor(
  bool Function() condition,
  String description, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $description');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
