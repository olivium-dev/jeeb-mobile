// Render tests for the ReviewsListScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/reviews/presentation/reviews_list_screen.dart';
import 'package:jeeb_mobile/features/reviews/presentation/widgets/review_row.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The previews under test, by their `@JeebPreview(name:)`.
/// `Loading · first page` and `Resolving session id` are deliberately absent —
const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Loaded · rated jeeber': reviewsListScreenRated,
  'Empty · no reviews yet': reviewsListScreenEmpty,
  'Error · offline': reviewsListScreenErrorNetwork,
  'Cold start · New Jeeber': reviewsListScreenColdStart,
  'Score withheld · 42 ratings': reviewsListScreenScoreWithheld,
  'Longest content · compact 320': reviewsListScreenLongestContent,
};

/// One string per state that no OTHER state below can produce.
/// Reviewer NAMES are unusable here on purpose: `ReviewRow` prints each one
const Map<String, String> _expectedText = <String, String>{
  // The only two states that reach the scored header carry different scores and
  'Loaded · rated jeeber': '4.6 · 10 reviews',
  'Longest content · compact 320': '3.9 · 128 reviews',
  // A successful read that came back with nothing — never the error copy.
  'Empty · no reviews yet': 'No reviews yet',
  // …and the offline failure, which is a different sentence from the generic
  'Error · offline': 'No connection. Check your network and try again.',
  // Both New-badge states render the SAME header, so each is pinned on the one
  'Cold start · New Jeeber': 'Great first delivery!',
  'Score withheld · 42 ratings': 'Left the parcel with the concierge.',
};

/// Wraps a preview the way the preview canvas does — real themes, real
/// localizations, the shared [jeebPreviewHost] — plus the golden font families
Widget _reviewsListScreenCanvas(
  Widget Function() preview,
  Locale locale, {
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: withGoldenTestFonts(AppTheme.light()),
    darkTheme: withGoldenTestFonts(AppTheme.dark()),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // The 200% rendering the `matrix: true` previews put in the canvas. The
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: jeebPreviewHost(preview()),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    _reviewsListScreenCanvas(preview, locale, textScale: textScale),
  );
  await tester.pumpAndSettle();
}

/// The D59 header's chip label, which BOTH New-badge states render.
Finder get _newBadge => find.text('New');

/// `reviewsTitle` in Arabic — the app-bar title the loading state keeps and the
/// session-resolving state does not have.
const String _arabicTitle = 'كل التقييمات';

