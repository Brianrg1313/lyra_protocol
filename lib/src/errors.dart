/// The common error codes any op may answer (`protocol-v1.md` §8). Domain codes are listed in
/// each spec next to the op that answers them.
///
/// A code is stable: the engine never renames one, because clients branch on it.
abstract final class ErrorCodes {
  static const badRequest = "bad_request";
  static const unknownOp = "unknown_op";
  static const invalidField = "invalid_field";
  static const required = "required";
  static const notFound = "not_found";
  static const forbidden = "forbidden";
  static const sessionExpired = "session_expired";
  static const sessionRevoked = "session_revoked";
  static const deviceRevoked = "device_revoked";
  static const locked = "locked";
  static const rateLimited = "rate_limited";
  static const versionMismatch = "version_mismatch";
  static const updateRequired = "update_required";
  static const commandReused = "command_reused";
  static const resyncRequired = "resync_required";
  static const needsInternet = "needs_internet";
  static const frameTooLarge = "frame_too_large";
  static const internal = "internal";

  static const Set<String> all = {
    badRequest, unknownOp, invalidField, required, notFound, forbidden, sessionExpired,
    sessionRevoked, deviceRevoked, locked, rateLimited, versionMismatch, updateRequired,
    commandReused, resyncRequired, needsInternet, frameTooLarge, internal,
  };
}

/// The route keys an error's `action` may name, as the app's api layer reads them today.
abstract final class ErrorActions {
  /// The session is gone: the app's `onSessionRejected` sends the person to sign in.
  static const login = "login";

  /// This client and the master don't speak the same version.
  static const update = "update";
}
