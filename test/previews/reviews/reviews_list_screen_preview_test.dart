// Render tests for the ReviewsListScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`, with the deliberate deviations
// described below.
//
// This screen picks ONE of four bodies off `ReviewsState.status` — skeletons,
// error, empty state, or the list — under identical chrome (the same
// [OMDSAppBar], the same back button). A render-only check therefore passes on
// almost any mis-wiring: an "empty" preview whose fixture started throwing looks
// like the error state to it, and the two are one branch apart in the view.
// Every state below is pinned on a string only IT can produce, and the specifics
// group pins the structural claims a string cannot — which body mounted, whether
// the surface has an app bar at all, and whether the frame under test is a phone
// or the 800 pt test surface.
//
// ## Why this suite builds its own canvas
//
// `previewCanvas` in the shared harness builds `AppTheme.light()` unmodified and
// loads no fonts, so every glyph lays out in Flutter's 1-em test face — Latin
// ~2x too wide, Arabic ~2.4x. The assertions at the bottom are about whether the
// aggregate header FITS on a 320 pt frame at 200% text; measured through the
// fake face they would report a breakage that exists on no device. This suite
// therefore loads the real Inter faces AND applies `withGoldenTestFonts`, which
// is what puts the Arabic fallback family on the theme's text roles — without it
// `loadInterTestFont` registers the Noto subset but nothing selects it.
//
// ## Why two states are not in the shared map
//
// `Loading · first page` draws six shimmer rows and no copy at all, and
// `Resolving session id` is a bare spinner with no chrome — neither has a string
// that distinguishes it from a broken build of any other state. Each gets its
// own group, pinned the only way available: the body that mounted plus the
// absence of every other one.

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
///
/// `Loading · first page` and `Resolving session id` are deliberately absent —
/// see the header note and their own groups at the bottom.
const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Loaded · rated jeeber': reviewsListScreenRated,
  'Empty · no reviews yet': reviewsListScreenEmpty,
  'Error · offline': reviewsListScreenErrorNetwork,
  'Cold start · New Jeeber': reviewsListScreenColdStart,
  'Score withheld · 42 ratings': reviewsListScreenScoreWithheld,
  'Longest content · compact 320': reviewsListScreenLongestContent,
};

/// One string per state that no OTHER state below can produce.
///
/// Reviewer NAMES are unusable here on purpose: `ReviewRow` prints each one
/// twice (its own attribution node, then again as `OmdsReviewCard.userName`), so
/// `findsOneWidget` on a name fails for reasons that have nothing to do with the
/// state under test. Every pin below is either an aggregate line or a comment
/// body, both of which are rendered exactly once.
const Map<String, String> _expectedText = <String, String>{
  // The only two states that reach the scored header carry different scores and
  // different counts, so the aggregate line identifies the cast on its own.
  'Loaded · rated jeeber': '4.6 · 10 reviews',
  'Longest content · compact 320': '3.9 · 128 reviews',
  // A successful read that came back with nothing — never the error copy.
  'Empty · no reviews yet': 'No reviews yet',
  // …and the offline failure, which is a different sentence from the generic
  // "Could not load reviews." the other three failures collapse into.
  'Error · offline': 'No connection. Check your network and try again.',
  // Both New-badge states render the SAME header, so each is pinned on the one
  // thing that differs: the list under it.
  'Cold start · New Jeeber': 'Great first delivery!',
  'Score withheld · 42 ratings': 'Left the parcel with the concierge.',
};

/// Wraps a preview the way the preview canvas does — real themes, real
/// localizations, the shared [jeebPreviewHost] — plus the golden font families
/// so Latin and Arabic measure the way they do on a device.
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
    // canvas applies it through `Preview(textScaleFactor:)`, which lands on the
    // same `MediaQuery.textScaler` this sets.
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
/// `<score> · <count> <noun>` order in both locales.
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
    // does NOT rebuild these — `_reviewsListScreenCanvas` produces the same
    // widget types, so the `BlocProvider` element is UPDATED rather than
    // replaced and keeps the cubit the first preview created.
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of the layout under review
      // applies there.
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
      // same RefreshIndicator the loaded list uses.
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
      // OUTSIDE the RefreshIndicator, so the one recovery affordance is the
      // silent button — `refresh()` emits nothing until it resolves.
      expect(find.byType(RefreshIndicator), findsNothing);
    });

    // The finding the `Score withheld` preview exists for. `_AggregateHeader`
    // takes its cold-start branch on `coldStart || averageScore == null`, so a
    // jeeber with 42 ratings and a missing score gets the same "New Jeeber"
    // header as a jeeber with one delivery.
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
      // usable probe here: `OmdsReviewCard` paints five of them per row.)
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
    // ellipsize — it grows, and on a 320 pt frame it takes 341 of the 464 dp of
    // list area, cutting the next review at the fold. Measured through the real
    // faces; the numbers are exact, not font-derived.
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
      // stars and its Report button are all below the fold.
      expect(second.top, lessThan(frame.bottom));
      expect(second.bottom, greaterThan(frame.bottom));

      // And it did not ellipsize: the body is one unclamped paragraph.
      final RenderParagraph body = tester.renderObject<RenderParagraph>(
        find.textContaining('He arrived almost an hour after'),
      );
      expect(body.maxLines, isNull);
    });

    // Measured through the REAL faces on the 320 pt frame. The aggregate line
    // is a bare Text in a Row with no Flexible and no maxLines, so whether it
    // fits is a property of the copy, not of the layout — pinned with numbers
    // rather than asserted away. `size.width == maxIntrinsicWidth` is the
    // statement that it was NOT squeezed: a Row child that outgrew its slot
    // would be handed less than it asked for.
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
  // plus the absence of every other body — and by the chrome it keeps, which is
  // what distinguishes it from the session-resolving surface below.
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
  // no ReviewsCubit yet and the FutureBuilder's placeholder is all there is.
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
      // this screen while secure storage is read is the system gesture.
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
