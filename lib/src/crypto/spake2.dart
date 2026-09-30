import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/ecc/api.dart';

import './der.dart';
import './hashes.dart';
import './p256.dart';

/// SPAKE2 over P-256 (RFC 9382, ciphersuite P256-SHA256-HKDF-HMAC): how a device and the master
/// prove they typed or scanned the same pairing secret without sending it (`protocol-v1.md` §3).
///
/// An attacker in the middle gets **one guess per exchange** and learns nothing it can test
/// offline; three failed exchanges void the code (S-40). The device is party A (it speaks first
/// and uses M), the master party B (N).
///
/// Chosen over CPace because RFC 9382 is a final RFC with test vectors for exactly this suite
/// (`test/crypto_test.dart` runs them), and it needs only point arithmetic, which
/// `pointycastle` has; CPace needs hash-to-curve, which no vetted Dart library offers.
final class Spake2 {
  Spake2._(this._role, this._w, this._x, this._idA, this._idB, this._aad) {
    final blind = (_role == _Role.a ? _m : _n) * _w;
    _message = P256.encodePoint(((P256.generator * _x)! + blind)!);
  }

  /// The device's side. [x] is fixed only by the RFC's test vectors.
  factory Spake2.a(BigInt w, {required String idA, required String idB, String aad = "", BigInt? x}) =>
    Spake2._(_Role.a, w, x ?? P256.randomScalar(), idA, idB, aad);

  /// The master's side. [y] is fixed only by the RFC's test vectors.
  factory Spake2.b(BigInt w, {required String idA, required String idB, String aad = "", BigInt? y}) =>
    Spake2._(_Role.b, w, y ?? P256.randomScalar(), idA, idB, aad);

  static final ECPoint _m = P256.decodePoint(
    Hashes.fromHex("02886e2f97ace46e55ba9dd7242579f2993b64e16ef3dcab95afd497333d8fa12f"),
  );
  static final ECPoint _n = P256.decodePoint(
    Hashes.fromHex("03d8bbd6c639c62937b04d997f38c3770719c629d7014d49a24b4f98baa1292b49"),
  );

  /// `w` for a pairing secret (the 8-digit code, or the QR's token), bound to the master it
  /// pairs with. SHA-512 reduced mod n, 256 extra bits against bias (RFC 9382 §3.2).
  ///
  /// RFC 9382 recommends a memory-hard function here. It protects a **stored** verifier; the
  /// master stores none (a code lives 5 minutes in memory), and online guesses are capped at
  /// three, so a slow hash would only slow a phone down.
  static BigInt passwordScalar(String secret, {required String instanceId}) {
    final input = BytesBuilder()
      ..add(_lengthPrefixed(utf8.encode("lyra/pairing/v1")))
      ..add(_lengthPrefixed(utf8.encode(instanceId)))
      ..add(_lengthPrefixed(utf8.encode(secret)));

    return Der.toBigInt(Hashes.sha512(input.takeBytes())) % P256.order;
  }

  final _Role _role;
  final BigInt _w;
  final BigInt _x;
  final String _idA;
  final String _idB;
  final String _aad;
  late final Uint8List _message;

  /// `pA` or `pB`: the only thing this side sends before the confirmations.
  Uint8List get message => _message;

  /// Mixes in the peer's message. A peer point that isn't on the curve, or that makes `K` the
  /// identity, is a [FormatException] (and counts as a failed attempt for the caller).
  Spake2Keys finish(List<int> peerMessage) {
    final peer = P256.decodePoint(peerMessage);
    final unblind = (_role == _Role.a ? _n : _m) * _w;
    final k = ((peer - unblind!)! * _x)!;

    if (k.isInfinity) throw const FormatException("SPAKE2: degenerate exchange");

    final pA = _role == _Role.a ? _message : Uint8List.fromList(peerMessage);
    final pB = _role == _Role.a ? Uint8List.fromList(peerMessage) : _message;
    final transcript = BytesBuilder()
      ..add(_lengthPrefixed(utf8.encode(_idA)))
      ..add(_lengthPrefixed(utf8.encode(_idB)))
      ..add(_lengthPrefixed(pA))
      ..add(_lengthPrefixed(pB))
      ..add(_lengthPrefixed(P256.encodePoint(k)))
      ..add(_lengthPrefixed(Der.fixed(_w, 32)));
    final tt = transcript.takeBytes();
    final hash = Hashes.sha256(tt);
    final kc = Hashes.hkdf(
      hash.sublist(16),
      info: [...utf8.encode("ConfirmationKeys"), ...utf8.encode(_aad)],
      length: 32,
    );

    return Spake2Keys._(
      role: _role,
      sharedKey: hash.sublist(0, 16),
      confirmA: Hashes.hmacSha256(kc.sublist(0, 16), tt),
      confirmB: Hashes.hmacSha256(kc.sublist(16), tt),
    );
  }

  static Uint8List _lengthPrefixed(List<int> bytes) {
    final length = ByteData(8)..setUint64(0, bytes.length, Endian.little);

    return Uint8List.fromList([...length.buffer.asUint8List(), ...bytes]);
  }
}

enum _Role { a, b }

/// What both sides agree on after [Spake2.finish]. [sharedKey] is only usable once the peer's
/// confirmation checked out ([checkPeer]).
final class Spake2Keys {
  Spake2Keys._({required _Role role, required this.sharedKey, required this.confirmA, required this.confirmB})
    : _role = role;

  final _Role _role;

  /// `Ke`, 16 bytes. Keys for the rest of the pairing are derived from it ([derive]).
  final Uint8List sharedKey;

  final Uint8List confirmA;
  final Uint8List confirmB;

  /// This side's confirmation, to send.
  Uint8List get confirmation => _role == _Role.a ? confirmA : confirmB;

  /// Whether the peer's confirmation proves it holds the same secret.
  bool checkPeer(List<int> confirmation) => Hashes.equal(_role == _Role.a ? confirmB : confirmA, confirmation);

  /// A 32-byte key for [purpose] (`"lyra/pairing/mac"`…), from [sharedKey].
  Uint8List derive(String purpose) => Hashes.hkdf(sharedKey, info: utf8.encode(purpose));
}
