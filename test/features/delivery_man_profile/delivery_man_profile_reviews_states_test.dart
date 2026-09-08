// DMP-01 / DMP-02: three rungs on the reviews band, the count line suppressed
// when nothing is loaded, and no "View all" that would show the CLIENT's own
// reviews.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/domain/delivery_man_profile_repository.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/domain/delivery_man_profile_view_data.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/delivery_man_profile_screen.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/widgets/delivery_reviews_header.dart';

import '../../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../../support/midnight_test_harness.dart';

class _Stalled implements DeliveryManProfileRepository {
  _Stalled();

  @override
  Future<DeliveryManReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) => Completer<DeliveryManReviewsPage>().future;
}

class _Failing implements DeliveryManProfileRepository {
  _Failing();

  int reads = 0;

  @override
  Future<DeliveryManReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    reads++;
    throw const NetworkFailure(offline: true);
  }
}

class _EmptyPage implements DeliveryManProfileRepository {
  const _EmptyPage();

  @override
  Future<DeliveryManReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async => DeliveryManReviewsPage.empty;
}

const DeliveryManProfileViewData _data = DeliveryManProfileViewData(
  name: 'Kamal Hajj',
  rating: 4.3,
  reviewCount: 113,
  location: 'Lebanon',
  isAvailable: true,
  jeeberId: 'jeeber-kamal',
  reviews: <DeliveryReviewData>[],
);

const DeliveryManProfileViewData _noId = DeliveryManProfileViewData(
  name: 'Kamal Hajj',
  rating: 4.3,
  reviewCount: 113,
  location: 'Lebanon',
  isAvailable: true,
  reviews: <DeliveryReviewData>[],
);

Widget _screen(
  DeliveryManProfileRepository? repo, {
  DeliveryManProfileViewData data = _data,
  Locale locale = const Locale('en'),
}) => wrapMidnight(
  DeliveryManProfileScreen(data: data, repositoryOverride: repo),
  locale: locale,
  scrollable: false,
);

/// A tall viewport, so the reviews band is on screen and tappable.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final Locale locale in kFailureLocales) {
    testWidgets('${locale.languageCode}: the loading rung has its own id', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      _tallSurface(tester);
      await tester.pumpWidget(_screen(_Stalled(), locale: locale));
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('delivery_man_profile_reviews_loading'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('delivery_man_profile_reviews_error'),
        findsNothing,
      );
    });

    testWidgets('${locale.languageCode}: the error rung retries', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      _tallSurface(tester);
      final _Failing repo = _Failing();
      await tester.pumpWidget(_screen(repo, locale: locale));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('delivery_man_profile_reviews_error'),
        findsOneWidget,
      );
      // Error branch BEFORE empty.
      expect(
        find.bySemanticsIdentifier('delivery_man_profile_reviews_empty'),
        findsNothing,
      );

      final int before = repo.reads;
      await tester.tap(
        find.bySemanticsIdentifier('delivery_man_profile_reviews_retry_cta'),
      );
      await tester.pumpAndSettle();
      expect(repo.reads, greaterThan(before));
    });
  }

  testWidgets('a loaded EMPTY list suppresses the count line', (
    WidgetTester tester,
  ) async {
    useReduceMotion(tester);
    _tallSurface(tester);
    await tester.pumpWidget(_screen(const _EmptyPage()));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('delivery_man_profile_reviews_empty'),
      findsOneWidget,
    );
    // The band's own count line is a claim about loaded rows; there are none.
    expect(find.textContaining('0 Reviews'), findsNothing);
    expect(
      tester
          .widget<DeliveryReviewsHeader>(find.byType(DeliveryReviewsHeader))
          .showCount,
      isFalse,
      reason: 'a count above "No reviews yet" is a contradiction',
    );
  });

  testWidgets('DMP-02 · no jeeberId → "View all" is not interactive', (
    WidgetTester tester,
  ) async {
    useReduceMotion(tester);
    _tallSurface(tester);
    await tester.pumpWidget(_screen(null, data: _noId));
    await tester.pumpAndSettle();

    final JeebCtaButton viewAll = tester.widget<JeebCtaButton>(
      find.byKey(const Key('delivery-man-profile-view-all')),
    );
    expect(viewAll.isInteractive, isFalse);
  });

  testWidgets('with a jeeberId "View all" stays interactive', (
    WidgetTester tester,
  ) async {
    useReduceMotion(tester);
    _tallSurface(tester);
    await tester.pumpWidget(_screen(const _EmptyPage()));
    await tester.pumpAndSettle();

    final JeebCtaButton viewAll = tester.widget<JeebCtaButton>(
      find.byKey(const Key('delivery-man-profile-view-all')),
    );
    expect(viewAll.isInteractive, isTrue);
  });
}
