# Module: lyra_protocol

**Path** `E:/andromeda/frontend/packages/lyra_protocol` (own git repo, pure Dart)
**Role** The LAN protocol shared by the app and the engine: op catalogue, frames, error codes, handshake, pairing
cryptography, the RPC client. The written contract is `lyra/app/docs/offline/protocol-v1.md`; this package matches it.
**Used by** `lyra/app` (path dependency), `lyra_node`.

## Files

- `lib/lyra_protocol.dart` — barrel (platform-neutral, web included).
- `lib/io.dart` — `dart:io` only: `LanIdentity` (pinned CA + device certificate), `connectRpc` (mutual TLS, TLS 1.3),
  `connectPairing` / `IoPairingChannel` (`/pair`, records the server certificate).
- `lib/src/version.dart` — `protocolVersion`, `maxFrameBytes`, `defaultPort`.
- `lib/src/ops.dart` — `Op` (`name`, `kind`, `needsCommandId`), `OpKind` (`read`, `write`, `session`), `Ops` (every v1
  op, `all`, `byName`).
- `lib/src/frames.dart` — `Frame.decode`, `RpcRequest`, `RpcResponse` (`ok` / `failed`), `RpcError`
  (`{code, message, action, data}`), `RpcEvent`.
- `lib/src/errors.dart` — `ErrorCodes` (the common codes of `protocol-v1.md` §8), `ErrorActions` (`login`, `update`).
- `lib/src/hello.dart` — `HelloArgs`, `HelloAnswer`, `EngineState` (`ready`, `locked`), `Version`.
- `lib/src/rpc_client.dart` — `RpcClient` (ids, out-of-order answers, `events`, `hello`), `FrameSocket`, `RpcClosed`.
- `lib/src/pairing.dart` — `PairingOffer` (the QR), `PairingDevice`, `DeviceSigner` / `LocalDeviceSigner`, `Pairing`
  (steps, MAC, codes, limits), `PairingChannel`, `pairDevice` (device side), `PairingResult`, `PairingFailure`,
  `DeviceProof` (what a browser signs for `device.prove`).
- `lib/src/discovery.dart` — `Discovery` (`_lyra._tcp.local`, `advertisedId`, `instanceName`).
- `lib/src/canonical_json.dart` — `canonicalJson` (sorted keys; what gets hashed or MACed).
- `lib/src/crypto/spake2.dart` — `Spake2` (RFC 9382, P256-SHA256-HKDF-HMAC), `Spake2Keys`.
- `lib/src/crypto/p256.dart` — `P256` (point checks, SPKI, ECDSA verify of DER or raw signatures), `EcKeyPair`
  (generate, SEC1 PEM, RFC 6979 signing), `Fingerprint`.
- `lib/src/crypto/der.dart` — `Der` (encoder), `DerReader` / `DerElement` (strict reader), `Pem`.
- `lib/src/crypto/hashes.dart` — `Hashes` (SHA-256/512, HMAC, HKDF, constant-time compare, random, hex).
- `test/protocol_test.dart` — catalogue, frame round trips, hello.
- `test/crypto_test.dart` — RFC 9382 vectors, SPAKE2 in pairing, P-256 keys, RFC 5869 HKDF.

## Invariants

- The op catalogue equals `protocol-v1.md` §9: the app's `test/protocol_catalogue_test.dart` reads the doc and compares.
  A new op goes in the doc and in `Ops` in the same change (CLAUDE.md, local ops rule).
- `lib/lyra_protocol.dart` never imports `dart:io` (the app's web build imports it); native sockets live in `lib/io.dart`.
- Every point and signature from a peer goes through `P256.decodePoint` / `P256.verify`, never straight to pointycastle.
- Domain argument and answer DTOs arrive here with their domain (plan phase 4); until then each spec is the contract.

## Commands

```
dart analyze        # must report "No issues found!"
dart test
```
