// JEBV4-13 (wave-1 P2-1): the customer-profile rate-app row was a confirmed
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';

import 'package:jeeb_mobile/features/rate_app/data/in_app_review_launcher.dart';

class _RecordingReview implements InAppReview {
  _RecordingReview({this.available = true, this.throwOnAvailability = false});

  final bool available;
  final bool throwOnAvailability;
  int isAvailableCalls = 0;
  int requestReviewCalls = 0;

  @override
  Future<bool> isAvailable() async {
    isAvailableCalls++;
    if (throwOnAvailability) {
      throw StateError('platform channel unavailable');
    }
    return available;
  }

  @override
  Future<void> requestReview() async {
    requestReviewCalls++;
  }

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {}
}

void main() {
  test('raises the OS review sheet when the platform reports availability',
      () async {
    final review = _RecordingReview();
    final launcher = InAppReviewLauncher(review: review);

    await launcher.requestReview();

    expect(review.isAvailableCalls, 1);
    expect(review.requestReviewCalls, 1);
  });

  test('stays silent when the platform declines (rate-limited/unavailable)',
      () async {
    final review = _RecordingReview(available: false);
    final launcher = InAppReviewLauncher(review: review);

    await launcher.requestReview();

    expect(review.requestReviewCalls, 0);
  });

  test('never throws — a platform failure must not crash the profile tab',
      () async {
    final review = _RecordingReview(throwOnAvailability: true);
    final launcher = InAppReviewLauncher(review: review);

    await expectLater(launcher.requestReview(), completes);
    expect(review.requestReviewCalls, 0);
  });
}
