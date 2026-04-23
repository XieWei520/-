import 'package:permission_handler/permission_handler.dart';

/// Authoritative permission utilities shared across the app.
class WKPermissions {
  /// Request camera permission
  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request microphone permission
  static Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request storage permission
  static Future<bool> requestStorage() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Request photos permission (iOS)
  static Future<bool> requestPhotos() async {
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  /// Request location permission
  static Future<bool> requestLocation() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Request notification permission
  static Future<bool> requestNotification() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Request multiple permissions at once
  static Future<Map<Permission, PermissionStatus>> requestMultiple(
    List<Permission> permissions,
  ) async {
    return await permissions.request();
  }

  /// Check if camera permission is granted
  static Future<bool> isCameraGranted() async {
    return await Permission.camera.isGranted;
  }

  /// Check if microphone permission is granted
  static Future<bool> isMicrophoneGranted() async {
    return await Permission.microphone.isGranted;
  }

  /// Check if storage permission is granted
  static Future<bool> isStorageGranted() async {
    return await Permission.storage.isGranted;
  }

  /// Check if location permission is granted
  static Future<bool> isLocationGranted() async {
    return await Permission.location.isGranted;
  }

  /// Check if notification permission is granted
  static Future<bool> isNotificationGranted() async {
    return await Permission.notification.isGranted;
  }

  /// Check if permission is permanently denied
  static Future<bool> isPermanentlyDenied(Permission permission) async {
    return await permission.isPermanentlyDenied;
  }

  /// Open app settings
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Request camera and microphone together (for video calls)
  static Future<bool> requestCameraAndMicrophone() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();
    return cameraStatus.isGranted && micStatus.isGranted;
  }

  /// Request storage and photos together (for media access)
  static Future<bool> requestMediaAccess() async {
    final storageStatus = await Permission.storage.request();
    final photosStatus = await Permission.photos.request();
    return storageStatus.isGranted || photosStatus.isGranted;
  }
}
