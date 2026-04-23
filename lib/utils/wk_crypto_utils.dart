import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';

/// Crypto utilities wrapper for wukong_base exports
class WKCryptoUtils {
  /// Generate MD5 hash
  static String md5(String input) {
    return crypto.md5.convert(utf8.encode(input)).toString();
  }

  /// Generate SHA256 hash
  static String sha256(String input) {
    return crypto.sha256.convert(utf8.encode(input)).toString();
  }
}
