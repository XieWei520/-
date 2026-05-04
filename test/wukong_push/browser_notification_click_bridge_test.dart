import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/browser_notification_click_bridge.dart';

void main() {
  group('BrowserNotificationClickBridge', () {
    test('extracts encoded payload from service worker click messages', () {
      final encoded = jsonEncode(<String, dynamic>{
        'payload': <String, dynamic>{
          'channel_id': 'group-1',
          'channel_type': 2,
          'message_id': 'msg-1',
        },
        'title': 'Group',
        'body': 'Hello',
      });

      expect(
        extractBrowserNotificationClickPayload(<String, dynamic>{
          'type': 'wk.notification.click',
          'payload': encoded,
        }),
        encoded,
      );
    });

    test('encodes object payloads from service worker click messages', () {
      final payload = extractBrowserNotificationClickPayload(<String, dynamic>{
        'type': 'wk.notification.click',
        'payload': <String, dynamic>{
          'payload': <String, dynamic>{'channelId': 'u-1', 'channelType': '1'},
          'title': 'Alice',
          'body': 'Ping',
        },
      });

      expect(payload, isNotNull);
      expect(jsonDecode(payload!)['payload']['channelId'], 'u-1');
      expect(jsonDecode(payload)['title'], 'Alice');
    });

    test('wraps bare conversation payload maps from service worker clicks', () {
      final payload = extractBrowserNotificationClickPayload(<String, dynamic>{
        'type': 'wk.notification.click',
        'payload': <String, dynamic>{
          'channel_id': 'group-raw',
          'channel_type': 2,
          'message_id': 'msg-raw',
          'title': 'Raw Group',
          'body': 'Raw body',
        },
      });

      expect(payload, isNotNull);
      final decoded = jsonDecode(payload!) as Map<String, dynamic>;
      expect(decoded['payload']['channel_id'], 'group-raw');
      expect(decoded['payload']['message_id'], 'msg-raw');
      expect(decoded['title'], 'Raw Group');
      expect(decoded['body'], 'Raw body');
    });

    test('ignores unrelated window messages', () {
      expect(
        extractBrowserNotificationClickPayload(<String, dynamic>{
          'type': 'other.message',
          'payload': 'ignored',
        }),
        isNull,
      );
    });

    test(
      'delivers normalized click payloads from the gateway stream',
      () async {
        final gateway = _FakeBrowserNotificationClickGateway();
        final delivered = <String>[];
        final bridge = BrowserNotificationClickBridge(gateway: gateway);

        bridge.start(onNotificationClick: delivered.add);
        gateway.add(<String, dynamic>{
          'type': 'wk.notification.click',
          'payload': jsonEncode(<String, dynamic>{
            'payload': <String, dynamic>{
              'channel_id': 'c-1',
              'channel_type': 1,
            },
          }),
        });

        await Future<void>.delayed(Duration.zero);

        expect(delivered, hasLength(1));
        expect(jsonDecode(delivered.single)['payload']['channel_id'], 'c-1');

        await bridge.dispose();
        await gateway.close();
      },
    );
  });
}

class _FakeBrowserNotificationClickGateway
    implements BrowserNotificationClickGateway {
  final StreamController<Object?> _controller =
      StreamController<Object?>.broadcast();

  @override
  bool get isSupported => true;

  @override
  Stream<Object?> get messages => _controller.stream;

  void add(Object? message) {
    _controller.add(message);
  }

  Future<void> close() => _controller.close();
}
