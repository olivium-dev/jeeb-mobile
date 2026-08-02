// Render tests for the JeeberPendingOffersScreen previews.

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
  'Longest content · compact 320': '1440 min',
};

/// Wraps a preview the way the preview canvas does — real themes, real
/// localizations, the shared [jeebPreviewHost] — plus the golden font families
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
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
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
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    // sprint-009. The branch that must never regress: withdrawing an accepted
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
    testWidgets('an offer note reaches no pixel of the list', (
      WidgetTester tester,
    ) async {
      await _pump(tester, jeeberPendingOffersScreenAwaitingDecision);

      expect(find.bySemanticsIdentifier('pending_offer_0'), findsOneWidget);
      expect(find.textContaining('lobby'), findsNothing);
    });

    // Every non-list body on this screen is a `mainAxisSize.min` Column handed
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
      expect(spinner.width, lessThan(screen.width / 2));
    });

    // The `matrix: true` states exist for this rendering, so it is asserted
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
      expect(find.text(r'$21.90'), findsNothing);
      await tester.scrollUntilVisible(
        find.text(r'$21.90'),
        200,
        scrollable: _pendingList,
      );
      expect(find.text(r'$21.90'), findsOneWidget);

      // Nothing on the surface says how many offers there are, or what they
      expect(find.text('6'), findsNothing);
    });
  });

  // The loading body is an `OmdsLoadingState`, i.e. a repeating
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
      expect(find.byType(OmdsPullToRefresh), findsNothing);
    });
  });
}
