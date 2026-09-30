import 'dart:convert';

import './crypto/hashes.dart';

/// How a master shows up on the LAN with mDNS / DNS-SD (plan §5.2).
///
/// The advertisement carries **only** a random-looking id and the port: nothing about the
/// company, and not the instance id itself (a UUIDv7 would tell when the master was set up).
/// Discovery is a hint: trust comes from pairing, so a spoofed answer at most gets a refused
/// connection.
abstract final class Discovery {
  static const String serviceType = "_lyra._tcp.local";

  /// The id a master advertises, derived from its instance id so a client that paired can
  /// recognise its own master among several.
  static String advertisedId(String instanceId) =>
    Hashes.hex(Hashes.sha256(utf8.encode("lyra/mdns/v1\u0000$instanceId"))).substring(0, 12);

  /// The DNS-SD instance name (`lyra-<id>._lyra._tcp.local`).
  static String instanceName(String instanceId) => "lyra-${advertisedId(instanceId)}.$serviceType";
}
