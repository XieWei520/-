/// Represents a user device for login management.
class Device {
  final String id;
  final String name;
  final String model;
  final String os;
  final String appVersion;
  final DateTime lastActiveAt;
  final bool isCurrent;
  final bool isLocked;
  final String? ipAddress;
  final String? location;

  Device({
    required this.id,
    required this.name,
    required this.model,
    required this.os,
    required this.appVersion,
    required this.lastActiveAt,
    required this.isCurrent,
    required this.isLocked,
    this.ipAddress,
    this.location,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Device',
      model: json['model']?.toString() ?? '',
      os: _parseOS(json['os']),
      appVersion: json['app_version']?.toString() ?? '',
      lastActiveAt: _parseDateTime(json['last_active_at']),
      isCurrent: json['is_current'] == true || json['isCurrent'] == true,
      isLocked: json['is_locked'] == true || json['isLocked'] == true,
      ipAddress: json['ip_address']?.toString() ?? json['ip']?.toString(),
      location: json['location']?.toString(),
    );
  }

  static String _parseOS(dynamic osValue) {
    if (osValue == null) return 'Unknown';
    if (osValue is int) {
      // 0=Android, 1=iOS, 2=Windows, 3=macOS, 4=Linux, 5=Web
      switch (osValue) {
        case 0:
          return 'Android';
        case 1:
          return 'iOS';
        case 2:
          return 'Windows';
        case 3:
          return 'macOS';
        case 4:
          return 'Linux';
        case 5:
          return 'Web';
        default:
          return 'Unknown';
      }
    }
    return osValue.toString();
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) {
      // Unix timestamp in seconds
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// Returns a human-readable description of the device.
  String get description {
    final parts = <String>[];
    if (model.isNotEmpty) parts.add(model);
    if (os.isNotEmpty && os != 'Unknown') parts.add(os);
    if (appVersion.isNotEmpty) parts.add('v$appVersion');
    return parts.join(' • ');
  }

  /// Returns the last active time as a relative string (e.g., "2 hours ago").
  String get lastActiveRelative {
    final now = DateTime.now();
    final difference = now.difference(lastActiveAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model': model,
      'os': os,
      'app_version': appVersion,
      'last_active_at': lastActiveAt.toIso8601String(),
      'is_current': isCurrent,
      'is_locked': isLocked,
      'ip_address': ipAddress,
      'location': location,
    };
  }
}
