// Designed states for `TierSelectionScreen` — the "Choose speed" tier picker.

import 'dart:async';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_cubit.dart';
import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_state.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

import '../tier_catalog_fixture.dart';

/// A tier read that never lands — the FIRST FRAME of every mount, held open.
class TierSelectionScreenStalledTierRepository implements TierRepository {
  const TierSelectionScreenStalledTierRepository();

  @override
  Future<List<Tier>> fetchTiers() => Completer<List<Tier>>().future;
}

/// A tier read that SUCCEEDS with nothing in it.
class TierSelectionScreenEmptyTierRepository implements TierRepository {
  const TierSelectionScreenEmptyTierRepository();

  @override
  Future<List<Tier>> fetchTiers() async => const <Tier>[];
}

/// A tier read that throws a classified [AppFailure] — the only way the three
/// copy variants (503 / 403 / offline) become reviewable.
class TierSelectionScreenFailingTierRepository implements TierRepository {
  const TierSelectionScreenFailingTierRepository(this.failure);

  final AppFailure failure;

  @override
  Future<List<Tier>> fetchTiers() async => throw failure;
}

/// A cubit parked on an exact [TierSelectionState], for states the cubit's own
class TierSelectionScreenSeededCubit extends TierSelectionCubit {
  TierSelectionScreenSeededCubit(TierSelectionState seed)
      : super(repository: const TierSelectionScreenStalledTierRepository()) {
    emit(seed);
  }
}

/// The designed states, named once for both dev surfaces.
abstract final class TierSelectionScreenPreviewFixtures {
  /// The tier both dev surfaces select. Express rather than Flash on purpose:
  /// Flash is the `recommended` one, so selecting it would let a "selection"
  static const TierId selectedTier = TierId.express;

  /// What the delivery service serves today: Flash / Express / Standard.
  static TierRepository servedCatalogue() => const DevtoolTierRepository();

  /// The same three tiers as data, for seeding a cubit directly.
  static List<Tier> servedTiers() => FakeTierRepository.defaultCatalog
      .where((Tier tier) => DevtoolTierRepository.supportedTierIds.contains(
            tier.id,
          ))
      .toList(growable: false);

  /// All five tiers the client can render: the served three plus On-the-way and
  static TierRepository fullCatalogue() => const FakeTierRepository();

  /// The read never resolves: the centred spinner, held.
  static TierRepository stalled() =>
      const TierSelectionScreenStalledTierRepository();

  /// The read succeeds and answers with no tiers at all.
  static TierRepository emptyCatalogue() =>
      const TierSelectionScreenEmptyTierRepository();

  /// The read throws [failure] — `TierSelectionStatus.error`, the retry body.
  static TierRepository failing(TierLoadFailure failure) =>
      DevtoolTierRepository(failWith: failure);

  /// The read throws a classified failure: kind-aware copy, reviewable.
  static TierRepository failingWith(AppFailure failure) =>
      TierSelectionScreenFailingTierRepository(failure);

  /// 503 — service unavailable, retryable.
  static TierRepository unavailable() =>
      const TierSelectionScreenFailingTierRepository(
        ServerFailure(status: 503),
      );

  /// 403 — forbidden, NOT retryable: the block shows an exit, not a Retry.
  static TierRepository forbidden() =>
      const TierSelectionScreenFailingTierRepository(ForbiddenFailure());

  /// No transport at all — the one kind allowed to blame the connection.
  static TierRepository offline() =>
      const TierSelectionScreenFailingTierRepository(
        NetworkFailure(offline: true),
      );

  /// A cubit already carrying a selection, for the `cubit:` seam.
  static TierSelectionCubit selectedTierCubit(TierId select) {
    final TierSelectionCubit cubit = TierSelectionCubit(
      repository: const DevtoolTierRepository(),
    );
    unawaited(
      cubit.load().then((_) {
        if (cubit.isClosed) return;
        cubit.selectTier(select);
      }),
    );
    return cubit;
  }

  /// The loaded body wearing the cached-options banner — the ONE state seeded
  static TierSelectionCubit cachedFallbackCubit() =>
      TierSelectionScreenSeededCubit(
        TierSelectionState(
          status: TierSelectionStatus.loaded,
          tiers: servedTiers(),
          usingCachedFallback: true,
        ),
      );
}
