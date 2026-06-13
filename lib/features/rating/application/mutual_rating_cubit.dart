import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/entities/rating_status.dart';
import '../domain/rating_repository.dart';
import 'mutual_rating_state.dart';

/// Cubit driving the mutual blind rating flow (T-MOB-020).
///
/// Flow: inputting → submitting → awaitingOther -(poll)→ revealed|autoRevealed
class MutualRatingCubit extends Cubit<MutualRatingState> {
  MutualRatingCubit({
    required RatingRepository repository,
    required this.deliveryId,
    required this.isClient,
    Duration pollInterval = const Duration(seconds: 5),
  })  : _repository = repository,
        _pollInterval = pollInterval,
        super(const MutualRatingState());

  final RatingRepository _repository;
  final String deliveryId;
  final bool isClient;
  final Duration _pollInterval;
  Timer? _pollTimer;

  void setStars(int stars) => emit(state.copyWith(stars: stars));
  void setComment(String comment) => emit(state.copyWith(comment: comment));

  void toggleTag(String tag) {
    final tags = List<String>.from(state.tags);
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else {
      tags.add(tag);
    }
    emit(state.copyWith(tags: tags));
  }

  Future<void> submit() async {
    if (state.stars == 0) return;
    emit(state.copyWith(phase: MutualRatingPhase.submitting, clearError: true));
    try {
      await _repository.submitRating(
        deliveryId: deliveryId,
        stars: state.stars,
        isClient: isClient,
        comment: state.comment.isEmpty ? null : state.comment,
        tags: state.tags.isEmpty ? null : state.tags,
      );
      emit(state.copyWith(phase: MutualRatingPhase.awaitingOther));
      _startPolling();
    } catch (_) {
      emit(state.copyWith(
        phase: MutualRatingPhase.error,
        errorMessage: 'ratingError',
      ));
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollStatus());
  }

  Future<void> _pollStatus() async {
    if (isClosed) return;
    emit(state.copyWith(phase: MutualRatingPhase.polling));
    try {
      final status = await _repository.fetchRatingStatus(
        deliveryId: deliveryId,
      );
      _applyStatus(status);
    } catch (_) {
      // Polling failure is silent — keep in awaitingOther
      if (!isClosed) {
        emit(state.copyWith(phase: MutualRatingPhase.awaitingOther));
      }
    }
  }

  void _applyStatus(RatingStatus status) {
    if (isClosed) return;
    switch (status.revealState) {
      case RatingRevealState.bothRated:
        _pollTimer?.cancel();
        emit(state.copyWith(
          phase: MutualRatingPhase.revealed,
          counterpartRating: status.counterpartRating,
        ));
      case RatingRevealState.autoRevealed:
        _pollTimer?.cancel();
        emit(state.copyWith(
          phase: MutualRatingPhase.autoRevealed,
          counterpartRating: status.counterpartRating,
        ));
      default:
        emit(state.copyWith(phase: MutualRatingPhase.awaitingOther));
    }
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
