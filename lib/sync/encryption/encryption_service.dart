import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Simple encryption service for sync data.
/// Uses AES-like encryption via crypto package for hashing.
/// For full AES encryption, add the `encrypt` package later.
class EncryptionService {
  bool _enabled = false;
  String _key = '';

  bool get isEnabled => _enabled;

  /// Enable encryption with a key
  void enable(String key) {
    _enabled = true;
    // Pad/truncate key to 32 chars for consistency
    _key = key.padRight(32, '0').substring(0, 32);
  }

  /// Disable encryption
  void disable() {
    _enabled = false;
    _key = '';
  }

  /// Encrypt content (if enabled)
  /// Currently uses base64 encoding as a placeholder.
  /// Replace with AES encryption when `encrypt` package is added.
  String encrypt(String plainText) {
    if (!_enabled) return plainText;
    // Simple obfuscation with base64 + key-based XOR
    final keyBytes = utf8.encode(_key);
    final plainBytes = utf8.encode(plainText);
    final encrypted = <int>[];
    for (int i = 0; i < plainBytes.length; i++) {
      encrypted.add(plainBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return base64Encode(encrypted);
  }

  /// Decrypt content (if enabled)
  String decrypt(String cipherText) {
    if (!_enabled) return cipherText;
    try {
      final keyBytes = utf8.encode(_key);
      final encrypted = base64Decode(cipherText);
      final decrypted = <int>[];
      for (int i = 0; i < encrypted.length; i++) {
        decrypted.add(encrypted[i] ^ keyBytes[i % keyBytes.length]);
      }
      return utf8.decode(decrypted);
    } catch (e) {
      // If decryption fails, return as-is (might be unencrypted)
      return cipherText;
    }
  }

  /// Hash a password/key for storage
  String hashKey(String key) {
    final bytes = utf8.encode(key);
    return sha256.convert(bytes).toString();
  }

  /// Verify a key against a hash
  bool verifyKey(String key, String hash) {
    return hashKey(key) == hash;
  }
}
