import 'package:equatable/equatable.dart';

/// Reflects the blind-reveal state of a mutual delivery rating.
///
/// Aligned with the Express mock score-taking-service on :4010
/// `GET /v1/ratings/jeeb/{deliveryId}/status` response
/// (`state`: pending_both|pending_self|pending_counter|revealed). The legacy
/// Mockoon `status` shape (pending_mine|pending_theirs|both_rated|
/// auto_revealed) is still tolerated for backward compat.
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

  final int stars;
  final String? comment;

  factory CounterpartRating.fromJson(Map<String, dynamic> json) {
    // Real mock returns `score`; legacy shape used `stars`. Tolerate both.
    final raw = json['stars'] ?? json['score'];
    return CounterpartRating(
      stars: (raw as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
    );
  }

  @override
  List<Object?> get props => [stars, comment];
}

class RatingStatus extends Equatable {
  const RatingStatus({
    required this.deliveryId,
    required this.revealState,
    this.counterpartRating,
  });

  final String deliveryId;
  final RatingRevealState revealState;
  final CounterpartRating? counterpartRating;

  factory RatingStatus.fromJson(String deliveryId, Map<String, dynamic> json) {
    // Real mock uses `state`; legacy Mockoon used `status`. Tolerate both.
    final raw = (json['state'] ?? json['status']) as String? ?? 'pending_self';
    return RatingStatus(
      deliveryId: deliveryId,
      revealState: _parseState(raw),
      counterpartRating: _parseCounterpart(json),
    );
  }

  static RatingRevealState _parseState(String raw) {
    switch (raw) {
      // Express mock score-taking-service states.
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
    // Real mock returns a `ratings: [...]` list once revealed; the legacy shape
    // nested a single `counterpartRating` object. Tolerate both.
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
