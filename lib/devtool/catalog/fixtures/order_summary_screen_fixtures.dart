// Designed states for `OrderSummaryScreen` (JM-031 order-summary) — ONE source
// of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_08_entries.dart
//       the designer-facing, on-device Screen Catalog
//   lib/features/order_summary/presentation/order_summary_screen.dart
//       the JEEB PREVIEWS section at its bottom
//
// The catalog owned a private `_PendingOrderSummaryRepository` and an inline
// `_sampleOrderSummary()` literal. They moved here whole when the screen got a
// preview section: two copies of the same "designed state" drift, and the
// catalog is the one a designer signs off against. The three catalog states are
// [loaded], [notFound] and [coldRead] — unchanged in values, unchanged in
// label.
//
// ## The screen has ONE seam that matters here, and every state drives it
//
// `OrderSummaryScreen` takes a `repository:` constructor override
// (40_GUARDRAILS_ARCH §5.4) and builds `OrderSummaryCubit(...)..load()` at
// mount. `load()` short-circuits unless the status is still `initial`, so the
// reachable set is exactly what the repository can produce:
//
//  * `loaded` — a repository that answers with a canned [OrderSummary];
//  * `failed` — a repository that throws a typed [OrderSummaryFailure];
//  * `loading` — a repository whose future never completes.
//
// There is a fourth, and it is the one nobody designs: `repository: null` with
// NOTHING registered in GetIt. `_resolveRepository()` then falls back to the
// shipped [FakeOrderSummaryRepository] and the screen renders INVENTED order
// data. [unconfiguredDi] is that state, kept here because it is a real
// production reading of this screen and not a preview trick — see the preview
// section's findings.
//
// ## Network-free by construction
//
// Every repository here answers from a `const` object, throws, or never
// completes. None builds a Dio client or touches GetIt, so neither dev surface
// depends on the `CatalogNetworkGuard` its host installs — that is a net, not
// the plan.
//
// ## Each state carries content only IT can produce
//
// The screen paints no delivery id, no request id and no timestamp (see the
// preview section's findings), so two states with the same money and the same
// jeeber are pixel-identical. Every loaded fixture below therefore varies its
// jeeber name AND its item summary, so a card silently wired to a neighbour's
// fixture is visible rather than plausible.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'dart:async';

import '../../../features/order_summary/data/fake_order_summary_repository.dart';
import '../../../features/order_summary/domain/order_summary.dart';
import '../../../features/order_summary/domain/order_summary_repository.dart';

/// One designed state: the id the route would carry, and the repository behind
/// it.
///
/// They travel as a pair because the screen reads both — and because a null
/// [repository] is itself a state (see [OrderSummaryScreenFixtures.
/// unconfiguredDi]) rather than a missing value a caller forgot to supply.
final class OrderSummaryScreenDesignedState {
  const OrderSummaryScreenDesignedState({
    required this.deliveryId,
    this.repository,
  });

  /// The `/orders/:id/summary` path parameter this state stands for.
  final String deliveryId;

  /// The read behind this state. Always a local fake — or NULL, which hands the
  /// decision to `OrderSummaryScreen._resolveRepository()`.
  final OrderSummaryRepository? repository;
}

/// A read that never completes — the cold-load state, held open.
///
/// Not a synthetic condition: it is the first frame of EVERY order summary,
/// because `OrderSummaryCubit.load()` emits `loading` before it awaits and only
/// leaves it when the fetch resolves. Holding it open is the only way to
/// inspect that frame without a real slow connection.
///
/// Extracted from the catalog's private `_PendingOrderSummaryRepository`.
class OrderSummaryScreenPendingRepository implements OrderSummaryRepository {
  const OrderSummaryScreenPendingRepository();

  @override
  Future<OrderSummary> fetchSummary(String deliveryId) =>
      Completer<OrderSummary>().future;
}

/// The item summary on [OrderSummaryScreenFixtures.longestContent].
///
/// Public because the render test pins it — it is the one string that fixture
/// alone produces. Long enough to wrap several times at 390 pt and to be the
/// tallest single value the item fact can be handed; customers dictate their
/// request as one run-on sentence, so this is a real shape rather than a
/// stress string.
const String kOrderSummaryScreenLongItem =
    'Two crates of bottled water, a 5 kg bag of rice, four tins of tuna and '
    'the blood-pressure medicine from the pharmacy next to the Mar Elias '
    'junction — ring the bell twice, the intercom on the third floor is broken';

/// The jeeber id [OrderSummaryScreenFixtures.minimalPayload] shows in place of
/// a name.
///
/// Public because the render test pins it. `DioOrderSummaryRepository` falls
/// back to `jeeberId` when neither the delivery, the request nor the user read
/// carried a name — so this exact shape is what a customer sees when the
/// enrichment `GET /v1/users/:id` fails.
const String kOrderSummaryScreenJeeberId =
    'jbr-7f3c1a92-4d8e-4b21-9a05-6c1e2f3a4b5d';

