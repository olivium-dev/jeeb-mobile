import 'package:in_app_review/in_app_review.dart';

import '../domain/app_review_launcher.dart';

/// Production [AppReviewLauncher] adapter for JM-064 (`rate-the-app`).
///
/// JEBV4-13 (wave-1 P2-1): the rate-app row was a confirmed no-op — this
/// adapter shipped with a guarded empty body because `in_app_review` was not
/// yet a resolved dependency. The INTEGRATOR-SWAP documented here has now
/// been executed: `in_app_review ^2.0.12` is in `pubspec.yaml`, the body
/// raises the real OS store-review sheet (App Store `SKStoreReviewController`
/// / Play In-App Review), and `injection_container.dart` registers this
/// adapter as the [AppReviewLauncher], which
/// `CustomerProfileScreen._resolveReviewLauncher()` already prefers over the
/// [NoopAppReviewLauncher] fallback.
///
/// Contract (JM-064): never throws — a failed/declined review prompt must
/// never crash or toast the profile tab. The OS rate-limits the sheet, so a
/// given tap is best-effort by design; when the platform declines
/// (`isAvailable()` false or an internal error) the call resolves silently
/// and the user simply stays on Profile.
class InAppReviewLauncher implements AppReviewLauncher {
  const InAppReviewLauncher({InAppReview? review}) : _review = review;

  /// Test seam; production uses the plugin singleton.
  final InAppReview? _review;

  @override
  Future<void> requestReview() async {
    try {
      final review = _review ?? InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } on Object {
      // Best-effort by contract: the OS owns (and rate-limits) the sheet; a
      // failure here must never surface on the profile tab.
    }
  }
}
