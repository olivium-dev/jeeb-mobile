// Render tests for the EarningsTab previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently.
// Every state pins a DISTINCT string, because all six previews are the same
// widget over the same two GetIt registrations, told apart only by what those
// fixtures answer — a suite that only asked "did something render?" would pass
// on six copies of the fail-closed line.
//
// `Session resolving` is the one preview `testPreviewsRender` cannot carry:
// `pumpPreview` ends in `pumpAndSettle`, and the tab's waiting branch is an
// `OmdsLoadingState` — a `CircularProgressIndicator` whose animation never
// settles, so the pump runs to its simulated timeout and throws. It is pumped
// without settling in its own group, in both locales.
//
// The last group is not preview hygiene. It is the three defects these previews
// exposed in the dashboard body the tab hosts, held as numbers so they cannot
// regress unnoticed. None is visible in the default reading a reviewer gets
// without the matrix and without a phone-width box: one needs 200% text, one
// needs the AR rendering, and one needs a non-USD amount at 390 dp — the 800 dp
// test surface hides all three.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/previews/shell/earnings_tab_preview.dart';

import '../preview_test_harness.dart';

/// `MoneyFormat` wraps every amount in an LTR isolate (JEBV4-98 / F10), so the
/// rendered string is not the bare token.
const String _lri = '\u2066';
const String _pdi = '\u2069';
const String _readyTotal = '$_lri\$245.00$_pdi';
const String _longTotal = '${_lri}LBP 18,750,000.00$_pdi';

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview.
const String _emptyTitle = 'No earnings yet this period';
const String _loadFailed = "Couldn't load earnings.";
const String _noSession = 'Unable to load earnings account.';
const String _feesLabel = 'Platform fees paid';

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
  await tester.pumpWidget(previewCanvas(preview, locale));
  await tester.pump();
}

