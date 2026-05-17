/// What the OS told us about location access. The cubit only starts the
/// stream once we hold [always] — anything else surfaces a permission
/// prompt or a denied banner in the UI.
enum LocationPermission {
  /// The user hasn't been asked yet (fresh install, fresh role-switch).
  notDetermined,

  /// Explicitly denied or revoked from system settings.
  denied,

  /// Foreground-only ("while in use"). Background tracking is not allowed —
  /// we'd lose samples as soon as the screen locks. The cubit treats this
  /// like a soft-denial and re-prompts for [always].
  whileInUse,

  /// Background tracking is allowed. The only state where we start the
  /// upload pipeline.
  always,
}
