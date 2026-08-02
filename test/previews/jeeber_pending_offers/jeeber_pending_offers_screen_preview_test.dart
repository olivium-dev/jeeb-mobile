// Render tests for the JeeberPendingOffersScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`, with the two deliberate deviations
// described below.
//
// This screen picks ONE of four bodies off `SubmittedOffersState` — spinner,
// error, empty state, or the list — under identical chrome (the same app bar,
// the same title, the same back arrow). A render-only check therefore passes on
// almost any mis-wiring: an "empty" preview whose fixture started throwing looks
// exactly like the error state to it, and the two are one branch order apart in
// the view. Every state below is pinned on a string only IT can produce, and the
// specifics group pins the structural claims a string cannot: which body
// mounted, whether a terminal row still offers Withdraw, and whether the frame
// under test is a phone or the 800 pt test surface.
//
// ## Why this suite builds its own canvas
//
// `previewCanvas` in the shared harness builds `AppTheme.light()` unmodified and
// loads no fonts, so every glyph lays out in Flutter's 1-em test face — Latin
// ~2x too wide, Arabic ~2.4x. One of the previews below is a layout ceiling on a
// 320 pt frame whose whole point is whether the content fits; measured through
// the fake face it would report overflows that exist on no device. This suite
// therefore loads the real Inter faces AND applies `withGoldenTestFonts`, which
// is what puts the Arabic fallback family on the theme's text roles — without it
// `loadInterTestFont` registers the Noto subset but nothing selects it.
//
// ## Why `Loading · cold read` is not in the shared map
//
// It renders an `OmdsLoadingState` and no copy at all, so there is no string
// that distinguishes it from a broken build of any other state. Its own group
// at the bottom pins it the only way available: the indicator is mounted and
// every other body is absent.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The previews under test, by their `@JeebPreview(name:)`.
///
/// `Loading · cold read` is deliberately absent — see the header note and its
/// own group at the bottom.
const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Awaiting decision': jeeberPendingOffersScreenAwaitingDecision,
  'Mixed outcomes · accepted / not selected':
      jeeberPendingOffersScreenMixedOutcomes,
  'Empty · nothing submitted': jeeberPendingOffersScreenEmpty,
  'Load failed · retry': jeeberPendingOffersScreenLoadFailed,
  'Long list · scrolls': jeeberPendingOffersScreenLongList,
  'Longest content · compact 320': jeeberPendingOffersScreenLongestContent,
};

/// One string per state that no OTHER state below can produce.
///
/// Every price in the fixtures is unique across casts precisely so this map can
/// exist: the chrome is identical in all six, so the money string is the only
/// thing that identifies which cast was loaded.
const Map<String, String> _expectedText = <String, String>{
  // The reference cast's first bid.
  'Awaiting decision': r'$12.50',
  // The LOST row of the lifecycle cast.
  'Mixed outcomes · accepted / not selected': r'$9.75',
  // A successful read that came back with nothing — never the failure copy.
  'Empty · nothing submitted': 'No pending offers',
  // …and the failure copy, which is about SENDING an offer, not listing them.
  'Load failed · retry':
      'Something went wrong sending your offer. Please try again.',
  // The scrolling cast's cheapest bid, first in render order.
  'Long list · scrolls': r'$4.25',
  // The ceiling's multi-day ETA. Pinned instead of the LBP money string because
  // the ETA is locale-stable in EN and the money string is what ELLIPSIZES —
  // `find.text` would still match a fully-clipped price.
  'Longest content · compact 320': '1440 min',
};

/// Wraps a preview the way the preview canvas does — real themes, real
/// localizations, the shared [jeebPreviewHost] — plus the golden font families
/// so Latin and Arabic measure the way they do on a device.
Widget _jeeberPendingOffersScreenCanvas(
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
    _jeeberPendingOffersScreenCanvas(preview, locale, textScale: textScale),
  );
  await tester.pumpAndSettle();
}

/// The [RenderParagraph] behind the one [Text] whose `data` is [text].
RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

