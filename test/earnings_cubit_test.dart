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
    required String jeeberId,
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    await Future<void>.delayed(Duration.zero);
    if (failWith != null) throw EarningsRepositoryException(failWith!);
    return _sample;
  }

  @override
  Future<String> exportEarningsPdf({
    required String jeeberId,
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
