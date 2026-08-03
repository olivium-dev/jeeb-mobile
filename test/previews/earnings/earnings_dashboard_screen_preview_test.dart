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
const String _lri = '\u2066';
const String _pdi = '\u2069';

const String _populatedTotal = '$_lri\$245.00$_pdi';
const String _populatedFees = '$_lri\$24.50$_pdi';
const String _totalsOnlyTotal = '$_lri\$312.75$_pdi';
const String _longestTotal = '${_lri}LBP 128,450,000.00$_pdi';
const String _longestFees = '${_lri}LBP 12,845,000.00$_pdi';

/// Exact copy, so a reworded string breaks the test instead of silently
const String _emptyTitle = 'No earnings yet this period';
const String _loadFailed = "Couldn't load earnings.";
const String _feesLabel = 'Platform fees paid';
const String _breakdownTitle = 'Recent deliveries';
const String _memberSinceLabel = 'Member since';

/// What `_MemberSinceRow` prints for the ceiling fixture's epoch-seconds join
const String _absurdMemberSince = 'Jul 173060';

/// The canvas, with the REAL font faces installed.
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
Finder get _earningsList => find.descendant(
      of: find.byType(EarningsDashboardScreen),
      matching: find.byType(Scrollable),
    );

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

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
      'Populated · cash, fees and breakdown': _populatedTotal,
      'Empty · nothing recorded this period': _emptyTitle,
      'Load failed · retry': _loadFailed,
      'Totals only · no breakdown rows': _totalsOnlyTotal,
      'Longest content · compact 320': _longestTotal,
    },
  );

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
      expect(find.byType(OmdsEmptyState), findsNothing);
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.byType(OmdsPullToRefresh), findsNothing);
      expect(find.text('This week'), findsNothing);
      expect(find.text('Export PDF'), findsNothing);
    });
  });

  group('EarningsDashboardScreen preview specifics', () {
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
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
      expect(find.textContaining('0.00'), findsNothing);
      expect(find.text('Total cash earned'), findsNothing);
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
      expect(find.text(_emptyTitle), findsNothing);
      expect(
        find.text('Completed deliveries for this period will appear here.'),
        findsNothing,
        reason: 'the shipped, translated ARB string is not wired to this branch',
      );
    });

    testWidgets('EPOCH JOIN DATE: the guard misses and the row states a date '
        'in the year 173060', (WidgetTester tester) async {
      await _pumpWithFonts(tester, earningsDashboardScreenLongestContent);

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
      expect(find.text('1730592000'), findsNothing);
    });

    testWidgets('AR: the member-since month never localizes', (
      WidgetTester tester,
    ) async {
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
      await _pumpWithFonts(tester, earningsDashboardScreenPopulated);
      final Rect usdCard = _feesCard(tester, _populatedFees);
      final double usdLabel = tester.getSize(find.text(_feesLabel)).width;

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpWithFonts(tester, earningsDashboardScreenLongestContent);
      final Rect lbpCard = _feesCard(tester, _longestFees);
      final double lbpLabel = tester.getSize(find.text(_feesLabel)).width;

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
