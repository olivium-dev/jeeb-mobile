import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/cancel_request_repository.dart';
import 'cancel_request_state.dart';

class CancelRequestCubit extends Cubit<CancelRequestState> {
  CancelRequestCubit({
    required CancelRequestRepository repository,
    required String requestId,
    CancelRequestState? initialState,
  })  : _repository = repository,
        _requestId = requestId,
        super(initialState ?? const CancelRequestState());

  final CancelRequestRepository _repository;
  final String _requestId;

  Future<void> confirmCancel() async {
    if (state.isInFlight) return;
    emit(state.copyWith(status: CancelRequestStatus.inFlight, clearError: true));
    try {
      await _repository.cancelRequest(requestId: _requestId);
      emit(state.copyWith(status: CancelRequestStatus.succeeded));
    } on CancelRequestException catch (e) {
      emit(state.copyWith(status: CancelRequestStatus.failed, error: e.failure));
    } catch (_) {
      emit(state.copyWith(
        status: CancelRequestStatus.failed,
        error: CancelRequestFailure.unknown,
      ));
    }
  }

  void acknowledgeError() => emit(state.copyWith(clearError: true));
}
