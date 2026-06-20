// Tests for InAppReviewLauncher (profile/feedback/support rate-the-app, JM-064).
//
// Verifies the launcher requests the OS sheet only when available, and — per
// the JM-064 failure contract — swallows every error so a failed/declined
// review prompt never crashes the profile tab.

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_review_platform_interface/in_app_review_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:jeeb_mobile/features/rate_app/data/in_app_review_launcher.dart';

class _FakePlatform extends InAppReviewPlatform
    with MockPlatformInterfaceMixin {
  _FakePlatform({
    this.available = true,
    this.throwOnAvailable = false,
    this.throwOnRequest = false,
  });

  final bool available;
  final bool throwOnAvailable;
  final bool throwOnRequest;
  int requestCount = 0;

  @override
  Future<bool> isAvailable() async {
    if (throwOnAvailable) throw Exception('platform error');
    return available;
  }

  @override
  Future<void> requestReview() async {
    requestCount++;
    if (throwOnRequest) throw Exception('request error');
  }

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {}
}

void main() {
  test('available: requests the review sheet', () async {
    final platform = _FakePlatform(available: true);
    InAppReviewPlatform.instance = platform;
    final launcher = InAppReviewLauncher(review: InAppReview.instance);

    await launcher.requestReview();

    expect(platform.requestCount, 1);
  });

  test('unavailable: no-op, does not request', () async {
    final platform = _FakePlatform(available: false);
    InAppReviewPlatform.instance = platform;
    final launcher = InAppReviewLauncher(review: InAppReview.instance);

    await launcher.requestReview();

    expect(platform.requestCount, 0);
  });

  test('swallows a platform error (never throws)', () async {
    final platform = _FakePlatform(throwOnAvailable: true);
    InAppReviewPlatform.instance = platform;
    final launcher = InAppReviewLauncher(review: InAppReview.instance);

    // Must not throw — JM-064: a review failure never crashes the profile tab.
    await expectLater(launcher.requestReview(), completes);
  });

  test('swallows a requestReview error (never throws)', () async {
    final platform = _FakePlatform(available: true, throwOnRequest: true);
    InAppReviewPlatform.instance = platform;
    final launcher = InAppReviewLauncher(review: InAppReview.instance);

    await expectLater(launcher.requestReview(), completes);
  });
}
