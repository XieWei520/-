import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_network_capture.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_network_capture_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bridge starts native capture and emits parsed generic events', () async {
    final bridge = MengxiaNetworkCaptureBridge();
    final calls = <MethodCall>[];
    StreamSubscription<MengxiaNetworkCaptureEvent>? subscription;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge.channel, (call) async {
          calls.add(call);
          if (call.method == 'start') {
            return <String, Object>{'state': 'running'};
          }
          if (call.method == 'stop') {
            return <String, Object>{'state': 'stopped'};
          }
          return null;
        });
    addTearDown(() async {
      await subscription?.cancel();
      await bridge.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge.channel, null);
    });

    final received = <MengxiaNetworkCaptureEvent>[];
    subscription = bridge.events.listen(received.add);

    await bridge.start();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          bridge.channel.name,
          bridge.channel.codec.encodeMethodCall(
            const MethodCall('networkEvent', <String, Object>{
              'id': 'evt_1',
              'observed_at': '2026-05-17T01:00:00Z',
              'source': 'httpResponse',
              'url': 'https://mx.2026.naaifu.cn/3/api/messages?token=secret',
              'method': 'GET',
              'status_code': 200,
              'mime_type': 'application/json',
              'payload_preview': '{"ok":true}',
            }),
          ),
          (_) {},
        );
    await Future<void>.delayed(Duration.zero);

    expect(calls.single.method, 'start');
    expect(received, hasLength(1));
    expect(received.single.id, 'evt_1');
    expect(received.single.source, MengxiaNetworkEventSource.httpResponse);
    expect(received.single.toRedactedJson()['url'], contains('token=<redacted>'));
  });

  test('bridge exposes native unavailable errors', () async {
    final bridge = MengxiaNetworkCaptureBridge();
    StreamSubscription<String>? subscription;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge.channel, (call) async {
          if (call.method == 'stop') {
            return <String, Object>{'state': 'stopped'};
          }
          return null;
        });
    addTearDown(() async {
      await subscription?.cancel();
      await bridge.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge.channel, null);
    });

    final errors = <String>[];
    subscription = bridge.unavailableErrors.listen(errors.add);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          bridge.channel.name,
          bridge.channel.codec.encodeMethodCall(
            const MethodCall('networkUnavailable', <String, Object>{
              'message': 'WebView2 network capture failed.',
            }),
          ),
          (_) {},
        );
    await Future<void>.delayed(Duration.zero);

    expect(errors, <String>['WebView2 network capture failed.']);
  });
}
