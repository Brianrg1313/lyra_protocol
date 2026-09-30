import 'dart:convert';

/// A JSON text frame on `/rpc` (`protocol-v1.md` §2). [Frame.decode] tells the three apart; a
/// frame that is none of them is a [FormatException], which the master answers as
/// `bad_request`.
sealed class Frame {
  const Frame();

  Map<String, Object?> toJson();

  String encode() => jsonEncode(toJson());

  static Frame decode(String text) {
    final Object? json;

    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const FormatException("A frame is one JSON object");
    }

    if (json is! Map<String, Object?>) throw const FormatException("A frame is one JSON object");

    if (json.containsKey("op")) return RpcRequest.fromJson(json);
    if (json.containsKey("event")) return RpcEvent.fromJson(json);
    if (json.containsKey("ok")) return RpcResponse.fromJson(json);

    throw const FormatException("Not a request, a response or an event");
  }
}

/// Client → master. [commandId] is present exactly on writes (`OpKind.write`); the master
/// refuses a write without one and a read with one.
final class RpcRequest extends Frame {
  const RpcRequest({required this.id, required this.op, this.args = const {}, this.commandId});

  factory RpcRequest.fromJson(Map<String, Object?> json) {
    final id = json["id"];
    final op = json["op"];
    final args = json["args"] ?? const <String, Object?>{};
    final commandId = json["commandId"];

    if (id is! int) throw const FormatException("id must be an integer");
    if (op is! String || op.isEmpty) throw const FormatException("op must be a name");
    if (args is! Map<String, Object?>) throw const FormatException("args must be an object");
    if (commandId != null && commandId is! String) {
      throw const FormatException("commandId must be a string");
    }

    return RpcRequest(id: id, op: op, args: args, commandId: commandId as String?);
  }

  final int id;
  final String op;
  final Map<String, Object?> args;
  final String? commandId;

  @override
  Map<String, Object?> toJson() => {
    "id": id,
    "op": op,
    "args": args,
    if (commandId != null) "commandId": commandId,
  };
}

/// Master → client, matched to its request by [id]. Answers may come out of order.
final class RpcResponse extends Frame {
  const RpcResponse.ok(this.id, [this.data]) : error = null;

  const RpcResponse.failed(this.id, RpcError this.error) : data = null;

  factory RpcResponse.fromJson(Map<String, Object?> json) {
    final id = json["id"];
    final ok = json["ok"];

    if (id is! int) throw const FormatException("id must be an integer");
    if (ok == true) return RpcResponse.ok(id, json["data"]);

    final error = json["error"];

    if (ok != false || error is! Map<String, Object?>) {
      throw const FormatException("A failed answer carries an error object");
    }

    return RpcResponse.failed(id, RpcError.fromJson(error));
  }

  final int id;
  final Object? data;
  final RpcError? error;

  bool get ok => error == null;

  @override
  Map<String, Object?> toJson() => ok
    ? {"id": id, "ok": true, "data": data}
    : {"id": id, "ok": false, "error": error!.toJson()};
}

/// A refusal. [message] is written in the company language, ready to show; [action] is a route
/// key (`ErrorActions`) when the client must go somewhere. That is the `{message, action}`
/// shape the app's api layer already normalises every failure to, so `FloatFlag.showFromError`
/// and `onSessionRejected` work on it unchanged.
final class RpcError implements Exception {
  const RpcError(this.code, this.message, {this.action, this.data});

  factory RpcError.fromJson(Map<String, Object?> json) {
    final code = json["code"];
    final message = json["message"];
    final action = json["action"];
    final data = json["data"];

    if (code is! String || code.isEmpty) throw const FormatException("error.code is required");

    return RpcError(
      code,
      message is String ? message : "",
      action: action is String ? action : null,
      data: data is Map<String, Object?> ? data : null,
    );
  }

  final String code;
  final String message;
  final String? action;

  /// The fields a spec names for [code] (for example `available` on `insufficient_stock`).
  final Map<String, Object?>? data;

  Map<String, Object?> toJson() => {
    "code": code,
    "message": message,
    "action": action,
    if (data != null) "data": data,
  };

  @override
  String toString() => "RpcError($code: $message)";
}

/// Master → client after `events.subscribe`. [seq] is one increasing counter over the master's
/// whole stream; the client keeps the last one it processed and subscribes `since` it.
final class RpcEvent extends Frame {
  const RpcEvent({required this.event, required this.seq, this.data});

  factory RpcEvent.fromJson(Map<String, Object?> json) {
    final event = json["event"];
    final seq = json["seq"];

    if (event is! String || event.isEmpty) throw const FormatException("event must be a name");
    if (seq is! int || seq < 1) throw const FormatException("seq must be a positive integer");

    return RpcEvent(event: event, seq: seq, data: json["data"]);
  }

  final String event;
  final int seq;
  final Object? data;

  @override
  Map<String, Object?> toJson() => {"event": event, "seq": seq, "data": data};
}