/// The Arabic aggregate line of the ceiling cast. Note that only the trailing
/// noun localizes: `ReviewsL10n.aggregate` builds the same
const String _arabicAggregate = '3.9 · 128 تقييمات';

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  group('ReviewsListScreen previews', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final MapEntry<String, Widget Function()> entry
          in _previews.entries) {
        testWidgets('${entry.key} · ${locale.languageCode}', (
          WidgetTester tester,
        ) async {
          await _pump(tester, entry.value, locale: locale);

          expect(tester.takeException(), isNull);
        });
      }
    }

    _expectedText.forEach((String state, String text) {
      testWidgets('$state renders its own state', (WidgetTester tester) async {
        await _pump(tester, _previews[state]!);

        expect(find.text(text), findsOneWidget);
      });
    });
  });

  group('ReviewsListScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      await _pump(tester, reviewsListScreenRated);

      expect(tester.getSize(find.byType(ReviewsListScreen)).width, 390);
    });

    testWidgets('the ceiling preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await _pump(tester, reviewsListScreenLongestContent);

      expect(
        tester.getSize(find.byType(ReviewsListScreen)),
        const Size(320, 568),
      );
    });

    testWidgets('the rated state shows the SCORE, not the New badge', (
      WidgetTester tester,
    ) async {
      await _pump(tester, reviewsListScreenRated);

      expect(find.text('4.6 · 10 reviews'), findsOneWidget);
      expect(_newBadge, findsNothing);
      expect(find.byType(ReviewRow), findsWidgets);
      // The scored header is a star + a line of text, never the chip's note.
      expect(
        find.textContaining('overall score appears after'),
        findsNothing,
      );
    });

    testWidgets('the empty preview is the EMPTY state, and it can be pulled', (
      WidgetTester tester,
    ) async {
      await _pump(tester, reviewsListScreenEmpty);

      expect(find.byType(OmdsEmptyState), findsOneWidget);
      expect(find.byType(ReviewRow), findsNothing);
      expect(find.text('Could not load reviews.'), findsNothing);
      // The empty branch keeps the retry gesture: it is a ListView inside the
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('the failure body is an error with a retry — and NO pull '
        'gesture behind it', (WidgetTester tester) async {
      await _pump(tester, reviewsListScreenErrorNetwork);

      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(OmdsEmptyState), findsNothing);
      expect(find.byType(ReviewRow), findsNothing);
      // The defect this preview exists for: the error branch is returned
      expect(find.byType(RefreshIndicator), findsNothing);
    });

    // The finding the `Score withheld` preview exists for. `_AggregateHeader`
    testWidgets('a NULL score renders "New Jeeber" over 42 ratings', (
      WidgetTester tester,
    ) async {
      await _pump(tester, reviewsListScreenScoreWithheld);

      expect(_newBadge, findsOneWidget);
      expect(
        find.text(
          'New Jeeber — overall score appears after a few completed '
          'deliveries.',
        ),
        findsOneWidget,
      );
      // …and no aggregate line at all, for any count. (`Icons.star` is not a
      expect(find.textContaining('42 reviews'), findsNothing);
      expect(find.textContaining('· 42'), findsNothing);
      // The rows underneath are real, which is what makes the badge wrong.
      expect(find.byType(ReviewRow), findsNWidgets(2));
    });

    testWidgets('the cold-start state renders the SAME header from one rating',
        (WidgetTester tester) async {
      await _pump(tester, reviewsListScreenColdStart);

      expect(_newBadge, findsOneWidget);
      expect(
        find.text(
          'New Jeeber — overall score appears after a few completed '
          'deliveries.',
        ),
        findsOneWidget,
      );
      expect(find.byType(ReviewRow), findsOneWidget);
    });

    // The ceiling. Nothing on a row clamps, so a long comment does not
    testWidgets('one long review fills the compact frame and cuts the next at '
        'the fold', (WidgetTester tester) async {
      await _pump(tester, reviewsListScreenLongestContent);

      expect(find.byType(ReviewRow), findsNWidgets(2));
      final Rect frame = tester.getRect(find.byType(ReviewsListScreen));
      final Rect first = tester.getRect(find.byType(ReviewRow).first);
      final Rect second = tester.getRect(find.byType(ReviewRow).last);

      // One review, 341 dp of a 568 dp phone.
      expect(first.height, greaterThan(330));
      expect(first.bottom, lessThan(frame.bottom));
      // The next one starts on screen and is clipped by it — its comment, its
      expect(second.top, lessThan(frame.bottom));
      expect(second.bottom, greaterThan(frame.bottom));

      // And it did not ellipsize: the body is one unclamped paragraph.
      final RenderParagraph body = tester.renderObject<RenderParagraph>(
        find.textContaining('He arrived almost an hour after'),
      );
      expect(body.maxLines, isNull);
    });

    // Measured through the REAL faces on the 320 pt frame. The aggregate line
    testWidgets('the aggregate line clears the compact frame at 200%, in both '
        'locales', (WidgetTester tester) async {
      await _pump(tester, reviewsListScreenLongestContent, textScale: 2.0);

      final Rect frame = tester.getRect(find.byType(ReviewsListScreen));
      final RenderParagraph en = tester.renderObject<RenderParagraph>(
        find.text('3.9 · 128 reviews'),
      );
      // 228.1 dp of the 264.0 the padded Row can give it.
      expect(
        en.size.width,
        closeTo(en.getMaxIntrinsicWidth(double.infinity), 0.01),
      );
      expect(en.size.width, lessThan(264.0));
      expect(tester.getRect(find.text('3.9 · 128 reviews')).right,
          lessThan(frame.right));

      await _pump(
        tester,
        reviewsListScreenLongestContent,
        locale: const Locale('ar'),
        textScale: 2.0,
      );

      final RenderParagraph ar = tester.renderObject<RenderParagraph>(
        find.text(_arabicAggregate),
      );
      // 214.1 dp — shorter than the English line, not longer.
      expect(
        ar.size.width,
        closeTo(ar.getMaxIntrinsicWidth(double.infinity), 0.01),
      );
      expect(ar.size.width, lessThan(264.0));
    });
  });

  // Six shimmer rows and no copy. Its state is pinned by the placeholder count
  group('ReviewsListScreen previews · Loading · first page', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · first page · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await _pump(tester, reviewsListScreenLoadingFirstPage, locale: locale);

        expect(tester.takeException(), isNull);
        expect(
          find.text(locale.languageCode == 'ar' ? _arabicTitle : 'All reviews'),
          findsOneWidget,
        );
      });
    }

    testWidgets('Loading · first page renders its own state', (
      WidgetTester tester,
    ) async {
      await _pump(tester, reviewsListScreenLoadingFirstPage);

      // Always six, whatever the 20-item page the cubit asked for.
      expect(find.byType(OmdsListItemShimmer), findsNWidgets(6));
      expect(find.byType(ReviewRow), findsNothing);
      expect(find.byType(OmdsEmptyState), findsNothing);
      expect(find.text('Retry'), findsNothing);
      // The chrome stays up while the list area shimmers.
      expect(find.byType(OMDSAppBar), findsOneWidget);
    });
  });

  // The pre-cubit surface: `AuthTokenStore.userId` has not resolved, so there is
  group('ReviewsListScreen previews · Resolving session id', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Resolving session id · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await _pump(tester, reviewsListScreenResolvingSession, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Resolving session id has a spinner and NO app bar', (
      WidgetTester tester,
    ) async {
      await _pump(tester, reviewsListScreenResolvingSession);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      // The finding: no chrome at all, so no back button — the only way off
      expect(find.byType(OMDSAppBar), findsNothing);
      expect(find.text('All reviews'), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      // …and none of the four ReviewsState bodies has been reached.
      expect(find.byType(OmdsListItemShimmer), findsNothing);
      expect(find.byType(ReviewRow), findsNothing);
      expect(find.byType(OmdsEmptyState), findsNothing);
    });
  });
}
