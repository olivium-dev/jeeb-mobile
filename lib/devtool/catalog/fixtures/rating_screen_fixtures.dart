import 'dart:async';

import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';

/// Canned [RatingRepository] for previews; const-constructible for catalog.
class RatingScreenFakeRepository implements RatingRepository {
  const RatingScreenFakeRepository({this.throwOnSubmit = false});

  /// When true, submit is simulated as unreachable.
  final bool throwOnSubmit;

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {
    if (throwOnSubmit) {
      throw const RatingRepositoryException(RatingFailure.network);
    }
  }

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async {
    return RatingStatus(
      deliveryId: deliveryId,
      revealState: RatingRevealState.pendingMine,
    );
  }
}

/// Submit never completes, holding screen in in-flight state.
class RatingScreenStalledRepository implements RatingRepository {
  const RatingScreenStalledRepository();

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) =>
      Completer<void>().future;

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) =>
      Completer<RatingStatus>().future;
}

/// The delivery id for rating.
const String ratingScreenDeliveryId = 'DEL-3390';

/// Jeeber being rated by client.
const String ratingScreenJeeberRatee = 'Rami Chidiac';

/// Client being rated by jeeber.
const String ratingScreenClientRatee = 'Layla Haddad';

/// Long name for layout testing.
const String ratingScreenLongRatee = 'Abd Al-Rahman Al-Muhandis Al-Trabulsi';

/// Ratee for "stars picked" state.
const String ratingScreenRatedRatee = 'Karim Nassar';

/// Ratee for submitting state.
const String ratingScreenSubmittingRatee = 'Nour Ghanem';

/// Ratee for failed submit state.
const String ratingScreenFailedRatee = 'Hadi Mansour';
