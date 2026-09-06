import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../domain/dispute_status_repository.dart';
import 'dispute_status_state.dart';

class DisputeStatusCubit extends Cubit<DisputeStatusState> {
  DisputeStatusCubit({
    required DisputeStatusRepository repository,
    required this.disputeId,
  }) : _repository = repository,
       super(const DisputeStatusState());

  final DisputeStatusRepository _repository;

  final String disputeId;
  int _generation = 0;

  Future<void> load() async {
    if (isClosed ||
        (state.status != DisputeStatusViewStatus.initial &&
            state.status != DisputeStatusViewStatus.failed)) {
      return;
    }
    if (disputeId.trim().isEmpty) {
      // Terminal: the screen offers the way out, never an inert Retry.
      emit(
        state.copyWith(
          status: DisputeStatusViewStatus.failed,
          error: DisputeStatusFailure.notFound,
          failure: const NotFoundFailure(),
        ),
      );
      return;
    }
    final generation = ++_generation;
    emit(
      state.copyWith(status: DisputeStatusViewStatus.loading, clearError: true),
    );
    await _fetch(generation);
  }

  Future<void> refresh() async {
    if (isClosed || disputeId.trim().isEmpty) return;
    final generation = ++_generation;
    if (state.status == DisputeStatusViewStatus.failed) {
      emit(
        state.copyWith(
          status: DisputeStatusViewStatus.loading,
          clearError: true,
        ),
      );
    }
    await _fetch(generation);
  }

  void acknowledgeRefreshError() {
    if (isClosed) return;
    emit(state.copyWith(clearRefreshError: true));
  }

  Future<void> _fetch(int generation) async {
    try {
      final dispute = await _repository.fetchDispute(disputeId);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: DisputeStatusViewStatus.loaded,
          dispute: dispute,
          clearError: true,
          clearRefreshError: true,
        ),
      );
    } on DisputeStatusRepositoryException catch (e) {
      if (isClosed || generation != _generation) return;
      _emitFailure(e.failure, e.appFailure ?? AppFailure.of(e));
    } catch (error) {
      if (isClosed || generation != _generation) return;
      _emitFailure(DisputeStatusFailure.unknown, AppFailure.of(error));
    }
  }

  /// A warm failure keeps the loaded dispute on screen; only a cold read
  /// blanks the surface (R6 "error before empty, refresh keeps rows").
  void _emitFailure(DisputeStatusFailure kind, AppFailure failure) {
    if (state.status == DisputeStatusViewStatus.loaded) {
      emit(state.copyWith(refreshError: failure));
      return;
    }
    emit(
      state.copyWith(
        status: DisputeStatusViewStatus.failed,
        error: kind,
        failure: failure,
      ),
    );
  }
}
