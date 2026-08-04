library;
import 'entities/rating_status.dart';

enum RatingFailure {
  network,

  unknown,
}

class RatingRepositoryException implements Exception {
  const RatingRepositoryException(this.failure, [this.message]);

  final RatingFailure failure;
  final String? message;

  @override
  String toString() => 'RatingRepositoryException($failure, $message)';
}

abstract class RatingRepository {
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  });

  Future<RatingStatus> fetchRatingStatus({required String deliveryId});
}
