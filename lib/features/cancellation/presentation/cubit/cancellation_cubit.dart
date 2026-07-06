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
  // DT-04 screen-catalog / test seam: [initialState] presets a non-idle start
  // (e.g. [CancellationLoading]) so a designed state can be previewed without
  // driving the real async submit. Null (default) keeps production
  // behaviour — the cubit starts idle exactly as before.
  CancellationCubit(this._repository, {CancellationState? initialState})
      : super(initialState ?? const CancellationIdle());

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
