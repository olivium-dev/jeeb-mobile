import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/cancel_request_repository.dart';
import 'cancel_request_state.dart';

/// Owns the JM-030 pre-accept cancel action (D69).
///
/// Receives the abstract [CancelRequestRepository] by constructor injection
/// (no `sl`, no `data/` import — 40_GUARDRAILS_ARCH §2). Confirming maps a
/// hard network failure to a transient `failed` state (sheet stays open);
/// the soft `unknown` failure still resolves to `succeeded`, because the
/// pre-accept cancel is free and locally authoritative (the request is
/// released from the client's perspective regardless of a soft server hiccup).
class CancelRequestCubit extends Cubit<CancelRequestState> {
  CancelRequestCubit({
    required CancelRequestRepository repository,
    required String requestId,
  })  : _repository = repository,
        _requestId = requestId,
        super(const CancelRequestState());

  final CancelRequestRepository _repository;
  final String _requestId;

  /// Confirm the cancel. Re-entrancy-guarded so a double-tap fires once.
  Future<void> confirmCancel() async {
    if (state.isInFlight) return;
    emit(state.copyWith(status: CancelRequestStatus.inFlight, clearError: true));
    try {
      await _repository.cancelRequest(requestId: _requestId);
      emit(state.copyWith(status: CancelRequestStatus.succeeded));
    } on CancelRequestException catch (e) {
      if (e.failure == CancelRequestFailure.network) {
        // Cannot confirm the request was released — keep the sheet open.
        emit(state.copyWith(status: CancelRequestStatus.failed, error: e.failure));
      } else {
        // Soft failure: the pre-accept cancel is free + client-authoritative
        // (D69), so the flow still completes.
        emit(state.copyWith(status: CancelRequestStatus.succeeded));
      }
    } catch (_) {
      emit(state.copyWith(status: CancelRequestStatus.succeeded));
    }
  }

  /// Dismiss a transient error banner without retrying.
  void acknowledgeError() => emit(state.copyWith(clearError: true));
}
