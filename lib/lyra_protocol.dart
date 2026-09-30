/// The Lyra LAN protocol, v1: op names, frames, error codes and the handshake.
///
/// The written contract is `lyra/app/docs/offline/protocol-v1.md`; this package must match it
/// (the app's `test/protocol_catalogue_test.dart` compares the op catalogue). Domain argument
/// and answer shapes arrive here with each domain in phase 4 of the plan.
library;

export 'src/errors.dart';
export 'src/frames.dart';
export 'src/hello.dart';
export 'src/ops.dart';
export 'src/version.dart';
