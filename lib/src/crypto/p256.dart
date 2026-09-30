import 'dart:typed_data';

import 'package:pointycastle/api.dart' show PrivateKeyParameter, PublicKeyParameter;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256r1.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';

import './der.dart';
import './hashes.dart';

/// NIST P-256: the curve of every key in the LAN mode (device keys, the installation CA, the
/// server certificate, the pairing exchange). One curve, because it is the one every TLS stack,
/// WebCrypto and OS key store supports.
abstract final class P256 {
  static final ECDomainParameters domain = ECCurve_secp256r1();

  static BigInt get order => domain.n;

  static final BigInt _prime = BigInt.parse("ffffffff00000001000000000000000000000000ffffffffffffffffffffffff", radix: 16);

  static ECPoint get generator => domain.G;

  static const String keyOid = "1.2.840.10045.2.1";
  static const String curveOid = "1.2.840.10045.3.1.7";
  static const String ecdsaSha256Oid = "1.2.840.10045.4.3.2";

  /// A uniform scalar in `[1, n)`: 64 extra bits before the reduction make the bias negligible
  /// (NIST SP 800-56A).
  static BigInt randomScalar() => Der.toBigInt(Hashes.random(40)) % (order - BigInt.one) + BigInt.one;

  /// Decodes a SEC1 point and checks it is on the curve and not the identity. Every point a
  /// peer sends goes through here: an invalid point is how small-subgroup and invalid-curve
  /// attacks start.
  static ECPoint decodePoint(List<int> bytes) {
    final ECPoint? point;
    try {
      point = domain.curve.decodePoint(bytes);
    } catch (_) {
      throw const FormatException("Not a P-256 point");
    }

    if (point == null || point.isInfinity || !_onCurve(point)) throw const FormatException("Not a P-256 point");

    return point;
  }

  static bool _onCurve(ECPoint point) {
    final x = point.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    final q = _prime;
    final a = domain.curve.a!.toBigInteger()!;
    final b = domain.curve.b!.toBigInteger()!;

    return (y * y - (x * x * x + a * x + b)) % q == BigInt.zero;
  }

  /// Uncompressed SEC1 (`04 ‖ x ‖ y`), 65 bytes.
  static Uint8List encodePoint(ECPoint point) => point.getEncoded(false);

  /// The `SubjectPublicKeyInfo` of [point]: what a certificate carries and what fingerprints hash.
  static Uint8List spki(ECPoint point) => Der.sequence([
    Der.sequence([Der.oid(keyOid), Der.oid(curveOid)]),
    Der.bitString(encodePoint(point)),
  ]);

  /// The point inside a P-256 `SubjectPublicKeyInfo`.
  static ECPoint pointOfSpki(List<int> spki) {
    final outer = DerReader(spki).next(Der.tagSequence).children;
    final algorithm = outer.next(Der.tagSequence).children;

    if (algorithm.oid() != keyOid || algorithm.oid() != curveOid) throw const FormatException("Not a P-256 key");

    return decodePoint(outer.bitString());
  }

  /// Checks an ECDSA-SHA256 [signature] of [message] by [publicKey] (a point or an SPKI).
  /// [signature] is DER (`SEQUENCE {r, s}`, what TLS and X.509 use) or raw `r ‖ s`, 64 bytes
  /// (what WebCrypto produces).
  static bool verify(List<int> publicKey, List<int> message, List<int> signature) {
    try {
      final point = publicKey.length == 65 ? decodePoint(publicKey) : pointOfSpki(publicKey);
      final ECSignature parsed;

      if (signature.length == 64) {
        parsed = ECSignature(Der.toBigInt(signature.sublist(0, 32)), Der.toBigInt(signature.sublist(32)));
      } else {
        final reader = DerReader(signature).next(Der.tagSequence).children;
        parsed = ECSignature(reader.integer(), reader.integer());
        if (!reader.isEmpty) return false;
      }

      final signer = ECDSASigner(SHA256Digest())..init(false, PublicKeyParameter(ECPublicKey(point, domain)));

      return signer.verifySignature(Uint8List.fromList(message), parsed);
    } on FormatException {
      return false;
    }
  }
}

/// A P-256 key pair this side holds: a device's identity, the CA, the server certificate.
///
/// The private scalar only leaves as the PEM that `SecurityContext.usePrivateKeyBytes` needs,
/// and whoever stores that PEM stores it encrypted (the engine in its database, a client in
/// its OS key store).
final class EcKeyPair {
  EcKeyPair._(this._d) : publicKey = (P256.generator * _d)!;

  factory EcKeyPair.generate() => EcKeyPair._(P256.randomScalar());

  /// Reads a SEC1 `EC PRIVATE KEY` PEM, as [privateKeyPem] writes it.
  factory EcKeyPair.fromPem(String pem) {
    final key = DerReader(Pem.decode("EC PRIVATE KEY", pem)).next(Der.tagSequence).children;

    if (key.integer() != BigInt.one) throw const FormatException("Not a SEC1 key");

    final d = Der.toBigInt(key.next(Der.tagOctetString).value);
    if (d <= BigInt.zero || d >= P256.order) throw const FormatException("Not a P-256 key");

    return EcKeyPair._(d);
  }

  final BigInt _d;
  final ECPoint publicKey;

  Uint8List get spki => P256.spki(publicKey);

  /// SEC1 `EC PRIVATE KEY` with the curve and the public key, the form BoringSSL reads.
  String get privateKeyPem => Pem.encode(
    "EC PRIVATE KEY",
    Der.sequence([
      Der.smallInteger(1),
      Der.octetString(Der.fixed(_d, 32)),
      Der.explicit(0, Der.oid(P256.curveOid)),
      Der.explicit(1, Der.bitString(P256.encodePoint(publicKey))),
    ]),
  );

  /// ECDSA-SHA256 of [message], DER encoded. Deterministic (RFC 6979), so a weak random source
  /// can't leak the key through its nonces.
  Uint8List sign(List<int> message) {
    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
      ..init(true, PrivateKeyParameter(ECPrivateKey(_d, P256.domain)));
    final signature = signer.generateSignature(Uint8List.fromList(message)) as ECSignature;

    return Der.sequence([Der.integer(signature.r), Der.integer(signature.s)]);
  }
}

/// SHA-256 fingerprints, lowercase hex: how a certificate is named on a QR, in the devices list
/// and on the deny list.
abstract final class Fingerprint {
  static String of(List<int> der) => Hashes.hex(Hashes.sha256(der));

  /// `AB12 CD34 …`: the form people compare on two screens.
  static String display(String fingerprint) {
    final upper = fingerprint.toUpperCase();

    return [for (var i = 0; i < upper.length; i += 4) upper.substring(i, (i + 4).clamp(0, upper.length))].join(" ");
  }
}
