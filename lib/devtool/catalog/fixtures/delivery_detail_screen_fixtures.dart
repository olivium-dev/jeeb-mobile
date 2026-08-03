import 'dart:async';

import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';

/// Answers one canned wire `statusId` — the single value the hub classifies
class DeliveryDetailScreenFakeSummaryRepository
    implements OrderChatSummaryRepository {
  const DeliveryDetailScreenFakeSummaryRepository(this.statusId);

  /// The status exactly as the gateway spells it on the wire (`Ordered`,
  final String statusId;

  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) async =>
      OrderChatSummary(deliveryId: deliveryId, statusId: statusId);
}

/// The status read FAILED — a 500, a dropped transport, the delivery service
class DeliveryDetailScreenUnavailableSummaryRepository
    implements OrderChatSummaryRepository {
  const DeliveryDetailScreenUnavailableSummaryRepository();

  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) async =>
      throw const OrderChatSummaryException(OrderChatSummaryFailure.network);
}

/// A status read that never lands, holding the hub in its `_statusId == null`
class DeliveryDetailScreenPendingSummaryRepository
    implements OrderChatSummaryRepository {
  const DeliveryDetailScreenPendingSummaryRepository();

  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) =>
      Completer<OrderChatSummary>().future;
}

/// Canned server-owned rating reveal state (JEBV4-308) for the Rate row.
class DeliveryDetailScreenFakeRatingRepository implements RatingRepository {
  const DeliveryDetailScreenFakeRatingRepository(
    this.revealState, {
    this.counterpartStars,
  });

  final RatingRevealState revealState;

  /// Stars the counterpart gave, shown in the read-only summary sheet once both
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
  static const String deliveryId = 'ORD-4821';

  /// ACTIVE, pre-pickup: the free-cancel window (JEBV4-289) is OPEN.
  static const OrderChatSummaryRepository ordered =
      DeliveryDetailScreenFakeSummaryRepository('Ordered');

  /// ACTIVE, parcel in hand: same bucket, but `isCancelAllowed` is now false so
  static const OrderChatSummaryRepository inTransit =
      DeliveryDetailScreenFakeSummaryRepository('InTransit');

  /// DELIVERED terminal: banner + Rate + Receipt, no Cancel / OTP / tracking.
  static const OrderChatSummaryRepository delivered =
      DeliveryDetailScreenFakeSummaryRepository('Done');

  /// CANCELLED terminal: banner + Report only.
  static const OrderChatSummaryRepository cancelled =
      DeliveryDetailScreenFakeSummaryRepository('Cancelled');

  /// A NON-CANCELLED terminal. `_bucket` folds every non-delivered terminal
  static const OrderChatSummaryRepository expired =
      DeliveryDetailScreenFakeSummaryRepository('Expired');

  /// The read threw — the hub FAILS OPEN to the full legacy list.
  static const OrderChatSummaryRepository statusUnavailable =
      DeliveryDetailScreenUnavailableSummaryRepository();

  /// The read is still in flight — the first frame of every delivery.
  static const OrderChatSummaryRepository statusPending =
      DeliveryDetailScreenPendingSummaryRepository();

  /// This user has NOT rated yet: a tap on Rate routes to the mandatory
  static const RatingRepository notYetRated =
      DeliveryDetailScreenFakeRatingRepository(RatingRevealState.pendingMine);

  /// This user HAS rated and the counterpart has not: a tap on Rate opens the
  static const RatingRepository alreadyRated =
      DeliveryDetailScreenFakeRatingRepository(RatingRevealState.pendingTheirs);

  /// Both sides rated: the summary sheet carries the counterpart's stars.
  static const RatingRepository revealed =
      DeliveryDetailScreenFakeRatingRepository(
    RatingRevealState.bothRated,
    counterpartStars: 5,
  );
}
