import 'package:flutter_test/flutter_test.dart';
import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_network_capture_store.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_page_probe.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_runtime_snapshot_mapper.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_shell_snapshot_updater.dart';

void main() {
  test('store keeps recent network events and redacted diagnostics', () {
    final store = MengxiaNetworkCaptureStore();
    final event = NormalizedMessageEvent(
      eventId: 'network:mx-alpha:msg-1',
      dedupeKey: 'network:mx-alpha:msg-1',
      accountId: '',
      conversationId: 'mx-alpha',
      conversationName: 'Alpha',
      conversationType: 'group',
      messageId: 'msg-1',
      senderId: '',
      senderName: 'Alice',
      messageType: 'text',
      text: 'hello',
      sentAt: '',
      observedAt: '2026-05-17T01:00:00.000Z',
      captureSource: 'network_api',
    );

    store.addMessageEvent(event);

    expect(store.recentMessageEvents, hasLength(1));
    expect(store.toDiagnosticsJson()['network_message_event_count'], 1);
    expect(
      store.toDiagnosticsJson()['network_capture_state'],
      'running',
    );
  });

  test('network events merge into shell snapshot recent events', () {
    final networkEvent = NormalizedMessageEvent(
      eventId: 'network:mx-alpha:msg-1',
      dedupeKey: 'network:mx-alpha:msg-1',
      accountId: '',
      conversationId: 'mx-alpha',
      conversationName: 'Alpha',
      conversationType: 'group',
      messageId: 'msg-1',
      senderId: '',
      senderName: 'Alice',
      messageType: 'text',
      text: 'hello from network',
      sentAt: '',
      observedAt: '2026-05-17T01:00:00.000Z',
      captureSource: 'network_api',
    );

    final next = applyMengxiaRuntimeSnapshot(
      current: ShellSnapshot.initial(),
      snapshot: mapMengxiaRuntimeSnapshot(
        MengxiaPageProbe(
          runtimeUrl: 'https://mx.2026.naaifu.cn/#/',
          pageTitle: 'Mengxia',
          pageKind: MengxiaPageKind.workspace,
          observedAt: DateTime.utc(2026, 5, 17, 1),
        ),
      ),
      probe: MengxiaPageProbe(
        runtimeUrl: 'https://mx.2026.naaifu.cn/#/',
        pageTitle: 'Mengxia',
        pageKind: MengxiaPageKind.workspace,
        observedAt: DateTime.utc(2026, 5, 17, 1),
      ),
      updatedAt: DateTime.utc(2026, 5, 17, 1),
      networkEvents: <NormalizedMessageEvent>[networkEvent],
      networkDiagnostics: const <String, dynamic>{
        'network_message_event_count': 1,
      },
    );

    expect(next.recentEvents, hasLength(1));
    expect(next.recentEvents.single.captureSource, 'network_api');
    expect(next.recentEvents.single.text, 'hello from network');
    expect(next.probeDiagnostics['network_message_event_count'], 1);
  });
}
