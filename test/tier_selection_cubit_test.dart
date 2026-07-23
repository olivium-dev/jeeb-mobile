import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_cubit.dart';
import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_state.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

void main() {
  group('TierSelectionCubit — load', () {
    blocTest<TierSelectionCubit, TierSelectionState>(
      'hydrates the catalog without preselecting the recommended tier',
      build: () => TierSelectionCubit(repository: const FakeTierRepository()),
      act: (cubit) => cubit.load(),
      expect: () => [
        predicate<TierSelectionState>(
          (s) =>
              s.status == TierSelectionStatus.loading &&
              s.tiers.isEmpty &&
              s.failure == null,
          'transitions to loading and clears failure',
        ),
        predicate<TierSelectionState>(
          (s) =>
              s.status == TierSelectionStatus.loaded &&
              s.tiers.length == FakeTierRepository.defaultCatalog.length &&
              s.selectedTierId == null &&
              s.canConfirm == false &&
              s.failure == null,
          'lands on loaded with no customer selection',
        ),
      ],
    );

    blocTest<TierSelectionCubit, TierSelectionState>(
      'surfaces the failure instead of serving the fallback catalog (JEBV4-300)',
      build: () => TierSelectionCubit(
        repository: const FakeTierRepository(failWith: TierLoadFailure.network),
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        predicate<TierSelectionState>(
          (s) => s.status == TierSelectionStatus.loading,
        ),
        // JEBV4-300: the fallback catalog's tiers carry serverId == null, so
        // confirming one would post a client-side enum slug the gateway never
        // minted. On failure the cubit lands on error (blocking Continue and
        // showing a retry) rather than silently serving the bundled catalog.
        predicate<TierSelectionState>(
          (s) =>
              s.status == TierSelectionStatus.error &&
              s.failure == TierLoadFailure.network &&
              s.usingCachedFallback == false &&
              s.selectedTierId == null &&
              s.canConfirm == false,
          'lands on error with the failure surfaced and no selection',
        ),
      ],
    );

    test('a second load while loading is a no-op', () async {
      final cubit = TierSelectionCubit(repository: const FakeTierRepository());
      addTearDown(cubit.close);
      final first = cubit.load();
      // The second call should not double-emit loading nor double-resolve.
      final second = cubit.load();
      await Future.wait([first, second]);
      expect(cubit.state.status, TierSelectionStatus.loaded);
      expect(cubit.state.tiers, FakeTierRepository.defaultCatalog);
    });

    test(
      'retry after a surfaced failure restores the live loaded state',
      () async {
        var shouldFail = true;
        final cubit = TierSelectionCubit(
          repository: _ToggleRepository(() => shouldFail),
        );
        addTearDown(cubit.close);
        await cubit.load();
        // JEBV4-300: the first load fails the network and surfaces the error
        // rather than serving the bundled catalog — Continue stays blocked.
        expect(cubit.state.status, TierSelectionStatus.error);
        expect(cubit.state.failure, TierLoadFailure.network);
        expect(cubit.state.usingCachedFallback, isFalse);
        expect(cubit.state.canConfirm, isFalse);

        shouldFail = false;
        await cubit.load();
        // Retry succeeds against the live repository: now loaded with real tiers
        // (each carrying its gateway serverId) and the failure cleared.
        expect(cubit.state.status, TierSelectionStatus.loaded);
        expect(cubit.state.usingCachedFallback, isFalse);
        expect(cubit.state.failure, isNull);
      },
    );
  });

  group('TierSelectionCubit — selection + confirm', () {
    test('selectTier records the user choice once loaded', () async {
      final cubit = TierSelectionCubit(repository: const FakeTierRepository());
      addTearDown(cubit.close);
      await cubit.load();

      cubit.selectTier(TierId.standard);
      expect(cubit.state.selectedTierId, TierId.standard);
      expect(cubit.state.selectedTier?.id, TierId.standard);
      expect(cubit.state.canConfirm, isTrue);
    });

    test('selectTier ignores ids that are not in the catalog', () async {
      final cubit = TierSelectionCubit(
        repository: const _SingleTierRepository(TierId.standard),
      );
      addTearDown(cubit.close);
      await cubit.load();
      cubit.selectTier(TierId.standard);
      // Standard is the only tier; selecting onTheWay should be ignored.
      cubit.selectTier(TierId.onTheWay);
      expect(cubit.state.selectedTierId, TierId.standard);
    });

    test('selectTier is a no-op before the catalog has loaded', () {
      final cubit = TierSelectionCubit(repository: const FakeTierRepository());
      addTearDown(cubit.close);
      cubit.selectTier(TierId.express);
      expect(cubit.state.selectedTierId, isNull);
      expect(cubit.state.canConfirm, isFalse);
    });

    test('confirm commits the selection so the host can navigate', () async {
      final cubit = TierSelectionCubit(repository: const FakeTierRepository());
      addTearDown(cubit.close);
      await cubit.load();
      cubit.selectTier(TierId.onTheWay);
      cubit.confirm();
      expect(cubit.state.confirmedTierId, TierId.onTheWay);
    });

    test('confirm is a no-op when nothing is selected', () async {
      final cubit = TierSelectionCubit(repository: const FakeTierRepository());
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.selectedTierId, isNull);
      cubit.confirm();
      expect(cubit.state.confirmedTierId, isNull);
    });

    test('selectTier after confirm clears the prior confirmation', () async {
      final cubit = TierSelectionCubit(repository: const FakeTierRepository());
      addTearDown(cubit.close);
      await cubit.load();
      cubit.selectTier(TierId.flash);
      cubit.confirm();
      expect(cubit.state.confirmedTierId, TierId.flash);

      cubit.selectTier(TierId.standard);
      expect(
        cubit.state.confirmedTierId,
        isNull,
        reason: 'changing selection should require a fresh confirm tap',
      );
    });
  });
}

class _ToggleRepository implements TierRepository {
  const _ToggleRepository(this._shouldFail);

  final bool Function() _shouldFail;

  @override
  Future<List<Tier>> fetchTiers() async {
    if (_shouldFail()) {
      throw const TierLoadException(TierLoadFailure.network);
    }
    return FakeTierRepository.defaultCatalog;
  }
}

class _SingleTierRepository implements TierRepository {
  const _SingleTierRepository(this.id);

  final TierId id;

  @override
  Future<List<Tier>> fetchTiers() async => [
    Tier(
      id: id,
      priceLow: 10000,
      priceHigh: 20000,
      currency: 'LBP',
      vehicleClass: TierVehicleClass.any,
      slaMinutes: 60,
      recommended: false,
    ),
  ];
}
