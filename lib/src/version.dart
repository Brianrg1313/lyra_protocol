/// The protocol version a `hello` carries (`protocol-v1.md` §10).
///
/// Adding an op, an optional argument, an answer field or an event does not change it. Removing
/// or changing the meaning of anything does, and the master then speaks both versions for at
/// least one release.
const int protocolVersion = 1;

/// Largest text frame either side accepts, in bytes (`frame_too_large`). Anything bigger is a
/// file (`protocol-v1.md` §2, §6).
const int maxFrameBytes = 1024 * 1024;

/// The port the master listens on unless the admin changes it.
const int defaultPort = 4780;
