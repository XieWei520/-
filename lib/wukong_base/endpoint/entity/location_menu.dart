/// Location menu
/// 
/// Used for displaying or selecting location
class LocationMenu {
  /// Address text
  final String address;

  /// Longitude
  final double longitude;

  /// Latitude
  final double latitude;

  /// Location name (optional)
  final String? name;

  LocationMenu({
    required this.address,
    required this.longitude,
    required this.latitude,
    this.name,
  });
}
