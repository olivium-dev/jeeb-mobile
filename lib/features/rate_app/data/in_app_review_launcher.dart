import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import '../domain/app_review_launcher.dart';

/// Production [AppReviewLauncher] adapter for JM-064 (`rate-the-app`).
///
/// Raises the OS store-review sheet behind the [AppReviewLauncher] port via
/// `package:in_app_review` (App Store `SKStoreReviewController` / Play In-App
/// Review). There is **no** in-app rating UI and **no** network call — the OS
/// owns the sheet. The request is itself rate-limited and best-effort by the
/// OS, so a real sheet is never guaranteed to appear on any given tap.
///
/// Failure contract (JM-064): a failed / unavailable / declined review prompt
/// must never be user-facing or crash the profile tab. [requestReview] swallows
/// every error and returns normally so the caller can keep the user on Profile
/// (the AC's "returns to Profile" leg).
class InAppReviewLauncher implements AppReviewLauncher {
  const InAppReviewLauncher({InAppReview? review}) : _review = review;

  /// Injectable for tests — a recording double stands in for the platform
  /// plugin so unit tests never touch a real `InAppReview` channel. Production
  /// passes `null` and falls back to [InAppReview.instance].
  final InAppReview? _review;

  @override
  Future<void> requestReview() async {
    final review = _review ?? InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      }
      // When unavailable (e.g. emulator without Play Store, or the OS quota is
      // exhausted) this is a contract-faithful no-op — the tap is still
      // accepted and control returns to Profile.
    } catch (error) {
      // A review-prompt failure must never crash the profile tab (JM-064).
      if (kDebugMode) {
        debugPrint(
          'InAppReviewLauncher.requestReview() failed (swallowed): $error',
        );
      }
    }
  }
}
