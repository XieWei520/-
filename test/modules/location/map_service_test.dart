import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/utils/map_service.dart';

void main() {
  test('map service falls back to the first reachable tile endpoint', () async {
    final adapter = _MapProbeAdapter(<String, int>{
      'https://primary.example.com/0/0/0.png': 504,
      'https://fallback.example.com/0/0/0.png': 200,
    });
    final dio = Dio()..httpClientAdapter = adapter;
    final service = MapService(
      dio: dio,
      availabilityCacheDuration: const Duration(hours: 1),
      tileEndpoints: const <MapTileEndpoint>[
        MapTileEndpoint(
          urlTemplate: 'https://primary.example.com/{z}/{x}/{y}.png',
          probeUrl: 'https://primary.example.com/0/0/0.png',
        ),
        MapTileEndpoint(
          urlTemplate: 'https://fallback.example.com/{z}/{x}/{y}.png',
          probeUrl: 'https://fallback.example.com/0/0/0.png',
        ),
      ],
    );

    final available = await service.ensureRemoteMapAvailable(
      forceRefresh: true,
    );

    expect(available, isTrue);
    expect(
      service.activeTileUrlTemplate,
      'https://fallback.example.com/{z}/{x}/{y}.png',
    );
  });

  test(
    'map service reuses cached probe result until force refreshed',
    () async {
      final adapter = _MapProbeAdapter(<String, int>{
        'https://cached.example.com/0/0/0.png': 200,
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final service = MapService(
        dio: dio,
        availabilityCacheDuration: const Duration(hours: 1),
        tileEndpoints: const <MapTileEndpoint>[
          MapTileEndpoint(
            urlTemplate: 'https://cached.example.com/{z}/{x}/{y}.png',
            probeUrl: 'https://cached.example.com/0/0/0.png',
          ),
        ],
      );

      expect(
        await service.ensureRemoteMapAvailable(forceRefresh: true),
        isTrue,
      );
      expect(await service.ensureRemoteMapAvailable(), isTrue);
      expect(adapter.requestCount, 1);

      expect(
        await service.ensureRemoteMapAvailable(forceRefresh: true),
        isTrue,
      );
      expect(adapter.requestCount, 2);
    },
  );
}

class _MapProbeAdapter implements HttpClientAdapter {
  _MapProbeAdapter(this._responsesByUrl);

  final Map<String, int> _responsesByUrl;
  int requestCount = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount += 1;
    final statusCode = _responsesByUrl[options.uri.toString()] ?? 404;
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'status': statusCode}),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}
