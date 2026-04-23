import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto_lib;

class CryptoUtils {
  CryptoUtils._();

  /// MD5加密
  static String md5(String input) {
    return crypto_lib.md5.convert(utf8.encode(input)).toString();
  }

  /// SHA256加密
  static String sha256(String input) {
    return crypto_lib.sha256.convert(utf8.encode(input)).toString();
  }

  /// 生成随机字符串
  static String generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[(random + i * 7) % chars.length]);
    }
    return buffer.toString();
  }

  /// 验证签名
  static bool verifySignature(String data, String signature, String secret) {
    final expectedSignature = md5('$data$secret');
    return expectedSignature == signature;
  }

  /// 生成签名
  static String generateSignature(String data, String secret) {
    return md5('$data$secret');
  }
}
