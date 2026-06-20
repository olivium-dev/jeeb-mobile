// Tests for EarningsCubit (T-MOB-019).
//
// Design note: EarningsCubit fires loadEarnings() in its constructor.
// Because bloc_test subscribes to the stream AFTER build() returns, the
// synchronous emit(loading) that happens before the first await in
// loadEarnings() is not captured by the test listener — only states
// emitted after await points are observable.  Tests therefore assert the
// final observable state(s) rather than the transient loading intermediate.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/earnings/application/earnings_cubit.dart';
import 'package:jeeb_mobile/features/earnings/application/earnings_state.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';

class _FakeEarningsRepository implements EarningsRepository {
  const _FakeEarningsRepository({this.failWith});

  final EarningsErrorKind? failWith;

  // Fee-only reframe (JM-052, D41/D44): total cash earned (net, off-wallet COD)
  // + captured 10% fees + delivery count + member-since. No gross/commission/
  // net-payout (the removed platform-takes-a-cut model).
  static const _sample = EarningsSummary(
    totalCashEarned: 1000,
    feesPaid: 100,
    currency: 'USD',
    deliveryCount: 5,
    memberSince: '2026-01-15T10:00:00Z',
  );

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    await Future<void>.delayed(Duration.zero);
    if (failWith != null) throw EarningsRepositoryException(failWith!);
    return _sample;
  }

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    await Future<void>.delayed(Duration.zero);
    if (failWith != null) throw EarningsRepositoryException(failWith!);
    return '/tmp/earnings_week.pdf';
  }
}

