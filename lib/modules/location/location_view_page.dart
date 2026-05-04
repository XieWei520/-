import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/map_service.dart';
import '../../data/models/wk_custom_content.dart';

class LocationViewPage extends StatefulWidget {
  final WKLocationContent location;

  const LocationViewPage({super.key, required this.location});

  @override
  State<LocationViewPage> createState() => _LocationViewPageState();
}

class _LocationViewPageState extends State<LocationViewPage> {
  bool _remoteMapAvailable = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final available = await MapService.instance.ensureRemoteMapAvailable(
      forceRefresh: true,
    );
    if (!mounted) {
      return;
    }
    setState(() => _remoteMapAvailable = available);
  }

  @override
  Widget build(BuildContext context) {
    final latlng = LatLng(widget.location.latitude, widget.location.longitude);
    return Scaffold(
      appBar: AppBar(
        title: const Text('\u4f4d\u7f6e'),
        actions: [
          IconButton(
            icon: const Icon(Icons.navigation),
            onPressed: () => _openInMaps(latlng),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ColoredBox(
                  color: const Color(0xFFF5F5F5),
                  child: FlutterMap(
                    options: MapOptions(initialCenter: latlng, initialZoom: 15),
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
                            point: latlng,
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
                              '\u5730\u56fe\u5e95\u56fe\u8fde\u63a5\u8d85\u65f6\uff0c\u5df2\u5207\u6362\u4e3a\u5750\u6807\u67e5\u770b\u6a21\u5f0f',
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
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.location.title.isNotEmpty) ...[
                  Text(
                    widget.location.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  widget.location.address.isNotEmpty
                      ? widget.location.address
                      : MapService.instance.formatCoordinateAddress(latlng),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.directions),
                        label: const Text('\u5bfc\u822a'),
                        onPressed: () => _openInMaps(latlng),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text('\u5206\u4eab'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF07C160),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _shareLocation(latlng),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInMaps(LatLng latlng) async {
    final url = Uri.parse(
      'https://www.openstreetmap.org/?mlat=${latlng.latitude}&mlon=${latlng.longitude}#map=15/${latlng.latitude}/${latlng.longitude}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _shareLocation(LatLng latlng) {
    debugPrint('Share location: ${latlng.latitude}, ${latlng.longitude}');
  }
}
