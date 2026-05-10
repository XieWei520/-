import 'dart:async';

import 'package:feishu_monitor_shell_app/src/feishu_network_capture.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bridge starts native capture and emits parsed events', () async {
    final calls = <MethodCall>[];
    final bridge = FeishuNetworkCaptureBridge();
    StreamSubscription<FeishuNetworkCaptureEvent>? subscription;

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

    final received = <FeishuNetworkCaptureEvent>[];
    subscription = bridge.events.listen(received.add);

    await bridge.start();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          bridge.channel.name,
          bridge.channel.codec.encodeMethodCall(
            const MethodCall('networkEvent', <String, Object>{
              'id': 'evt_1',
              'observed_at': '2026-05-10T06:00:00Z',
              'source': 'httpResponse',
              'url': 'https://a.test/messages',
              'method': 'GET',
              'status_code': 200,
              'mime_type': 'application/json',
              'payload_preview': '{}',
            }),
          ),
          (_) {},
        );
    await Future<void>.delayed(Duration.zero);

    expect(calls.single.method, 'start');
    expect(received, hasLength(1));
    expect(received.single.id, 'evt_1');
    expect(received.single.source, FeishuNetworkEventSource.httpResponse);

    await subscription.cancel();
    subscription = null;
  });

  test(
    'dispose completes when native stop fails and ignores late events',
    () async {
      final calls = <MethodCall>[];
      final bridge = FeishuNetworkCaptureBridge();
      StreamSubscription<FeishuNetworkCaptureEvent>? subscription;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge.channel, (call) async {
            calls.add(call);
            if (call.method == 'stop') {
              throw PlatformException(code: 'stop_failed');
            }
            return null;
          });
      addTearDown(() async {
        await subscription?.cancel();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(bridge.channel, null);
      });

      final received = <FeishuNetworkCaptureEvent>[];
      subscription = bridge.events.listen(received.add);

      await bridge.dispose();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            bridge.channel.name,
            bridge.channel.codec.encodeMethodCall(
              const MethodCall('networkEvent', <String, Object>{
                'id': 'evt_late',
                'observed_at': '2026-05-10T06:00:00Z',
                'source': 'httpResponse',
                'url': 'https://a.test/messages',
                'method': 'GET',
                'status_code': '200',
                'mime_type': 'application/json',
                'payload_preview': '{}',
              }),
            ),
            (_) {},
          );
      await Future<void>.delayed(Duration.zero);

      expect(calls.map((call) => call.method), contains('stop'));
      expect(received, isEmpty);
    },
  );

  test('bridge parses saved response body metadata', () async {
    final bridge = FeishuNetworkCaptureBridge();
    StreamSubscription<FeishuNetworkCaptureEvent>? subscription;

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

    final received = <FeishuNetworkCaptureEvent>[];
    subscription = bridge.events.listen(received.add);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          bridge.channel.name,
          bridge.channel.codec.encodeMethodCall(
            const MethodCall('networkEvent', <String, Object>{
              'id': 'evt_image',
              'observed_at': '2026-05-10T06:00:00Z',
              'source': 'httpResponse',
              'url':
                  'https://internal-api-lark-file.feishu.cn/static-resource/v1/image.webp?token=secret',
              'method': 'GET',
              'status_code': 200,
              'mime_type': 'image/webp',
              'payload_preview': '',
              'body_local_path':
                  r'C:\Users\COLORFUL\AppData\Local\Temp\wukong_feishu_monitor_images\abc.webp',
              'body_sha1': 'abc123',
              'body_size': 12345,
              'body_mime_type': 'image/webp',
              'body_base64_encoded': true,
              'body_saved': true,
              'body_save_error': '',
            }),
          ),
          (_) {},
        );
    await Future<void>.delayed(Duration.zero);

    expect(received, hasLength(1));
    expect(received.single.bodyLocalPath, endsWith('abc.webp'));
    expect(received.single.bodySha1, 'abc123');
    expect(received.single.bodySize, 12345);
    expect(received.single.bodyMimeType, 'image/webp');
    expect(received.single.bodyBase64Encoded, isTrue);
    expect(received.single.bodySaved, isTrue);
    expect(received.single.bodySaveError, isEmpty);
  });

  test('bridge exposes native unavailable errors', () async {
    final bridge = FeishuNetworkCaptureBridge();
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
              'error': 'network_capture_unavailable',
              'message': 'WebView2 CDP Network.enable failed.',
            }),
          ),
          (_) {},
        );
    await Future<void>.delayed(Duration.zero);

    expect(errors, <String>['WebView2 CDP Network.enable failed.']);
  });
}