/// The scrollable inside the pending list, for the states whose evidence sits
/// below the fold: the render surface is 800x600, so a preview asking for an
/// 844 pt phone gets ~600 and the last rows are off-screen.
Finder get _pendingList => find.descendant(
  of: find.byType(ListView),
  matching: find.byType(Scrollable),
);

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  group('JeeberPendingOffersScreen previews', () {
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

  group('JeeberPendingOffersScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — `_jeeberPendingOffersScreenCanvas` produces the
    // same widget types, so the `BlocProvider` element is UPDATED rather than
    // replaced and keeps the cubit the first preview created.
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of the row layout under
      // review applies there.
      await _pump(tester, jeeberPendingOffersScreenAwaitingDecision);

      expect(
        tester.getSize(find.byType(JeeberPendingOffersScreen)).width,
        390,
      );
    });

    testWidgets('the ceiling preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await _pump(tester, jeeberPendingOffersScreenLongestContent);

      expect(
        tester.getSize(find.byType(JeeberPendingOffersScreen)),
        const Size(320, 568),
      );
    });

    // The empty/failed pair. A failed read leaves `offers` empty too, so a body
    // that tested emptiness first would render "No pending offers" — a claim
    // about server data — over a read that never happened.
    testWidgets('the empty preview is the EMPTY state, not the error one', (
      WidgetTester tester,
    ) async {
      await _pump(tester, jeeberPendingOffersScreenEmpty);

      expect(find.byType(OmdsEmptyState), findsOneWidget);
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.byType(OmdsLoadingState), findsNothing);
      // No rows, and therefore no Withdraw control anywhere.
      expect(find.bySemanticsIdentifier('pending_offer_0'), findsNothing);
    });

    testWidgets('the failure body is an error with a retry, never the empty '
        'state', (WidgetTester tester) async {
      await _pump(tester, jeeberPendingOffersScreenLoadFailed);

      expect(find.byType(OmdsErrorState), findsOneWidget);
      expect(find.byType(OmdsEmptyState), findsNothing);
      expect(find.text('No pending offers'), findsNothing);
      // An error the jeeber cannot act on is barely better than the empty state
      // it replaced.
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    // sprint-009. The branch that must never regress: withdrawing an accepted
    // offer would ask the gateway to delete a bid that has already become a
    // delivery.
    testWidgets('a TERMINAL row shows a badge and NO withdraw; the open row '
        'keeps both', (WidgetTester tester) async {
      await _pump(tester, jeeberPendingOffersScreenMixedOutcomes);

      // Row 0 accepted, row 1 lost — badges, no withdraw.
      expect(
        find.bySemanticsIdentifier('pending_offer_0_status'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('pending_offer_1_status'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('pending_offer_0_withdraw_cta'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('pending_offer_1_withdraw_cta'),
        findsNothing,
      );

      // Row 2 is still open — awaiting label + withdraw, no badge.
      expect(
        find.bySemanticsIdentifier('pending_offer_awaiting_label'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('pending_offer_2_withdraw_cta'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('pending_offer_2_status'), findsNothing);
    });

    // The note a jeeber typed on the offer-submission screen is carried on the
    // model and rendered by nothing. This pins the defect rather than asserting
    // it away — if a row ever starts showing it, this test is where to say so.
    testWidgets('an offer note reaches no pixel of the list', (
      WidgetTester tester,
    ) async {
      await _pump(tester, jeeberPendingOffersScreenAwaitingDecision);

      expect(find.bySemanticsIdentifier('pending_offer_0'), findsOneWidget);
      expect(find.textContaining('lobby'), findsNothing);
    });

    // Every non-list body on this screen is a `mainAxisSize.min` Column handed
    // straight to `Scaffold.body`, and Scaffold lays its body out under LOOSE
    // constraints at the content origin. So none of them is centred: they hang
    // off the bottom of the app bar, and the spinner — which shrink-wraps in
    // BOTH axes — ends up in the corner. Pinned rather than asserted away; the
    // fix is `OmdsEmptyStatePage` / `OmdsErrorStatePage`, or a `Center`.
    testWidgets('the empty body hangs off the app bar instead of centring', (
      WidgetTester tester,
    ) async {
      await _pump(tester, jeeberPendingOffersScreenEmpty);

      final Rect screen = tester.getRect(
        find.byType(JeeberPendingOffersScreen),
      );
      final Rect body = tester.getRect(find.byType(OmdsEmptyState));

      // Flush against the bottom of the 56 dp app bar…
      expect(body.top - screen.top, 56);
      // …which leaves far more space below it than above it.
      expect(
        screen.bottom - body.bottom,
        greaterThan(2 * (body.top - screen.top)),
      );
    });

    testWidgets('the cold-load spinner sits in the top-left corner', (
      WidgetTester tester,
    ) async {
      await _pump(tester, jeeberPendingOffersScreenLoading);

      final Rect screen = tester.getRect(
        find.byType(JeeberPendingOffersScreen),
      );
      final Rect spinner = tester.getRect(find.byType(OmdsLoadingState));

      expect(spinner.left, screen.left);
      expect(spinner.top - screen.top, 56);
      // 48 dp indicator inside 20 dp of padding — it never grows to fill the
      // body, so it is nowhere near the middle of a 390 pt frame.
      expect(spinner.width, lessThan(screen.width / 2));
    });

    // The `matrix: true` states exist for this rendering, so it is asserted
    // here rather than left to whoever opens the canvas. Both numbers are
    // measured through the REAL faces — under the 1-em test face they would be
    // roughly double and would report a truncation that no device shows.
    testWidgets('at 200% on the 320 frame the price and the app-bar title '
        'both truncate', (WidgetTester tester) async {
      await _pump(
        tester,
        jeeberPendingOffersScreenLongestContent,
        textScale: 2.0,
      );

      final RenderParagraph price = _paragraph(tester, 'L£2,750,000');
      expect(price.didExceedMaxLines, isTrue);
      expect(
        price.getMaxIntrinsicWidth(double.infinity),
        greaterThan(price.size.width),
      );

      // The ETA beside it yields nothing — it is a bare Text with no Flexible,
      // so it takes its intrinsic width first and the Expanded price pays.
      final RenderParagraph eta = _paragraph(tester, '1440 min');
      expect(eta.didExceedMaxLines, isFalse);

      // And the chrome truncates with the content.
      expect(_paragraph(tester, 'Pending offers').didExceedMaxLines, isTrue);
    });

    testWidgets('at 1x the same ceiling row fits with room to spare', (
      WidgetTester tester,
    ) async {
      await _pump(tester, jeeberPendingOffersScreenLongestContent);

      final RenderParagraph price = _paragraph(tester, 'L£2,750,000');
      expect(price.didExceedMaxLines, isFalse);
      expect(
        price.getMaxIntrinsicWidth(double.infinity),
        lessThan(price.size.width),
      );
      expect(_paragraph(tester, 'Pending offers').didExceedMaxLines, isFalse);
    });

    // The terminal badge is `maxLines: 1` with no `overflow`, which WOULD clip
    // without an ellipsis — but it does not clip at any size this screen is
    // reviewed at. Asserted so the note in the preview section stays honest.
    testWidgets('the terminal badge does not clip, even at 200% on 320', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        jeeberPendingOffersScreenLongestContent,
        textScale: 2.0,
      );

      expect(_paragraph(tester, 'Request declined').didExceedMaxLines, isFalse);
    });

    testWidgets('the long list scrolls, and nothing counts it', (
      WidgetTester tester,
    ) async {
      await _pump(tester, jeeberPendingOffersScreenLongList);

      // The last bid is below the fold on the 600 pt render surface — which is
      // also true of a real 844 pt phone for this cast.
      expect(find.text(r'$21.90'), findsNothing);
      await tester.scrollUntilVisible(
        find.text(r'$21.90'),
        200,
        scrollable: _pendingList,
      );
      expect(find.text(r'$21.90'), findsOneWidget);

      // Nothing on the surface says how many offers there are, or what they
      // reserve: the body is a bare ListView under an app bar.
      expect(find.text('6'), findsNothing);
    });
  });

  // The loading body is an `OmdsLoadingState`, i.e. a repeating
  // `CircularProgressIndicator`. The preview mutes its ticker so `pumpAndSettle`
  // returns, but it still has no copy of its own — so its state is pinned by the
  // indicator plus the absence of every other body.
  group('JeeberPendingOffersScreen previews · Loading · cold read', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · cold read · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await _pump(tester, jeeberPendingOffersScreenLoading, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · cold read renders its own state', (
      WidgetTester tester,
    ) async {
      await _pump(tester, jeeberPendingOffersScreenLoading);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      // None of the three other bodies.
      expect(find.byType(OmdsEmptyState), findsNothing);
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.byType(ListView), findsNothing);
      // …and no copy at all: while `GET /v1/offers?jeeberId=` is outstanding
      // the screen says nothing about what it is doing or how long it takes.
      expect(find.byType(OmdsPullToRefresh), findsNothing);
    });
  });
}
