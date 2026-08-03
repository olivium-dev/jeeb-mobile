/// Social sign-in failure types; cubit maps every native SDK error into one of these.
enum SocialAuthError {
  /// User closed the Google/Apple sheet without finishing; not surfaced as error.
  cancelled,

  /// No network or gateway 5xx/timeout.
  network,

  /// Gateway rejected ID token (replay, audience, expiry).
  invalidToken,

  /// Account is locked or banned (403 with ban payload).
  accountDisabled,

  /// 409 `email_collision` — email already registered via another method.
  /// NOT surfaced as error banner; cubit raises distinct outcome to route to collision-prompt.
  collision,

  /// Unexpected error.
  unknown,
}
