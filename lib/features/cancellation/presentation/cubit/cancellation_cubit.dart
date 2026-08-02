import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/cancellation_repository.dart';
import 'cancellation_state.dart';

/// Lifecycle: Idle → submit → Loading → Success/TooLate/Error.
class CancellationCubit extends Cubit<CancellationState> {
  /// [initialState] presets a state for screen-catalog preview (DT-04).
  CancellationCubit(this._repository, {CancellationState? initialState})
      : super(initialState ?? const CancellationIdle());

  final CancellationRepository _repository;

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
    } on CancellationTooLateException {
      emit(const CancellationTooLate());
    } on CancellationException catch (e) {
      emit(CancellationError(e.message));
    } catch (_) {
      emit(const CancellationError());
    }
  }

  void reset() => emit(const CancellationIdle());
}
