import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/rating_repository.dart';
import 'mutual_rating_state.dart';

/// Cubit driving the mandatory post-delivery rating (JM-034).
///
/// Flow: inputting → submitting → submitted.
///
/// Per JM-034 (D56) the rating is a mandatory TERMINAL step: a successful
/// submit lands in [MutualRatingPhase.submitted] and the screen navigates back
/// to the role-aware shell (customer → customer-orders-home; jeeber → Dashboard
/// tab). There is no skip/dismiss on this path and no blind-reveal poll loop —
/// the rating is fire-and-forget against the score-taking-service, which owns
/// reveal/auto-reveal server-side (T-BE-025 cron).
class MutualRatingCubit extends Cubit<MutualRatingState> {
  MutualRatingCubit({
    required RatingRepository repository,
    required this.deliveryId,
    required this.isClient,
  })  : _repository = repository,
        super(const MutualRatingState());

  final RatingRepository _repository;
  final String deliveryId;
  final bool isClient;

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
      // JM-034 (AC2/AC3, D56): mandatory terminal — the screen's BlocListener
      // navigates back to the shell on this phase (nav side-effects belong in
      // the listener, never the builder).
      emit(state.copyWith(phase: MutualRatingPhase.submitted));
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
}
