// Render tests for the OrderHistoryScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`, with the two deliberate deviations
// described below.
//
// This screen picks ONE of four bodies off the active tab's `OrderTabState` —
// spinner, error, empty state, or the list — under identical chrome (the same
// filter chip, the same three-tab bar). A render-only check therefore passes on
// almost any mis-wiring: an "empty" preview whose fixture started throwing looks
// exactly like the error state to it, and the two are one branch apart in the
// view. Every state below is pinned on a string only IT can produce, and the
// specifics group pins the structural claims a string cannot — which body
// mounted, whether it can be pulled to refresh, and whether the frame under test
// is a phone or the 800 pt test surface.
//
// ## Why this suite builds its own canvas
//
// `previewCanvas` in the shared harness builds `AppTheme.light()` unmodified and
// loads no fonts, so every glyph lays out in Flutter's 1-em test face — Latin
// ~2x too wide, Arabic ~2.4x. Two of the assertions below are about whether
// content FITS (the 320 pt ceiling, and the error body at 200% text); measured
// through the fake face they would report breakages that exist on no device.
// This suite therefore loads the real Inter faces AND applies
// `withGoldenTestFonts`, which is what puts the Arabic fallback family on the
// theme's text roles — without it `loadInterTestFont` registers the Noto subset
// but nothing selects it.
//
// ## Why `Loading · first page` is not in the shared map
//
// It renders an `OmdsLoadingState` and no copy at all, so there is no string
// that distinguishes it from a broken build of any other state. Its own group at
// the bottom pins it the only way available: the indicator is mounted and every
// other body is absent.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_card.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The previews under test, by their `@JeebPreview(name:)`.
///
/// `Loading · first page` is deliberately absent — see the header note and its
/// own group at the bottom.
const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Active · two live deliveries': orderHistoryScreenActive,
  'Empty · no orders yet': orderHistoryScreenEmpty,
  'Error · cold load failed': orderHistoryScreenErrorServer,
  'Date filter applied': orderHistoryScreenDateFilterApplied,
  'Longest content · compact 320': orderHistoryScreenLongestContent,
};

/// One string per state that no OTHER state below can produce.
///
/// Every cast prices its rows differently precisely so this map can exist: the
/// chrome is identical in all five, so the money token is the only thing that
/// identifies which cast was loaded.
///
/// `MoneyFormat` wraps every amount in a Unicode LTR isolate (U+2066 … U+2069 —
/// JEBV4-98 / F10), spelled as escapes here so the source does not carry
/// invisible direction marks.
const Map<String, String> _expectedText = <String, String>{
  // The reference cast's priced row. Its neighbour has NO amount, which is what
  // the em-dash assertion below is for.
  'Active · two live deliveries': '\u2066\$12.50\u2069',
  // A successful read that came back with nothing — the Active tab's own
  // subtitle, never the Completed/Cancelled one.
  'Empty · no orders yet': 'Active deliveries will show up here.',
  // …and the failure copy, which is a different sentence from the empty one.
  'Error · cold load failed': 'Something went wrong on our end. Please try again.',
  // The chip label that only a non-empty `OrderDateRange` produces.
  'Date filter applied': 'Date filter applied',
  // The ceiling's money token: zero-decimal LBP at the 2026 peg, the widest
  // string this list can render.
  'Longest content · compact 320': '\u2066LBP 1,335,000.00\u2069',
};

/// Wraps a preview the way the preview canvas does — real themes, real
/// localizations, the shared [jeebPreviewHost] — plus the golden font families
/// so Latin and Arabic measure the way they do on a device.
Widget _orderHistoryScreenCanvas(
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
    _orderHistoryScreenCanvas(preview, locale, textScale: textScale),
  );
  await tester.pumpAndSettle();
}

/// The filter chip's own box — the thing whose gutter disappears above 1.5x.
Finder get _filterChip => find.byKey(const Key('order-history-filter-chip'));

