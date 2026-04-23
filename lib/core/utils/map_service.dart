import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

@immutable
class MapTileEndpoint {
  const MapTileEndpoint({required this.urlTemplate, required this.probeUrl});

  final String urlTemplate;
  final String probeUrl;
}

class MapService {
  MapService({
    Dio? dio,
    List<MapTileEndpoint>? tileEndpoints,
    Duration availabilityCacheDuration = const Duration(minutes: 10),
  }) : _dio = dio ?? _buildDefaultDio(),
       _tileEndpoints = tileEndpoints == null || tileEndpoints.isEmpty
           ? _defaultTileEndpoints
           : List<MapTileEndpoint>.unmodifiable(tileEndpoints),
       _availabilityCacheDuration = availabilityCacheDuration;

  static final MapService instance = MapService();

  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const List<MapTileEndpoint> _defaultTileEndpoints = <MapTileEndpoint>[
    MapTileEndpoint(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      probeUrl: 'https://tile.openstreetmap.org/0/0/0.png',
    ),
    MapTileEndpoint(
      urlTemplate: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
      probeUrl: 'https://a.tile.openstreetmap.fr/hot/0/0/0.png',
    ),
    MapTileEndpoint(
      urlTemplate: 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
      probeUrl: 'https://basemaps.cartocdn.com/light_all/0/0/0.png',
    ),
  ];

  final Dio _dio;
  final List<MapTileEndpoint> _tileEndpoints;
  final Duration _availabilityCacheDuration;

  bool? _remoteMapAvailable;
  DateTime? _lastProbeAt;
  MapTileEndpoint? _activeTileEndpoint;

  bool get isRemoteMapAvailable => _remoteMapAvailable ?? false;
  String get activeTileUrlTemplate =>
      _activeTileEndpoint?.urlTemplate ?? tileUrlTemplate;

  Future<bool> ensureRemoteMapAvailable({bool forceRefresh = false}) async {
    final lastProbeAt = _lastProbeAt;
    if (!forceRefresh &&
        _remoteMapAvailable != null &&
        lastProbeAt != null &&
        DateTime.now().difference(lastProbeAt) < _availabilityCacheDuration) {
      return _remoteMapAvailable!;
    }

    try {
      final endpoint = await _probeAvailableTileEndpoint();
      if (endpoint != null) {
        _activeTileEndpoint = endpoint;
      }
      _remoteMapAvailable = endpoint != null || _activeTileEndpoint != null;
    } catch (_) {
      _remoteMapAvailable = _activeTileEndpoint != null;
    } finally {
      _lastProbeAt = DateTime.now();
    }

    return _remoteMapAvailable ?? false;
  }

  Future<String> reverseGeocode(LatLng latlng) async {
    final fallbackAddress = formatCoordinateAddress(latlng);
    final available = await ensureRemoteMapAvailable();
    if (!available) {
      return fallbackAddress;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': latlng.latitude,
          'lon': latlng.longitude,
          'format': 'json',
        },
      );
      final displayName = response.data?['display_name']?.toString().trim();
      return displayName == null || displayName.isEmpty
          ? fallbackAddress
          : displayName;
    } catch (_) {
      return fallbackAddress;
    }
  }

  Future<LatLng?> searchLocation(String keyword) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) {
      return null;
    }

    final available = await ensureRemoteMapAvailable();
    if (!available) {
      return null;
    }

    try {
      final response = await _dio.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'q': trimmedKeyword, 'format': 'json', 'limit': 1},
      );
      final data = response.data;
      if (data == null || data.isEmpty) {
        return null;
      }

      final first = data.first;
      if (first is! Map) {
        return null;
      }

      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lon == null) {
        return null;
      }
      return LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }

  String formatCoordinateAddress(LatLng latlng) {
    return '\u7eac\u5ea6 ${latlng.latitude.toStringAsFixed(6)}\uff0c'
        '\u7ecf\u5ea6 ${latlng.longitude.toStringAsFixed(6)}';
  }

  Future<MapTileEndpoint?> _probeAvailableTileEndpoint() async {
    if (_tileEndpoints.isEmpty) {
      return null;
    }

    final completer = Completer<MapTileEndpoint?>();
    var remaining = _tileEndpoints.length;

    for (final endpoint in _tileEndpoints) {
      _probeTileEndpoint(endpoint)
          .then((available) {
            if (completer.isCompleted) {
              return;
            }
            if (available) {
              completer.complete(endpoint);
              return;
            }
            remaining -= 1;
            if (remaining == 0) {
              completer.complete(null);
            }
          })
          .catchError((_) {
            if (completer.isCompleted) {
              return;
            }
            remaining -= 1;
            if (remaining == 0) {
              completer.complete(null);
            }
          });
    }

    return completer.future;
  }

  Future<bool> _probeTileEndpoint(MapTileEndpoint endpoint) async {
    final response = await _dio.get<List<int>>(
      endpoint.probeUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.statusCode == 200;
  }

  static Dio _buildDefaultDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
        headers: const {'User-Agent': 'wukong_im_app/1.0'},
      ),
    );
  }
}
