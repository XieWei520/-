/// String utilities
class WKStringUtils {
  /// Check if string is empty
  static bool isEmpty(String? str) {
    return str == null || str.isEmpty;
  }

  /// Check if string is not empty
  static bool isNotEmpty(String? str) {
    return str != null && str.isNotEmpty;
  }

  /// Get initials from name
  static String getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}
