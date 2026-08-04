import 'package:in_app_review/in_app_review.dart';

import '../domain/app_review_launcher.dart';

class InAppReviewLauncher implements AppReviewLauncher {
  const InAppReviewLauncher({InAppReview? review}) : _review = review;

  final InAppReview? _review;

  @override
  Future<void> requestReview() async {
    try {
      final review = _review ?? InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } on Object {
      // Store review is fire-and-forget; never surface a failure.
    }
  }
}
