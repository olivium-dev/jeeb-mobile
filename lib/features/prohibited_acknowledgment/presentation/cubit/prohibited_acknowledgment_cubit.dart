import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/app_failure.dart';
import '../../domain/prohibited_acknowledgment_repository.dart';
import 'prohibited_acknowledgment_state.dart';

class ProhibitedAcknowledgmentCubit
    extends Cubit<ProhibitedAcknowledgmentState> {
  ProhibitedAcknowledgmentCubit({
    required ProhibitedAcknowledgmentRepository repository,
    List<String> matches = const <String>[],
  })  : _repository = repository,
        super(ProhibitedAcknowledgmentState(matches: matches));

  final ProhibitedAcknowledgmentRepository _repository;

  Future<void> load() async {
    if (state.isLoading) return;
    emit(state.copyWith(
      status: ProhibitedAckStatus.loading,
      clearFailure: true,
    ));
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
    } catch (e) {
      emit(state.copyWith(
        status: ProhibitedAckStatus.error,
        failure: AppFailure.of(e),
      ));
    }
  }

  Future<void> acknowledge() async {
    if (state.status != ProhibitedAckStatus.loaded &&
        state.status != ProhibitedAckStatus.acknowledgeFailed) {
      return;
    }
    emit(state.copyWith(
      status: ProhibitedAckStatus.acknowledging,
      clearFailure: true,
    ));
    try {
      await _repository.acknowledge();
      await _repository.saveLocalAcknowledgment();
      emit(state.copyWith(status: ProhibitedAckStatus.acknowledged));
    } catch (e) {
      // Never latch locally on a failed server ack, or the user is never asked
      // again and the server never recorded it (F4).
      emit(state.copyWith(
        status: ProhibitedAckStatus.acknowledgeFailed,
        failure: AppFailure.of(e),
      ));
    }
  }
}