/// `orderHistoryTabCompleted` in Arabic ("منجَزة"), spelled as escapes so the
/// source stays ASCII and an editor cannot silently normalize the fatha away.
const String _arabicCompletedTab =
    '\u0645\u0646\u062c\u064e\u0632\u0629';

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  group('OrderHistoryScreen previews', () {
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

  group('OrderHistoryScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — `_orderHistoryScreenCanvas` produces the same
    // widget types, so the `BlocProvider` element is UPDATED rather than
    // replaced and keeps the cubit the first preview created.
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of the layout under review
      // applies there.
      await _pump(tester, orderHistoryScreenActive);

      expect(tester.getSize(find.byType(OrderHistoryScreen)).width, 390);
    });

    testWidgets('the ceiling preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await _pump(tester, orderHistoryScreenLongestContent);

      expect(
        tester.getSize(find.byType(OrderHistoryScreen)),
        const Size(320, 568),
      );
    });

    // Every preview is the ACTIVE tab, and it is not a choice: `_tabController`
    // starts at index 0 and is only ever driven by a tap on the TabBar — it does
    // not read `state.activeTab` — so no fixture can open this screen on
    // Completed or Cancelled. The three tab LABELS are up; only one body is.
    testWidgets('all three tabs are labelled but only the Active body is built',
        (WidgetTester tester) async {
      await _pump(tester, orderHistoryScreenActive);

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);

      expect(find.byKey(const Key('order-history-list-active')), findsOneWidget);
      expect(
        find.byKey(const Key('order-history-list-completed')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('order-history-list-cancelled')),
        findsNothing,
      );
    });

    // T11 / SW-02 at screen level: the unpriced row degrades to a muted em-dash
    // beside a priced one. A fabricated `$0.00` is the regression.
    testWidgets('an unpriced row shows the em-dash, never a fabricated zero', (
      WidgetTester tester,
    ) async {
      await _pump(tester, orderHistoryScreenActive);

      expect(find.text('—'), findsOneWidget);
      expect(find.textContaining('0.00'), findsNothing);
    });

    // The empty/error pair. A failed cold read leaves `orders` empty too, so a
    // body that tested emptiness first would render "No orders yet" — a claim
    // about server data — over a read that never happened.
    testWidgets('the empty preview is the EMPTY state, and it can be pulled', (
      WidgetTester tester,
    ) async {
      await _pump(tester, orderHistoryScreenEmpty);

      expect(find.byType(OmdsEmptyState), findsOneWidget);
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.byType(OmdsLoadingState), findsNothing);
      // The empty branch keeps the retry gesture: it is a ListView inside
      // OmdsPullToRefresh.
      expect(find.byType(OmdsPullToRefresh), findsOneWidget);
    });

    testWidgets('the failure body is an error with a retry — and NO pull '
        'gesture behind it', (WidgetTester tester) async {
      await _pump(tester, orderHistoryScreenErrorServer);

      expect(find.byType(OmdsErrorState), findsOneWidget);
      expect(find.byType(OmdsEmptyState), findsNothing);
      expect(find.text('No orders yet'), findsNothing);
      expect(find.text("Couldn't load orders"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      // The defect this preview exists for: the error branch is returned BARE
      // into the TabBarView. The empty branch beside it has a pull-to-refresh;
      // this one has only the button, and nothing inside it scrolls. (The
      // TabBarView's own page Scrollable is not one — it pages sideways between
      // tabs and cannot move the body a pixel vertically.)
      expect(find.byType(OmdsPullToRefresh), findsNothing);
      expect(
        find.descendant(
          of: find.byType(OmdsErrorState),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
    });

    // The filtered state is the real post-`applyDateRange` state, not a painted
    // chip: the range reset all three tabs and re-read page 1, so the list under
    // the chip is the filtered slice.
    testWidgets('applying a range selects the chip and narrows the list', (
      WidgetTester tester,
    ) async {
      await _pump(tester, orderHistoryScreenDateFilterApplied);

      expect(find.text('Date filter applied'), findsOneWidget);
      expect(find.text('Filter by date'), findsNothing);
      expect(find.byType(OrderHistoryCard), findsOneWidget);
      expect(find.text('\u2066\$7.30\u2069'), findsOneWidget);
    });

    testWidgets('the unfiltered chip reads the CTA copy, not the applied copy', (
      WidgetTester tester,
    ) async {
      await _pump(tester, orderHistoryScreenActive);

      expect(find.text('Filter by date'), findsOneWidget);
      expect(find.text('Date filter applied'), findsNothing);
    });

    // Forward compatibility, at screen level: a status this build has never
    // heard of buckets into Active and renders the localized pill rather than
    // vanishing from the list.
    testWidgets('an unknown wire status still renders a row', (
      WidgetTester tester,
    ) async {
      await _pump(tester, orderHistoryScreenLongestContent);

      expect(find.text('In progress'), findsOneWidget);
      expect(find.byType(OrderHistoryCard), findsNWidgets(2));
    });

    // The finding the `matrix: true` on the filtered preview exists for. Above
    // `_kLargeFilterTextScaleThreshold` (1.5) `_FilterBar` takes its
    // `usesLargeText` branch, which sets the row's horizontal padding to ZERO on
    // both sides — so the chip loses the 16 pt gutter every card below it keeps.
    // Measured through the REAL faces; the numbers are exact, not font-derived.
    testWidgets('the filter chip keeps a 16 pt gutter at 1x and loses it at '
        '200%', (WidgetTester tester) async {
      await _pump(tester, orderHistoryScreenDateFilterApplied);

      final Rect screenAtOneX = tester.getRect(find.byType(OrderHistoryScreen));
      final Rect chipAtOneX = tester.getRect(_filterChip);
      expect(chipAtOneX.left - screenAtOneX.left, Spacing.medium);
      expect(screenAtOneX.right - chipAtOneX.right, Spacing.medium);
      // At 1x it is also full-bleed between those gutters — an `Expanded` chip,
      // not a chip-sized chip.
      expect(chipAtOneX.width, screenAtOneX.width - 2 * Spacing.medium);

      await _pump(
        tester,
        orderHistoryScreenDateFilterApplied,
        textScale: 2.0,
      );

      final Rect screenAtTwoX = tester.getRect(find.byType(OrderHistoryScreen));
      final Rect chipAtTwoX = tester.getRect(_filterChip);
      expect(
        chipAtTwoX.left - screenAtTwoX.left,
        0,
        reason: 'the chip is flush against the leading edge above 1.5x',
      );
      // …while the cards below it are not: their content keeps the inset.
      expect(
        tester.getRect(find.text('Ras Beirut')).left - screenAtTwoX.left,
        greaterThan(Spacing.medium),
      );
      // And it shrink-wraps, because the large-text branch also wraps it in a
      // horizontal SingleChildScrollView. Same control, two silhouettes.
      expect(chipAtTwoX.width, lessThan(screenAtTwoX.width));
    });

    testWidgets('above 1.5x the chip drops its icon and mirrors flush against '
        'the RIGHT edge in AR', (WidgetTester tester) async {
      await _pump(tester, orderHistoryScreenDateFilterApplied);
      expect(
        find.descendant(of: _filterChip, matching: find.byIcon(Icons.tune)),
        findsOneWidget,
      );

      await _pump(
        tester,
        orderHistoryScreenDateFilterApplied,
        locale: const Locale('ar'),
        textScale: 2.0,
      );

      expect(
        find.descendant(of: _filterChip, matching: find.byIcon(Icons.tune)),
        findsNothing,
        reason: 'the icon is dropped so the longer label survives',
      );
      final Rect screen = tester.getRect(find.byType(OrderHistoryScreen));
      final Rect chip = tester.getRect(_filterChip);
      expect(screen.right - chip.right, 0);
    });

    // The `Tab` label is laid out with `softWrap: false` + `TextOverflow.fade`
    // and the TabBar is not scrollable, so a label that outgrows its third of
    // the bar is faded away rather than wrapped. EN is the locale that pays:
    // "Completed" wants 147.0 dp of the 98.0 it gets. AR does not — its label
    // wants 85.5 and gets 85.5 — so this is invisible in the AR reading.
    testWidgets('at 200% the EN tab label is clipped and the AR one is not', (
      WidgetTester tester,
    ) async {
      await _pump(tester, orderHistoryScreenActive, textScale: 2.0);

      final RenderParagraph completed = tester.renderObject<RenderParagraph>(
        find.text('Completed'),
      );
      expect(
        completed.getMaxIntrinsicWidth(double.infinity),
        greaterThan(completed.size.width),
      );

      await _pump(
        tester,
        orderHistoryScreenActive,
        locale: const Locale('ar'),
        textScale: 2.0,
      );

      final RenderParagraph completedAr = tester.renderObject<RenderParagraph>(
        find.text(_arabicCompletedTab),
      );
      expect(
        completedAr.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(completedAr.size.width),
      );
    });

    // The error branch has no scroll view, so whether the retry is REACHABLE is
    // a pure question of how tall the tab body is. Pinned with numbers rather
    // than asserted away: measured through the real faces on the 390 pt frame,
    // the body clears the bottom at every scale the app supports — an earlier
    // reading that called this an overflow was taken under the 1-em test face,
    // where the wrapped message is roughly twice as tall as it is on a device.
    testWidgets('at 200% the error body still clears the frame — but only '
        'because the frame is tall enough', (WidgetTester tester) async {
      await _pump(tester, orderHistoryScreenErrorServer, textScale: 2.0);

      final Rect screen = tester.getRect(find.byType(OrderHistoryScreen));
      final Rect body = tester.getRect(find.byType(OmdsErrorState));
      final Rect retry = tester.getRect(find.text('Try again'));
      final Rect icon = tester.getRect(find.byIcon(Icons.error_outline));

      // The only recovery affordance on the state is on screen.
      expect(retry.bottom, lessThan(screen.bottom));
      // Icon top → button bottom is 388 dp at 200%, inside a body given 486.
      // Add `OmdsErrorState`'s own 20 dp padding top and bottom and the branch
      // needs ~428 dp of tab area; below that it clips instead of scrolling,
      // because nothing here scrolls.
      expect(retry.bottom - icon.top, greaterThan(380));
      expect(body.height, greaterThan(retry.bottom - icon.top));
      expect(
        find.descendant(
          of: find.byType(OmdsErrorState),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
    });
  });

  // The loading body is an `OmdsLoadingState`, i.e. a repeating
  // `CircularProgressIndicator`. The preview mutes its ticker so `pumpAndSettle`
  // returns, but it still has no copy of its own — so its state is pinned by the
  // indicator plus the absence of every other body.
  group('OrderHistoryScreen previews · Loading · first page', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · first page · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await _pump(tester, orderHistoryScreenLoadingFirstPage, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · first page renders its own state', (
      WidgetTester tester,
    ) async {
      await _pump(tester, orderHistoryScreenLoadingFirstPage);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      // None of the three other bodies.
      expect(find.byType(OmdsEmptyState), findsNothing);
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.byType(OrderHistoryCard), findsNothing);
      // The chrome stays up while the list area spins: the filter chip and the
      // tab bar live outside the TabBarView.
      expect(_filterChip, findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });
  });
}

