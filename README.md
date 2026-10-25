# lyra_protocol

The Lyra LAN protocol, shared by the Lyra app and its engine (`lyra_node`): the op catalogue,
frames, error codes, the `hello` handshake, pairing cryptography (SPAKE2, P-256, HKDF) and the
RPC client. Pure Dart, no Flutter.

> **Proprietary software.** All rights reserved — see [LICENSE](LICENSE). No use, copying or
> distribution is permitted without written authorization.

## Layout

| Path | What it is |
|---|---|
| `lib/lyra_protocol.dart` | Barrel, platform-neutral (web included). |
| `lib/io.dart` | `dart:io` only: device identity, mutual-TLS RPC connection, pairing channel. |
| `lib/src/` | Ops, frames, errors, events, permissions and each domain's vocabulary. |
| `lib/src/crypto/` | Pairing and key cryptography. |
| `test/` | Catalogue, frames, crypto vectors, and the permissions copy against its fixture. |

[`MODULE.md`](MODULE.md) lists every file and the invariants. The written contract is
`lyra/app/docs/offline/protocol-v1.md` in the app repository; this package matches it.

## Used by

- `lyra/app` — path dependency.
- `lyra_node` — path dependency (`../lyra_protocol`).

Both expect this repository checked out next to them under `frontend/packages/`.

## Requirements

- Dart SDK `^3.9.2`

## Development

```sh
dart pub get
dart analyze      # must report "No issues found!"
dart test
```

A new op goes into the protocol doc, `Ops`, an engine handler and a contract test in the same
change.

## Security

- No keys, certificates or credentials belong in this repository; `.gitignore` keeps them out.
  Test vectors are public RFC values or generated at run time.
- Report vulnerabilities privately to the maintainer; do not open public issues for them.

## License

Proprietary. Copyright (c) 2025-2026 David. All rights reserved. See [LICENSE](LICENSE).