/// The designed states, named once for both dev surfaces.
///
/// Every member is a getter so that each read hands out a fresh state — the
/// preview canvas mounts many cards at once and the catalog rebuilds on every
/// navigation.
///
/// The first three are the states the Screen Catalog has shown since DT-04.
/// The rest are reachable only from the preview canvas today; they are kept
/// here, beside their siblings, so that adding them to the catalog later is a
/// one-line change rather than a re-derivation.
abstract final class OrderSummaryScreenFixtures {
  /// CATALOG · "Loaded". The reference reading: an accepted express order with
  /// every optional field populated — rating, count, ETA and item summary.
  ///
  /// Values unchanged from the catalog's `_sampleOrderSummary()`.
  static OrderSummaryScreenDesignedState get loaded =>
      OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2044',
        repository: FakeOrderSummaryRepository(
          summary: const OrderSummary(
            deliveryId: 'DEL-2044',
            requestId: 'REQ-2044',
            conversationId: 'CONV-2044',
            price: 14.5,
            currency: 'USD',
            jeeberName: 'Rami Chidiac',
            tier: 'express',
            jeeberRating: 4.8,
            jeeberRatingCount: 214,
            etaMinutes: 12,
            itemSummary: 'Pharmacy pickup',
          ),
        ),
      );

  /// CATALOG · "Failed — Not Found". The accepted order is gone (404), or the
  /// deep link carried an id this account cannot see.
  static OrderSummaryScreenDesignedState get notFound =>
      OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2044',
        repository: FakeOrderSummaryRepository(
          failure: OrderSummaryFailure.notFound,
        ),
      );

  /// CATALOG · "Loading". The fetch is on the wire and nothing has come back.
  static OrderSummaryScreenDesignedState get coldRead =>
      const OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2044',
        repository: OrderSummaryScreenPendingRepository(),
      );

  /// The phone is offline (or the gateway is unreachable).
  ///
  /// A DIFFERENT typed failure from [notFound] — and, on this screen, the same
  /// picture. That is the point of keeping both.
  static OrderSummaryScreenDesignedState get networkFailure =>
      OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2077',
        repository: FakeOrderSummaryRepository(
          failure: OrderSummaryFailure.network,
        ),
      );

  /// The emptiest LOADED body this screen can reach — every optional field
  /// absent and every required one defaulted.
  ///
  /// Straight out of `DioOrderSummaryRepository.fetchSummary`, which
  /// null-coalesces the whole payload:
  ///
  ///   price:      `_money(...) ?? 0.0`          → an authoritative `0.00`
  ///   currency:   `_currency(...) ?? 'USD'`     → USD, whatever the order was in
  ///   jeeberName: `... ?? (jeeberId ?? '')`     → a uuid where a person goes
  ///   tier:       `... ?? ''`                   → the "Pending" placeholder
  ///
  /// Reached whenever the delivery row is thin and the best-effort enrichment
  /// reads (`/v1/requests/:id`, `/v1/offers`, `/v1/users/:id`) all fail — each
  /// of which is swallowed by design.
  static OrderSummaryScreenDesignedState get minimalPayload =>
      OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2101',
        repository: FakeOrderSummaryRepository(
          summary: const OrderSummary(
            deliveryId: 'DEL-2101',
            requestId: 'DEL-2101',
            conversationId: '',
            price: 0,
            currency: 'USD',
            jeeberName: kOrderSummaryScreenJeeberId,
            tier: '',
          ),
        ),
      );

  /// The longest plausible content on every axis at once.
  ///
  /// A seven-digit lira amount is ordinary in SYP rather than adversarial, the
  /// tier label is the longest one the resolver has ("On the way"), the ETA is
  /// a four-hour cross-town run, the review count is five digits, and the item
  /// summary is a dictated run-on sentence
  /// ([kOrderSummaryScreenLongItem]).
  static OrderSummaryScreenDesignedState get longestContent =>
      OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
        repository: FakeOrderSummaryRepository(
          summary: const OrderSummary(
            deliveryId: 'DEL-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
            requestId: 'REQ-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
            conversationId: 'CONV-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
            price: 1234567.89,
            currency: 'SYP',
            jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
            tier: 'on-the-way',
            jeeberRating: 4.97,
            jeeberRatingCount: 12480,
            etaMinutes: 240,
            itemSummary: kOrderSummaryScreenLongItem,
          ),
        ),
      );

  /// NO repository and NO DI: what the screen shows when nothing is registered.
  ///
  /// `_resolveRepository()` ends in `return FakeOrderSummaryRepository();`, so
  /// this renders the fake's built-in default — Kamal Hajj, 9.00 USD, express,
  /// 20 min, "Groceries from Spinneys" — as an authoritative accepted order,
  /// with no badge, no banner and no way for the customer to tell. See the
  /// preview section's findings.
  static OrderSummaryScreenDesignedState get unconfiguredDi =>
      const OrderSummaryScreenDesignedState(deliveryId: 'DEL-2044');
}
