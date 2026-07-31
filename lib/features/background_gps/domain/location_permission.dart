/// What the OS told us about location access. The cubit only starts the
/// stream once we hold [always] — anything else surfaces a permission
/// prompt or a denied banner in the UI.
enum LocationPermission {
  /// The user hasn't been asked yet (fresh install, fresh role-switch).
  notDetermined,

  /// Explicitly denied or revoked, but the OS will still show a prompt on the
  /// next request (the user can still be recovered in-app).
  denied,

  /// Denied in a way the OS will no longer prompt for ("Don't allow" twice, or
  /// the permission turned off from Settings). Re-requesting is a silent no-op,
  /// so the ONLY recovery is the app's system settings page — the banner shows
  /// the "Open settings" CTA rather than a re-prompt.
  deniedForever,

  /// Foreground-only ("while in use"). Background tracking is not allowed —
  /// we'd lose samples as soon as the screen locks. The cubit treats this
  /// like a soft-denial and re-prompts for [always].
  ///
  /// On Android 10+ this is ALSO what geolocator reports when the app holds
  /// foreground location but not `ACCESS_BACKGROUND_LOCATION`, which is the
  /// state the escalation step in `BackgroundGpsCubit.start()` exists to fix.
  whileInUse,

  /// Background tracking is allowed. The only state where we start the
  /// upload pipeline.
  always,
}

/// True for the states from which no further in-app prompt can help — the user
/// has to be sent to the OS settings page.
extension LocationPermissionX on LocationPermission {
  bool get requiresSystemSettings => this == LocationPermission.deniedForever;
}
