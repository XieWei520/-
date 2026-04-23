import 'dart:convert';
import 'package:uuid/uuid.dart';

/// String utilities
class WKStringUtils {
  /// Check if string is empty
  static bool isEmpty(String? str) {
    return str == null || str.isEmpty;
  }

  /// Check if string is not empty
  static bool isNotEmpty(String? str) {
    return !isEmpty(str);
  }

  /// Generate UUID v4
  static String generateUUID() {
    return const Uuid().v4();
  }

  /// Generate short UUID
  static String generateShortUUID() {
    return const Uuid().v4().substring(0, 8);
  }

  /// MD5 hash
  static String md5(String input) {
    // Use crypto package
    return input; // Placeholder, implement with crypto package
  }

  /// Base64 encode
  static String base64Encode(String input) {
    return base64.encode(utf8.encode(input));
  }

  /// Base64 decode
  static String base64Decode(String input) {
    return utf8.decode(base64.decode(input));
  }

  /// Truncate string with ellipsis
  static String truncate(String str, int maxLength, {String ellipsis = '...'}) {
    if (str.length <= maxLength) return str;
    return '${str.substring(0, maxLength)}$ellipsis';
  }

  /// Mask phone number (e.g., 138****5678)
  static String maskPhone(String phone) {
    if (phone.length < 7) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }

  /// Format phone number with spaces
  static String formatPhoneNumber(String phone) {
    if (phone.length == 11) {
      return '${phone.substring(0, 3)} ${phone.substring(3, 7)} ${phone.substring(7)}';
    }
    return phone;
  }

  /// Get initials from name (max 2 characters)
  static String getInitials(String name, {int maxLength = 2}) {
    if (isEmpty(name)) return '';
    
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    
    // Try to get Chinese pinyin initials
    final words = trimmed.split(RegExp(r'[\s_-]+'));
    if (words.length > 1) {
      final initials = words.take(maxLength).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
      if (initials.length >= maxLength) return initials;
    }
    
    // For Chinese names, get first character
    if (trimmed.length >= 2) {
      return trimmed.substring(0, maxLength);
    }
    
    return trimmed.substring(0, 1).toUpperCase();
  }

  /// Check if string is numeric
  static bool isNumeric(String str) {
    if (isEmpty(str)) return false;
    return double.tryParse(str) != null;
  }

  /// Check if string is a valid email
  static bool isEmail(String str) {
    if (isEmpty(str)) return false;
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(str);
  }

  /// Check if string is a valid phone number
  static bool isPhone(String str) {
    if (isEmpty(str)) return false;
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(str);
  }

  /// Remove whitespace from string
  static String removeWhitespace(String str) {
    return str.replaceAll(RegExp(r'\s+'), '');
  }

  /// Escape HTML entities
  static String escapeHtml(String str) {
    return str
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Unescape HTML entities
  static String unescapeHtml(String str) {
    return str
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  /// Convert null to empty string
  static String nullToEmpty(String? str) {
    return str ?? '';
  }
}
