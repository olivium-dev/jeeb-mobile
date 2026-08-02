// Render tests for the OrderHistoryScreen previews.

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
/// `Loading · first page` is deliberately absent — see the header note and its
const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Active · two live deliveries': orderHistoryScreenActive,
  'Empty · no orders yet': orderHistoryScreenEmpty,
  'Error · cold load failed': orderHistoryScreenErrorServer,
  'Date filter applied': orderHistoryScreenDateFilterApplied,
  'Longest content · compact 320': orderHistoryScreenLongestContent,
};

/// One string per state that no OTHER state below can produce.
/// Every cast prices its rows differently precisely so this map can exist: the
const Map<String, String> _expectedText = <String, String>{
  // The reference cast's priced row. Its neighbour has NO amount, which is what
  'Active · two live deliveries': '\u2066\$12.50\u2069',
  // A successful read that came back with nothing — the Active tab's own
  'Empty · no orders yet': 'Active deliveries will show up here.',
  // …and the failure copy, which is a different sentence from the empty one.
  'Error · cold load failed': 'Something went wrong on our end. Please try again.',
  // The chip label that only a non-empty `OrderDateRange` produces.
  'Date filter applied': 'Date filter applied',
  // The ceiling's money token: zero-decimal LBP at the 2026 peg, the widest
  'Longest content · compact 320': '\u2066LBP 1,335,000.00\u2069',
};

/// Wraps a preview the way the preview canvas does — real themes, real
/// localizations, the shared [jeebPreviewHost] — plus the golden font families
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
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
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
    testWidgets('an unpriced row shows the em-dash, never a fabricated zero', (
      WidgetTester tester,
    ) async {
      await _pump(tester, orderHistoryScreenActive);

      expect(find.text('—'), findsOneWidget);
      expect(find.textContaining('0.00'), findsNothing);
    });

    // The empty/error pair. A failed cold read leaves `orders` empty too, so a
    testWidgets('the empty preview is the EMPTY state, and it can be pulled', (
      WidgetTester tester,
    ) async {
      await _pump(tester, orderHistoryScreenEmpty);

      expect(find.byType(OmdsEmptyState), findsOneWidget);
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.byType(OmdsLoadingState), findsNothing);
      // The empty branch keeps the retry gesture: it is a ListView inside
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
    testWidgets('an unknown wire status still renders a row', (
      WidgetTester tester,
    ) async {
      await _pump(tester, orderHistoryScreenLongestContent);

      expect(find.text('In progress'), findsOneWidget);
      expect(find.byType(OrderHistoryCard), findsNWidgets(2));
    });

    // The finding the `matrix: true` on the filtered preview exists for. Above
    testWidgets('the filter chip keeps a 16 pt gutter at 1x and loses it at '
        '200%', (WidgetTester tester) async {
      await _pump(tester, orderHistoryScreenDateFilterApplied);

      final Rect screenAtOneX = tester.getRect(find.byType(OrderHistoryScreen));
      final Rect chipAtOneX = tester.getRect(_filterChip);
      expect(chipAtOneX.left - screenAtOneX.left, Spacing.medium);
      expect(screenAtOneX.right - chipAtOneX.right, Spacing.medium);
      // At 1x it is also full-bleed between those gutters — an `Expanded` chip,
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
      expect(_filterChip, findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });
  });
}
