/// Hashing helpers for publication fingerprinting.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashUtils {
  HashUtils._();

  /// Computes a SHA-256 fingerprint hex string from raw bytes.
  static String sha256Bytes(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Computes a SHA-256 fingerprint hex string from text.
  static String sha256Text(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }
}
