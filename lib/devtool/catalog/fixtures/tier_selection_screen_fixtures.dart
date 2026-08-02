// Designed states for `TierSelectionScreen` — the "Choose speed" tier picker.
// ONE source of truth, two consumers:
//
//   lib/devtool/catalog/entries/batch_11_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/tier_selection/presentation/tier_selection_screen.dart
//                                                       the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog owned one fixture inline — `_PendingTierRepository` — and built
// its three states from that plus [DevtoolTierRepository]. It is extracted here
// unchanged in behaviour as [TierSelectionScreenStalledTierRepository] (the
// privacy underscore removed), and the catalog's three labels — `Loading`,
// `Loaded — delivery-service catalog, no selection`, `Error — network
// unreachable` — are untouched.
//
// ## The screen's TWO seams, and which states each one can reach
//
// `TierSelectionScreen` takes both `repository:` and `cubit:`, and they are not
// interchangeable:
//
//   * `repository:` is the production path. The screen builds its own
//     [TierSelectionCubit] inside `BlocProvider.create` and calls `load()` on
//     it, so whatever the repository does — answer, stall, throw — IS the
//     state. [servedCatalogue], [fullCatalogue], [stalled], [emptyCatalogue]
//     and [failing] are all reached the way the app reaches them.
//   * `cubit:` mounts through `BlocProvider.value` and does NOT call `load()`.
//     A caller who hands over a fresh cubit gets a screen stuck on
//     `TierSelectionStatus.initial` — the spinner — forever, so a `cubit:`
//     fixture has to drive itself ([selectedTierCubit]) or be seeded
//     ([cachedFallbackCubit]).
//
// Selection is the one designed state `repository:` cannot reach:
// `TierSelectionCubit.selectTier` returns early unless `status == loaded`, and
// nothing in the constructor pre-selects — deliberately, since JEBV4 requires a
// DELIBERATE tap rather than defaulting the customer onto the recommended tier.
//
// ## `usingCachedFallback` has NO producer at all
//
// [TierSelectionState.usingCachedFallback] drives the `_CachedBanner` at the top
// of the loaded body ("Showing cached options — prices may differ"), and the
// cubit sets it to `false` on every one of its three emits and to `true` on
// none. No repository, no failure mode and no retry can raise it, so the banner
// and its ARB string are unreachable through the public API. That is the
// residue of JEBV4-300, which REMOVED the cached-catalog fallback — see the two
// `tier-selection-cached-banner` assertions in
// `test/tier_selection_screen_test.dart`, which pin its absence. To render the
// widget at all, [cachedFallbackCubit] seeds the state directly; nothing else
// here reaches past the cubit's public API.
//
// ## Network-free by construction
//
// Every fixture answers from a `const` list, throws, or never completes. That is
// load-bearing rather than decorative: `TierSelectionScreen._resolveRepository()`
// falls back to `sl<TierRepository>()` whenever one is registered — inside the
// running app, which is where the Screen Catalog lives, that is
// `DioTierRepository` and a real `GET /tiers`. The `CatalogNetworkGuard` both
// dev hosts install would NOT stop it either: it rejects mutating verbs only,
// and a tier read is a GET. The guard is the net; this file is the plan.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'dart:async';

import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_cubit.dart';
import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_state.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

import '../tier_catalog_fixture.dart';

/// A tier read that never lands — the FIRST FRAME of every mount, held open.
///
/// Extracted verbatim from the Screen Catalog's `_PendingTierRepository`. Safe
/// to share one `const` instance between mounted cards: a fresh [Completer] is
/// created per call and nothing here is stateful.
class TierSelectionScreenStalledTierRepository implements TierRepository {
  const TierSelectionScreenStalledTierRepository();

  @override
  Future<List<Tier>> fetchTiers() => Completer<List<Tier>>().future;
}

