import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;

/// Provides encryption and decryption utilities.
class WKCryptoUtils {
  /// MD5 hash
  static String md5(String input) {
    return crypto.md5.convert(utf8.encode(input)).toString();
  }

  /// SHA256 hash
  static String sha256(String input) {
    return crypto.sha256.convert(utf8.encode(input)).toString();
  }

  /// Generate random string
  static String generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Generate random bytes
  static Uint8List generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Base64 encode
  static String base64EncodeString(String input) {
    return base64.encode(utf8.encode(input));
  }

  /// Base64 decode
  static String base64DecodeString(String input) {
    return utf8.decode(base64.decode(input));
  }

  /// Base64 encode bytes
  static String base64EncodeBytes(Uint8List bytes) {
    return base64.encode(bytes);
  }

  /// Base64 decode to bytes
  static Uint8List base64DecodeBytes(String input) {
    return Uint8List.fromList(base64.decode(input));
  }

  /// Hex encode
  static String hexEncode(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hex decode
  static Uint8List hexDecode(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(result);
  }

  /// Simple XOR encryption (for educational purposes only)
  /// Note: For production, use proper encryption libraries
  static String simpleXorEncrypt(String input, String key) {
    final inputBytes = utf8.encode(input);
    final keyBytes = utf8.encode(key);
    final output = <int>[];
    
    for (var i = 0; i < inputBytes.length; i++) {
      output.add(inputBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return base64.encode(Uint8List.fromList(output));
  }

  /// Simple XOR decryption
  static String simpleXorDecrypt(String encrypted, String key) {
    final encryptedBytes = base64.decode(encrypted);
    final keyBytes = utf8.encode(key);
    final output = <int>[];
    
    for (var i = 0; i < encryptedBytes.length; i++) {
      output.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return utf8.decode(Uint8List.fromList(output));
  }
}
