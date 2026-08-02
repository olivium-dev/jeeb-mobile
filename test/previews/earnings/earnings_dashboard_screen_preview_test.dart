// Render tests for the EarningsDashboardScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently.
// This follows the template in `test/previews/preview_test_harness.dart`.
//
// All six previews are the SAME widget over the same one seam — a
// `BlocProvider<EarningsCubit>` above it — told apart only by what the fixture
// repository answers. Three of them (`Empty`, `Totals only`, `Load failed`) are
// bodies with no headline cards at all, so a suite that asked only "did
// something render?" would pass on three copies of the empty state. Every state
// therefore pins a string only IT can produce.
//
// ## Fonts: this suite loads the real faces, and that changes the answers
//
// `preview_test_harness.dart` deliberately does not load fonts, so text lays out
// in Flutter's 1-em-per-glyph test face — Latin measures ~2x too wide and Arabic
// ~2.4x. Every geometry assertion below is therefore taken through
// `loadInterTestFont()` + `withGoldenTestFonts()` (see `_earningsCanvas`), and
// the numbers are NOT the ones the same fixtures produce under the fake face.
// The period-pill row is the clearest case: through the shipping Inter it does
// not overflow a 390 dp phone AT ALL at 100% text, and overflows by 70 dp at
// 200%. `test/previews/shell/earnings_tab_preview_test.dart` measures the same
// row without fonts and records ~42 dp over at 100% and >250 dp at 200% — the
// first of those is a font artifact and describes no device.
//
// So the defect the pills carry is a LARGE-TEXT defect, not an everyday one,
// and saying which is the entire value of loading the fonts.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/earnings/presentation/earnings_dashboard_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// `MoneyFormat` wraps every amount in an LTR isolate (JEBV4-98 / F10), so the
/// rendered string is never the bare token.
const String _lri = '\u2066';
const String _pdi = '\u2069';

const String _populatedTotal = '$_lri\$245.00$_pdi';
const String _populatedFees = '$_lri\$24.50$_pdi';
const String _totalsOnlyTotal = '$_lri\$312.75$_pdi';
const String _longestTotal = '${_lri}LBP 128,450,000.00$_pdi';
const String _longestFees = '${_lri}LBP 12,845,000.00$_pdi';

/// Exact copy, so a reworded string breaks the test instead of silently
/// unpinning the preview. The first two are ARB keys; the rest come from the
/// feature-local `EarningsDashboardL10n` map.
const String _emptyTitle = 'No earnings yet this period';
const String _loadFailed = "Couldn't load earnings.";
const String _feesLabel = 'Platform fees paid';
const String _breakdownTitle = 'Recent deliveries';
const String _memberSinceLabel = 'Member since';

/// What `_MemberSinceRow` prints for the ceiling fixture's epoch-seconds join
/// date (`'1730592000'`). Declared here rather than derived so a preview quietly
/// rewired to an ISO date fails instead of silently losing the only state that
/// exercises the mis-parse.
const String _absurdMemberSince = 'Jul 173060';

/// The canvas, with the REAL font faces installed.
///
/// Identical to `previewCanvas` except for `withGoldenTestFonts`, which adds the
/// deterministic Noto Arabic family to the theme's `fontFamilyFallback`. Without
/// it `loadInterTestFont` fixes Latin only and every Arabic glyph still lays out
/// in the 1-em test face — which is the difference between measuring this screen
/// and measuring the test binding.
Widget _earningsCanvas(Widget Function() preview, Locale locale) {
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
    home: jeebPreviewHost(preview()),
  );
}

