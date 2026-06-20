import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/entities/rating_status.dart';
import '../domain/rating_repository.dart';
import 'mutual_rating_state.dart';

/// Cubit driving the post-delivery rating (JM-034) and the optional
/// double-blind reveal (feedback-double-blind-reveal, SC-043/SC-093).
///
/// Two paths share this cubit, selected by [revealMode]:
///
/// 1. **Mandatory terminal (default, revealMode=false, JM-034 / D56):**
///    inputting → submitting → submitted. A successful submit lands in
///    [MutualRatingPhase.submitted] and the screen navigates back to the shell.
///    No reveal poll.
///
/// 2. **Double-blind reveal (revealMode=true, T-MOB-020):** inputting →
///    submitting → awaitingOther → (poll) → revealed | autoRevealed. After the
///    user submits, the cubit polls the server-owned reveal status
///    (`GET /v1/ratings/jeeb/{id}/status`, reveal computed by the T-BE-025
///    cron). The counterpart's rating stays HIDDEN until the server reports
///    both sides rated (`revealed`) or the 7-day auto-reveal fired
///    (`autoRevealed`) — never inferred client-side. If the user opens the
///    screen after already rating, [startRevealPolling] resumes the poll without
///    re-submitting.
class MutualRatingCubit extends Cubit<MutualRatingState> {
  MutualRatingCubit({
    required RatingRepository repository,
    required this.deliveryId,
    required this.isClient,
    this.revealMode = false,
    this.pollInterval = const Duration(seconds: 5),
    this.maxPolls = 24,
  })  : _repository = repository,
        super(const MutualRatingState());

  final RatingRepository _repository;
  final String deliveryId;
  final bool isClient;

  /// When true, follow the double-blind reveal path (poll for the counterpart);
  /// when false, the rating is the mandatory terminal step (JM-034).
  final bool revealMode;

  /// Spacing between reveal status polls.
  final Duration pollInterval;

  /// Bound on the number of polls so an un-revealed delivery doesn't poll
  /// forever (the server owns the 7-day auto-reveal; the live screen just
  /// stops polling and shows "awaiting" after this many attempts).
  final int maxPolls;

  Timer? _pollTimer;
  int _pollCount = 0;

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
      if (revealMode) {
        // T-MOB-020: don't navigate away — wait for the server-owned reveal.
        emit(state.copyWith(phase: MutualRatingPhase.awaitingOther));
        await startRevealPolling();
      } else {
        // JM-034 (AC2/AC3, D56): mandatory terminal — the screen's BlocListener
        // navigates back to the shell on this phase.
        emit(state.copyWith(phase: MutualRatingPhase.submitted));
      }
    } on RatingRepositoryException {
      emit(state.copyWith(
        phase: MutualRatingPhase.error,
        errorMessage: 'ratingError',
      ));
    } catch (_) {
      emit(state.copyWith(
        phase: MutualRatingPhase.error,
        errorMessage: 'ratingError',
      ));
    }
  }

  /// Begins polling the server reveal status (double-blind path). Safe to call
  /// after a submit, or directly when the screen opens for an already-rated
  /// delivery. The counterpart is surfaced only when the SERVER reports a
  /// revealed / auto-revealed state.
  Future<void> startRevealPolling() async {
    _pollTimer?.cancel();
    _pollCount = 0;
    await _pollOnce();
    if (isClosed) return;
    // If the first poll already revealed, we're done; otherwise schedule.
    if (_isTerminalReveal(state.phase)) return;
    _pollTimer = Timer.periodic(pollInterval, (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    if (isClosed) return;
    _pollCount++;
    try {
      final status = await _repository.fetchRatingStatus(deliveryId: deliveryId);
      if (isClosed) return;
      _applyStatus(status);
    } on RatingRepositoryException {
      // A transient status-poll failure must not strand the user — keep the
      // awaiting view and let the next tick retry.
    } catch (_) {
      // Same: swallow and retry on the next tick.
    }
    if (_pollCount >= maxPolls && !_isTerminalReveal(state.phase)) {
      _pollTimer?.cancel();
    }
  }

  void _applyStatus(RatingStatus status) {
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
      case RatingRevealState.pendingTheirs:
        // We rated; counterpart hasn't — keep it hidden.
        emit(state.copyWith(phase: MutualRatingPhase.awaitingOther));
      case RatingRevealState.pendingMine:
        // Server says we still owe a rating — stay on input.
        emit(state.copyWith(phase: MutualRatingPhase.inputting));
    }
  }

  bool _isTerminalReveal(MutualRatingPhase phase) =>
      phase == MutualRatingPhase.revealed ||
      phase == MutualRatingPhase.autoRevealed;

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
