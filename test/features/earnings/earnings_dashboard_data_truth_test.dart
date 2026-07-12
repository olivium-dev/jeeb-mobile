// T11 / SW-01: earnings must never render a wall of confident zeros after a
// real (or not-yet-synced) delivery. Proves:
//   * EarningsSummary.isEmpty is true only when nothing is recorded;
//   * an empty period renders the honest OmdsEmptyState (no "0.00" anywhere);
//   * a non-empty period renders amounts through the single MoneyFormat rule.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/earnings/application/earnings_cubit.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';
import 'package:jeeb_mobile/features/earnings/presentation/earnings_dashboard_screen.dart';

import '../../support/sync_app_localizations.dart';

class _FakeRepo implements EarningsRepository {
  const _FakeRepo(this.summary);
  final EarningsSummary summary;

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    await Future<void>.delayed(Duration.zero);
    return summary;
  }

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      '/tmp/e.pdf';
}

const _empty = EarningsSummary(
  totalCashEarned: 0,
  feesPaid: 0,
  currency: 'USD',
  deliveryCount: 0,
);

const _funded = EarningsSummary(
  totalCashEarned: 1000,
  feesPaid: 100,
  currency: 'USD',
  deliveryCount: 5,
);

Future<void> _pump(WidgetTester tester, EarningsSummary summary) async {
  await tester.pumpWidget(
    wrapForTest(
      BlocProvider<EarningsCubit>(
        create: (_) => EarningsCubit(repository: _FakeRepo(summary)),
        child: const EarningsDashboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('EarningsSummary.isEmpty', () {
    test('all-zero, no deliveries → empty', () {
      expect(_empty.isEmpty, isTrue);
    });

    test('any cash earned → NOT empty', () {
      expect(
        const EarningsSummary(
          totalCashEarned: 12,
          feesPaid: 0,
          currency: 'USD',
          deliveryCount: 1,
        ).isEmpty,
        isFalse,
      );
    });

    test('fees paid but zero cash (COD off-wallet) → NOT empty', () {
      expect(
        const EarningsSummary(
          totalCashEarned: 0,
          feesPaid: 1.2,
          currency: 'USD',
          deliveryCount: 1,
        ).isEmpty,
        isFalse,
      );
    });
  });

  testWidgets('empty period → honest empty state, NO fabricated 0.00',
      (tester) async {
    await _pump(tester, _empty);

    expect(find.text('No earnings yet this period'), findsOneWidget);
    // The trust-breaker the audit caught: "0.00 USD · 0 Deliveries · 0.00 fees"
    // must NOT be rendered as if real.
    expect(find.textContaining('0.00'), findsNothing);
    expect(find.text('Total cash earned'), findsNothing);
  });

  testWidgets('funded period → MoneyFormat amounts, no empty state',
      (tester) async {
    await _pump(tester, _funded);

    expect(find.text('No earnings yet this period'), findsNothing);
    expect(find.text('Total cash earned'), findsOneWidget);
    // Rendered through the one money rule ($ for USD), not "1000.00 USD".
    // MoneyFormat wraps the token in an LTR isolate (JEBV4-98/F10).
    expect(find.text('\u2066\$1,000.00\u2069'), findsOneWidget);
  });
}
