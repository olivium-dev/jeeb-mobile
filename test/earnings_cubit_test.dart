// Tests for EarningsCubit (T-MOB-019).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/earnings/application/earnings_cubit.dart';
import 'package:jeeb_mobile/features/earnings/application/earnings_state.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';

class _FakeEarningsRepository implements EarningsRepository {
  const _FakeEarningsRepository({this.failWith});

  final EarningsErrorKind? failWith;

  // Fee-only reframe (JM-052, D41/D44): total cash earned (net, off-wallet COD)
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
        EarningsSummary.fromJson({
          ...mockBody,
          'memberSince': '2026-01-15',
        }).memberSince,
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

    test('parses live gateway entries/totals shape', () {
      final s = EarningsSummary.fromJson({
        'jeeberId': 'c23efd76-6fa4-40cf-814c-116f67ea5e95',
        'period': 'weekly',
        'currency': 'USD',
        'rowCount': 3,
        'totalGross': 137.50,
        'totalCommission': 22.13,
        'totalNet': 115.37,
        'entries': [
          {
            'earningId': '90debfac-22c9-435a-941c-d806aeb0f8ae',
            'transactionId': 'seed-tx-2',
            'deliveryId': '22222222-2222-2222-2222-222222222222',
            'tierName': 'express',
            'gross': 62.50,
            'commission': 9.38,
            'net': 53.12,
            'currency': 'USD',
            'deliveredAt': '2026-06-20T14:00:00Z',
          },
        ],
      });

      expect(s.totalCashEarned, 137.50);
      expect(s.feesPaid, 22.13);
      expect(s.currency, 'USD');
      expect(s.deliveryCount, 3);
      expect(s.netPerOffer, closeTo(38.4566666667, 1e-9));
      expect(
        s.deliveries.single.deliveryId,
        '22222222-2222-2222-2222-222222222222',
      );
      expect(s.deliveries.single.cashCollected, 62.50);
      expect(s.deliveries.single.feePaid, 9.38);
      expect(s.deliveries.single.date, '2026-06-20T14:00:00Z');
    });
  });

  // §6B real-app regression: the LIVE gateway `GET /v1/jeeb/earnings` body keys
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

    test('binds totalGross → totalCashEarned (the §6B cash-collected headline)',
        () {
      final s = EarningsSummary.fromJson(liveBody);
      expect(s.totalCashEarned, 137.50); // cash physically collected (COD)
      expect(s.currency, 'USD');
    });

    test('binds rowCount → deliveryCount and entries → deliveries', () {
      final s = EarningsSummary.fromJson(liveBody);
      expect(s.deliveryCount, 3);
      expect(s.deliveries.length, 3);
      expect(s.deliveries.first.cashCollected, 62.50); // entry `gross` (COD)
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
          (s) =>
              s.mode == EarningsViewMode.error &&
              s.failure is NetworkFailure,
          'error carrying the network KIND, never an English sentence',
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

  group('EarningsCubit — wallet balance (footer pill)', () {
    blocTest<EarningsCubit, EarningsState>(
      'a healthy wallet read lands in state',
      build: () => EarningsCubit(
        repository: const _FakeEarningsRepository(),
        walletRepository: const _FakeWalletRepository(),
        jeeberId: 'jeeber-001',
      ),
      wait: const Duration(milliseconds: 20),
      verify: (c) {
        expect(c.state.walletBalance?.availableBalance, 6.40);
        expect(c.state.mode, EarningsViewMode.ready);
      },
    );

    blocTest<EarningsCubit, EarningsState>(
      'a failing wallet read never degrades the earnings screen',
      build: () => EarningsCubit(
        repository: const _FakeEarningsRepository(),
        walletRepository: const _FakeWalletRepository(fails: true),
        jeeberId: 'jeeber-001',
      ),
      wait: const Duration(milliseconds: 20),
      verify: (c) {
        // No error mode, no error message, no balance — the pill simply
        // renders without its suffix rather than showing a fabricated zero.
        expect(c.state.mode, EarningsViewMode.ready);
        expect(c.state.failure, isNull);
        expect(c.state.walletBalance, isNull);
      },
    );

    blocTest<EarningsCubit, EarningsState>(
      'LR-17: a second exportPdf while one is in flight is a no-op',
      build: () => EarningsCubit(
        repository: const _StallingExportRepository(),
        jeeberId: 'jeeber-001',
      ),
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        unawaited(c.exportPdf());
        await c.exportPdf();
      },
      verify: (c) => expect(c.state.exportMode, EarningsExportMode.exporting),
    );

    blocTest<EarningsCubit, EarningsState>(
      'LR-16: refresh() keeps `ready` and the current summary, and a failed '
      'refresh raises refreshError instead of blanking the dashboard',
      build: () => EarningsCubit(
        repository: _WarmFailingEarningsRepository(),
        jeeberId: 'jeeber-001',
      ),
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await c.refresh();
      },
      verify: (c) {
        expect(c.state.mode, EarningsViewMode.ready);
        expect(c.state.summary, isNotNull);
        expect(c.state.refreshError, isA<NetworkFailure>());
      },
    );

    blocTest<EarningsCubit, EarningsState>(
      'a period tap DOES flip to loading — the split is deliberate',
      build: () => EarningsCubit(
        repository: const _FakeEarningsRepository(),
        jeeberId: 'jeeber-001',
      ),
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await c.loadEarnings(period: EarningsPeriod.month);
      },
      skip: 1,
      expect: () => [
        predicate<EarningsState>(
          (s) => s.mode == EarningsViewMode.loading,
          'loading',
        ),
        predicate<EarningsState>(
          (s) => s.mode == EarningsViewMode.ready,
          'ready',
        ),
      ],
    );

    blocTest<EarningsCubit, EarningsState>(
      'LR-04/EARN-01: a RAW TypeError from the repository lands the error '
      'rung, never a hung skeleton',
      build: () => EarningsCubit(
        repository: const _RawThrowEarningsRepository(),
        jeeberId: 'jeeber-001',
      ),
      wait: const Duration(milliseconds: 20),
      verify: (c) {
        expect(c.state.mode, EarningsViewMode.error);
        expect(c.state.failure, isNotNull);
      },
    );
  });
}

