import 'package:equatable/equatable.dart';

import '../domain/entities/rating_status.dart';

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
    this.errorMessage,
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
  final String? errorMessage;

  MutualRatingState copyWith({
    MutualRatingPhase? phase,
    int? stars,
    String? comment,
    List<String>? tags,
    CounterpartRating? counterpartRating,
    String? counterpartName,
    String? counterpartAvatarUrl,
    String? errorMessage,
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
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
        errorMessage,
      ];
}
