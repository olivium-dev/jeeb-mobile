// Layout / a11y regression cover for the redesign-2026-08 screen-19 rebuild.
//
// The board packs a title, a three-pill period row, a navy hero with three
// stat columns, a fee strip, a breakdown and a docked two-pill footer onto one
// phone-width screen. Two of those rows are fixed-width `Row`s by design, and
// AC T-mobile-036 requires 200% text scaling with no overflow — so the funded
// body is pumped at a real 390pt device width in both locales at both scales.
//
// This caught a genuine defect during the rebuild: the period row was a fixed
// `JeebChipRow` and overflowed. It is a scrollable one now.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/earnings/application/earnings_cubit.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';
import 'package:jeeb_mobile/features/earnings/presentation/earnings_dashboard_screen.dart';

import '../../support/sync_app_localizations.dart';

/// The board's own numbers (`19-earnings.html`), so the widest realistic
/// strings are exercised: a three-column hero, a fee strip and a delivery row.
const _boardSummary = EarningsSummary(
  totalCashEarned: 127.50,
  feesPaid: 12.75,
  currency: 'USD',
  deliveryCount: 18,
  memberSince: '2025-03-04T00:00:00Z',
  deliveries: [
    EarningsDeliveryItem(
      deliveryId: 'd-1',
      date: '2026-08-01T10:00:00Z',
      cashCollected: 8,
      feePaid: 0.8,
      currency: 'USD',
    ),
  ],
);

class _BoardRepo implements EarningsRepository {
  const _BoardRepo();

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    await Future<void>.delayed(Duration.zero);
    return _boardSummary;
  }

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async => '/tmp/e.pdf';
}

/// A 390×844 logical viewport — the narrowest phone the app targets.
const _phoneSize = Size(390, 844);
const _phonePixelRatio = 3.0;

Future<void> _pumpPhone(
  WidgetTester tester, {
  required Locale locale,
  required double textScale,
}) async {
  tester.view.physicalSize = _phoneSize * _phonePixelRatio;
  tester.view.devicePixelRatio = _phonePixelRatio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    wrapForTest(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: BlocProvider<EarningsCubit>(
          create: (_) => EarningsCubit(repository: const _BoardRepo()),
          child: const EarningsDashboardScreen(),
        ),
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('funded body fits a 390pt phone — ${locale.languageCode} @ '
          '${(scale * 100).round()}%', (tester) async {
        await _pumpPhone(tester, locale: locale, textScale: scale);

        // Any RenderFlex overflow is reported as a framework exception.
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('every period pill stays findable when the row scrolls', (
    tester,
  ) async {
    // At 200% the pills are wider than the viewport, so at least one is off
    // screen. The kit's scrollable row is non-lazy precisely so Maestro and
    // `find.bySemanticsIdentifier` still resolve it.
    await _pumpPhone(tester, locale: const Locale('en'), textScale: 2);

    for (final period in EarningsPeriod.values) {
      expect(
        find.bySemanticsIdentifier('earnings_period_${period.name}'),
        findsOneWidget,
      );
    }
  });
}
