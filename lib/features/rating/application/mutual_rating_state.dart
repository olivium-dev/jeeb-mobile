import 'package:equatable/equatable.dart';

import '../domain/entities/rating_status.dart';

enum MutualRatingPhase {
  /// Awaiting user to pick stars and submit.
  inputting,

  /// Submit call in-flight.
  submitting,

  /// JM-034 mandatory terminal: the rating persisted and the screen must
  /// navigate away (customer → customer-orders-home, jeeber → Dashboard tab).
  /// This is the canonical end of the mandatory rating path (AC2/AC3, D56).
  /// The blind-reveal phases below remain for the T-MOB-020 standalone flow.
  submitted,

  /// Submitted; waiting for counterpart to rate.
  awaitingOther,

  /// Polling for status in-progress.
  polling,

  /// Both sides rated — reveal state.
  revealed,

  /// Auto-revealed after 7 days without counterpart rating.
  autoRevealed,

  /// Error state.
  error,
}

class MutualRatingState extends Equatable {
  const MutualRatingState({
    this.phase = MutualRatingPhase.inputting,
    this.stars = 0,
    this.comment = '',
    this.tags = const [],
    this.counterpartRating,
    this.errorMessage,
  });

  final MutualRatingPhase phase;
  final int stars;
  final String comment;
  final List<String> tags;
  final CounterpartRating? counterpartRating;
  final String? errorMessage;

  MutualRatingState copyWith({
    MutualRatingPhase? phase,
    int? stars,
    String? comment,
    List<String>? tags,
    CounterpartRating? counterpartRating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MutualRatingState(
      phase: phase ?? this.phase,
      stars: stars ?? this.stars,
      comment: comment ?? this.comment,
      tags: tags ?? this.tags,
      counterpartRating: counterpartRating ?? this.counterpartRating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [phase, stars, comment, tags, counterpartRating, errorMessage];
}
