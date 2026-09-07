import 'package:in_app_review/in_app_review.dart';

import '../domain/app_review_launcher.dart';

class InAppReviewLauncher
    implements AppReviewLauncher, AppReviewOutcomeLauncher {
  const InAppReviewLauncher({InAppReview? review}) : _review = review;

  final InAppReview? _review;

  @override
  Future<void> requestReview() => requestReviewOutcome();

  @override
  Future<AppReviewOutcome> requestReviewOutcome() async {
    try {
      final review = _review ?? InAppReview.instance;
      if (!await review.isAvailable()) return AppReviewOutcome.unavailable;
      await review.requestReview();
      return AppReviewOutcome.requested;
    } on Object {
      return AppReviewOutcome.failed;
    }
  }
}