/// A cold load that lands and every refresh after it that fails.
class _WarmFailingEarningsRepository implements EarningsRepository {
  bool _served = false;

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    if (_served) {
      throw const EarningsRepositoryException(
        EarningsErrorKind.network,
        null,
        NetworkFailure(),
      );
    }
    _served = true;
    return const EarningsSummary(
      totalCashEarned: 10,
      feesPaid: 1,
      currency: 'USD',
      deliveryCount: 1,
    );
  }

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      throw const EarningsRepositoryException(EarningsErrorKind.network);
}

/// Raises the untyped error an `as` cast in `fromJson` would.
class _RawThrowEarningsRepository implements EarningsRepository {
  const _RawThrowEarningsRepository();

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      throw TypeError();

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      throw TypeError();
}

/// Never resolves — the export in-flight guard's fixture.
class _StallingExportRepository implements EarningsRepository {
  const _StallingExportRepository();

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      const EarningsSummary(
        totalCashEarned: 10,
        feesPaid: 1,
        currency: 'USD',
        deliveryCount: 1,
      );

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) =>
      Completer<String>().future;
}

class _FakeWalletRepository implements WalletRepository {
  const _FakeWalletRepository({this.fails = false});

  final bool fails;

  @override
  Future<WalletBalance> fetchBalance() async {
    await Future<void>.delayed(Duration.zero);
    if (fails) {
      throw const WalletRepositoryException(WalletFailure.network);
    }
    return const WalletBalance(
      availableBalance: 6.40,
      affordabilityState: WalletAffordability.enough,
      reservedNow: 0,
      giftCredit: 0,
      currency: 'USD',
    );
  }
}
