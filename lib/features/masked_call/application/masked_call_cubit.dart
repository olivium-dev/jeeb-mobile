import 'package:flutter_bloc/flutter_bloc.dart';

class MaskedCallState {

  const MaskedCallState({
    this.isLoading = false,
    this.sessionId,
    this.failed = false,
  });
  final bool isLoading;
  final String? sessionId;

  /// Typed failure flag. The presentation layer maps this to a localized
  /// message; the raw exception is never surfaced to the UI.
  final bool failed;

  MaskedCallState copyWith({
    bool? isLoading,
    String? sessionId,
    bool? failed,
  }) {
    return MaskedCallState(
      isLoading: isLoading ?? this.isLoading,
      sessionId: sessionId ?? this.sessionId,
      failed: failed ?? false,
    );
  }
}

class MaskedCallCubit extends Cubit<MaskedCallState> {
  MaskedCallCubit() : super(const MaskedCallState());

  Future<void> initiateCall(String orderId) async {
    emit(state.copyWith(isLoading: true));
    try {
      await Future.delayed(const Duration(seconds: 1));
      emit(state.copyWith(
        isLoading: false,
        sessionId: 'session-$orderId',
      ));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        failed: true,
      ));
    }
  }
}
