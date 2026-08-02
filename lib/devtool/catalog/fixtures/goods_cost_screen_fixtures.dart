// Designed states for `GoodsCostScreen` ("Enter Goods Cost" — the Jeeber
// declares what the purchased goods cost, `goods_cost = G` in
// qa/test-plan-settlement.md) — ONE source of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_04_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/goods_cost/presentation/goods_cost_screen.dart
//                                                       the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog owned three inline `FakeGoodsCostRepository(...)` literals built
// straight into the entry list. Copying them into the preview section would
// have given the two surfaces two independent notions of "the goods-cost
// screen", free to drift the moment either was edited. Both now import this
// file; the three catalog states are [usd], [lbp] and [currencyUnavailable],
// unchanged in behaviour and in label.
//
// ## The screen's ONE seam, and what it can and cannot reach
//
// `GoodsCostScreen` builds its own `GoodsCostCubit` inside
// `BlocProvider.create` and calls `loadCurrency()` on it. There is no `cubit:`
// or `seed:` seam, so `repository:` is the whole of the injectable surface and
// every state below is reached the way production reaches it: through a
// collaborator that answers, stalls, or throws.
//
// That splits the states in two.
//
//   * The CURRENCY axis is reachable as a first frame. `loadCurrency()` runs at
//     mount, so [usd], [lbp], [currencyUnavailable] and [currencyPending] are
//     what the screen opens on.
//   * The SUBMIT axis is not reachable at all without input.
//     `GoodsCostSubmitStatus.inFlight` and `.failed` exist only after somebody
//     types a parseable amount AND presses `goodsCostSubmit` — the CTA is
//     `isEnabled: _controller.text.trim().isNotEmpty`, so an untouched screen
//     cannot even arm it. [recordRejected], [recordNetworkDown] and
//     [recordStalled] are therefore BOUND states: they open on an ordinary
//     form and only reveal themselves when the CTA is pressed. Both dev
//     surfaces let a human do that; the render test does it in CI.
//
// ## Why every fixture is a FUNCTION, not a const
//
// `FakeGoodsCostRepository.recorded` is a plain mutable field the record path
// writes. A repository shared between two mounted cards would let a submit in
// one be observed from the other, which is exactly the drift these fixtures
// exist to prevent. Each call hands out a fresh instance.
//
// ## No network, by construction
//
// Every answer here comes from a const value, throws, or never completes. That
// matters more than usual for this screen: `_resolveRepository()` falls back to
// `DioGoodsCostRepository(sl<Dio>())` whenever `Dio` is registered — and inside
// the running app, the only place the Screen Catalog runs, it always is. A
// state that forgot `repository:` would issue a live read against a real
// delivery id. The `CatalogNetworkGuard` both hosts install would not stop it
// either: the currency read is a GET, and the guard only rejects mutating
// verbs. The guard is a net; this file is the plan.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'dart:async';

import 'package:jeeb_mobile/features/goods_cost/data/fake_goods_cost_repository.dart';
import 'package:jeeb_mobile/features/goods_cost/domain/goods_cost.dart';
import 'package:jeeb_mobile/features/goods_cost/domain/goods_cost_repository.dart';

/// A collaborator whose calls never land.
///
/// [currency] `null` holds `loadCurrency()` open forever, which is the FIRST
/// FRAME of every mount — the entry-field label degrades to the neutral
/// `goodsCostFieldLabelNeutral` until the read resolves, and there is no
/// spinner, skeleton or placeholder anywhere on the screen to say a read is
/// happening. Passing a code instead lets the label settle and stalls only
/// `recordGoodsCost`, which is the only way to hold
/// `GoodsCostSubmitStatus.inFlight` on screen for longer than a microtask.
class GoodsCostScreenStalledRepository implements GoodsCostRepository {
  const GoodsCostScreenStalledRepository({this.currency});

  /// The code the label settles on, or `null` to stall the read as well.
  final String? currency;

  @override
  Future<String> fetchCurrency(String deliveryId) {
    final String? code = currency;
    return code == null ? Completer<String>().future : Future<String>.value(code);
  }

  @override
  Future<GoodsCost> recordGoodsCost({
    required String deliveryId,
    required double amount,
  }) => Completer<GoodsCost>().future;
}

/// The designed states, named once for both dev surfaces.
abstract final class GoodsCostScreenPreviewFixtures {
  /// The delivery every state declares a cost against.
  ///
  /// It is never rendered — this screen shows no order reference at all, which
  /// is worth noticing: the Jeeber is asked for a number with nothing on screen
  /// tying it to a delivery. The catalog has routed these states through
  /// `DEL-2001`/`2002`/`2003` since the entry was written; one id now serves
  /// every state because none of them can tell the difference.
  static const String deliveryId = 'DEL-2001';

  /// The dollar delivery: `GET` answers `USD`, so the field reads
  /// `Goods cost (USD)`.
  ///
  /// Also the success path — `FakeGoodsCostRepository` records happily — so
  /// this is the state that pops with a gateway-confirmed [GoodsCost].
  static GoodsCostRepository usd() =>
      FakeGoodsCostRepository(currency: 'USD');

  /// The Lebanese-pound delivery: `Goods cost (LBP)`.
  ///
  /// The screen's own comment above `_label` cites 40_GUARDRAILS_ARCH §5 — no
  /// hardcoded currency, the gateway is authoritative — which is what makes
  /// this state the interesting one. See the preview section.
  static GoodsCostRepository lbp() =>
      FakeGoodsCostRepository(currency: 'LBP');

  /// The best-effort currency read failed. Non-blocking by design: the label
  /// degrades to the neutral `Goods cost` and the Jeeber can still submit.
  static GoodsCostRepository currencyUnavailable() =>
      FakeGoodsCostRepository(fetchFailure: GoodsCostFailure.network);

  /// The currency read is still in flight — every mount's first frame, and
  /// visually identical to [currencyUnavailable].
  static GoodsCostRepository currencyPending() =>
      const GoodsCostScreenStalledRepository();

  /// Loads `USD` fine; the record is rejected with the 422 the gateway returns
  /// for a non-positive or out-of-range amount. Press the CTA to reach it.
  static GoodsCostRepository recordRejected() => FakeGoodsCostRepository(
        currency: 'USD',
        recordFailure: GoodsCostFailure.validation,
      );

  /// Loads `LBP` fine; the record never reaches the server. The retryable
  /// failure, and the one a Jeeber standing in a shop actually hits.
  static GoodsCostRepository recordNetworkDown() => FakeGoodsCostRepository(
        currency: 'LBP',
        recordFailure: GoodsCostFailure.network,
      );

  /// Loads `USD` fine; the record never lands at all. The only way to hold
  /// `GoodsCostSubmitStatus.inFlight` — spinner in the CTA, field disabled —
  /// on screen long enough to look at.
  static GoodsCostRepository recordStalled() =>
      const GoodsCostScreenStalledRepository(currency: 'USD');
}
