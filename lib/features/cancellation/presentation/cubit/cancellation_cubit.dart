import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/cancellation_repository.dart';
import 'cancellation_state.dart';

/// Drives the cancellation reason-picker + submission flow (T-MOB-024).
///
/// Lifecycle:
///   [CancellationIdle] → user fills form → [submit] →
///   [CancellationLoading] → 200 → [CancellationSuccess]
///                         → 429 → [CancellationRateLimited]
///                         → 409 → [CancellationTooLate]
///                         → 5xx → [CancellationError]
class CancellationCubit extends Cubit<CancellationState> {
  CancellationCubit(this._repository) : super(const CancellationIdle());

  final CancellationRepository _repository;

  /// Submits cancellation. [reason] must be non-empty; [otherDetails]
  /// is only relevant when [reason] == 'other'.
  Future<void> submit({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async {
    if (state is CancellationLoading) return;
    emit(const CancellationLoading());
    try {
      final result = await _repository.cancel(
        deliveryId: deliveryId,
        reason: reason,
        otherDetails: otherDetails,
      );
      emit(CancellationSuccess(result));
    } on CancellationRateLimitException catch (e) {
      emit(CancellationRateLimited(retryAfter: e.retryAfter));
    } on CancellationTooLateException {
      emit(const CancellationTooLate());
    } on CancellationException catch (e) {
      emit(CancellationError(e.message));
    } catch (_) {
      emit(const CancellationError());
    }
  }

  /// Resets to idle so the user can retry after an error.
  void reset() => emit(const CancellationIdle());
}
