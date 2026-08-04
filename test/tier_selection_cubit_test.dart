import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_cubit.dart';
import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_state.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

void main() {
  group('TierSelectionCubit — load', () {
    blocTest<TierSelectionCubit, TierSelectionState>(
      // MIDNIGHT R9 / doc-13 P0-4 reverses the old "nothing is pre-selected"
      // rule: the board loads with the recommended tier already lit.
      'preselects the recommended tier on load',
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
              s.selectedTierId == TierId.standard &&
              s.canConfirm == true &&
              s.failure == null,
          'lands on loaded with the recommended tier selected',
        ),
      ],
    );

    test('leaves the selection null when no tier is flagged recommended', () async {
      final cubit = TierSelectionCubit(
        repository: const _SingleTierRepository(TierId.standard),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.selectedTierId, isNull);
      expect(cubit.state.canConfirm, isFalse);
    });

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
        expect(cubit.state.status, TierSelectionStatus.error);
        expect(cubit.state.failure, TierLoadFailure.network);
        expect(cubit.state.usingCachedFallback, isFalse);
        expect(cubit.state.canConfirm, isFalse);

        shouldFail = false;
        await cubit.load();
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
      // A catalog with no recommended tier is now the only way to reach the
      // "nothing selected" state after a successful load.
      final cubit = TierSelectionCubit(
        repository: const _SingleTierRepository(TierId.standard),
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
