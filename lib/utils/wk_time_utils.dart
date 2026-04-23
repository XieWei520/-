/// Time utilities
class WKTimeUtils {
  /// Format timestamp to readable string
  static String formatTime(int timestamp) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toString();
  }

  /// Format timestamp to chat time (HH:mm)
  static String formatChatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Get current timestamp
  static int now() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }
}
