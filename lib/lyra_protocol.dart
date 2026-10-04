/// The Lyra LAN protocol, v1: op names, frames, error codes, the handshake, and the pairing
/// cryptography both ends run (SPAKE2, P-256 device keys).
///
/// The written contract is `lyra/app/docs/offline/protocol-v1.md`; this package must match it
/// (the app's `test/protocol_catalogue_test.dart` compares the op catalogue). Each domain of plan
/// phase 4 adds its vocabulary here (field keys, event names); argument and answer shapes stay
/// in its spec.
library;

export 'src/business.dart';
export 'src/canonical_json.dart';
export 'src/catalogs.dart';
export 'src/crypto/der.dart';
export 'src/crypto/hashes.dart';
export 'src/crypto/p256.dart';
export 'src/crypto/spake2.dart';
export 'src/discovery.dart';
export 'src/employees.dart';
export 'src/errors.dart';
export 'src/events.dart';
export 'src/files.dart';
export 'src/frames.dart';
export 'src/hello.dart';
export 'src/inventory.dart';
export 'src/money.dart';
export 'src/ops.dart';
export 'src/pairing.dart';
export 'src/permissions.dart';
export 'src/pos.dart';
export 'src/rpc_client.dart';
export 'src/sales.dart';
export 'src/version.dart';
