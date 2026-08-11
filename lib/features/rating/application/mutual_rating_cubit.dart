import 'package:flutter_bloc/flutter_bloc.dart';

import '../../chat/domain/order_chat_summary.dart';
import '../domain/rating_repository.dart';
import 'mutual_rating_state.dart';

/// Mandatory post-delivery rating: fire-and-forget.
class MutualRatingCubit extends Cubit<MutualRatingState> {
  MutualRatingCubit({
    required RatingRepository repository,
    required this.deliveryId,
    required this.isClient,
    OrderChatSummaryRepository? counterpartRepository,
  })  : _repository = repository,
        _counterpartRepository = counterpartRepository,
        super(const MutualRatingState());

  final RatingRepository _repository;
  final OrderChatSummaryRepository? _counterpartRepository;
  final String deliveryId;
  final bool isClient;

  /// Resolves who is being rated so entry points that carry no counterpart data
  /// (receipt confirm, OTP handover) still show a real name + photo.
  /// Decoration only: it NEVER blocks, errors or delays the mandatory rating.
  Future<void> loadCounterpart() async {
    final repo = _counterpartRepository;
    if (repo == null) return;
    try {
      final summary = await repo.fetchSummary(deliveryId);
      if (isClosed) return;
      emit(state.copyWith(
        counterpartName: summary.counterpartName(viewerIsJeeber: !isClient),
        counterpartAvatarUrl:
            summary.counterpartAvatarUrl(viewerIsJeeber: !isClient) ?? '',
      ));
    } catch (_) {
      // Identity is decoration; a miss leaves the role-aware fallback.
    }
  }

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
      /// Mandatory terminal: BlocListener navigates back on submitted.
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
