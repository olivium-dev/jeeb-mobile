import 'package:flutter/foundation.dart';

import '../domain/app_review_launcher.dart';

/// Production [AppReviewLauncher] adapter for JM-064 (`rate-the-app`).
///
/// This is the drop-in that raises the OS store-review sheet behind the
/// [AppReviewLauncher] port. The body is written to be a one-line swap to
/// `package:in_app_review`'s `InAppReview` once the dep + DI land — exactly the
/// `MapPickerLauncher` → `ofl_geo_capture` follow-up idiom.
///
/// INTEGRATOR-SWAP(JM-064): add `in_app_review: ^2.0.10` to `pubspec.yaml`,
/// then replace the guarded body of [requestReview] with:
///
/// ```dart
/// import 'package:in_app_review/in_app_review.dart';
/// // ...
/// final review = _review ?? InAppReview.instance;
/// if (await review.isAvailable()) {
///   await review.requestReview();
/// }
/// ```
///
/// and register it in `injection_container.dart`:
///
/// ```dart
/// // JM-064: native store-review sheet (in_app_review).
/// sl.registerLazySingleton<AppReviewLauncher>(() => const InAppReviewLauncher());
/// ```
///
/// then swap `CustomerProfileScreen._resolveReviewLauncher()` from
/// [NoopAppReviewLauncher] to `sl<AppReviewLauncher>()`.
///
/// **Why the body is guarded today (CTO-D R-F):** the `in_app_review` package is
/// not resolvable in this worktree (absent from `pubspec.lock`); importing it
/// would red `flutter analyze` (the `MapPickerLauncher`/`ofl_geo_capture`
/// situation). Until the dep lands the adapter resolves without raising a sheet —
/// the row stays honest (tap accepted, returns to Profile; no fabricated sheet —
/// CTO brief §6.7 / AP-9). The `in_app_review` request is itself rate-limited and
/// best-effort by the OS, so a no-op is contract-faithful: a real sheet is never
/// guaranteed to appear on any given tap.
class InAppReviewLauncher implements AppReviewLauncher {
  const InAppReviewLauncher();

  @override
  Future<void> requestReview() async {
    // INTEGRATOR-SWAP(JM-064): replace this body with the `in_app_review` call
    // documented above once the dep is added. Wrap that real call in a try/catch
    // that swallows the error — a failed/declined review prompt must never be
    // user-facing or crash the profile tab (JM-064).
    if (kDebugMode) {
      debugPrint(
        'InAppReviewLauncher.requestReview() — in_app_review dep pending '
        '(JM-064; see 50_ROUTE_REQUESTS.md). No-op until wired.',
      );
    }
  }
}