/// A tier read that SUCCEEDS with nothing in it.
///
/// `200 OK` with an empty `items` array — what the gateway returns when no tier
/// is configured for the caller's city, and also what
/// `DioTierRepository._parseResponse` produces from a well-formed response whose
/// entries all carry names this client cannot map (`_tierIdFromLabel` silently
/// drops the ones it does not know, so ONE renamed tier server-side removes it
/// from the app and five renamed tiers empty the screen). As far as every layer
/// below the widget is concerned this is a success:
/// `TierSelectionStatus.loaded`, no failure, no retry.
class TierSelectionScreenEmptyTierRepository implements TierRepository {
  const TierSelectionScreenEmptyTierRepository();

  @override
  Future<List<Tier>> fetchTiers() async => const <Tier>[];
}

/// A cubit parked on an exact [TierSelectionState], for states the cubit's own
/// API cannot produce.
///
/// There is exactly one of those — `usingCachedFallback: true`, see the header —
/// so this is deliberately not a general-purpose escape hatch: every other
/// fixture in this file drives the real cubit through `load()` / `selectTier()`.
/// The repository is the stalled one, so the retry inside the error body (the
/// only path that could call `load()` on a seeded cubit) cannot reach the
/// network either.
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
  /// state be confused with a "recommendation" state.
  static const TierId selectedTier = TierId.express;

  /// What the delivery service serves today: Flash / Express / Standard.
  ///
  /// [DevtoolTierRepository] filters [FakeTierRepository.defaultCatalog] down to
  /// the three ids the gateway actually returns, so this is the list a customer
  /// sees on a healthy device — and the list the catalog's `Loaded —
  /// delivery-service catalog, no selection` state has always shown.
  static TierRepository servedCatalogue() => const DevtoolTierRepository();

  /// The same three tiers as data, for seeding a cubit directly.
  static List<Tier> servedTiers() => FakeTierRepository.defaultCatalog
      .where((Tier tier) => DevtoolTierRepository.supportedTierIds.contains(
            tier.id,
          ))
      .toList(growable: false);

  /// All five tiers the client can render: the served three plus On-the-way and
  /// Eco.
  ///
  /// Not hypothetical — [FakeTierRepository] is the SHIPPING fallback
  /// (`_resolveRepository()` returns `const FakeTierRepository()` when no
  /// `TierRepository` is registered), and the two extra tiers own the only
  /// hyphenated title, the only `No SLA` row and the only SLA the screen renders
  /// in hours (Eco's 2880 minutes → `≤ 48 hr`). This is the tallest list the
  /// screen can be asked to lay out.
  static TierRepository fullCatalogue() => const FakeTierRepository();

  /// The read never resolves: the centred spinner, held.
  static TierRepository stalled() =>
      const TierSelectionScreenStalledTierRepository();

  /// The read succeeds and answers with no tiers at all.
  static TierRepository emptyCatalogue() =>
      const TierSelectionScreenEmptyTierRepository();

  /// The read throws [failure] — `TierSelectionStatus.error`, the retry body.
  ///
  /// Both members of [TierLoadFailure] are reachable and the screen renders the
  /// same sentence for each; see the preview section for why that is worth
  /// looking at.
  static TierRepository failing(TierLoadFailure failure) =>
      DevtoolTierRepository(failWith: failure);

  /// A cubit already carrying a selection, for the `cubit:` seam.
  ///
  /// `selectTier` is a no-op until `load()` has landed, so the selection is
  /// chained onto the load rather than emitted alongside it — the real
  /// transition a customer's tap makes, not a synthesised state. The `isClosed`
  /// guard matters because the preview host disposes its cubit and an `emit` on
  /// a closed cubit throws.
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
  /// rather than driven, because nothing in the cubit can produce it.
  ///
  /// Same three served tiers underneath, so the only difference from
  /// [servedCatalogue] is the banner itself.
  static TierSelectionCubit cachedFallbackCubit() =>
      TierSelectionScreenSeededCubit(
        TierSelectionState(
          status: TierSelectionStatus.loaded,
          tiers: servedTiers(),
          usingCachedFallback: true,
        ),
      );
}
