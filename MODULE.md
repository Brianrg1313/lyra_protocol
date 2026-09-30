# Module: lyra_protocol

**Path** `E:/andromeda/frontend/packages/lyra_protocol` (own git repo, pure Dart)
**Role** The LAN protocol shared by the app and the engine: op catalogue, frames, error codes,
handshake. The written contract is `lyra/app/docs/offline/protocol-v1.md`; this package matches it.
**Used by** `lyra/app` (path dependency), `lyra_node`.

## Files

- `lib/lyra_protocol.dart` — barrel.
- `lib/src/version.dart` — `protocolVersion`, `maxFrameBytes`, `defaultPort`.
- `lib/src/ops.dart` — `Op` (`name`, `kind`, `needsCommandId`), `OpKind` (`read`, `write`, `session`), `Ops` (every v1
  op, `all`, `byName`).
- `lib/src/frames.dart` — `Frame.decode`, `RpcRequest`, `RpcResponse` (`ok` / `failed`), `RpcError`
  (`{code, message, action, data}`), `RpcEvent`.
- `lib/src/errors.dart` — `ErrorCodes` (the common codes of `protocol-v1.md` §8), `ErrorActions` (`login`, `update`).
- `lib/src/hello.dart` — `HelloArgs`, `HelloAnswer`, `EngineState` (`ready`, `locked`), `Version`.
- `test/protocol_test.dart` — catalogue, frame round trips, hello.

## Invariants

- The op catalogue equals `protocol-v1.md` §9: the app's `test/protocol_catalogue_test.dart` reads the doc and compares.
  A new op goes in the doc and in `Ops` in the same change (CLAUDE.md, local ops rule).
- Domain argument and answer DTOs arrive here with their domain (plan phase 4); until then each spec is the contract.

## Commands

```
dart analyze        # must report "No issues found!"
dart test
```
