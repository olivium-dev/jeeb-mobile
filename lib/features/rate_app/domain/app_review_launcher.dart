abstract class AppReviewLauncher {
  Future<void> requestReview();
}

/// What the store review request actually did — RATE-01: a tap that cannot
/// open the store must not be a silent no-op.
enum AppReviewOutcome { requested, unavailable, failed }

/// The outcome-reporting lane. A launcher implements it only when it can say
/// what happened; callers `is`-check and fall back to [AppReviewLauncher].
abstract class AppReviewOutcomeLauncher {
  Future<AppReviewOutcome> requestReviewOutcome();
}

class NoopAppReviewLauncher
    implements AppReviewLauncher, AppReviewOutcomeLauncher {
  const NoopAppReviewLauncher();

  @override
  Future<void> requestReview() async {}

  @override
  Future<AppReviewOutcome> requestReviewOutcome() async =>
      AppReviewOutcome.unavailable;
}
