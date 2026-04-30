import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

@immutable
class DeviceLocationPosition {
  const DeviceLocationPosition({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

Future<bool> isDeviceLocationServiceEnabled() {
  return Geolocator.isLocationServiceEnabled();
}

Future<DeviceLocationPosition> getCurrentDeviceLocation() async {
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
  return DeviceLocationPosition(
    latitude: position.latitude,
    longitude: position.longitude,
  );
}
