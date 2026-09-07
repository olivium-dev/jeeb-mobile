// Designed states for `RequestTypeScreen` — the tier picker at `/request-type`,

import 'dart:async';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_cubit.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

import '../tier_catalog_fixture.dart';

/// A tier read that never lands — the FIRST FRAME of every mount, held open.
/// Extracted verbatim from the Screen Catalog's `_PendingTierRepository`. Safe
/// to share one `const` instance between mounted cards: a fresh [Completer] is
class RequestTypeScreenStalledTierRepository implements TierRepository {
  const RequestTypeScreenStalledTierRepository();

  @override
  Future<List<Tier>> fetchTiers() => Completer<List<Tier>>().future;
}

/// A tier read that SUCCEEDS with nothing in it.
/// `200 OK` with an empty `items` array, which is what the gateway returns when
/// no tier is configured for the caller's city — and what `DioTierRepository
class RequestTypeScreenEmptyTierRepository implements TierRepository {
  const RequestTypeScreenEmptyTierRepository();

  @override
  Future<List<Tier>> fetchTiers() async => const <Tier>[];
}

/// A tier read that throws a classified [AppFailure], so the error rung's
/// kind-aware copy is reviewable.
class RequestTypeScreenFailingTierRepository implements TierRepository {
  const RequestTypeScreenFailingTierRepository(this.failure);

  final AppFailure failure;

  @override
  Future<List<Tier>> fetchTiers() async => throw failure;
}

/// The served three tiers with every gateway-owned NUMBER changed — and copy
/// that does not move a pixel.
/// `_RequestTierCopy.of(l10n, tier.id)` keys every string on `tier.id` alone, so
class RequestTypeScreenRepricedTierRepository implements TierRepository {
  const RequestTypeScreenRepricedTierRepository();

  /// Same three ids as the served catalogue, nothing else in common.
  static const List<Tier> catalogue = <Tier>[
    Tier(
      id: TierId.flash,
      serverId: 'tier_flash_v2',
      priceLow: 99,
      priceHigh: 125,
      currency: 'USD',
      vehicleClass: TierVehicleClass.carOrVan,
      slaMinutes: 5,
    ),
    Tier(
      id: TierId.express,
      serverId: 'tier_express_v2',
      priceLow: 49,
      priceHigh: 62,
      currency: 'USD',
      vehicleClass: TierVehicleClass.bikeOrScooter,
      slaMinutes: 20,
      recommended: true,
    ),
    Tier(
      id: TierId.standard,
      serverId: 'tier_standard_v2',
      priceLow: 12,
      priceHigh: 18,
      currency: 'USD',
      vehicleClass: TierVehicleClass.any,
      slaMinutes: 1440,
    ),
  ];

  @override
  Future<List<Tier>> fetchTiers() async => catalogue;
}

/// The designed states, named once for both dev surfaces.
abstract final class RequestTypeScreenPreviewFixtures {
  /// The tier the catalog's "Selected" state has always chosen, and the one
  /// both dev surfaces select. Named so a render test pins the same tier the
  static const TierId selectedTier = TierId.standard;

  /// What the delivery service serves today: Flash / Express / Standard.
  /// [DevtoolTierRepository] filters [FakeTierRepository.defaultCatalog] down to
  static TierRepository servedCatalogue() => const DevtoolTierRepository();

  /// All five tiers the client can render: the served three plus On-the-Way and
  /// Eco.
  static TierRepository fullCatalogue() => const FakeTierRepository();

  /// The read never resolves: the centred spinner, held.
  static TierRepository stalled() =>
      const RequestTypeScreenStalledTierRepository();

  /// The read succeeds and answers with no tiers at all.
  static TierRepository emptyCatalogue() =>
      const RequestTypeScreenEmptyTierRepository();

  /// The served three ids carrying completely different prices, SLAs, vehicle
  /// classes and recommendations — which the screen renders identically.
  static TierRepository repricedCatalogue() =>
      const RequestTypeScreenRepricedTierRepository();

  /// The read throws [failure] — `TierSelectionStatus.error`, the retry body.
  /// Both members of [TierLoadFailure] are reachable and the screen renders the
  static TierRepository failing(TierLoadFailure failure) =>
      DevtoolTierRepository(failWith: failure);

  /// The read throws a classified failure: kind-aware copy, reviewable.
  static TierRepository failingWith(AppFailure failure) =>
      RequestTypeScreenFailingTierRepository(failure);

  /// 503 — retryable.
  static TierRepository unavailable() =>
      const RequestTypeScreenFailingTierRepository(ServerFailure(status: 503));

  /// 403 — not retryable.
  static TierRepository forbidden() =>
      const RequestTypeScreenFailingTierRepository(ForbiddenFailure());

  /// No transport.
  static TierRepository offline() =>
      const RequestTypeScreenFailingTierRepository(
        NetworkFailure(offline: true),
      );

  /// A cubit already carrying a selection, for the `cubit:` seam.
  /// Same mechanism the Screen Catalog has always used: `selectTier` is a no-op
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
}
