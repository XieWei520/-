import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/utils/map_service.dart';
import '../../core/utils/platform_utils.dart';
import 'location_position_service.dart';

class LocationMapPage extends StatefulWidget {
  final LatLng? initialPosition;

  const LocationMapPage({super.key, this.initialPosition});

  @override
  State<LocationMapPage> createState() => _LocationMapPageState();
}

class _LocationMapPageState extends State<LocationMapPage> {
  late LatLng _center;
  final MapController _mapController = MapController();
  String _address = '\u6b63\u5728\u83b7\u53d6\u5730\u5740...';
  bool _loadingAddress = true;
  String _keyword = '';
  bool _remoteMapAvailable = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _center = widget.initialPosition ?? const LatLng(39.908823, 116.397470);
    _initialize();
  }

  Future<void> _initialize() async {
    final remoteMapAvailable = await MapService.instance
        .ensureRemoteMapAvailable(forceRefresh: true);
    if (mounted) {
      setState(() => _remoteMapAvailable = remoteMapAvailable);
    }
    await _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      if (PlatformUtils.isMobile) {
        final status = await Permission.location.request();
        if (!status.isGranted) {
          if (mounted) {
            setState(() {
              _statusMessage =
                  '\u672a\u83b7\u5f97\u5b9a\u4f4d\u6743\u9650\uff0c\u53ef\u624b\u52a8\u70b9\u9009\u5730\u56fe\u53d1\u9001\u4f4d\u7f6e';
            });
          }
          await _reverseGeocode(_center);
          return;
        }
      }

      final serviceEnabled = await isDeviceLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _statusMessage = PlatformUtils.isDesktop
                ? '\u7cfb\u7edf\u5b9a\u4f4d\u672a\u5f00\u542f\uff0c\u53ef\u624b\u52a8\u70b9\u9009\u5730\u56fe\u53d1\u9001\u5750\u6807'
                : '\u5b9a\u4f4d\u670d\u52a1\u672a\u5f00\u542f\uff0c\u53ef\u624b\u52a8\u70b9\u9009\u5730\u56fe\u53d1\u9001\u4f4d\u7f6e';
          });
        }
        await _reverseGeocode(_center);
        return;
      }

      final position = await getCurrentDeviceLocation();
      _center = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _statusMessage = null);
        _mapController.move(_center, 15);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = PlatformUtils.isDesktop
              ? '\u6682\u65f6\u65e0\u6cd5\u8bfb\u53d6\u7cfb\u7edf\u5b9a\u4f4d\uff0c\u53ef\u624b\u52a8\u70b9\u9009\u5730\u56fe\u53d1\u9001\u5750\u6807'
              : '\u6682\u65f6\u65e0\u6cd5\u83b7\u53d6\u5f53\u524d\u4f4d\u7f6e\uff0c\u53ef\u624b\u52a8\u70b9\u9009\u5730\u56fe\u53d1\u9001\u4f4d\u7f6e';
        });
      }
    }

    await _reverseGeocode(_center);
  }

  Future<void> _reverseGeocode(LatLng latlng) async {
    if (!mounted) {
      return;
    }

    setState(() => _loadingAddress = true);
    final address = await MapService.instance.reverseGeocode(latlng);
    if (!mounted) {
      return;
    }

    setState(() {
      _address = address;
      _keyword = address;
      _loadingAddress = false;
      _remoteMapAvailable = MapService.instance.isRemoteMapAvailable;
    });
  }

  Future<void> _searchLocation() async {
    final keyword = _keyword.trim();
    if (keyword.isEmpty) {
      return;
    }

    final latlng = await MapService.instance.searchLocation(keyword);
    if (latlng == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _remoteMapAvailable
                ? '\u672a\u627e\u5230\u5bf9\u5e94\u4f4d\u7f6e'
                : '\u5730\u56fe\u641c\u7d22\u670d\u52a1\u6682\u4e0d\u53ef\u7528\uff0c\u8bf7\u76f4\u63a5\u53d1\u9001\u5f53\u524d\u9009\u4e2d\u5750\u6807',
          ),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _center = latlng;
      _statusMessage = null;
    });
    _mapController.move(_center, 15);
    await _reverseGeocode(_center);
  }

  void _confirmLocation() {
    Navigator.of(context).pop({
      'latitude': _center.latitude,
      'longitude': _center.longitude,
      'title': _getShortAddress(_address),
      'address': _address,
    });
  }

  String _getShortAddress(String full) {
    final parts = full.split(RegExp('[,\uFF0C]'));
    if (parts.length >= 3) {
      return parts.sublist(0, 3).join('\uff0c');
    }
    return full;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('\u4f4d\u7f6e'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _loadCurrentLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '\u641c\u7d22\u5730\u70b9',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    onChanged: (value) => _keyword = value,
                    onSubmitted: (_) => _searchLocation(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchLocation,
                  child: const Text('\u641c\u7d22'),
                ),
              ],
            ),
          ),
          if (_statusMessage?.trim().isNotEmpty == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              color: Colors.white,
              child: Text(
                _statusMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                ColoredBox(
                  color: const Color(0xFFF5F5F5),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 15,
                      onTap: (tapPosition, latlng) {
                        setState(() {
                          _center = latlng;
                          _statusMessage = null;
                        });
                        _reverseGeocode(latlng);
                      },
                    ),
                    children: [
                      if (_remoteMapAvailable)
                        TileLayer(
                          urlTemplate:
                              MapService.instance.activeTileUrlTemplate,
                          userAgentPackageName: 'com.wukongim.app',
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _center,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _address,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_remoteMapAvailable)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '\u5730\u56fe\u5e95\u56fe\u8fde\u63a5\u8d85\u65f6\uff0c\u4ecd\u53ef\u53d1\u9001\u5f53\u524d\u9009\u4e2d\u5750\u6807',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_loadingAddress)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF07C160),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _confirmLocation,
                child: const Text(
                  '\u53d1\u9001\u4f4d\u7f6e',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
