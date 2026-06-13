import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/prohibited_acknowledgment_repository.dart';
import 'prohibited_acknowledgment_state.dart';

/// Drives the one-time prohibited-items acknowledgment dialog (T-MOB-021).
///
/// Lifecycle: initial → loading → loaded → acknowledging → acknowledged
///                                       ↘ error (with retry via [load])
class ProhibitedAcknowledgmentCubit
    extends Cubit<ProhibitedAcknowledgmentState> {
  ProhibitedAcknowledgmentCubit({
    required ProhibitedAcknowledgmentRepository repository,
  })  : _repository = repository,
        super(const ProhibitedAcknowledgmentState());

  final ProhibitedAcknowledgmentRepository _repository;

  /// Checks if already acknowledged, then fetches the catalog.
  Future<void> load() async {
    emit(state.copyWith(status: ProhibitedAckStatus.loading));
    try {
      final alreadyAcked = await _repository.hasAcknowledged();
      if (alreadyAcked) {
        emit(state.copyWith(status: ProhibitedAckStatus.acknowledged));
        return;
      }
      final items = await _repository.fetchItems();
      emit(state.copyWith(
        status: ProhibitedAckStatus.loaded,
        items: items,
      ));
    } catch (_) {
      emit(state.copyWith(status: ProhibitedAckStatus.error));
    }
  }

  /// Records the acknowledgment both locally and on the server.
  Future<void> acknowledge() async {
    if (state.status != ProhibitedAckStatus.loaded) return;
    emit(state.copyWith(status: ProhibitedAckStatus.acknowledging));
    try {
      await _repository.acknowledge();
      await _repository.saveLocalAcknowledgment();
      emit(state.copyWith(status: ProhibitedAckStatus.acknowledged));
    } catch (_) {
      // Server error: persist locally so the dialog doesn't show again,
      // but don't block the user (AC2 — when call returns 200 dismiss).
      await _repository.saveLocalAcknowledgment();
      emit(state.copyWith(status: ProhibitedAckStatus.acknowledged));
    }
  }
}
