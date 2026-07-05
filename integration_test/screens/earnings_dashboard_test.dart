// Isolated native UI test — EarningsDashboardScreen (routed earnings / Earnings
// tab, JM-052). Drives the screen off an in-memory EarningsRepository through
// the cubit (which auto-loads in its constructor). The screen owns its own
// Scaffold; we provide the EarningsCubit via BlocProvider and pump it directly.
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/earnings/application/earnings_cubit.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';
import 'package:jeeb_mobile/features/earnings/presentation/earnings_dashboard_screen.dart';

import '../support/screen_harness.dart';

/// In-memory EarningsRepository serving one fixed summary (mirrors the widget
/// test's _FakeRepo so amounts render exactly like the app).
class _StaticEarningsRepository implements EarningsRepository {
  const _StaticEarningsRepository(this._summary);
  final EarningsSummary _summary;

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    await Future<void>.delayed(Duration.zero);
    return _summary;
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
  totalCashEarned: 1240.50,
  feesPaid: 124.05,
  currency: 'USD',
  deliveryCount: 6,
  memberSince: '2025-03-01T00:00:00Z',
  deliveries: [
    EarningsDeliveryItem(
      deliveryId: 'dlv-101',
      date: '2026-06-30T12:00:00Z',
      cashCollected: 210,
      feePaid: 21,
      currency: 'USD',
    ),
    EarningsDeliveryItem(
      deliveryId: 'dlv-102',
      date: '2026-06-29T12:00:00Z',
      cashCollected: 145.50,
      feePaid: 14.55,
      currency: 'USD',
    ),
  ],
);

Widget _screen(EarningsSummary summary) => BlocProvider<EarningsCubit>(
      create: (_) =>
          EarningsCubit(repository: _StaticEarningsRepository(summary)),
      child: const EarningsDashboardScreen(),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('earnings: populated totals + breakdown (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(_funded),
      'earnings__populated',
    );
  });

  testWidgets('earnings: empty / zero period, honest empty state (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(_empty),
      'earnings__empty',
    );
  });

  testWidgets('earnings: populated totals (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(_funded),
      'earnings__ar',
      locale: const Locale('ar'),
    );
  });
}
