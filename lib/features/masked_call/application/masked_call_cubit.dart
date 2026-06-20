import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/masked_call_repository.dart';
import '../domain/phone_dialer.dart';

/// View state for the masked-call action (orders-masked-call).
class MaskedCallState {
  const MaskedCallState({
    this.isLoading = false,
    this.session,
    this.error,
  });

  final bool isLoading;
  final MaskedCallSession? session;

  /// Localization key for a failure (`maskedCallError*`), or null.
  final String? error;

  MaskedCallState copyWith({
    bool? isLoading,
    MaskedCallSession? session,
    String? error,
  }) {
    return MaskedCallState(
      isLoading: isLoading ?? this.isLoading,
      session: session ?? this.session,
      error: error,
    );
  }
}

/// Cubit driving the masked / anonymised call (orders-masked-call).
///
/// Flow: tap → request a masked-call session from the gateway → open the native
/// dialer pre-filled with the returned proxy number. The user dials; the
/// carrier bridge connects the two real numbers behind the proxy so neither
/// party sees the other's number.
///
/// The previous shell was a `Future.delayed(1s)` then a fabricated
/// `session-$orderId` with no telephony, no gateway session, no dial.
class MaskedCallCubit extends Cubit<MaskedCallState> {
  MaskedCallCubit({
    required MaskedCallRepository repository,
    required PhoneDialer dialer,
  })  : _repository = repository,
        _dialer = dialer,
        super(const MaskedCallState());

  final MaskedCallRepository _repository;
  final PhoneDialer _dialer;

  Future<void> initiateCall(String orderId) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final session = await _repository.requestSession(orderId: orderId);
      final dialed = await _dialer.dial(session.proxyNumber);
      if (!dialed) {
        emit(state.copyWith(
          isLoading: false,
          session: session,
          error: 'maskedCallErrorDialer',
        ));
        return;
      }
      emit(state.copyWith(isLoading: false, session: session));
    } on MaskedCallException catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.failure == MaskedCallFailure.network
            ? 'maskedCallErrorNetwork'
            : 'maskedCallErrorUnavailable',
      ));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        error: 'maskedCallErrorUnavailable',
      ));
    }
  }
}
