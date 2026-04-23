import 'crypto_utils.dart' as crypto;

/// Crypto utilities wrapper for wukong_base exports
class WKcryptoUtils {
  static String md5(String input) => crypto.WKCryptoUtils.md5(input);
  static String sha256(String input) => crypto.WKCryptoUtils.sha256(input);
}
