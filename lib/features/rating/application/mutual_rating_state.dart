import 'package:equatable/equatable.dart';

import '../domain/entities/rating_status.dart';
import '../domain/rating_repository.dart';

enum MutualRatingPhase {
  inputting,
  submitting,

  /// Mandatory terminal: rating persisted, screen must navigate away.
  submitted,

  awaitingOther,
  polling,
  revealed,

  /// Auto-revealed after 7 days.
  autoRevealed,

  error,
}

class MutualRatingState extends Equatable {
  const MutualRatingState({
    this.phase = MutualRatingPhase.inputting,
    this.stars = 0,
    this.comment = '',
    this.tags = const [],
    this.counterpartRating,
    this.counterpartName = '',
    this.counterpartAvatarUrl = '',
    this.failure,
  });

  final MutualRatingPhase phase;
  final int stars;
  final String comment;
  final List<String> tags;
  final CounterpartRating? counterpartRating;

  /// Self-resolved identity of the person being rated. Decoration only —
  /// never gates submit, and empty simply keeps the role-aware fallback.
  final String counterpartName;
  final String counterpartAvatarUrl;

  /// Why the submit failed. Replaces the `'ratingError'` sentinel string.
  final RatingFailure? failure;

  MutualRatingState copyWith({
    MutualRatingPhase? phase,
    int? stars,
    String? comment,
    List<String>? tags,
    CounterpartRating? counterpartRating,
    String? counterpartName,
    String? counterpartAvatarUrl,
    RatingFailure? failure,
    bool clearError = false,
  }) {
    return MutualRatingState(
      phase: phase ?? this.phase,
      stars: stars ?? this.stars,
      comment: comment ?? this.comment,
      tags: tags ?? this.tags,
      counterpartRating: counterpartRating ?? this.counterpartRating,
      counterpartName: counterpartName ?? this.counterpartName,
      counterpartAvatarUrl: counterpartAvatarUrl ?? this.counterpartAvatarUrl,
      failure: clearError ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
        phase,
        stars,
        comment,
        tags,
        counterpartRating,
        counterpartName,
        counterpartAvatarUrl,
        failure,
      ];
}
