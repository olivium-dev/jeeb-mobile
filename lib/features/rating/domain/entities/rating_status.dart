import 'package:equatable/equatable.dart';

enum RatingRevealState {
  pendingMine,

  pendingTheirs,

  bothRated,

  autoRevealed,
}

class CounterpartRating extends Equatable {
  const CounterpartRating({required this.stars, this.comment});

  factory CounterpartRating.fromJson(Map<String, dynamic> json) {
    final raw = json['stars'] ?? json['score'];
    return CounterpartRating(
      stars: (raw as num?)?.toInt() ?? 0,
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
    final raw = (json['state'] ?? json['status']) as String? ?? 'pending_self';
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

      case 'pending_both':
      case 'pending_self':
      case 'pending_mine':
        return RatingRevealState.pendingMine;
      case 'pending_counter':
      case 'pending_theirs':
        return RatingRevealState.pendingTheirs;
      case 'revealed':
      case 'both_rated':
        return RatingRevealState.bothRated;
      case 'auto_revealed':
        return RatingRevealState.autoRevealed;
      default:
        return RatingRevealState.pendingMine;
    }
  }

  static CounterpartRating? _parseCounterpart(Map<String, dynamic> json) {
    final nested = json['counterpartRating'];
    if (nested is Map<String, dynamic>) {
      return CounterpartRating.fromJson(nested);
    }
    final ratings = json['ratings'];
    if (ratings is List && ratings.isNotEmpty) {
      final first = ratings.first;
      if (first is Map<String, dynamic>) {
        return CounterpartRating.fromJson(first);
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [deliveryId, revealState, counterpartRating];
}
