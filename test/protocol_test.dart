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

  group('catalogues', () {
    test('every country quotes in a currency of the snapshot and names its zone', () {
      for (final country in Catalogs.countryRows) {
        expect(Catalogs.hasCurrency(country["currency"] as String), isTrue, reason: "${country["code"]}");
        expect(country["timezone"], isA<String>(), reason: "${country["code"]}");
      }
    });

    test('codes are unique and every served name answers rows', () {
      for (final rows in [Catalogs.countryRows, Catalogs.currencyRows]) {
        final codes = rows.map((row) => row["code"]).toList();
        expect(codes.toSet().length, codes.length);
      }
      for (final name in Catalogs.names) {
        expect(Catalogs.named(name), isNotEmpty, reason: name);
      }
      expect(Catalogs.named("money.rails"), isNull);
    });
  });

  group('inventory', () {
    test('every template field is a real type, with at most one STOCK and one TITLE, named in English', () {
      for (final MapEntry(key: code, value: fields) in TableTemplates.fields.entries) {
        expect(fields.map((field) => field.$1), everyElement(isIn(FieldTypes.all)), reason: code);
        expect(fields.where((field) => field.$1 == FieldTypes.stock), hasLength(1), reason: code);
        expect(fields.where((field) => field.$1 == FieldTypes.title), hasLength(1), reason: code);
        expect(fields.map((field) => field.$2["en"]), everyElement(isNotNull), reason: code);
      }
      expect(TableTemplates.exists(TableTemplates.blank), isTrue);
    });

    test('a default reason belongs to its operation; a reserve has none', () {
      for (final MapEntry(key: operation, value: reason) in StockOperations.defaults.entries) {
        expect(StockOperations.reasons[operation], contains(reason));
      }
      expect(StockOperations.defaults.containsKey(StockOperations.reserve), isFalse);
      expect(FieldTypes.from("select"), FieldTypes.options);
      expect(FieldTypes.from("VECTOR"), isNull);
    });
  });

  group('pos', () {
    test('settlement kinds: one default, every language the company can use, credit left out on request', () {
      expect(Settlements.kinds.keys, contains(Settlements.defaultMethod));
      for (final MapEntry(key: method, value: kind) in Settlements.kinds.entries) {
        expect(kind.$4.keys.toSet(), Catalogs.languages, reason: method);
      }

      final offline = Settlements.rows("es", credit: false);
      expect(offline.map((row) => row["method"]), isNot(contains("account")));
      expect(offline.where((row) => row["default"] == true).single["name"], "Efectivo");
      expect(Settlements.rows("ja").first["name"], "Cash");
      expect(Settlements.name("account", "pt"), "Crédito da loja");
      expect(Settlements.name("barter", "es"), isNull);
    });
  });

  group('sales', () {
    test('stages, modes and states are named in every language the company can use', () {
      for (final MapEntry(key: stage, value: kind) in SaleStages.kinds.entries) {
        expect(kind.$5.keys.toSet(), Catalogs.languages, reason: stage);
      }
      for (final MapEntry(key: mode, value: (_, names)) in Handover.modes.entries) {
        expect(names.keys.toSet(), Catalogs.languages, reason: mode);
      }
      for (final MapEntry(key: state, value: names) in Handover.states.entries) {
        expect(names.keys.toSet(), Catalogs.languages, reason: state);
      }
    });

    test('offline, only the stages a master measures, in precedence order (SA-2)', () {
      expect(SaleStages.rows("es", offline: true).map((row) => row["stage"]),
        ["open", "shipping", "handover", "transit", "pickup", "completed"]);
      expect(SaleStages.rows("es").first, {
        "stage": "open", "name": "Ticket abierto", "section": "process", "level": "info", "attention": true,
      });
      expect(SaleStages.name("completed", "ja"), "Sale completed");
      expect(Handover.rows("es").last["states"], [
        {"state": "pending", "name": "Sin entregar"},
        {"state": "dispatched", "name": "Despachado"},
        {"state": "done", "name": "Entregado"},
      ]);
      expect(SaleChannels.rows("en"), [{"channel": "pos", "name": "Point of sale", "default": true}]);
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
