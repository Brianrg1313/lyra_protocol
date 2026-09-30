import 'dart:convert';
import 'dart:typed_data';

import './canonical_json.dart';
import './crypto/hashes.dart';
import './crypto/p256.dart';
import './crypto/spake2.dart';
import './hello.dart' show Version;
import './version.dart';

/// What the master's QR carries (`protocol-v1.md` §3): where it is, which CA it answers with,
/// and a one-use token that is the pairing secret when the camera is used. The camera reads the
/// master's own screen, so nothing on the network can swap the fingerprint.
final class PairingOffer {
  const PairingOffer({
    required this.instanceId,
    required this.addresses,
    required this.port,
    required this.caFingerprint,
    required this.token,
  });

  static const String scheme = "lyra-pair:";

  /// Reads a scanned QR. Anything else is a [FormatException].
  factory PairingOffer.parse(String text) {
    if (!text.startsWith(scheme)) throw const FormatException("Not a Lyra pairing QR");

    final Object? json;
    try {
      json = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(text.substring(scheme.length)))));
    } catch (_) {
      throw const FormatException("Not a Lyra pairing QR");
    }

    if (json is! Map<String, Object?> ||
        json["v"] != 1 ||
        json["instanceId"] is! String ||
        json["port"] is! int ||
        json["caFingerprint"] is! String ||
        json["token"] is! String ||
        json["addresses"] is! List ||
        (json["addresses"] as List).any((address) => address is! String)) {
      throw const FormatException("Not a Lyra pairing QR");
    }

    return PairingOffer(
      instanceId: json["instanceId"] as String,
      addresses: (json["addresses"] as List).cast<String>(),
      port: json["port"] as int,
      caFingerprint: json["caFingerprint"] as String,
      token: json["token"] as String,
    );
  }

  final String instanceId;

  /// Every address the master listens on, the likeliest first.
  final List<String> addresses;
  final int port;

  /// SHA-256 of the installation CA certificate ([Fingerprint.of]).
  final String caFingerprint;

  /// The pairing secret of the QR flow: 32 random bytes, base64url. It never travels on the
  /// network either; it is the SPAKE2 password, like the code.
  final String token;

  String encode() => scheme + base64Url.encode(utf8.encode(jsonEncode({
    "v": 1,
    "instanceId": instanceId,
    "addresses": addresses,
    "port": port,
    "caFingerprint": caFingerprint,
    "token": token,
  }))).replaceAll("=", "");
}

/// Which secret the device proves it holds.
enum PairingSecret {
  /// The 8-digit code, typed.
  code,

  /// The QR's token, scanned.
  token,
}

/// What a device says about itself when it pairs; it appears in "Devices" (`session.md`).
final class PairingDevice {
  const PairingDevice({required this.name, required this.platform, required this.appVersion});

  static const Set<String> platforms = {"windows", "macos", "linux", "android", "ios", "web"};

  /// Null when [json] is not a valid device (the master answers `bad_request`).
  static PairingDevice? tryParse(Object? json) {
    if (json is! Map) return null;

    final name = json["name"];
    final platform = json["platform"];
    final app = json["appVersion"];

    if (name is! String || name.trim().isEmpty || name.length > 64) return null;
    if (!platforms.contains(platform) || app is! String || Version.tryParse(app) == null) return null;

    return PairingDevice(name: name.trim(), platform: platform as String, appVersion: app);
  }

  final String name;
  final String platform;
  final String appVersion;

  bool get isWeb => platform == "web";

  Map<String, Object?> toJson() => {"name": name, "platform": platform, "appVersion": appVersion};
}

/// A device's identity key as the pairing needs it: its public key, and a way to sign.
///
/// Native devices hold an [EcKeyPair] ([LocalDeviceSigner]); a browser holds a non-extractable
/// WebCrypto key, whose signing is asynchronous and happens outside Dart.
abstract interface class DeviceSigner {
  Uint8List get spki;

  Future<Uint8List> sign(List<int> message);
}

final class LocalDeviceSigner implements DeviceSigner {
  const LocalDeviceSigner(this.key);

  final EcKeyPair key;

  @override
  Uint8List get spki => key.spki;

  @override
  Future<Uint8List> sign(List<int> message) async => key.sign(message);
}

