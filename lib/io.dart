/// Native (`dart:io`) connections to a master: the pinned, mutual-TLS `/rpc` socket and the
/// `/pair` socket. Separate from `lyra_protocol.dart` so the web build never imports `dart:io`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'lyra_protocol.dart';

/// What a paired native device holds to reach its master (`protocol-v1.md` §3).
final class LanIdentity {
  const LanIdentity({required this.caCertificate, required this.certificate, required this.privateKeyPem});

  /// DER of the installation CA. The **only** root trusted for this master: the OS store is
  /// never consulted, so no other CA on this computer can vouch for someone in the middle.
  final Uint8List caCertificate;

  /// DER of this device's certificate, signed by that CA.
  final Uint8List certificate;
  final String privateKeyPem;

  SecurityContext get context => SecurityContext(withTrustedRoots: false)
    ..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_3
    ..setTrustedCertificatesBytes(utf8.encode(Pem.encode("CERTIFICATE", caCertificate)))
    ..useCertificateChainBytes(utf8.encode(Pem.encode("CERTIFICATE", certificate)))
    ..usePrivateKeyBytes(utf8.encode(privateKeyPem));
}

/// Opens `/rpc` on [host]:[port] with mutual TLS, pinned to [identity]'s CA.
///
/// TLS fails (a [HandshakeException]) when the server's certificate doesn't chain to that CA or
/// doesn't name [host]; the master refuses the upgrade when this device is revoked.
Future<RpcClient> connectRpc(
  String host,
  int port,
  LanIdentity identity, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final client = HttpClient(context: identity.context)..connectionTimeout = timeout;
  final socket = await WebSocket.connect(_url(host, port, "/rpc"), customClient: client).timeout(timeout);

  socket.pingInterval = const Duration(seconds: 20);

  return RpcClient(_IoFrameSocket(socket));
}

/// Opens `/pair` on [host]:[port]. The device has no trust yet, so **any** certificate is let
/// through here and recorded ([PairingChannel.serverFingerprint]); `pairDevice` then trusts
/// nothing the master says until SPAKE2 authenticated it, and compares that certificate.
Future<IoPairingChannel> connectPairing(String host, int port, {Duration timeout = const Duration(seconds: 10)}) async {
  String? seen;
  final context = SecurityContext(withTrustedRoots: false)..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_3;
  final client = HttpClient(context: context)
    ..connectionTimeout = timeout
    ..badCertificateCallback = (certificate, _, _) {
      seen = Fingerprint.of(certificate.der);
      return true;
    };
  final socket = await WebSocket.connect(_url(host, port, "/pair"), customClient: client).timeout(timeout);

  return IoPairingChannel._(socket, seen);
}

String _url(String host, int port, String path) {
  final address = InternetAddress.tryParse(host);
  final authority = address?.type == InternetAddressType.IPv6 ? "[$host]" : host;

  return "wss://$authority:$port$path";
}

/// `/pair` over a `dart:io` WebSocket.
final class IoPairingChannel implements PairingChannel {
  IoPairingChannel._(this._socket, this.serverFingerprint) {
    _socket.listen(
      (frame) {
        try {
          final json = frame is String ? jsonDecode(frame) : null;
          if (json is Map<String, Object?>) _incoming.add(json);
        } on FormatException {
          // Ignored: the step that waits for it times out or fails.
        }
      },
      onDone: _incoming.close,
      onError: (_) => _incoming.close(),
    );
  }

  final WebSocket _socket;
  final StreamController<Map<String, Object?>> _incoming = StreamController();
  late final StreamIterator<Map<String, Object?>> _reader = StreamIterator(_incoming.stream);

  @override
  final String? serverFingerprint;

  @override
  Future<Map<String, Object?>> receive() async {
    if (!await _reader.moveNext().timeout(const Duration(seconds: 30))) {
      throw const PairingFailure(Pairing.noPairing);
    }

    return _reader.current;
  }

  @override
  void send(Map<String, Object?> message) => _socket.add(jsonEncode(message));

  Future<void> close() => _socket.close();
}

final class _IoFrameSocket implements FrameSocket {
  _IoFrameSocket(this._socket);

  final WebSocket _socket;

  @override
  Stream<String> get frames => _socket.where((frame) => frame is String).cast<String>();

  @override
  void send(String frame) => _socket.add(frame);

  @override
  Future<void> close() => _socket.close();
}
