import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/delivery_snapshot.dart';
import '../domain/delivery_status_gateway.dart';
import 'delivery_status_state.dart';

class DeliveryStatusCubit extends Cubit<DeliveryStatusState> {
  DeliveryStatusCubit({
    required this.deliveryId,
    required DeliveryStatusGateway gateway,
  })  : _gateway = gateway,
        super(const DeliveryStatusState()) {
    _subscribe();
  }

  final String deliveryId;

  final DeliveryStatusGateway _gateway;

  StreamSubscription<DeliverySnapshot>? _subscription;

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _gateway.watch(deliveryId).listen(
      (snapshot) {
        emit(state.copyWith(
          mode: DeliveryStatusViewMode.ready,
          snapshot: snapshot,
          clearError: true,
        ));
      },
      onError: (_) {
        emit(state.copyWith(
          mode: DeliveryStatusViewMode.error,
          error: DeliveryStatusError.streamLost,
        ));
      },
      onDone: () {
        // Stream closing mid-flight = transport failure.
        final current = state.snapshot;
        final inFlight = current?.isInFlight ?? false;
        if (inFlight) {
          emit(state.copyWith(
            mode: DeliveryStatusViewMode.error,
            error: DeliveryStatusError.streamLost,
          ));
        }
      },
    );
  }

  void retry() {
    emit(state.copyWith(
      mode: DeliveryStatusViewMode.loading,
      clearError: true,
    ));
    _subscribe();
  }

  /// Honors canCancel to handle race (courier picked up while user tapping).
  Future<void> cancel() async {
    if (state.isCancelling) return;
    final snapshot = state.snapshot;
    if (snapshot == null || !snapshot.canCancel) {
      emit(state.copyWith(error: DeliveryStatusError.cancelTooLate));
      return;
    }
    emit(state.copyWith(isCancelling: true, clearError: true));
    final outcome = await _gateway.cancel(deliveryId);
    switch (outcome) {
      case CancellationOutcome.success:
        emit(state.copyWith(isCancelling: false));
      case CancellationOutcome.tooLate:
        emit(state.copyWith(
          isCancelling: false,
          error: DeliveryStatusError.cancelTooLate,
        ));
      case CancellationOutcome.networkError:
        emit(state.copyWith(
          isCancelling: false,
          error: DeliveryStatusError.cancelNetwork,
        ));
    }
  }

  /// Only surfaces contactUnavailable error; tel: launch is view's responsibility.
  String? requestContactNumber() {
    final snapshot = state.snapshot;
    if (snapshot == null || !snapshot.canContactJeeber) {
      emit(state.copyWith(error: DeliveryStatusError.contactUnavailable));
      return null;
    }
    return snapshot.jeeber!.phoneE164;
  }

  void acknowledgeError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
