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

  static const _sample = EarningsSummary(
    totalEarnings: 1000,
    currency: 'LBP',
    deliveryCount: 5,
    commission: 100,
    netPayout: 900,
    periodLabel: 'This week',
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