/// Pumps a preview into a real phone-width box at [textScale], the way the
/// canvas renders it, instead of into the 800×600 default test surface. The
/// width is the whole point: at 800 dp every overflow below disappears.
Future<void> _pumpInPreviewBox(
  WidgetTester tester,
  Widget Function() preview, {
  required double textScale,
  Size box = const Size(390, 900),
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = box;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

/// The `Card` that wraps the fees-paid amount [token].
Rect _feesCard(WidgetTester tester, String token) => tester.getRect(
      find.ancestor(of: find.text(token), matching: find.byType(Card)).first,
    );

/// The overflow amount reported by a `RenderFlex` error, in logical pixels.
double _overflowPixels(Object? exception) {
  final Match? match =
      RegExp(r'overflowed by ([\d.]+) pixels').firstMatch('$exception');
  expect(match, isNotNull, reason: 'not a RenderFlex overflow: $exception');
  return double.parse(match!.group(1)!);
}

void main() {
  setUpAll(loadPreviewArbs);

  // Each preview re-registers what it needs, so ordering cannot leak between
  // tests — but nothing else in this isolate should inherit canvas fixtures.
  tearDown(() {
    if (sl.isRegistered<EarningsRepository>()) {
      sl.unregister<EarningsRepository>();
    }
    if (sl.isRegistered<AuthTokenStore>()) {
      sl.unregister<AuthTokenStore>();
    }
  });

  testPreviewsRender(
    'EarningsTab',
    const <String, Widget Function()>{
      'Ready · cash, fees and breakdown': earningsTabReady,
      'Empty period · honest zero': earningsTabEmptyPeriod,
      'Load failed · retry': earningsTabLoadFailed,
      'No session · fail closed': earningsTabNoSession,
      'Long content · LBP millions': earningsTabLongContent,
    },
    expectedText: const <String, String>{
      'Ready · cash, fees and breakdown': _readyTotal,
      'Empty period · honest zero': _emptyTitle,
      'Load failed · retry': _loadFailed,
      'No session · fail closed': _noSession,
      'Long content · LBP millions': _longTotal,
    },
  );

  group('EarningsTab · Session resolving preview', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('builds · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await _pumpUnsettled(tester, earningsTabSessionResolving,
            locale: locale);

        expect(tester.takeException(), isNull);
        expect(find.byType(OmdsLoadingState), findsOneWidget);
      });
    }

    testWidgets('waits instead of guessing, and says nothing while it waits', (
      WidgetTester tester,
    ) async {
      await _pumpUnsettled(tester, earningsTabSessionResolving);

      // Why this state has no `expectedText`: there is nothing to pin. No
      // message, no skeleton, no label — the tab renders a bare spinner, so a
      // screen reader is told nothing while the session read is in flight.
      expect(find.byType(Text), findsNothing);
      // Critically, it has NOT fallen through to the fail-closed line: an
      // unresolved keychain read is not the same as "no account".
      expect(find.text(_noSession), findsNothing);
    });
  });

  group('EarningsTab preview specifics', () {
    testWidgets('every preview lands on a different branch of the tab', (
      WidgetTester tester,
    ) async {
      // The failure this suite exists to catch: six previews of one widget that
      // all render the same branch.
      Future<String> branchOf(Widget Function() preview) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpPreview(tester, preview);
        if (find.text(_noSession).evaluate().isNotEmpty) return 'no-session';
        if (find.byType(OmdsErrorState).evaluate().isNotEmpty) return 'error';
        if (find.byType(OmdsEmptyState).evaluate().isNotEmpty) return 'empty';
        if (find.text(_readyTotal).evaluate().isNotEmpty) return 'ready-usd';
        if (find.text(_longTotal).evaluate().isNotEmpty) return 'ready-lbp';
        fail('no EarningsTab branch rendered');
      }

      expect(await branchOf(earningsTabNoSession), 'no-session');
      expect(await branchOf(earningsTabLoadFailed), 'error');
      expect(await branchOf(earningsTabEmptyPeriod), 'empty');
      expect(await branchOf(earningsTabReady), 'ready-usd');
      expect(await branchOf(earningsTabLongContent), 'ready-lbp');
    });

    testWidgets('fail-closed binds NO earnings account (S0-OAD-03)', (
      WidgetTester tester,
    ) async {
      // The defect this branch exists to prevent is showing SOMEONE ELSE's
      // earnings, which a fixture-id fallback would do silently. Asserting the
      // rendered line is not enough — this asserts that nothing was resolvable
      // to bind in the first place.
      await pumpPreview(tester, earningsTabNoSession);

      expect(find.text(_noSession), findsOneWidget);
      expect(sl.isRegistered<EarningsRepository>(), isFalse);
      expect(find.byType(OmdsPullToRefresh), findsNothing);
      expect(find.text('Export PDF'), findsNothing);
    });

    testWidgets('an empty period renders no fabricated zeros (T11/SW-01)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, earningsTabEmptyPeriod);

      expect(find.text(_emptyTitle), findsOneWidget);
      // The trust-breaker the audit caught: "0.00 · 0 Deliveries · 0.00 fees"
      // must not be rendered as if it were a real result.
      expect(find.textContaining('0.00'), findsNothing);
      expect(find.text('Total cash earned'), findsNothing);
    });

    testWidgets('no preview reaches the network or the keychain', (
      WidgetTester tester,
    ) async {
      // The store fixture answers `userId` from memory and throws on both
      // writers; the repositories are local classes. If a future edit swaps in
      // the real AuthTokenStore, the platform channel is unimplemented under
      // `flutter test` and this fails instead of quietly hanging the canvas.
      await pumpPreview(tester, earningsTabReady);

      expect(tester.takeException(), isNull);
      expect(sl<AuthTokenStore>().runtimeType, isNot(AuthTokenStore));
      expect(await sl<AuthTokenStore>().userId, 'user-jeeber-002');
    });
  });

  group('EarningsTab defects the preview matrix exposed', () {
    testWidgets('200% TEXT: the period pills clip, and the clip is unreachable',
        (WidgetTester tester) async {
      // `_PeriodFilterRow` is a bare `Row` of three `OmdsChip`s — no `Wrap`, no
      // horizontal scroll, no `Flexible`. Past the width the three labels need
      // it is a hard clip, and because the row cannot scroll there is no
      // gesture that brings the hidden pill back: a large-text jeeber cannot
      // switch period at all. Measured on the EMPTY state deliberately — the
      // pills are the only control that state offers besides pull-to-refresh.
      //
      // Caveat on the 100% number: `flutter test` substitutes a monospaced font
      // whose glyphs are wider than the shipping Inter face, so the 42 dp at
      // 100% is a margin indicator (this row has none), not proof of a
      // shipping defect. The 200% number is 8x larger than that margin, which
      // no font substitution explains.
      await _pumpInPreviewBox(tester, earningsTabEmptyPeriod, textScale: 1.0);
      final double at100 = _overflowPixels(tester.takeException());
      expect(at100, lessThan(60));

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpInPreviewBox(tester, earningsTabEmptyPeriod, textScale: 2.0);

      final double at200 = _overflowPixels(tester.takeException());
      expect(
        at200,
        greaterThan(250),
        reason: 'at 200% the row needs ~688 dp against 358 dp of content width '
            '(${at100.toStringAsFixed(0)} dp over at 100%): the whole "This '
            'month" pill and part of "This week" are off the trailing edge',
      );
    });

    testWidgets('200% TEXT: Arabic pills clip too, and by slightly more', (
      WidgetTester tester,
    ) async {
      // Shorter labels (اليوم / هذا الأسبوع / هذا الشهر) do not rescue the row,
      // so this is a layout defect and not a copy-length one. RTL also moves
      // the clip to the LEFT edge, where a reviewer reading the EN rendering
      // never looks.
      await _pumpInPreviewBox(
        tester,
        earningsTabEmptyPeriod,
        textScale: 2.0,
        locale: const Locale('ar'),
      );

      expect(_overflowPixels(tester.takeException()), greaterThan(250));
    });

    testWidgets('LONG MONEY: the fees-paid card collapses into a ribbon', (
      WidgetTester tester,
    ) async {
      // `_FeesPaidCard` is `Icon + Expanded(label column) + Text(amount)`. The
      // amount has no flex, so it is measured against an UNBOUNDED main axis
      // and takes whatever it wants; the `Expanded` then divides what is left.
      // A USD token leaves plenty. `LBP 1,875,000.00` leaves 3 dp — the label
      // column becomes a one-glyph-per-line vertical ribbon and the card grows
      // to ~6x its height, pushing everything below it off the screen.
      //
      // Nothing throws: this is a silently-wrong layout, not an overflow, which
      // is exactly why it needs a preview. The only exception on the frame is
      // the period-pill clip above.
      await _pumpInPreviewBox(tester, earningsTabReady, textScale: 1.0);
      expect(
        _overflowPixels(tester.takeException()),
        lessThan(60),
        reason: 'the pills row is the only thing that reports an overflow',
      );
      final Rect usdCard = _feesCard(tester, '$_lri\$24.50$_pdi');
      final double usdLabel = tester.getSize(find.text(_feesLabel)).width;

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpInPreviewBox(tester, earningsTabLongContent, textScale: 1.0);
      tester.takeException();
      final Rect lbpCard = _feesCard(tester, '${_lri}LBP 1,875,000.00$_pdi');
      final double lbpLabel = tester.getSize(find.text(_feesLabel)).width;

      expect(usdCard.height, lessThan(200));
      expect(usdLabel, greaterThan(100));
      expect(
        lbpLabel,
        lessThan(10),
        reason: '"Platform fees paid" is squeezed to '
            '${lbpLabel.toStringAsFixed(1)} dp wide — one glyph per line',
      );
      expect(
        lbpCard.height,
        greaterThan(5 * usdCard.height),
        reason: 'the same card is ${usdCard.height.toStringAsFixed(0)} dp tall '
            'in USD and ${lbpCard.height.toStringAsFixed(0)} dp tall in LBP; '
            'the amount needs a `Flexible`, or the row needs to wrap',
      );
    });

    testWidgets('AR: the member-since month never localizes', (
      WidgetTester tester,
    ) async {
      // `_MemberSinceRow._formatDate` calls a bare `DateFormat.yMMM()`, which
      // resolves through `Intl.getCurrentLocale()` — and nothing in this app
      // sets `Intl.defaultLocale`, so it is `en_US` in every locale. The label
      // beside it DOES translate, so the Arabic rendering reads "عضو منذ
      // Nov 2025": half-translated, with a Latin-script month dropped into RTL
      // copy. Delete this expectation when the row takes the ambient locale.
      await _pumpInPreviewBox(
        tester,
        earningsTabReady,
        textScale: 1.0,
        locale: const Locale('ar'),
      );
      tester.takeException();

      expect(find.text('عضو منذ'), findsOneWidget);
      expect(
        find.text('Nov 2025'),
        findsOneWidget,
        reason: 'the ONLY Latin string in the whole Arabic rendering, and the '
            'app ships date formats for ar',
      );
    });
  });
}
