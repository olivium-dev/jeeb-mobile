import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/prohibited_acknowledgment_repository.dart';
import 'prohibited_acknowledgment_state.dart';

class ProhibitedAcknowledgmentCubit
    extends Cubit<ProhibitedAcknowledgmentState> {
  ProhibitedAcknowledgmentCubit({
    required ProhibitedAcknowledgmentRepository repository,
  })  : _repository = repository,
        super(const ProhibitedAcknowledgmentState());

  final ProhibitedAcknowledgmentRepository _repository;

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

  Future<void> acknowledge() async {
    if (state.status != ProhibitedAckStatus.loaded) return;
    emit(state.copyWith(status: ProhibitedAckStatus.acknowledging));
    try {
      await _repository.acknowledge();
      await _repository.saveLocalAcknowledgment();
      emit(state.copyWith(status: ProhibitedAckStatus.acknowledged));
    } catch (_) {
      await _repository.saveLocalAcknowledgment();
      emit(state.copyWith(status: ProhibitedAckStatus.acknowledged));
    }
  }
}
