import 'package:flutter_bloc/flutter_bloc.dart';

class MaskedCallState {

  const MaskedCallState({
    this.isLoading = false,
    this.sessionId,
    this.error,
  });
  final bool isLoading;
  final String? sessionId;
  final String? error;

  MaskedCallState copyWith({
    bool? isLoading,
    String? sessionId,
    String? error,
  }) {
    return MaskedCallState(
      isLoading: isLoading ?? this.isLoading,
      sessionId: sessionId ?? this.sessionId,
      error: error,
    );
  }
}

class MaskedCallCubit extends Cubit<MaskedCallState> {
  MaskedCallCubit() : super(const MaskedCallState());

  Future<void> initiateCall(String orderId) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await Future.delayed(const Duration(seconds: 1));
      emit(state.copyWith(
        isLoading: false,
        sessionId: 'session-$orderId',
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to initiate call: $e',
      ));
    }
  }
}
