/// Port the customer-profile "Rate the app" row (JM-064, blueprint
/// `rate-the-app`) drives to raise the platform's native store-review sheet.
///
/// JM-064 AC: Given the Rate-app row, When `customer_profile_rate_app_row` is
/// tapped, Then the native store-review sheet is invoked and control returns to
/// Profile. There is **no** in-app rating UI and **no** network call — the OS
/// owns the sheet (App Store `SKStoreReviewController` / Play In-App Review).
///
/// This is a pure-Dart port (no Flutter / plugin imports) so the screen and its
/// widget tests stay platform-free. It mirrors the established native-side-channel
/// idiom in this codebase: `MapPickerLauncher` (location) and `VoiceRecorder`
/// (voice_request) — the feature talks to the abstraction; a thin adapter wraps
/// the platform plugin (`in_app_review`) behind it.
///
/// **Why no direct `in_app_review` import here (CTO-D R-F):** the `in_app_review`
/// package is not yet resolved in this worktree (it is not in `pubspec.lock`),
/// exactly the situation `MapPickerLauncher` documents for `ofl_geo_capture`.
/// Importing it would red `flutter analyze`. The production adapter
/// (`InAppReviewLauncher` over `package:in_app_review`) + its pubspec dep + DI
/// registration are requested from the wave integrator in
/// `docs/build-out/50_ROUTE_REQUESTS.md`. Until that lands, the screen
/// self-provides [NoopAppReviewLauncher], so the row is **honest** (the tap is
/// accepted and control stays on Profile — the AC's return leg) without
/// fabricating a sheet the build can't raise (CTO brief §6.7 / AP-9).
abstract class AppReviewLauncher {
  /// Requests the OS store-review sheet. Implementations must:
  ///   - never throw (a review prompt failure must never crash the profile tab);
  ///   - be a no-op when the platform declines to show the sheet (the OS rate-
  ///     limits it — there is no error to surface);
  ///   - return after the request resolves so the caller can keep the user on
  ///     Profile (the JM-064 "returns to profile" leg).
  Future<void> requestReview();
}

/// Default, dependency-free [AppReviewLauncher] used until the real
/// `in_app_review`-backed adapter is wired by the integrator (see the class
/// doc). It accepts the request and resolves immediately — the row is tappable
/// and returns to Profile (AP-9 honest: no unraisable sheet is faked, nothing
/// crashes). Also the unit-test seam: tests inject a recording double instead
/// of touching any platform plugin.
class NoopAppReviewLauncher implements AppReviewLauncher {
  const NoopAppReviewLauncher();

  @override
  Future<void> requestReview() async {
    // Intentionally a no-op: the OS sheet is unavailable in this worktree (the
    // in_app_review dep is integrator-pending). Returning normally keeps the
    // tap accepted and the user on Profile (JM-064 return leg).
  }
}