void main() {
  // JM-052 fee-only reframe (D41/D44/D37): EarningsSummary.fromJson against the
  // REAL mock wire shape (GET /wallet-service/v1/jeeb/earnings). The endpoint
  // returns net off-wallet COD entries only; the 10% fee (D37) is DERIVED.
  group('EarningsSummary.fromJson — fee-only parse (real mock shape)', () {
    // Verbatim mock payload for user-jeeber-002 (2 deliveries: 4.5 + 6 = 10.5).
    final mockBody = <String, dynamic>{
      'jeeberId': 'user-jeeber-002',
      'totalEarnings': {'value': 10.5, 'currency': 'USD'},
      'items': [
        {
          'id': 'earning-delivery-001',
          'deliveryId': 'delivery-001',
          'type': 'delivery',
          'amount': {'value': 4.5, 'currency': 'USD'},
          'syncedAt': '2026-05-18T15:00:00Z',
        },
        {
          'id': 'earning-delivery-004',
          'deliveryId': 'delivery-004',
          'type': 'delivery',
          'amount': {'value': 6, 'currency': 'USD'},
          'syncedAt': '2026-05-18T16:30:00Z',
        },
      ],
      'cursor': null,
    };

    test('total cash earned = sum of off-wallet COD (D41)', () {
      final s = EarningsSummary.fromJson(mockBody);
      expect(s.totalCashEarned, 10.5);
      expect(s.currency, 'USD');
      expect(s.deliveryCount, 2);
    });

    test('fees paid = derived flat 10% per delivery (D37)', () {
      final s = EarningsSummary.fromJson(mockBody);
      // 0.10 * (4.5 + 6) = 1.05.
      expect(s.feesPaid, closeTo(1.05, 1e-9));
      expect(s.deliveries.first.feePaid, closeTo(0.45, 1e-9));
    });

    test('net-per-offer = (cash - fees) / count (D44)', () {
      final s = EarningsSummary.fromJson(mockBody);
      // (10.5 - 1.05) / 2 = 4.725.
      expect(s.netPerOffer, closeTo(4.725, 1e-9));
    });

    test('prefers an explicit fee total when the wire surfaces one', () {
      final s = EarningsSummary.fromJson({...mockBody, 'feesPaid': 2.0});
      expect(s.feesPaid, 2.0);
    });

    test('member-since is null when the wire omits it (never fabricated)', () {
      expect(EarningsSummary.fromJson(mockBody).memberSince, isNull);
      expect(
        EarningsSummary.fromJson({...mockBody, 'memberSince': '2026-01-15'})
            .memberSince,
        '2026-01-15',
      );
    });

    test('empty entries → zeroed summary, no divide-by-zero', () {
      final s = EarningsSummary.fromJson({
        'totalEarnings': {'value': 0, 'currency': 'USD'},
        'items': <dynamic>[],
      });
      expect(s.totalCashEarned, 0);
      expect(s.feesPaid, 0);
      expect(s.netPerOffer, 0);
      expect(s.deliveryCount, 0);
    });
  });

  // §6B real-app regression: the LIVE gateway `GET /v1/jeeb/earnings` body keys
  // on `entries`/`totalNet`/`totalCommission`/`rowCount` — NONE of which the
  // prior parser read, so the screen bound 0.00/0 despite a real 200. This is
  // the VERBATIM body the S22 received for c23efd76 (net 115.37 over 3 rows).
  group('EarningsSummary.fromJson — LIVE gateway shape (§6B)', () {
    final liveBody = <String, dynamic>{
      'jeeberId': 'c23efd76-6fa4-40cf-814c-116f67ea5e95',
      'period': 'weekly',
      'currency': 'USD',
      'rowCount': 3,
      'totalGross': 137.5,
      'totalCommission': 22.13,
      'totalNet': 115.37,
      'entries': [
        {
          'deliveryId': '22222222-2222-2222-2222-222222222222',
          'tierName': 'express',
          'gross': 62.5,
          'commission': 9.38,
          'net': 53.12,
          'currency': 'USD',
          'deliveredAt': '2026-06-20T14:00:00Z',
        },
        {
          'deliveryId': '11111111-1111-1111-1111-111111111111',
          'tierName': 'standard',
          'gross': 45.0,
          'commission': 6.75,
          'net': 38.25,
          'currency': 'USD',
          'deliveredAt': '2026-06-20T10:00:00Z',
        },
        {
          'deliveryId': '33333333-3333-3333-3333-333333333333',
          'tierName': 'flash',
          'gross': 30.0,
          'commission': 6.0,
          'net': 24.0,
          'currency': 'USD',
          'deliveredAt': '2026-06-15T09:00:00Z',
        },
      ],
    };

    test('binds totalNet → totalCashEarned (the §6B 115.37 headline)', () {
      final s = EarningsSummary.fromJson(liveBody);
      expect(s.totalCashEarned, 115.37);
      expect(s.currency, 'USD');
    });

    test('binds rowCount → deliveryCount and entries → deliveries', () {
      final s = EarningsSummary.fromJson(liveBody);
      expect(s.deliveryCount, 3);
      expect(s.deliveries.length, 3);
      expect(s.deliveries.first.cashCollected, 53.12); // entry `net`
      expect(s.deliveries.first.feePaid, 9.38); // entry `commission`
    });

    test('binds totalCommission → feesPaid', () {
      final s = EarningsSummary.fromJson(liveBody);
      expect(s.feesPaid, 22.13);
    });
  });

  group('EarningsCubit — initial load (constructor-triggered)', () {
    blocTest<EarningsCubit, EarningsState>(
      'emits ready with summary on success',
      build: () => EarningsCubit(
        repository: const _FakeEarningsRepository(),
        jeeberId: 'jeeber-001',
      ),
      expect: () => [
        predicate<EarningsState>(
          (s) => s.mode == EarningsViewMode.ready && s.summary != null,
          'ready with summary',
        ),
      ],
    );

    blocTest<EarningsCubit, EarningsState>(
      'emits error on network failure',
      build: () => EarningsCubit(
        repository: const _FakeEarningsRepository(
          failWith: EarningsErrorKind.network,
        ),
        jeeberId: 'jeeber-001',
      ),
      expect: () => [
        predicate<EarningsState>(
          (s) => s.mode == EarningsViewMode.error && s.errorMessage != null,
          'error with message',
        ),
      ],
    );
  });

  group('EarningsCubit — explicit loadEarnings', () {
    blocTest<EarningsCubit, EarningsState>(
      'emits loading then ready when called explicitly',
      build: () => EarningsCubit(
        repository: const _FakeEarningsRepository(),
        jeeberId: 'jeeber-001',
      ),
      // Wait for constructor-triggered load to settle, then fire a fresh one.
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await c.loadEarnings();
      },
      // Constructor load emits: [ready].  Explicit reload emits: [loading, ready].
      // We skip 1 (constructor ready) and assert the 2 reload states.
      skip: 1,
      expect: () => [
        predicate<EarningsState>(
          (s) => s.mode == EarningsViewMode.loading,
          'loading emitted first',
        ),
        predicate<EarningsState>(
          (s) => s.mode == EarningsViewMode.ready && s.summary != null,
          'ready with summary',
        ),
      ],
    );
  });

  group('EarningsCubit — period change', () {
    blocTest<EarningsCubit, EarningsState>(
      'reloads with new period',
      build: () => EarningsCubit(
        repository: const _FakeEarningsRepository(),
        jeeberId: 'jeeber-001',
      ),
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await c.loadEarnings(period: EarningsPeriod.month);
      },
      // skip the constructor-triggered ready state
      skip: 1,
      expect: () => [
        predicate<EarningsState>(
          (s) =>
              s.mode == EarningsViewMode.loading &&
              s.period == EarningsPeriod.month,
          'loading with month period',
        ),
        predicate<EarningsState>(
          (s) =>
              s.mode == EarningsViewMode.ready &&
              s.period == EarningsPeriod.month,
          'ready with month period',
        ),
      ],
    );
  });

  group('EarningsCubit — export PDF', () {
    blocTest<EarningsCubit, EarningsState>(
      'exportPdf transitions exporting → done with file path',
      build: () => EarningsCubit(
        repository: const _FakeEarningsRepository(),
        jeeberId: 'jeeber-001',
      ),
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await c.exportPdf();
      },
      skip: 1, // skip constructor-triggered ready
      expect: () => [
        predicate<EarningsState>(
          (s) => s.exportMode == EarningsExportMode.exporting,
          'exporting state',
        ),
        predicate<EarningsState>(
          (s) =>
              s.exportMode == EarningsExportMode.done &&
              s.exportedFilePath != null,
          'done with file path',
        ),
      ],
    );
  });
}
