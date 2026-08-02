// Designed states for `RequestTypeScreen` — the tier picker at `/request-type`,
// the first screen of the customer create flow (Figma 56535:2392). ONE source of
// truth, two consumers:
//
//   lib/devtool/catalog/entries/batch_10_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/request_type/presentation/request_type_screen.dart
//                                                       the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog owned two fixtures inline — `_PendingTierRepository` and
// `_selectedTierCubit(TierId)` — and its three states were built straight from
// them. Both are extracted here unchanged in behaviour:
// [RequestTypeScreenStalledTierRepository] is the pending repository with the
// privacy underscore removed, and [RequestTypeScreenPreviewFixtures
// .selectedTierCubit] is the same "load, then select once it resolves" trick,
// with one addition noted on the method. The catalog's three labels — `Loading`,
// `Loaded — no selection`, `Selected — Standard` — are unchanged.
//
// ## The screen's TWO seams, and which states each one can reach
//
// `RequestTypeScreen` takes both `repository:` and `cubit:` (§5.4 constructor
// test seams), and they are not interchangeable:
//
//   * `repository:` is the production path. The screen builds its own
//     [TierSelectionCubit] inside `BlocProvider.create` and calls `load()` on
//     it, so whatever the repository does — answer, stall, throw — IS the
//     state: [servedCatalogue], [fullCatalogue], [stalled], [emptyCatalogue]
//     and [failing] are all reached the way the app reaches them.
//   * `cubit:` mounts a cubit through `BlocProvider.value` and does NOT call
//     `load()` on it. A caller who hands over a fresh cubit gets a screen stuck
//     on `TierSelectionStatus.initial` — the spinner — forever. So a `cubit:`
//     fixture has to drive itself, which is the whole of
//     [selectedTierCubit].
//
// Selection is the one thing `repository:` cannot reach: `selectTier` is a
// no-op until `load()` has landed (`TierSelectionCubit.selectTier` returns
// early unless `status == loaded`), and nothing in the constructor pre-selects.
// That is why the "Selected" state is the only one built on the other seam.
//
// ## Network-free by construction
//
// Every fixture here answers from a `const` list, throws, or never completes.
// That is load-bearing rather than decorative: `RequestTypeScreen
// ._resolveRepository()` falls back to `sl<TierRepository>()` whenever one is
// registered — inside the running app, which is where the Screen Catalog lives,
// that is `DioTierRepository` and a real `GET /tiers`. The `CatalogNetworkGuard`
// both dev hosts install would NOT stop it either: it rejects mutating verbs
// only, and a tier read is a GET. The guard is the net; this file is the plan.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'dart:async';

import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_cubit.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

import '../tier_catalog_fixture.dart';

/// A tier read that never lands — the FIRST FRAME of every mount, held open.
///
/// Extracted verbatim from the Screen Catalog's `_PendingTierRepository`. Safe
/// to share one `const` instance between mounted cards: a fresh [Completer] is
/// created per call and nothing here is stateful.
class RequestTypeScreenStalledTierRepository implements TierRepository {
  const RequestTypeScreenStalledTierRepository();

  @override
  Future<List<Tier>> fetchTiers() => Completer<List<Tier>>().future;
}

/// A tier read that SUCCEEDS with nothing in it.
///
/// `200 OK` with an empty `items` array, which is what the gateway returns when
/// no tier is configured for the caller's city — and what `DioTierRepository
/// ._parseResponse` also produces from a well-formed response whose entries all
/// carry names this client cannot map (`_tierIdFromLabel` drops the ones it does
/// not know, so ONE renamed tier server-side removes it from the app and five
/// renamed tiers empty the screen). It is a success as far as every layer below
/// the widget is concerned: `TierSelectionStatus.loaded`, no failure, no retry.
class RequestTypeScreenEmptyTierRepository implements TierRepository {
  const RequestTypeScreenEmptyTierRepository();

  @override
  Future<List<Tier>> fetchTiers() async => const <Tier>[];
}

/// The served three tiers with every gateway-owned NUMBER changed — and copy
/// that does not move a pixel.
///
/// `_RequestTierCopy.of(l10n, tier.id)` keys every string on `tier.id` alone, so
/// `priceLow`, `priceHigh`, `currency`, `slaMinutes`, `vehicleClass`,
/// `recommended` and `serverId` reach the screen and are dropped. This
/// catalogue prices Flash at 99–125 USD instead of 120–160k LBP, promises it in
/// five minutes instead of sixty, moves it to a van, and takes its `recommended`
/// flag away; it renders byte-for-byte the same card as [
/// RequestTypeScreenPreviewFixtures.servedCatalogue]. That is the state, and it
/// is why this fixture exists.
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
  /// designer signed off against instead of picking its own.
  static const TierId selectedTier = TierId.standard;

  /// What the delivery service serves today: Flash / Express / Standard.
  ///
  /// [DevtoolTierRepository] filters [FakeTierRepository.defaultCatalog] down to
  /// the three ids the gateway actually returns, so this is the list a customer
  /// sees on a healthy device — and the list the catalog's `Loaded — no
  /// selection` state has always shown.
  static TierRepository servedCatalogue() => const DevtoolTierRepository();

  /// All five tiers the client can render: the served three plus On-the-Way and
  /// Eco.
  ///
  /// Not hypothetical — [FakeTierRepository] is the SHIPPING fallback
  /// (`_resolveRepository()` returns `const FakeTierRepository()` when no
  /// `TierRepository` is registered), and the two extra tiers own the longest
  /// title and the longest speed line in the ARB. This is the tallest list the
  /// screen can be asked to lay out.
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
  ///
  /// Both members of [TierLoadFailure] are reachable and the screen renders the
  /// same sentence for each; see the preview section for why that is worth
  /// looking at.
  static TierRepository failing(TierLoadFailure failure) =>
      DevtoolTierRepository(failWith: failure);

  /// A cubit already carrying a selection, for the `cubit:` seam.
  ///
  /// Same mechanism the Screen Catalog has always used: `selectTier` is a no-op
  /// until `load()` has landed, so the selection is chained onto the load rather
  /// than emitted alongside it. The ONE addition is the `isClosed` guard — the
  /// catalog never disposes these (it is an in-app browser and the cubit dies
  /// with the route), but the preview host does, and an `emit` on a closed cubit
  /// throws. The guard changes nothing about the designed state.
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