/// Pumps [preview] through [_earningsCanvas] at [textScale] and settles.
Future<void> _pumpWithFonts(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: _earningsCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps a preview WITHOUT settling, for the state that never settles.
///
/// Unmounts afterwards so the indicator's ticker is disposed before the test
/// ends — a live ticker at teardown is itself a failure.
Future<void> _pumpUnsettled(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(_earningsCanvas(preview, locale));
  await tester.pump();
}

/// The overflow amount reported by a `RenderFlex` error, in logical pixels.
double _overflowPixels(Object? exception) {
  final Match? match =
      RegExp(r'overflowed by ([\d.]+) pixels').firstMatch('$exception');
  expect(match, isNotNull, reason: 'not a RenderFlex overflow: $exception');
  return double.parse(match!.group(1)!);
}

/// The `Card` that wraps the fees-paid amount [token].
Rect _feesCard(WidgetTester tester, String token) => tester.getRect(
      find.ancestor(of: find.text(token), matching: find.byType(Card)).first,
    );

/// The ready body's `ListView`, for the rows that sit below the fold.
///
/// The render surface is 800x600, so a preview asking for a 844 pt phone gets
/// ~600 — and on the 320x568 ceiling preview the fees card alone is most of the
/// viewport, which puts everything from the stats row down out of the build.
Finder get _earningsList => find.descendant(
      of: find.byType(EarningsDashboardScreen),
      matching: find.byType(Scrollable),
    );

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  // Every preview except `Loading · cold read`, whose spinner cannot settle.
  testPreviewsRender(
    'EarningsDashboardScreen',
    const <String, Widget Function()>{
      'Populated · cash, fees and breakdown': earningsDashboardScreenPopulated,
      'Empty · nothing recorded this period':
          earningsDashboardScreenEmptyPeriod,
      'Load failed · retry': earningsDashboardScreenLoadFailed,
      'Totals only · no breakdown rows': earningsDashboardScreenTotalsOnly,
      'Longest content · compact 320': earningsDashboardScreenLongestContent,
    },
    expectedText: const <String, String>{
      // The only state with a join date AND a breakdown, pinned on its headline
      // amount — the one number no other fixture produces.
      'Populated · cash, fees and breakdown': _populatedTotal,
      // The honest T11 / SW-01 block. Not a headline card.
      'Empty · nothing recorded this period': _emptyTitle,
      // The generic localized load error — the ONLY message this body has.
      'Load failed · retry': _loadFailed,
      // Rollup totals with nothing itemized under them.
      'Totals only · no breakdown rows': _totalsOnlyTotal,
      // The widest money token the screen can emit, at 320 dp.
      'Longest content · compact 320': _longestTotal,
    },
  );

  // The loading body is an `OmdsLoadingState`, i.e. a repeating
  // `CircularProgressIndicator`. `pumpAndSettle` (which `pumpPreview` calls)
  // never returns while one is on screen, so this preview gets the same three
  // assertions the shared suite makes, driven by fixed pumps instead. It has no
  // text to pin at all, so its state is pinned by the indicator plus the absence
  // of every other body.
  group('EarningsDashboardScreen previews · Loading · cold read', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · cold read · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await _pumpUnsettled(
          tester,
          earningsDashboardScreenLoading,
          locale: locale,
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · cold read renders its own state', (
      WidgetTester tester,
    ) async {
      await _pumpUnsettled(tester, earningsDashboardScreenLoading);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      // None of the other three bodies…
      expect(find.byType(OmdsEmptyState), findsNothing);
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.byType(OmdsPullToRefresh), findsNothing);
      // …and no way to change period or leave: the whole body is replaced for
      // as long as the read takes, so a slow gateway removes the period pills
      // the jeeber would use to try a different one.
      expect(find.text('This week'), findsNothing);
      expect(find.text('Export PDF'), findsNothing);
    });
  });

  group('EarningsDashboardScreen preview specifics', () {
    // NB: one preview per test where a fresh cubit matters. Pumping a second
    // preview into the same tester does NOT rebuild the provider —
    // `_earningsCanvas` produces the same widget types, so the `BlocProvider`
    // element is UPDATED rather than replaced and keeps the first cubit.
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of the layout below applies
      // there.
      await _pumpWithFonts(tester, earningsDashboardScreenPopulated);

      expect(
        tester.getSize(find.byType(EarningsDashboardScreen)).width,
        390,
      );
    });

    testWidgets('the ceiling preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await _pumpWithFonts(tester, earningsDashboardScreenLongestContent);

      expect(
        tester.getSize(find.byType(EarningsDashboardScreen)),
        const Size(320, 568),
      );
    });

    testWidgets('every preview lands on a different body', (
      WidgetTester tester,
    ) async {
      // The failure this suite exists to catch: six previews of one screen that
      // all render the same body.
      Future<String> bodyOf(Widget Function() preview) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpWithFonts(tester, preview);
        if (find.byType(OmdsErrorState).evaluate().isNotEmpty) return 'error';
        if (find.text(_emptyTitle).evaluate().isNotEmpty) return 'empty';
        if (find.text(_populatedTotal).evaluate().isNotEmpty) return 'ready-usd';
        if (find.text(_totalsOnlyTotal).evaluate().isNotEmpty) {
          return 'ready-rollup';
        }
        if (find.text(_longestTotal).evaluate().isNotEmpty) return 'ready-lbp';
        fail('no EarningsDashboardScreen body rendered');
      }

      expect(await bodyOf(earningsDashboardScreenLoadFailed), 'error');
      expect(await bodyOf(earningsDashboardScreenEmptyPeriod), 'empty');
      expect(await bodyOf(earningsDashboardScreenPopulated), 'ready-usd');
      expect(await bodyOf(earningsDashboardScreenTotalsOnly), 'ready-rollup');
      expect(await bodyOf(earningsDashboardScreenLongestContent), 'ready-lbp');
    });

    testWidgets('an empty period renders no fabricated zeros (T11 / SW-01)', (
      WidgetTester tester,
    ) async {
      await _pumpWithFonts(tester, earningsDashboardScreenEmptyPeriod);

      expect(find.text(_emptyTitle), findsOneWidget);
      // The trust-breaker the audit caught: "0.00 · 0 Deliveries · 0.00 fees"
      // must not be rendered as if it were a real result.
      expect(find.textContaining('0.00'), findsNothing);
      expect(find.text('Total cash earned'), findsNothing);
      // The period pills survive: switching period is the one useful action
      // this state offers besides pull-to-refresh.
      expect(find.text('This week'), findsOneWidget);
    });

    testWidgets('the join date is skipped, never fabricated, when absent', (
      WidgetTester tester,
    ) async {
      await _pumpWithFonts(tester, earningsDashboardScreenTotalsOnly);

      expect(find.text(_memberSinceLabel), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpWithFonts(tester, earningsDashboardScreenPopulated);

      expect(find.text(_memberSinceLabel), findsOneWidget);
    });
  });

  group('EarningsDashboardScreen defects the previews exposed', () {
    testWidgets('ROLLUP PAYLOAD: the breakdown empty branch renders a BLANK '
        'box', (WidgetTester tester) async {
      // `_DeliveryBreakdownList` returns `const OmdsEmptyState()` when the
      // summary carries a delivery COUNT but no `items` — no icon, no title, no
      // subtitle, no button. `OmdsEmptyState` builds an empty `Column` inside
      // 24 dp of padding, so the jeeber gets a gap where an explanation should
      // be, and the "Recent deliveries" heading is not rendered either. The
      // copy for it already ships, translated, in both ARBs
      // (`earningsBreakdownEmpty`).
      await _pumpWithFonts(tester, earningsDashboardScreenTotalsOnly);

      final Finder breakdown = find.byType(OmdsEmptyState);
      expect(breakdown, findsOneWidget);
      expect(
        find.descendant(of: breakdown, matching: find.byType(Text)),
        findsNothing,
        reason: 'the breakdown empty state says nothing at all',
      );
      expect(
        find.descendant(of: breakdown, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(find.text(_breakdownTitle), findsNothing);
      // …and it is not the honest T11 block either, which DOES carry copy.
      expect(find.text(_emptyTitle), findsNothing);
      expect(
        find.text('Completed deliveries for this period will appear here.'),
        findsNothing,
        reason: 'the shipped, translated ARB string is not wired to this branch',
      );
    });

    testWidgets('EPOCH JOIN DATE: the guard misses and the row states a date '
        'in the year 173060', (WidgetTester tester) async {
      // `_MemberSinceRow._formatDate` is `DateTime.tryParse(iso) ?? iso`, which
      // reads as "unparseable input is echoed rather than formatted". It is not:
      // `DateTime.tryParse('1730592000')` does NOT return null. Ten digits match
      // the basic-ISO `yyyyyy-mm-dd` shape as `173059-20-00`, the out-of-range
      // month normalizes, and the result is `173060-07-31`. So an epoch-seconds
      // join date — a string the wire can legitimately carry, since
      // `EarningsSummary.fromJson` only casts to `String?` — renders as a
      // confident, formatted, entirely fictional date.
      await _pumpWithFonts(tester, earningsDashboardScreenLongestContent);

      // On the 320x568 ceiling frame the row is below the fold, which is itself
      // worth knowing: the collapsed fees card pushes it there.
      await tester.scrollUntilVisible(
        find.text(_memberSinceLabel),
        120,
        scrollable: _earningsList.first,
      );
      expect(find.text(_memberSinceLabel), findsOneWidget);
      expect(
        find.text(_absurdMemberSince),
        findsOneWidget,
        reason: 'the tryParse guard never fires, so nothing rejects the value',
      );
      // Not the raw echo the fallback promises, either — that would at least be
      // visibly wrong to the jeeber reading it.
      expect(find.text('1730592000'), findsNothing);
    });

    testWidgets('AR: the member-since month never localizes', (
      WidgetTester tester,
    ) async {
      // `_formatDate` calls a bare `DateFormat.yMMM()`, which resolves through
      // `Intl.getCurrentLocale()` — and nothing in this app sets
      // `Intl.defaultLocale`, so it is `en_US` in every locale. The label beside
      // it DOES translate, so the Arabic rendering reads "عضو منذ Nov 2025":
      // half-translated, with a Latin-script month dropped into RTL copy.
      // Delete this expectation when the row takes the ambient locale.
      await _pumpWithFonts(
        tester,
        earningsDashboardScreenPopulated,
        locale: const Locale('ar'),
      );

      expect(find.text('عضو منذ'), findsOneWidget);
      expect(
        find.text('Nov 2025'),
        findsOneWidget,
        reason: 'the only Latin-script date in the whole Arabic rendering, and '
            'the app ships date formats for ar',
      );
    });

    testWidgets('200% TEXT: the period pills clip, and the clip is '
        'unreachable', (WidgetTester tester) async {
      // `_PeriodFilterRow` is a bare `Row` of three `OmdsChip`s — no `Wrap`, no
      // horizontal scroll, no `Flexible`. Past the width the three labels need
      // it is a hard clip, and because the row cannot scroll there is no
      // gesture that brings the hidden pill back: a large-text jeeber cannot
      // switch period at all.
      //
      // Measured on the EMPTY state deliberately — the pills are the only
      // control that state offers besides pull-to-refresh — and through the real
      // Inter face, which is what makes the 100% reading meaningful: with the
      // shipping font the row FITS a 390 dp phone, so this is a large-text
      // defect and not an everyday one.
      await _pumpWithFonts(tester, earningsDashboardScreenEmptyPeriod);
      expect(
        tester.takeException(),
        isNull,
        reason: 'at 100% with the shipping face the pills fit 390 dp',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpWithFonts(
        tester,
        earningsDashboardScreenEmptyPeriod,
        textScale: 2.0,
      );

      expect(
        _overflowPixels(tester.takeException()),
        greaterThan(40),
        reason: 'at 200% the three pills run 70 dp past the 358 dp of content '
            'width a 390 dp phone leaves them, and the row cannot scroll',
      );
    });

    testWidgets('320 dp: the fees-paid amount starves its own label column', (
      WidgetTester tester,
    ) async {
      // `_FeesPaidCard` is `Icon + Expanded(label column) + Text(amount)`. The
      // amount has no flex, so it is measured against an UNBOUNDED main axis and
      // takes whatever it wants; the `Expanded` then divides what is left. A USD
      // token on a 390 dp phone leaves plenty. `LBP 12,845,000.00` on a 320 dp
      // phone does not, and the label column collapses far enough to wrap
      // "Platform fees paid" into a tall ribbon — the card grows several times
      // its reference height and pushes the stats row and the breakdown off
      // screen.
      //
      // Nothing throws: this is a silently-wrong layout, not an overflow, which
      // is exactly why it needs a preview.
      await _pumpWithFonts(tester, earningsDashboardScreenPopulated);
      final Rect usdCard = _feesCard(tester, _populatedFees);
      final double usdLabel = tester.getSize(find.text(_feesLabel)).width;

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpWithFonts(tester, earningsDashboardScreenLongestContent);
      final Rect lbpCard = _feesCard(tester, _longestFees);
      final double lbpLabel = tester.getSize(find.text(_feesLabel)).width;

      // Measured through the shipping faces: 104 dp tall, 123 dp of label at
      // 390 dp in USD, against 292 dp tall and 39 dp of label at 320 dp in LBP.
      expect(usdCard.height, lessThan(140));
      expect(usdLabel, greaterThan(90));
      expect(
        lbpLabel,
        lessThan(usdLabel / 2),
        reason: '"Platform fees paid" is squeezed to '
            '${lbpLabel.toStringAsFixed(1)} dp wide, from '
            '${usdLabel.toStringAsFixed(1)} dp',
      );
      expect(
        lbpCard.height,
        greaterThan(2 * usdCard.height),
        reason: 'the same card is ${usdCard.height.toStringAsFixed(0)} dp tall '
            'in USD at 390 dp and ${lbpCard.height.toStringAsFixed(0)} dp tall '
            'in LBP at 320 dp; the amount needs a `Flexible`, or the row needs '
            'to wrap',
      );
    });
  });
}
