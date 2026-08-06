import 'package:flutter_bloc/flutter_bloc.dart';

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
    if (isClosed || state.status != DisputeStatusViewStatus.initial) return;
    if (disputeId.trim().isEmpty) {
      emit(
        state.copyWith(
          status: DisputeStatusViewStatus.failed,
          error: DisputeStatusFailure.notFound,
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

  Future<void> _fetch(int generation) async {
    try {
      final dispute = await _repository.fetchDispute(disputeId);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: DisputeStatusViewStatus.loaded,
          dispute: dispute,
          clearError: true,
        ),
      );
    } on DisputeStatusRepositoryException catch (e) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: DisputeStatusViewStatus.failed,
          error: e.failure,
        ),
      );
    } catch (_) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: DisputeStatusViewStatus.failed,
          error: DisputeStatusFailure.unknown,
        ),
      );
    }
  }
}
