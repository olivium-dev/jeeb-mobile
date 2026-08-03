// Render tests for the RecentReviewsSection previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/rating/presentation/widgets/recent_reviews_section.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Three reviews, view all': recentReviewsSectionThreeReviews,
  'Empty (renders nothing)': recentReviewsSectionEmpty,
  'Twelve reviews, three shown': recentReviewsSectionTruncated,
  'No view-all CTA': recentReviewsSectionNoViewAll,
  'Long name and body': recentReviewsSectionLongContent,
  'Arabic reviewer': recentReviewsSectionArabicReviewer,
};

/// The two header strings [RecentReviewsSection] hardcodes as constructor
/// defaults, restated here so a change to either has to come through this file.
const String _viewAll = 'View all';

/// The ARB values that SHOULD be filling those two slots. Both keys already
/// exist in `app_ar.arb`; nothing in this widget reads them.
const String _reviewsTitleAr = 'التقييمات';
const String _viewAllAr = 'عرض الكل';

/// `OmdsReviewCard.verifiedPurchaseLabel`'s default — not exposed by
/// [RecentReviewsSection], so it cannot be overridden by a caller.
const String _verifiedBadge = 'Verified Purchase';

/// The gold `OmdsReviewCard` falls back to when no `starColor` is passed.
const Color _omdsGold = Color(0xFFFFB800);

/// `maxItems`' default — the number of cards drawn however long the list is.
const int _maxItems = 3;

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'RecentReviewsSection',
    _previews,
    expectedText: const <String, String>{
      'Three reviews, view all': 'Reviews (3)',
      // Caption-bound: this state draws nothing of its own. The zero-height
      'Empty (renders nothing)':
          'Empty list — the section collapses to zero height',
      'Twelve reviews, three shown': 'Reviews (12)',
      'No view-all CTA': 'Tarek Aoun',
      'Long name and body': 'Abdulrahman Al-Muhandis Al-Trabulsi',
      'Arabic reviewer': 'ليلى الحاج',
    },
  );

  group('RecentReviewsSection preview specifics', () {
    testWidgets('an empty list collapses to zero height and no header', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, recentReviewsSectionEmpty);

      // `SizedBox.shrink()`: the section keeps the width its stretching parent
      expect(tester.getSize(find.byType(RecentReviewsSection)).height, 0);
      expect(find.byType(OmdsReviewCard), findsNothing);
      expect(find.textContaining('Reviews'), findsNothing);
    });

    testWidgets('counts the whole list but draws only maxItems', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, recentReviewsSectionTruncated);

      // Defect 2: `count: reviews.length` over `reviews.take(maxItems)`. The
      expect(find.text('Reviews (12)'), findsOneWidget);
      expect(find.byType(OmdsReviewCard), findsNWidgets(_maxItems));

      // The first three of the list, in order — not an arbitrary three.
      expect(find.text('Karl Assaf'), findsOneWidget);
      expect(find.text('Nadia Chehab'), findsOneWidget);
      expect(find.text('Client 4'), findsNothing);
    });

    testWidgets('the view-all CTA is conditional on onViewAllTap', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, recentReviewsSectionThreeReviews);
      expect(find.text(_viewAll), findsOneWidget);

      await pumpPreview(tester, recentReviewsSectionNoViewAll);
      expect(
        find.text(_viewAll),
        findsNothing,
        reason: 'the header suppresses its own CTA when the callback is null '
            '(showShowAll: onViewAllTap != null) — which is also what leaves '
            'a truncated list with no route to the reviews it counted',
      );
      expect(find.text('Reviews (1)'), findsOneWidget);
    });

    testWidgets('renders English chrome in Arabic (defect 1)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        recentReviewsSectionThreeReviews,
        locale: const Locale('ar'),
      );

      // `title` and `viewAllText` are constructor DEFAULTS, not ARB lookups, so
      expect(find.text('Reviews (3)'), findsOneWidget);
      expect(find.text(_viewAll), findsOneWidget);

      // Both translations already exist in `app_ar.arb`
      expect(find.text(_reviewsTitleAr), findsNothing);
      expect(find.text(_viewAllAr), findsNothing);
    });

    testWidgets('the verified badge is unreachable English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        recentReviewsSectionArabicReviewer,
        locale: const Locale('ar'),
      );

      // `RecentReviewsSection` does not expose
      expect(find.text(_verifiedBadge), findsOneWidget);
      expect(find.text('عميل موثّق'), findsNothing);
    });

    testWidgets('an Arabic reviewer is anonymised into a "?" avatar', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, recentReviewsSectionArabicReviewer);

      // Defect 3: `OmdsReviewCard._buildUserAvatar` matches `[a-zA-Z]` and
      expect(find.text('?'), findsNWidgets(2));
      expect(find.text('ليلى الحاج'), findsOneWidget);

      // The contrast with a Latin name, so this pins the regex and not the
      await pumpPreview(tester, recentReviewsSectionNoViewAll);
      expect(find.text('?'), findsNothing);
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('the card header row overflows at 200% text (defect 4)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, recentReviewsSectionLongContent);
      expect(
        tester.takeException(),
        isNull,
        reason: 'at 1.0 the row fits — which is why this defect never shows in '
            'the default EN light rendering',
      );

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, recentReviewsSectionLongContent);

      // The trailing `timeAgo` stamp is neither Flexible nor maxLines-capped,
      expect(
        tester.takeException(),
        isA<FlutterError>(),
        reason: 'the header Row should overflow at the 200% accessibility '
            'ceiling; if it no longer does, OmdsReviewCard was fixed',
      );
    });

    testWidgets('a spelled-out timeAgo overflows the row at 1.0 as well', (
      WidgetTester tester,
    ) async {
      // Deliberately NOT a preview state: the harness above requires every
      await tester.pumpWidget(
        previewCanvas(
          // Mirrors the preview host: the Align is load-bearing (a Scaffold
          () => const Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(
              width: 350,
              child: SingleChildScrollView(
                child: RecentReviewsSection(
                  reviews: <RecentReviewPreview>[
                    RecentReviewPreview(
                      userName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
                      rating: 5,
                      reviewText: 'Great delivery, fast and friendly.',
                      timeAgo: '11 months and 3 weeks ago',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      // Measured: the stamp alone is 310 px of the 318 px content row, so the
      expect(tester.getSize(find.text('11 months and 3 weeks ago')).width, 310);
      expect(
        tester.getSize(find.text('Abdulrahman Al-Muhandis Al-Trabulsi')).width,
        0,
      );
      expect(
        tester.takeException(),
        isA<FlutterError>(),
        reason: 'the 318 px content row overflows by 44 px. Delete this test '
            'when OmdsReviewCard constrains the stamp — it is a gap, not a '
            'contract.',
      );
    });

    test('the stars are OMDS gold, not the brand orange', () {
      // Defect 5: `_ReviewCardItem` passes no `starColor`, so these cards paint
      expect(AppTheme.light().colorScheme.primary, isNot(_omdsGold));
    });
  });
}
