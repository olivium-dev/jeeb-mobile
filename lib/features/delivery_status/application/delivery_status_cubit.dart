import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/delivery_snapshot.dart';
import '../domain/delivery_status_gateway.dart';
import 'delivery_status_state.dart';

/// Drives the delivery status screen.
///
/// Subscribes to [DeliveryStatusGateway.watch] for live updates and
/// translates user-initiated actions (cancel, contact) into gateway calls +
/// one-shot UI surfaces. The cubit is intentionally thin — all happy-path
/// branching lives on the snapshot itself (`isInFlight`, `canCancel`,
/// `isEtaVisible`), so the view never has to reason about lifecycle rules.
class DeliveryStatusCubit extends Cubit<DeliveryStatusState> {
  DeliveryStatusCubit({
    required this.deliveryId,
    required DeliveryStatusGateway gateway,
  })  : _gateway = gateway,
        super(const DeliveryStatusState()) {
    _subscribe();
  }

  /// The id the cubit is bound to. Exposed so the view can use it as a key
  /// when navigating between deliveries.
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
        // Stream closing while the delivery is still in flight is a
        // transport-level failure — flip to error so the view can offer a
        // retry. A clean close on a terminal snapshot is fine.
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

  /// User tapped retry after a stream failure. Re-subscribes and flips the
  /// view back to its loading state until the first snapshot lands.
  void retry() {
    emit(state.copyWith(
      mode: DeliveryStatusViewMode.loading,
      clearError: true,
    ));
    _subscribe();
  }

  /// User tapped Cancel. Honours [DeliverySnapshot.canCancel] so a stale
  /// button tap (race between the courier picking up and the user tapping)
  /// surfaces the same toast the gateway would have returned.
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
        // The terminal snapshot will arrive via the watch stream.
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

  /// User tapped Contact Jeeber. The cubit only surfaces the
  /// `contactUnavailable` error — the actual `tel:` launch is the view's
  /// responsibility (kept there so this layer stays platform-agnostic and
  /// trivially testable).
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
