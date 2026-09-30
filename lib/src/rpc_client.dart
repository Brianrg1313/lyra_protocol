import 'dart:async';

import './frames.dart';
import './hello.dart';
import './ops.dart';
import './version.dart';

/// A connection that carries text frames: a WebSocket, as the platform provides it (`dart:io`
/// on native, the browser's on web).
abstract interface class FrameSocket {
  Stream<String> get frames;

  void send(String frame);

  Future<void> close();
}

/// The connection closed with requests still waiting. Not an [RpcError]: the master never
/// answered, so whether a write happened is only known by retrying it with the same
/// `commandId` (README, writes).
final class RpcClosed implements Exception {
  const RpcClosed();

  @override
  String toString() => "RpcClosed";
}

/// The client end of `/rpc` (`protocol-v1.md` §2): numbers requests, matches answers by `id`
/// (they may come out of order) and hands events to [events].
final class RpcClient {
  RpcClient(this._socket) {
    _subscription = _socket.frames.listen(_receive, onDone: _closed, onError: (_) => _closed());
  }

  final FrameSocket _socket;
  late final StreamSubscription<String> _subscription;
  final Map<int, Completer<Object?>> _pending = {};
  final StreamController<RpcEvent> _events = StreamController.broadcast();
  final Completer<void> _done = Completer();
  int _nextId = 1;

  /// Events after `events.subscribe`, in `seq` order.
  Stream<RpcEvent> get events => _events.stream;

  /// Completes when the connection is gone, whoever closed it.
  Future<void> get done => _done.future;

  bool get isClosed => _done.isCompleted;

  /// Sends [op] and answers its `data`, or throws the master's [RpcError] (or [RpcClosed]).
  /// A write needs its [commandId]; resending the same one after a lost answer is safe.
  Future<Object?> call(Op op, {Map<String, Object?> args = const {}, String? commandId}) {
    if (op.needsCommandId != (commandId != null)) {
      throw ArgumentError(op.needsCommandId ? "${op.name} is a write: it needs a commandId" : "${op.name} is not a write");
    }
    if (isClosed) return Future.error(const RpcClosed());

    final id = _nextId++;
    final answer = Completer<Object?>();

    _pending[id] = answer;
    _socket.send(RpcRequest(id: id, op: op.name, args: args, commandId: commandId).encode());

    return answer.future;
  }

  /// The first frame of every connection (`protocol-v1.md` §4).
  Future<HelloAnswer> hello({required String app, required String platform}) async {
    final data = await call(Ops.hello, args: HelloArgs(protocol: protocolVersion, app: app, platform: platform).toJson());

    return HelloAnswer.fromJson(data as Map<String, Object?>);
  }

  Future<void> close() async {
    await _socket.close();
    _closed();
  }

  void _receive(String text) {
    final Frame frame;
    try {
      frame = Frame.decode(text);
    } on FormatException {
      return;
    }

    switch (frame) {
      case RpcResponse():
        final answer = _pending.remove(frame.id);
        if (answer == null) return;
        frame.ok ? answer.complete(frame.data) : answer.completeError(frame.error!);
      case RpcEvent():
        _events.add(frame);
      case RpcRequest():
        // The master never sends requests.
        break;
    }
  }

  void _closed() {
    if (_done.isCompleted) return;

    unawaited(_subscription.cancel());
    for (final answer in _pending.values) {
      answer.completeError(const RpcClosed());
    }
    _pending.clear();
    unawaited(_events.close());
    _done.complete();
  }
}
