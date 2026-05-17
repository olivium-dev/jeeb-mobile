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

  /// Anything we did not anticipate — generic copy.
  unknown,
}
