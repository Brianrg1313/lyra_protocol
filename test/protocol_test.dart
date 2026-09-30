import 'dart:typed_data';

import 'package:lyra_protocol/lyra_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('ops', () {
    test('every name is unique and resolvable', () {
      final names = Ops.all.map((op) => op.name).toList();

      expect(names.toSet().length, names.length);
      for (final op in Ops.all) {
        expect(Ops.byName(op.name), same(op));
      }
      expect(Ops.byName("sales.approve"), isNull);
    });

    test('only writes need a commandId', () {
      expect(Ops.posInvoicesLine.needsCommandId, isTrue);
      expect(Ops.stockSummary.needsCommandId, isFalse);
      expect(Ops.authSignIn.needsCommandId, isFalse);
    });
  });

  group('frames', () {
    test('a request, a response and an event round-trip', () {
      const frames = <Frame>[
        RpcRequest(id: 3, op: "stock.move", args: {"qty": 2}, commandId: "0192"),
        RpcResponse.ok(3, {"balance": 5}),
        RpcResponse.failed(4, RpcError("insufficient_stock", "Only 2 left", data: {"available": 2})),
        RpcEvent(event: "stock/changed", seq: 88213, data: {"id": "p1"}),
      ];

      for (final frame in frames) {
        expect(Frame.decode(frame.encode()).toJson(), frame.toJson());
      }
    });

    test('a failure keeps the {message, action} shape the app reads', () {
      final frame = Frame.decode(
        '{"id":1,"ok":false,"error":{"code":"session_expired","message":"Sign in again","action":"login"}}',
      ) as RpcResponse;

      expect(frame.ok, isFalse);
      expect(frame.error!.toJson(), containsPair("message", "Sign in again"));
      expect(frame.error!.action, ErrorActions.login);
    });

    test('anything else is a format error', () {
      for (final text in ['[]', 'nope', '{"id":"1","op":"hello"}', '{"id":1}',
          '{"event":"x","seq":0}', '{"id":1,"ok":false}']) {
        expect(() => Frame.decode(text), throwsFormatException, reason: text);
      }
    });
  });

  group('hello', () {
    test('round-trips', () {
      const answer = HelloAnswer(
        protocol: protocolVersion,
        engine: "0.1.0",
        minApp: "0.0.7",
        instanceId: "abc",
        state: EngineState.locked,
      );

      expect(HelloAnswer.fromJson(answer.toJson()).toJson(), answer.toJson());
      expect(
        HelloArgs.fromJson(const HelloArgs(protocol: 1, app: "0.0.7+1", platform: "windows").toJson()).app,
        "0.0.7+1",
      );
    });

    test('carries a browser challenge', () {
      final answer = HelloAnswer(
        protocol: protocolVersion,
        engine: "0.1.0",
        minApp: "0.0.7",
        instanceId: "abc",
        state: EngineState.ready,
        challenge: Uint8List.fromList(List.generate(32, (i) => i)),
      );

      expect(HelloAnswer.fromJson(answer.toJson()).challenge, answer.challenge);
      expect(() => HelloAnswer.fromJson({...answer.toJson(), "challenge": 7}), throwsFormatException);
    });

    test('versions compare without the build suffix', () {
      expect(Version.tryParse("0.0.6+1")! < Version.tryParse("0.0.7")!, isTrue);
      expect(Version.tryParse("1.2.3+9"), const Version(1, 2, 3));
      expect(Version.tryParse("1.2"), isNull);
    });
  });
}
