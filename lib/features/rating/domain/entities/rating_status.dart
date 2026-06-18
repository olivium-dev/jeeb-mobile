import 'package:equatable/equatable.dart';

/// Reflects the blind-reveal state of a mutual delivery rating.
///
/// Aligned with Mockoon :3055 GET /api/deliveries/{id}/rating response.
enum RatingRevealState {
  /// Current user has not yet submitted their rating.
  pendingMine,

  /// Current user submitted; waiting for the counterpart.
  pendingTheirs,

  /// Both sides submitted — ratings are now visible.
  bothRated,

  /// 7-day auto-reveal: counterpart never rated.
  autoRevealed,
}

class CounterpartRating extends Equatable {
  const CounterpartRating({required this.stars, this.comment});

  factory CounterpartRating.fromJson(Map<String, dynamic> json) {
    return CounterpartRating(
      stars: json['stars'] as int? ?? 0,
      comment: json['comment'] as String?,
    );
  }

  final int stars;
  final String? comment;

  @override
  List<Object?> get props => [stars, comment];
}

class RatingStatus extends Equatable {
  const RatingStatus({
    required this.deliveryId,
    required this.revealState,
    this.counterpartRating,
  });

  factory RatingStatus.fromJson(String deliveryId, Map<String, dynamic> json) {
    final raw =
        json['status'] as String? ??
        json['revealState'] as String? ??
        'pending_mine';
    return RatingStatus(
      deliveryId: deliveryId,
      revealState: _parseState(raw),
      counterpartRating: _parseCounterpart(json),
    );
  }

  final String deliveryId;
  final RatingRevealState revealState;
  final CounterpartRating? counterpartRating;

  static RatingRevealState _parseState(String raw) {
    switch (raw) {
      case 'pending_mine':
      case 'pendingMine':
        return RatingRevealState.pendingMine;
      case 'pending_theirs':
      case 'pendingTheirs':
        return RatingRevealState.pendingTheirs;
      case 'both_rated':
      case 'bothRated':
        return RatingRevealState.bothRated;
      case 'auto_revealed':
      case 'autoRevealed':
        return RatingRevealState.autoRevealed;
      default:
        return RatingRevealState.pendingMine;
    }
  }

  static CounterpartRating? _parseCounterpart(Map<String, dynamic> json) {
    final raw = json['counterpartRating'] ?? json['counterpart_rating'];
    if (raw is Map<String, dynamic>) {
      return CounterpartRating.fromJson(raw);
    }
    return null;
  }

  @override
  List<Object?> get props => [deliveryId, revealState, counterpartRating];
}
