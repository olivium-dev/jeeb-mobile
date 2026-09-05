// Designed states for `GoodsCostScreen` ("Enter Goods Cost" — the Jeeber

import 'dart:async';

import 'package:jeeb_mobile/features/goods_cost/data/fake_goods_cost_repository.dart';
import 'package:jeeb_mobile/features/goods_cost/domain/goods_cost.dart';
import 'package:jeeb_mobile/features/goods_cost/domain/goods_cost_repository.dart';

/// A collaborator whose calls never land.
/// [currency] `null` holds `loadCurrency()` open forever, which is the FIRST
/// FRAME of every mount — the entry-field label degrades to the neutral
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
  /// It is never rendered — this screen shows no order reference at all, which
  static const String deliveryId = 'DEL-2001';

  /// The dollar delivery: `GET` answers `USD`, so the field reads
  /// `Goods cost (USD)`.
  static GoodsCostRepository usd() =>
      FakeGoodsCostRepository(currency: 'USD');

  /// The Lebanese-pound delivery: `Goods cost (LBP)`.
  /// The screen's own comment above `_label` cites 40_GUARDRAILS_ARCH §5 — no
  static GoodsCostRepository lbp() =>
      FakeGoodsCostRepository(currency: 'LBP');

  /// The best-effort currency read failed. Non-blocking by design: the label
  /// degrades to the neutral `Goods cost`, and the Jeeber is now TOLD the unit
  /// is unknown and given an inline retry (LR-29).
  static GoodsCostRepository currencyUnavailable() =>
      FakeGoodsCostRepository(fetchFailure: GoodsCostFailure.network);

  /// The delivery carried no currency at all — the gateway answered 200 with
  /// no `currency` member, which is now a failure rather than a fabricated USD.
  static GoodsCostRepository currencyAbsent() => FakeGoodsCostRepository(
        fetchFailure: GoodsCostFailure.currencyUnavailable,
      );

  /// Loads `USD` fine; the record's 201 carries no amount, so the screen must
  /// not report a confirmation the server never gave.
  static GoodsCostRepository amountUnconfirmed() => FakeGoodsCostRepository(
        currency: 'USD',
        recordFailure: GoodsCostFailure.unknown,
      );

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
  static GoodsCostRepository recordStalled() =>
      const GoodsCostScreenStalledRepository(currency: 'USD');
}
