import 'dart:convert';
import 'dart:typed_data';

/// Whether the master can serve data (`protocol-v1.md` §4).
enum EngineState {
  /// Keys are loaded: every op is served.
  ready,

  /// Passphrase mode and nobody has unlocked it yet: only `hello` and, from the master's own
  /// device, `engine.unlock` are answered; everything else is `locked`.
  locked;

  static EngineState? byName(Object? name) {
    for (final state in values) {
      if (state.name == name) return state;
    }

    return null;
  }
}

/// The first frame on `/rpc`: which protocol and app version the client speaks.
final class HelloArgs {
  const HelloArgs({required this.protocol, required this.app, required this.platform});

  factory HelloArgs.fromJson(Map<String, Object?> json) {
    final protocol = json["protocol"];
    final app = json["app"];
    final platform = json["platform"];

    if (protocol is! int) throw const FormatException("protocol must be an integer");
    if (app is! String || Version.tryParse(app) == null) {
      throw const FormatException("app must be a version");
    }
    if (platform is! String) throw const FormatException("platform must be a name");

    return HelloArgs(protocol: protocol, app: app, platform: platform);
  }

  final int protocol;
  final String app;
  final String platform;

  Map<String, Object?> toJson() => {"protocol": protocol, "app": app, "platform": platform};
}

/// The master's answer to `hello`.
final class HelloAnswer {
  const HelloAnswer({
    required this.protocol,
    required this.engine,
    required this.minApp,
    required this.instanceId,
    required this.state,
    this.challenge,
  });

  factory HelloAnswer.fromJson(Map<String, Object?> json) {
    final state = EngineState.byName(json["state"]);
    final values = [json["engine"], json["minApp"], json["instanceId"]];

    final challenge = json["challenge"];

    if (json["protocol"] is! int || state == null || values.any((value) => value is! String) ||
        (challenge != null && challenge is! String)) {
      throw const FormatException("Not a hello answer");
    }

    return HelloAnswer(
      protocol: json["protocol"] as int,
      engine: values[0] as String,
      minApp: values[1] as String,
      instanceId: values[2] as String,
      state: state,
      challenge: challenge == null ? null : base64.decode(challenge as String),
    );
  }

  final int protocol;
  final String engine;

  /// The oldest app this master serves; an older one gets `update_required`.
  final String minApp;
  final String instanceId;
  final EngineState state;

  /// 32 random bytes, only on a connection without a client certificate (a browser): it signs
  /// them with its device key and sends `device.prove` before anything else (`protocol-v1.md` §3).
  final Uint8List? challenge;

  Map<String, Object?> toJson() => {
    "protocol": protocol,
    "engine": engine,
    "minApp": minApp,
    "instanceId": instanceId,
    "state": state.name,
    if (challenge != null) "challenge": base64.encode(challenge!),
  };
}

/// A `major.minor.patch` app or engine version. A build suffix (`+7`) is ignored, as the app's
/// pubspec version carries one that never decides compatibility.
final class Version implements Comparable<Version> {
  const Version(this.major, this.minor, this.patch);

  static Version? tryParse(String text) {
    final match = RegExp(r"^(\d+)\.(\d+)\.(\d+)(\+\S+)?$").firstMatch(text.trim());

    if (match == null) return null;

    return Version(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(Version other) => major != other.major
    ? major.compareTo(other.major)
    : minor != other.minor
      ? minor.compareTo(other.minor)
      : patch.compareTo(other.patch);

  bool operator <(Version other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) => other is Version && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => "$major.$minor.$patch";
}
