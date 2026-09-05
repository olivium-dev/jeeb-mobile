import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../domain/masked_call_repository.dart';

class MaskedCallState {
  const MaskedCallState({
    this.isLoading = false,
    this.sessionId,
    this.failed = false,
    this.failure,
  });

  final bool isLoading;
  final String? sessionId;

  /// Typed failure flag. The presentation layer maps this to a localized
  /// message; the raw exception is never surfaced to the UI.
  final bool failed;

  final AppFailure? failure;

  MaskedCallState copyWith({
    bool? isLoading,
    String? sessionId,
    bool? failed,
    AppFailure? failure,
    bool clearFailed = false,
  }) {
    return MaskedCallState(
      isLoading: isLoading ?? this.isLoading,
      sessionId: sessionId ?? this.sessionId,
      // `failed ?? false` erased the flag on every copyWith that omitted it,
      // so the snack could never be read by a rebuild.
      failed: clearFailed ? false : (failed ?? this.failed),
      failure: clearFailed ? null : (failure ?? this.failure),
    );
  }
}

class MaskedCallCubit extends Cubit<MaskedCallState> {
  MaskedCallCubit({MaskedCallRepository? repository})
      : _repository = repository,
        super(const MaskedCallState());

  final MaskedCallRepository? _repository;

  Future<void> initiateCall(String orderId) async {
    if (state.isLoading) return;
    final repository = _repository;
    // No repository is an honest "unavailable" — the old 1-second delay
    // fabricated a session id for a call nobody ever placed.
    if (repository == null) {
      emit(state.copyWith(isLoading: false, failed: true));
      return;
    }
    emit(state.copyWith(isLoading: true, clearFailed: true));
    try {
      final sessionId = await repository.startCall(orderId: orderId);
      emit(state.copyWith(isLoading: false, sessionId: sessionId));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        failed: true,
        failure: AppFailure.of(e),
      ));
    }
  }

  void acknowledgeFailure() => emit(state.copyWith(clearFailed: true));
}
