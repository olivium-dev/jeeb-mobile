// AE-25 (screen half): a 409 report names the reason from `problem.typeSuffix`
// and offers NO Retry — the POST can never succeed. A retryable kind keeps one.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/gateway_problem.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:jeeb_mobile/features/reviews/presentation/reviews_list_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const ReviewItem _review = ReviewItem(
  id: 'rev-1',
  reviewerFirstName: 'Sami',
  score: 4,
  timestamp: '2026-07-03T10:00:00Z',
  body: 'On time.',
);

class _ReportFailingRepository implements ReviewsRepository {
  _ReportFailingRepository(this.appFailure);

  final AppFailure appFailure;
  int reports = 0;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async => const ReviewsPage(
    reviews: <ReviewItem>[_review],
    page: 1,
    totalPages: 1,
    reviewCount: 1,
    averageScore: 4,
  );

  @override
  Future<void> reportReview(String reviewId) async {
    reports += 1;
    throw ReviewsRepositoryException.classified(
      ReviewsFailure.unknown,
      appFailure: appFailure,
    );
  }
}

AppFailure _conflict(String typeSuffix) => ConflictFailure(
  problem: GatewayProblem.tryParse(<String, Object?>{
    'type': 'https://jeeb.app/errors/$typeSuffix',
    'title': typeSuffix,
    'status': 409,
  }),
);

void main() {
  Widget harness(
    ReviewsRepository repo, {
    Locale locale = const Locale('en'),
  }) => MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: ReviewsListScreen(jeeberId: 'jeeber-1', repository: repo),
  );

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  Future<void> report(WidgetTester tester) async {
    await tester.tap(byId('review_rev-1_report_cta'));
    await tester.pumpAndSettle();
    // OmdsConfirmationDialog pops itself with the tapped result.
    final l10n = AppLocalizations.of(tester.element(byId('reviews_root')));
    await tester.tap(find.text(l10n.reviewsReportConfirmCta).last);
    await tester.pumpAndSettle();
  }

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    for (final entry in <String, String Function(AppLocalizations)>{
      'already-rated': (l) => l.reviewsErrorAlreadyRated,
      'rating-window-closed': (l) => l.reviewsErrorWindowClosed,
      'not-rateable': (l) => l.reviewsErrorNotRateable,
    }.entries) {
      testWidgets('[$tag] a 409 ${entry.key} names the reason, no Retry', (
        tester,
      ) async {
        useReduceMotion(tester);
        final repo = _ReportFailingRepository(_conflict(entry.key));
        await tester.pumpWidget(harness(repo, locale: locale));
        await tester.pumpAndSettle();

        await report(tester);

        final snack = byId('reviews_report_error');
        expect(snack, findsOneWidget);
        final l10n = AppLocalizations.of(tester.element(byId('reviews_root')));
        expect(
          find.descendant(of: snack, matching: find.text(entry.value(l10n))),
          findsOneWidget,
        );
        // A conflict can never succeed: the generic copy and the Retry are out.
        expect(
          find.descendant(
            of: snack,
            matching: find.text(l10n.reviewsReportFailure),
          ),
          findsNothing,
        );
        // The kit hangs the Retry action off the snack's own key.
        expect(
          find.byKey(const Key('reviews_report_error_retry_cta')),
          findsNothing,
        );
        expect(repo.reports, 1);
      });
    }
  }

  testWidgets('a retryable report failure keeps the generic copy + Retry', (
    tester,
  ) async {
    useReduceMotion(tester);
    final repo = _ReportFailingRepository(const NetworkFailure(offline: true));
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    await report(tester);

    final snack = byId('reviews_report_error');
    final l10n = AppLocalizations.of(tester.element(byId('reviews_root')));
    expect(
      find.descendant(
        of: snack,
        matching: find.text(l10n.reviewsReportFailure),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reviews_report_error_retry_cta')),
      findsOneWidget,
    );
  });

  testWidgets('an unmapped 409 falls back to the generic report copy', (
    tester,
  ) async {
    useReduceMotion(tester);
    final repo = _ReportFailingRepository(_conflict('something-else'));
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    await report(tester);

    final snack = byId('reviews_report_error');
    final l10n = AppLocalizations.of(tester.element(byId('reviews_root')));
    expect(
      find.descendant(
        of: snack,
        matching: find.text(l10n.reviewsReportFailure),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reviews_report_error_retry_cta')),
      findsNothing,
    );
  });
}
