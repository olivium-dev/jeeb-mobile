// T11 / SW-01: earnings must never render a wall of confident zeros after a

import 'package:flutter/material.dart';
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

const _fundedWithJoinDate = EarningsSummary(
  totalCashEarned: 1000,
  feesPaid: 100,
  currency: 'USD',
  deliveryCount: 5,
  memberSince: '2025-03-04T00:00:00Z',
);

const _fundedWithRow = EarningsSummary(
  totalCashEarned: 8,
  feesPaid: 0.8,
  currency: 'USD',
  deliveryCount: 1,
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

Future<void> _pump(
  WidgetTester tester,
  EarningsSummary summary, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    wrapForTest(
      BlocProvider<EarningsCubit>(
        create: (_) => EarningsCubit(repository: _FakeRepo(summary)),
        child: const EarningsDashboardScreen(),
      ),
      locale: locale,
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
    expect(find.textContaining('0.00'), findsNothing);
    // The hero eyebrow is a JeebSectionLabel, which uppercases in EN.
    expect(find.text('TOTAL CASH EARNED'), findsNothing);
  });

  testWidgets('funded period → MoneyFormat amounts, no empty state',
      (tester) async {
    await _pump(tester, _funded);

    expect(find.text('No earnings yet this period'), findsNothing);
    expect(find.text('TOTAL CASH EARNED'), findsOneWidget);
    // Rendered through the one money rule ($ for USD), not "1000.00 USD".
    expect(find.text('\u2066\$1,000.00\u2069'), findsOneWidget);
  });

  testWidgets('period pills stay mounted in every state', (tester) async {
    await _pump(tester, _empty);

    for (final period in EarningsPeriod.values) {
      expect(
        find.bySemanticsIdentifier('earnings_period_${period.name}'),
        findsOneWidget,
        reason: 'switching period is how a jeeber escapes an empty period',
      );
    }
  });

  testWidgets('member-since is withheld when the wire omits it',
      (tester) async {
    await _pump(tester, _funded);

    expect(find.bySemanticsIdentifier('earnings_member_since'), findsNothing);
  });

  testWidgets('member-since renders when the wire carries it', (tester) async {
    await _pump(tester, _fundedWithJoinDate);

    expect(find.bySemanticsIdentifier('earnings_member_since'), findsOneWidget);
  });

  testWidgets('funded \u2192 footer + activity link docked, no scrolling needed',
      (tester) async {
    await _pump(tester, _funded);

    expect(find.bySemanticsIdentifier('earnings_wallet_link'), findsOneWidget);
    expect(find.bySemanticsIdentifier('earnings_export_cta'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('earnings_activity_link'),
      findsOneWidget,
    );
  });

  testWidgets('empty \u2192 no footer at all', (tester) async {
    await _pump(tester, _empty);

    // The empty body must stay money-free, and a wallet pill is a money
    // affordance: both exits are withheld until the period is funded.
    expect(find.bySemanticsIdentifier('earnings_wallet_link'), findsNothing);
    expect(find.bySemanticsIdentifier('earnings_export_cta'), findsNothing);
  });

  testWidgets('ar funded body lays out without overflow', (tester) async {
    await _pump(tester, _fundedWithRow, locale: const Locale('ar'));

    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsIdentifier('earnings_delivery_row_d-1'),
      findsOneWidget,
    );
  });
}
