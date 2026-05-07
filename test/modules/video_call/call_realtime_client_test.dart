import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/video_call/infrastructure/call_realtime_client.dart';

void main() {
  group('CallRealtimeClient helpers', () {
    test('builds browser-safe realtime URL with ticket query parameter', () {
      final url = buildCallRealtimeUri(
        controlUrl: 'wss://infoequity.cn/v1/callgateway/ws',
        ticket: 'jwt-token',
        roomId: 'room_01',
      );

      expect(
        url.toString(),
        'wss://infoequity.cn/v1/callgateway/ws?ticket=jwt-token&room_id=room_01',
      );
    });

    test('preserves existing query parameters when building realtime URL', () {
      final url = buildCallRealtimeUri(
        controlUrl: 'wss://infoequity.cn/v1/callgateway/ws?client=flutter',
        ticket: 'jwt-token',
        roomId: 'room_01',
      );

      expect(url.queryParameters['client'], 'flutter');
      expect(url.queryParameters['ticket'], 'jwt-token');
      expect(url.queryParameters['room_id'], 'room_01');
    });

    test('encodes and decodes control events as JSON payloads', () {
      const event = CallControlEvent(
        type: 'accept',
        roomId: 'room_01',
        payload: <String, dynamic>{'accepted': true},
      );

      final encoded = encodeCallControlEvent(event);
      final decoded = decodeCallControlEvent(jsonDecode(encoded));

      expect(decoded.type, 'accept');
      expect(decoded.roomId, 'room_01');
      expect(decoded.payload, <String, dynamic>{'accepted': true});
    });

    test(
      'managed client forwards decoded events from the socket stream',
      () async {
        final socket = _FakeCallRealtimeSocket();
        final client = ManagedCallRealtimeClient(
          connect: (_, {headers}) => socket,
        );

        await client.connect(
          uri: Uri.parse('wss://infoequity.cn/v1/callgateway/ws'),
        );
        final nextEvent = client.events.first;
        socket.emit('{"type":"accept","room_id":"room_01","accepted":true}');

        await expectLater(
          nextEvent,
          completion(
            isA<CallControlEvent>()
                .having((event) => event.type, 'type', 'accept')
                .having((event) => event.roomId, 'roomId', 'room_01')
                .having(
                  (event) => event.payload['accepted'],
                  'payload.accepted',
                  true,
                ),
          ),
        );
      },
    );

    test('managed client rolls back failed handshakes', () async {
      final socket = _FakeCallRealtimeSocket(
        readyError: StateError('handshake failed'),
      );
      final client = ManagedCallRealtimeClient(
        connect: (_, {headers}) => socket,
      );

      await expectLater(
        client.connect(uri: Uri.parse('wss://infoequity.cn/v1/callgateway/ws')),
        throwsA(isA<StateError>()),
      );

      expect(socket.closeCalls, 1);
      await expectLater(
        () => client.send(
          const CallControlEvent(type: 'accept', roomId: 'room_01'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'managed client clears the active socket after remote close',
      () async {
        final socket = _FakeCallRealtimeSocket();
        final client = ManagedCallRealtimeClient(
          connect: (_, {headers}) => socket,
        );

        await client.connect(
          uri: Uri.parse('wss://infoequity.cn/v1/callgateway/ws'),
        );
        await socket.finish();
        await Future<void>.delayed(Duration.zero);

        await expectLater(
          () => client.send(
            const CallControlEvent(type: 'accept', roomId: 'room_01'),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}

class _FakeCallRealtimeSocket implements CallRealtimeSocket {
  _FakeCallRealtimeSocket({this.readyError});

  final Object? readyError;
  final StreamController<Object?> _controller =
      StreamController<Object?>.broadcast();
  int closeCalls = 0;

  @override
  Stream<Object?> get stream => _controller.stream;

  @override
  Future<void> ready() async {
    if (readyError != null) {
      throw readyError!;
    }
  }

  @override
  void add(Object? data) {}

  void emit(Object? data) {
    _controller.add(data);
  }

  Future<void> finish() async {
    await _controller.close();
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closeCalls += 1;
    await _controller.close();
  }
}