/// The `/pair` conversation, both sides (`protocol-v1.md` §3). One JSON object per WebSocket
/// frame; every field after the SPAKE2 messages is MACed with a key only the two peers hold.
///
/// ```
/// master → device  {step: hello, instanceId, protocol}
/// device → master  {step: start, secret: code|token, pA}
/// master → device  {step: reply, pB}
/// device → master  {step: enroll, confirm, device, publicKey, proof, mac}
/// master → device  {step: paired, confirm, instanceId, caCertificate, serverFingerprint,
///                   certificate, deviceId, deviceCode, mac}
///                | {step: failed, code}
/// ```
abstract final class Pairing {
  static const String idDevice = "lyra-device";
  static const String aad = "lyra/pairing/v1";
  static const String macPurpose = "lyra/pairing/mac";
  static const String proofContext = "lyra/pairing/proof/v1";

  /// How long a code or a QR lasts (S-40).
  static const Duration lifetime = Duration(minutes: 5);

  /// Wrong exchanges before the code is void (S-40).
  static const int maxAttempts = 3;

  /// Refusal codes of `step: failed`.
  static const String failed = "pairing_failed";
  static const String expired = "pairing_expired";
  static const String noPairing = "pairing_closed";
  static const String badRequest = "bad_request";

  /// Adds the `mac` of [message] under [key].
  static Map<String, Object?> seal(Map<String, Object?> message, List<int> key) =>
    {...message, "mac": base64.encode(Hashes.hmacSha256(key, utf8.encode(canonicalJson(message))))};

  /// [message] without its `mac`, or null when the MAC doesn't check out.
  static Map<String, Object?>? open(Map<String, Object?> message, List<int> key) {
    final mac = message["mac"];
    if (mac is! String) return null;

    final body = {...message}..remove("mac");
    final expected = Hashes.hmacSha256(key, utf8.encode(canonicalJson(body)));

    try {
      return Hashes.equal(expected, base64.decode(mac)) ? body : null;
    } on FormatException {
      return null;
    }
  }

  /// What the device key signs: it binds the key to this exchange, so an enrolment can't carry
  /// somebody else's public key.
  static List<int> proofMessage(List<int> confirmA) => [...utf8.encode(proofContext), ...confirmA];

  /// A new 8-digit code (S-40), uniform over `00000000–99999999`.
  static String newCode() {
    final value = Hashes.random(8).fold<BigInt>(BigInt.zero, (sum, byte) => (sum << 8) | BigInt.from(byte));

    return (value % BigInt.from(100000000)).toString().padLeft(8, "0");
  }

  static String newToken() => base64Url.encode(Hashes.random(32)).replaceAll("=", "");
}

/// One side of a `/pair` connection as the device sees it.
abstract interface class PairingChannel {
  Future<Map<String, Object?>> receive();

  void send(Map<String, Object?> message);

  /// SHA-256 of the TLS certificate the server presented, or null where the platform
  /// validates it itself and doesn't show it (a browser, with the CA installed).
  String? get serverFingerprint;
}

/// What a paired device keeps.
final class PairingResult {
  const PairingResult({
    required this.instanceId,
    required this.deviceId,
    required this.deviceCode,
    required this.caCertificate,
    required this.certificate,
  });

  final String instanceId;
  final String deviceId;
  final String deviceCode;

  /// DER of the installation CA: the only root this device trusts for this master.
  final Uint8List caCertificate;

  /// DER of the device certificate for mutual TLS; null for a browser, which proves itself with
  /// `device.prove` instead.
  final Uint8List? certificate;
}

/// Why pairing stopped. [code] is a `Pairing` refusal, or `wrong_master` when the answer is
/// authentic but doesn't match what the device expected (another CA than the QR's, another
/// certificate than the one TLS showed: someone is in the middle).
final class PairingFailure implements Exception {
  const PairingFailure(this.code);

  static const String wrongMaster = "wrong_master";

  final String code;

  @override
  String toString() => "PairingFailure($code)";
}

