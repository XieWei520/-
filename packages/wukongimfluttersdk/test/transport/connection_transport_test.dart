import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukongimfluttersdk/manager/connection_transport.dart';

void main() {
  group('WKConnectTarget.parse', () {
    test('parses tcp host and port', () {
      final target = WKConnectTarget.parse('wemx.cc:5100');

      expect(target.type, WKTransportType.tcp);
      expect(target.host, 'wemx.cc');
      expect(target.port, 5100);
      expect(target.uri, isNull);
    });

    test('parses secure websocket uri', () {
      final target = WKConnectTarget.parse('wss://wemx.cc/ws');

      expect(target.type, WKTransportType.wss);
      expect(target.uri, Uri.parse('wss://wemx.cc/ws'));
      expect(target.host, 'wemx.cc');
    });

    test('parses websocket uri', () {
      final target = WKConnectTarget.parse('ws://wemx.cc/ws');

      expect(target.type, WKTransportType.ws);
      expect(target.uri, Uri.parse('ws://wemx.cc/ws'));
      expect(target.host, 'wemx.cc');
    });

    test('rejects malformed websocket uri', () {
      expect(
        () => WKConnectTarget.parse('ws://:5100/ws'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => WKConnectTarget.parse('wss:///ws'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('WKWebSocketFrameConverter', () {
    test('keeps Uint8List frames as bytes', () {
      final frame = Uint8List.fromList(<int>[1, 2, 3]);
      final bytes = WKWebSocketFrameConverter.toBytes(frame);

      expect(bytes, equals(Uint8List.fromList(<int>[1, 2, 3])));
    });

    test('converts List<int> websocket frame to Uint8List', () {
      final bytes = WKWebSocketFrameConverter.toBytes(<int>[4, 5, 6]);

      expect(bytes, equals(Uint8List.fromList(<int>[4, 5, 6])));
    });

    test('ignores text websocket frame', () {
      final bytes = WKWebSocketFrameConverter.toBytes('text frame');

      expect(bytes, isNull);
    });
  });

  group('WKWebSocketConnectionTransport', () {
    test('does not request websocket compression extensions', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      final extensionHeaderCompleter = Completer<String?>();
      server.listen((HttpRequest request) async {
        extensionHeaderCompleter.complete(
          request.headers.value('sec-websocket-extensions'),
        );
        final socket = await WebSocketTransformer.upgrade(request);
        await socket.close();
      });

      final target = WKConnectTarget.parse(
        'ws://${server.address.address}:${server.port}/ws',
      );
      final transport = await WKConnectionTransportFactory.connect(target);
      addTearDown(() async {
        await transport.close();
      });

      final extensionHeader = await extensionHeaderCompleter.future.timeout(
        const Duration(seconds: 5),
      );

      expect(extensionHeader, isNull);
    });

    test('delivers binary websocket frames as Uint8List', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((HttpRequest request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        socket.add(Uint8List.fromList(<int>[7, 8, 9]));
        await socket.close();
      });

      final target = WKConnectTarget.parse(
        'ws://${server.address.address}:${server.port}/ws',
      );
      final transport = await WKConnectionTransportFactory.connect(target);
      addTearDown(() async {
        await transport.close();
      });

      final bytesCompleter = Completer<Uint8List>();
      transport.listen((Uint8List data) {
        if (!bytesCompleter.isCompleted) {
          bytesCompleter.complete(data);
        }
      });

      final bytes = await bytesCompleter.future.timeout(
        const Duration(seconds: 5),
      );

      expect(bytes, Uint8List.fromList(<int>[7, 8, 9]));
    });
  });
}
