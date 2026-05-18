import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

import 'package:x25519/x25519.dart';

class CryptoUtils {
  static String aesKey = "";
  static String salt = "";
  static List<int>? dhPrivateKey;
  static List<int>? dhPublicKey;

  static init() {
    var keyPair = generateKeyPair();
    dhPrivateKey = keyPair.privateKey;
    dhPublicKey = keyPair.publicKey;
  }

  static generateMD5(String content) {
    return md5.convert(utf8.encode(content)).toString();
  }

  static setServerKeyAndSalt(String serverKey, String salt) {
    CryptoUtils.salt = salt;
    var sharedSecret = X25519(dhPrivateKey!, base64Decode(serverKey));
    var key = generateMD5(base64Encode(sharedSecret));
    if (key != "" && key.length > 16) {
      aesKey = key.substring(0, 16);
    } else {
      aesKey = key;
    }
  }

  static Uint8List _utf8Bytes(String value) {
    return Uint8List.fromList(utf8.encode(value));
  }

  static IV _buildIv() {
    final ivBytes = _utf8Bytes(salt);
    if (ivBytes.length != 16) {
      throw ArgumentError(
          "AES IV must be 16 bytes after UTF-8 encoding, got ${ivBytes.length}");
    }
    return IV(ivBytes);
  }

  static Key _buildKey() {
    final keyBytes = _utf8Bytes(aesKey);
    if (keyBytes.length != 16 &&
        keyBytes.length != 24 &&
        keyBytes.length != 32) {
      throw ArgumentError(
          "AES key must be 16/24/32 bytes after UTF-8 encoding, got ${keyBytes.length}");
    }
    return Key(keyBytes);
  }

  // 鍔犲瘑
  static String aesEncrypt(String content) {
    final iv = _buildIv();
    final key = _buildKey();
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.encrypt(content, iv: iv).base64;
  }

  // 瑙ｅ瘑
  static String aesDecrypt(String content) {
    final iv = _buildIv();
    final key = _buildKey();
    var encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    Encrypted encrypted = Encrypted(base64Decode(content));
    var decrypted = encrypter.decrypt(encrypted, iv: iv);
    return decrypted;
  }
}
