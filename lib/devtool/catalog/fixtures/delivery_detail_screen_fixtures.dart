// Shared dev-only fixtures for `DeliveryDetailScreen` (the client order-detail
// action hub at `/orders/:id`).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_03_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/deep_link_targets/delivery_detail_screen.dart`.
//
// The catalog entry had NO fixtures to extract: it mounted
// `const DeliveryDetailScreen(deliveryId: 'ORD-4821')` bare, on the strength of
// a comment that said the screen has "no repository/GetIt dependency at all".
// That was true when the entry was written and stopped being true with
// JEBV4-309 / JEBV4-308: the hub now resolves a status source from GetIt's
// `Dio` when `summaryRepository:` is null (`_resolveSummaryRepository`) and a
// `RatingRepository` from GetIt when `ratingRepository:` is null. Inside the
// app — which is the only place the catalog runs, and where DI IS built — the
// bare entry therefore issued a live `GET /v1/deliveries/{id}` (a GET, so
// `CatalogNetworkGuard` passes it) and rendered whichever lifecycle state that
// order happened to be in. A designed state that depends on live server data is
// not a designed state, so both seams are scripted here instead.
//
// Everything below is a LOCAL fake over the two domain contracts. No Dio, no
// GetIt, no network — network-free by construction, not merely by the guard the
// two hosts install. The screen reads exactly ONE field off the summary
// (`statusId`), so that is the only field these fakes vary; the rest of
// `OrderChatSummary` is left at its defaults on purpose, so a future reader is
// not misled into thinking the hub renders a price or an ETA. It does not.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'dart:async';

import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';

/// Answers one canned wire `statusId` — the single value the hub classifies
/// through `DeliveryStatusVocab` to pick its bucket.
///
/// `const`-constructible so both hosts can keep building a `const`
/// `DeliveryDetailScreen`.
class DeliveryDetailScreenFakeSummaryRepository
    implements OrderChatSummaryRepository {
  const DeliveryDetailScreenFakeSummaryRepository(this.statusId);

  /// The status exactly as the gateway spells it on the wire (`Ordered`,
  /// `InTransit`, `Done`, `Cancelled`, `Expired` …). Deliberately the raw
  /// CapitalCase spelling rather than a normalized token: normalizing is
  /// `DeliveryStatusVocab`'s job and these fixtures exist partly to exercise it.
  final String statusId;

  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) async =>
      OrderChatSummary(deliveryId: deliveryId, statusId: statusId);
}

/// The status read FAILED — a 500, a dropped transport, the delivery service
/// down. Throws the same typed exception the Dio implementation throws, which
/// is the only failure `_loadStatus` catches by name.
class DeliveryDetailScreenUnavailableSummaryRepository
    implements OrderChatSummaryRepository {
  const DeliveryDetailScreenUnavailableSummaryRepository();

  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) async =>
      throw const OrderChatSummaryException(OrderChatSummaryFailure.network);
}

/// A status read that never lands, holding the hub in its `_statusId == null`
/// bucket for as long as the surface is open.
///
/// This is not a synthetic state: it is what EVERY delivery shows on its first
/// frame, because `_loadStatus()` is kicked off from `initState` and the first
/// build happens before it resolves. It is the only way to inspect that frame
/// without a real slow connection.
class DeliveryDetailScreenPendingSummaryRepository
    implements OrderChatSummaryRepository {
  const DeliveryDetailScreenPendingSummaryRepository();

  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) =>
      Completer<OrderChatSummary>().future;
}

/// Canned server-owned rating reveal state (JEBV4-308) for the Rate row.
///
/// Only reached by a TAP — the hub reads it in `_onRateTapped`, never during
/// build — so it changes no preview's first frame. It is scripted anyway
/// because leaving it null sends the tap to `sl<RatingRepository>()`, and in
/// the catalog (which runs inside the app, with DI built) that is a live read.
class DeliveryDetailScreenFakeRatingRepository implements RatingRepository {
  const DeliveryDetailScreenFakeRatingRepository(
    this.revealState, {
    this.counterpartStars,
  });

  final RatingRevealState revealState;

  /// Stars the counterpart gave, shown in the read-only summary sheet once both
  /// sides are revealed. Null renders the "they didn't leave a rating" copy.
  final int? counterpartStars;

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async =>
      RatingStatus(
        deliveryId: deliveryId,
        revealState: revealState,
        counterpartRating: counterpartStars == null
            ? null
            : CounterpartRating(stars: counterpartStars!),
      );

  /// Unreachable from this screen — the hub only READS reveal state; submitting
  /// happens on the mutual-rating terminal. Loud rather than silent: a dev
  /// surface that quietly pretends to have persisted a rating is worse than one
  /// that stops.
  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async =>
      throw UnsupportedError(
        'DeliveryDetailScreen never submits a rating — it reads reveal state '
        'and routes. Reaching this means the hub grew a submit path.',
      );
}

/// The designed states, named once for both dev surfaces.
abstract final class DeliveryDetailScreenFixtures {
  /// The order every dev surface shows. Matches the reference the Screen
  /// Catalog has used for this screen since it was written.
  static const String deliveryId = 'ORD-4821';

  /// ACTIVE, pre-pickup: the free-cancel window (JEBV4-289) is OPEN.
  static const OrderChatSummaryRepository ordered =
      DeliveryDetailScreenFakeSummaryRepository('Ordered');

  /// ACTIVE, parcel in hand: same bucket, but `isCancelAllowed` is now false so
  /// the Cancel button is gone. The pair `ordered`/`inTransit` is the only way
  /// to see that rule move.
  static const OrderChatSummaryRepository inTransit =
      DeliveryDetailScreenFakeSummaryRepository('InTransit');

  /// DELIVERED terminal: banner + Rate + Receipt, no Cancel / OTP / tracking.
  static const OrderChatSummaryRepository delivered =
      DeliveryDetailScreenFakeSummaryRepository('Done');

  /// CANCELLED terminal: banner + Report only.
  static const OrderChatSummaryRepository cancelled =
      DeliveryDetailScreenFakeSummaryRepository('Cancelled');

  /// A NON-CANCELLED terminal. `_bucket` folds every non-delivered terminal
  /// into `cancelled`, so an expired broadcast is presented to the customer as
  /// "Cancelled". Kept as its own fixture precisely because the copy it
  /// produces is wrong for the status that produced it.
  static const OrderChatSummaryRepository expired =
      DeliveryDetailScreenFakeSummaryRepository('Expired');

  /// The read threw — the hub FAILS OPEN to the full legacy list.
  static const OrderChatSummaryRepository statusUnavailable =
      DeliveryDetailScreenUnavailableSummaryRepository();

  /// The read is still in flight — the first frame of every delivery.
  static const OrderChatSummaryRepository statusPending =
      DeliveryDetailScreenPendingSummaryRepository();

  /// This user has NOT rated yet: a tap on Rate routes to the mandatory
  /// mutual-rating terminal.
  static const RatingRepository notYetRated =
      DeliveryDetailScreenFakeRatingRepository(RatingRevealState.pendingMine);

  /// This user HAS rated and the counterpart has not: a tap on Rate opens the
  /// read-only summary sheet instead of a re-editable form — the JEBV4-308 fix,
  /// and the one rating state reachable without leaving the surface.
  static const RatingRepository alreadyRated =
      DeliveryDetailScreenFakeRatingRepository(RatingRevealState.pendingTheirs);

  /// Both sides rated: the summary sheet carries the counterpart's stars.
  static const RatingRepository revealed =
      DeliveryDetailScreenFakeRatingRepository(
    RatingRevealState.bothRated,
    counterpartStars: 5,
  );
}
