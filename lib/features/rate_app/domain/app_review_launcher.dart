///
///
abstract class AppReviewLauncher {
  Future<void> requestReview();
}

class NoopAppReviewLauncher implements AppReviewLauncher {
  const NoopAppReviewLauncher();

  @override
  Future<void> requestReview() async {
  }
}