/// Runs the device's side of `/pair`.
///
/// [offer] is the scanned QR (the token is the secret and its CA fingerprint is checked), or
/// null with [code] when the person typed it.
Future<PairingResult> pairDevice(
  PairingChannel channel, {
  required PairingDevice device,
  required DeviceSigner signer,
  PairingOffer? offer,
  String? code,
}) async {
  if ((offer == null) == (code == null)) throw ArgumentError("Pair with a QR or with a code");

  final hello = await channel.receive();
  final instanceId = hello["instanceId"];

  if (hello["step"] != "hello" || instanceId is! String) throw const PairingFailure(Pairing.badRequest);
  if (hello["protocol"] != protocolVersion) throw const PairingFailure(Pairing.badRequest);
  // A QR names its master; another one answering is not the one on the screen.
  if (offer != null && offer.instanceId != instanceId) throw const PairingFailure(PairingFailure.wrongMaster);

  final w = Spake2.passwordScalar(offer?.token ?? code!, instanceId: instanceId);
  final spake = Spake2.a(w, idA: Pairing.idDevice, idB: instanceId, aad: Pairing.aad);

  channel.send({
    "step": "start",
    "secret": offer != null ? PairingSecret.token.name : PairingSecret.code.name,
    "pA": base64.encode(spake.message),
  });

  final reply = await channel.receive();
  if (reply["step"] == "failed") throw PairingFailure(reply["code"] as String? ?? Pairing.failed);

  final pB = reply["pB"];
  if (reply["step"] != "reply" || pB is! String) throw const PairingFailure(Pairing.badRequest);

  final Spake2Keys keys;
  try {
    keys = spake.finish(base64.decode(pB));
  } on FormatException {
    throw const PairingFailure(Pairing.failed);
  }

  final macKey = keys.derive(Pairing.macPurpose);
  final proof = await signer.sign(Pairing.proofMessage(keys.confirmation));

  channel.send(Pairing.seal({
    "step": "enroll",
    "confirm": base64.encode(keys.confirmation),
    "device": device.toJson(),
    "publicKey": base64.encode(signer.spki),
    "proof": base64.encode(proof),
  }, macKey));

  final answer = await channel.receive();
  if (answer["step"] == "failed") throw PairingFailure(answer["code"] as String? ?? Pairing.failed);

  final paired = Pairing.open(answer, macKey);
  final confirm = paired?["confirm"];

  // Without the master's confirmation nothing it said is trusted, including a certificate.
  if (paired == null || paired["step"] != "paired" || confirm is! String || !keys.checkPeer(base64.decode(confirm))) {
    throw const PairingFailure(Pairing.failed);
  }

  final caText = paired["caCertificate"];
  final serverFingerprint = paired["serverFingerprint"];
  final certificate = paired["certificate"];
  final deviceId = paired["deviceId"];
  final deviceCode = paired["deviceCode"];

  if (caText is! String || deviceId is! String || deviceCode is! String || (certificate != null && certificate is! String)) {
    throw const PairingFailure(Pairing.badRequest);
  }

  final ca = base64.decode(caText);

  if (paired["instanceId"] != instanceId) throw const PairingFailure(PairingFailure.wrongMaster);
  if (offer != null && Fingerprint.of(ca) != offer.caFingerprint) {
    throw const PairingFailure(PairingFailure.wrongMaster);
  }
  // The master says which certificate it serves; TLS showed us one. If they differ, the TLS
  // connection ends somewhere else (a proxy in the middle), even though the code was right.
  if (channel.serverFingerprint != null && serverFingerprint != channel.serverFingerprint) {
    throw const PairingFailure(PairingFailure.wrongMaster);
  }

  return PairingResult(
    instanceId: instanceId,
    deviceId: deviceId,
    deviceCode: deviceCode,
    caCertificate: ca,
    certificate: certificate == null ? null : base64.decode(certificate as String),
  );
}

/// What a browser signs to prove, on each `/rpc` connection, that it is a paired device
/// (`device.prove`, `protocol-v1.md` §3). Browsers can't present client certificates reliably,
/// so the master sends a fresh challenge in the `hello` answer and checks the signature with
/// the public key registered at pairing.
abstract final class DeviceProof {
  static const String context = "lyra/device/prove/v1";

  static List<int> message(String instanceId, List<int> challenge) =>
    [...utf8.encode(context), 0, ...utf8.encode(instanceId), 0, ...challenge];
}
