import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/digests/sha512.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/api.dart' show KeyParameter;

/// The hash primitives the pairing and the device keys use, all SHA-2.
abstract final class Hashes {
  static Uint8List sha256(List<int> data) => SHA256Digest().process(Uint8List.fromList(data));

  static Uint8List sha512(List<int> data) => SHA512Digest().process(Uint8List.fromList(data));

  static Uint8List hmacSha256(List<int> key, List<int> data) {
    final mac = HMac(SHA256Digest(), 64)..init(KeyParameter(Uint8List.fromList(key)));

    return mac.process(Uint8List.fromList(data));
  }

  /// HKDF-SHA256 (RFC 5869). An empty [salt] is the hash length of zeros, as the RFC says.
  static Uint8List hkdf(List<int> ikm, {List<int> salt = const [], List<int> info = const [], int length = 32}) {
    final prk = hmacSha256(salt.isEmpty ? Uint8List(32) : salt, ikm);
    final out = BytesBuilder();
    var block = Uint8List(0);

    for (var i = 1; out.length < length; i++) {
      block = hmacSha256(prk, [...block, ...info, i]);
      out.add(block);
    }

    return Uint8List.sublistView(out.takeBytes(), 0, length);
  }

  /// Compares in time that depends only on the lengths (a MAC check must not leak where it
  /// differs).
  static bool equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;

    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }

    return diff == 0;
  }

  static final Random _random = Random.secure();

  static Uint8List random(int length) => Uint8List.fromList([for (var i = 0; i < length; i++) _random.nextInt(256)]);

  static String hex(List<int> bytes) => [for (final byte in bytes) byte.toRadixString(16).padLeft(2, "0")].join();

  static Uint8List fromHex(String hex) {
    if (hex.length.isOdd) throw const FormatException("odd hex length");

    return Uint8List.fromList([for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)]);
  }
}
