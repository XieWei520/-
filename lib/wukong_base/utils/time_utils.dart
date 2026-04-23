import 'package:intl/intl.dart';

/// Time utilities
class WKTimeUtils {
  /// Format timestamp to readable time string
  ///
  /// Examples:
  /// - Today: "14:30"
  /// - Yesterday: "昨天 14:30"
  /// - This year: "06-01 14:30"
  /// - Other years: "2024-06-01"
  static String formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    String timeStr = DateFormat('HH:mm').format(date);

    if (dateOnly == today) {
      return timeStr;
    } else if (dateOnly == yesterday) {
      return '昨天 $timeStr';
    } else if (date.year == now.year) {
      return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $timeStr';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  /// Format timestamp to full date time string
  static String formatFullTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  /// Format timestamp to date string
  static String formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Format timestamp to time string only
  static String formatTimeOnly(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('HH:mm').format(date);
  }

  /// Get relative time string (e.g., "刚刚", "5分钟前", "2Сʱǰ")
  static String getRelativeTime(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}Сʱǰ';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return formatDate(timestamp);
    }
  }

  /// Get chat time header string
  static String getChatTimeHeader(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return '今天';
    } else if (dateOnly == yesterday) {
      return '昨天';
    } else if (date.year == now.year) {
      return '${date.month}月${date.day}日';
    } else {
      return '${date.year}年${date.month}月${date.day}日';
    }
  }

  /// Get current timestamp in seconds
  static int get currentTimestamp =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// Get current timestamp in milliseconds
  static int get currentTimestampMs => DateTime.now().millisecondsSinceEpoch;
}
