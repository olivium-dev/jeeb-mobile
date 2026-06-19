/// Session-termination seam for the logout / delete-account confirm surface
/// (`logout-delete-account`, JM-062).
///
/// PURE Dart — no Flutter / Dio / GetIt imports (40_GUARDRAILS_ARCH §1). The
/// confirm sheet talks to this interface, not a Dio client, so the screen layer
/// can be exercised with a scripted fake in widget tests and the real
/// implementation (gateway logout + push-device unregister + keystore clear)
/// can be swapped without touching the presentation layer.
///
/// Both terminal actions (logout, delete-account) converge on the SAME local
/// outcome the JM-062 AC cares about: the locally-persisted session
/// (access/refresh token + userId in the keystore) is dropped so the router's
/// first-run gate ([SessionGate.isUnauthenticated]) flips to unauthenticated and
/// `context.go('/')` lands on splash → `/login` (D5). The gateway calls
/// (`POST /v1/auth/logout`, `POST /v1/devices/unregister`) are **best-effort**:
/// a transport failure must NOT trap the user in a logged-in-looking shell — the
/// local keystore clear is the load-bearing step and always runs.
abstract class AccountSessionTerminator {
  /// Log out the current user. Best-effort revokes the gateway session
  /// (`POST /v1/auth/logout`) and unregisters the push device
  /// (`POST /v1/devices/unregister`), then ALWAYS clears the local keystore
  /// tokens. Never throws — a network failure still clears the local session
  /// (fail-safe: a half-logged-out state is worse than an offline logout).
  Future<void> logout();

  /// Queue the current user's account for deletion (`status → deleted`, D5)
  /// then clear the local session exactly like [logout]. Best-effort on the
  /// gateway call; the local clear always runs. Never throws.
  Future<void> deleteAccount();
}
