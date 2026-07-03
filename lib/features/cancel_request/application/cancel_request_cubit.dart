import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/cancel_request_repository.dart';
import 'cancel_request_state.dart';

/// Owns the JM-030 pre-accept cancel action (D69).
///
/// Receives the abstract [CancelRequestRepository] by constructor injection
/// (no `sl`, no `data/` import — 40_GUARDRAILS_ARCH §2).
///
/// sprint-009 cycle-4: `succeeded` is emitted ONLY when the repository
/// confirmed the server released the request. Every failure — network,
/// 409 conflict, 404, 403, unknown — lands in `failed` with its typed
/// [CancelRequestFailure] so the sheet can show the right copy and keep the
/// request visible. The old behaviour (soft failures silently upgraded to
/// success while the server still had the request live) was the P0
/// "cancellations never reach the server" bug.
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
      // NO swallowing: a cancel the server did not confirm is a failure,
      // whatever its shape. The sheet stays open and surfaces typed copy.
      emit(state.copyWith(status: CancelRequestStatus.failed, error: e.failure));
    } catch (_) {
      emit(state.copyWith(
        status: CancelRequestStatus.failed,
        error: CancelRequestFailure.unknown,
      ));
    }
  }

  /// Dismiss a transient error banner without retrying.
  void acknowledgeError() => emit(state.copyWith(clearError: true));
}
