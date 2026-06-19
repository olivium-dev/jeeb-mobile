/// Classes of social sign-in failure. The cubit maps every native SDK error
/// (PlatformException, MissingPluginException, Dio errors, etc.) into one of
/// these so the screen layer never sees raw error strings.
enum SocialAuthError {
  /// The user closed the Google/Apple sheet without finishing. Not surfaced
  /// as an error — the screen returns to idle silently.
  cancelled,

  /// No network or the gateway returned 5xx / timed out.
  network,

  /// Gateway accepted the request but rejected the ID token (replay, bad
  /// audience, expired). Asks the user to try again.
  invalidToken,

  /// Account is locked or banned (gateway 403 with a ban payload).
  accountDisabled,

  /// 409 `email_collision` — the email behind this social identity is already
  /// registered via another method (email/password or a different provider).
  /// JM-018/JM-019, D22: NOT surfaced as an error banner — the cubit raises a
  /// distinct collision outcome so the host routes to `social-collision-prompt`
  /// (the `social_collision_sheet`).
  collision,

  /// Anything we did not anticipate — generic copy.
  unknown,
}
