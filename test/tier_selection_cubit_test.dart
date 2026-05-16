import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_cubit.dart';
import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_state.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

void main() {
  group('TierSelectionCubit — load', () {
    blocTest<TierSelectionCubit, TierSelectionState>(
      'hydrates the catalog and preselects the recommended tier',
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
              s.selectedTierId == TierId.express &&
              s.failure == null,
          'lands on loaded with Express pre-selected',
        ),
      ],
    );

    blocTest<TierSelectionCubit, TierSelectionState>(
      'surfaces a network failure when the repository throws',
      build: () => TierSelectionCubit(
        repository: const FakeTierRepository(failWith: TierLoadFailure.network),
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        predicate<TierSelectionState>(
          (s) => s.status == TierSelectionStatus.loading,
        ),
        predicate<TierSelectionState>(
          (s) =>
              s.status == TierSelectionStatus.error &&
              s.failure == TierLoadFailure.network &&
              s.tiers.isEmpty &&
              s.selectedTierId == null,
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

    test('retry after a failure restores the loaded state', () async {
      var shouldFail = true;
      final cubit = TierSelectionCubit(
        repository: _ToggleRepository(() => shouldFail),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.status, TierSelectionStatus.error);

      shouldFail = false;
      await cubit.load();
      expect(cubit.state.status, TierSelectionStatus.loaded);
      expect(cubit.state.failure, isNull);
    });
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
      // FakeTierRepository's default Express recommendation gets preselected;
      // a catalog without a recommended tier forces the no-selection state.
      final cubit = TierSelectionCubit(
        repository: const _SingleTierRepository(
          TierId.standard,
          recommended: false,
        ),
      );
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
      cubit.confirm();
      expect(cubit.state.confirmedTierId, TierId.express);

      cubit.selectTier(TierId.standard);
      expect(cubit.state.confirmedTierId, isNull,
          reason: 'changing selection should require a fresh confirm tap');
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
  const _SingleTierRepository(this.id, {this.recommended = false});

  final TierId id;
  final bool recommended;

  @override
  Future<List<Tier>> fetchTiers() async => [
        Tier(
          id: id,
          priceLow: 10000,
          priceHigh: 20000,
          currency: 'LBP',
          vehicleClass: TierVehicleClass.any,
          slaMinutes: 60,
          recommended: recommended,
        ),
      ];
}
