import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';

/// View-mode enum for the active-delivery Jeeber screen.
enum ActiveDeliveryMode { loading, ready, transitioning, error }

/// State emitted by [ActiveDeliveryCubit].
class ActiveDeliveryState extends Equatable {
  const ActiveDeliveryState({
    this.mode = ActiveDeliveryMode.loading,
    this.delivery,
    this.transitionError,
    this.errorMessage,
  });

  final ActiveDeliveryMode mode;
  final JeeberDelivery? delivery;

  /// One-shot snack error after a failed transition (reverted).
  final String? transitionError;

  /// Full-screen error message on load failure.
  final String? errorMessage;

  bool get isTransitioning => mode == ActiveDeliveryMode.transitioning;

  ActiveDeliveryState copyWith({
    ActiveDeliveryMode? mode,
    JeeberDelivery? delivery,
    String? transitionError,
    bool clearTransitionError = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ActiveDeliveryState(
      mode: mode ?? this.mode,
      delivery: delivery ?? this.delivery,
      transitionError: clearTransitionError
          ? null
          : (transitionError ?? this.transitionError),
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [mode, delivery, transitionError, errorMessage];
}

/// Drives the Jeeber active-delivery screen (T-MOB-031).
///
/// Loads the delivery snapshot from [ActiveDeliveryRepository] and allows
/// the Jeeber to advance the status by calling [advanceStatus]. Each
/// transition logs `delivery.status_transition` with from/to (AC7).
class ActiveDeliveryCubit extends Cubit<ActiveDeliveryState> {
  ActiveDeliveryCubit({
    required ActiveDeliveryRepository repository,
    required this.deliveryId,
  })  : _repository = repository,
        super(const ActiveDeliveryState());

  final ActiveDeliveryRepository _repository;
  final String deliveryId;

  Future<void> loadDelivery() async {
    emit(state.copyWith(mode: ActiveDeliveryMode.loading, clearError: true));
    try {
      final delivery = await _repository.fetchDelivery(deliveryId);
      emit(state.copyWith(mode: ActiveDeliveryMode.ready, delivery: delivery));
    } on ActiveDeliveryException catch (e) {
      emit(state.copyWith(
        mode: ActiveDeliveryMode.error,
        errorMessage: _mapLoadError(e),
      ));
    }
  }

  /// Advance status to the next valid stage.
  ///
  /// Emits transitioning immediately (optimistic UI), then either confirms
  /// on success or reverts + sets [transitionError] on failure.
  Future<void> advanceStatus() async {
    final current = state.delivery;
    if (current == null) return;
    final nextStatus = current.status.next;
    if (nextStatus == null) return;
    if (state.isTransitioning) return;

    final optimistic = _withStatus(current, nextStatus);
    emit(state.copyWith(
      mode: ActiveDeliveryMode.transitioning,
      delivery: optimistic,
      clearTransitionError: true,
    ));

    try {
      final confirmed = await _repository.transition(
        deliveryId: deliveryId,
        from: current.status,
        to: nextStatus,
      );
      _logTransition(current.status, confirmed);
      final confirmedDelivery = _withStatus(current, confirmed);
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: confirmedDelivery,
      ));
    } on ActiveDeliveryException catch (e) {
      // Revert
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: current,
        transitionError: _mapTransitionError(e),
      ));
    }
  }

  void acknowledgeTransitionError() {
    emit(state.copyWith(clearTransitionError: true));
  }

  JeeberDelivery _withStatus(JeeberDelivery d, JeeberDeliveryStatus s) {
    return JeeberDelivery(
      id: d.id,
      status: s,
      dropOff: d.dropOff,
      clientName: d.clientName,
      conversationId: d.conversationId,
    );
  }

  String _mapLoadError(ActiveDeliveryException e) {
    if (e.failure == ActiveDeliveryFailure.network) {
      return 'No internet connection';
    }
    if (e.failure == ActiveDeliveryFailure.notFound) {
      return 'Delivery not found';
    }
    return 'Unable to load delivery';
  }

  String _mapTransitionError(ActiveDeliveryException e) {
    if (e.failure == ActiveDeliveryFailure.invalidTransition) {
      return 'That transition is not allowed';
    }
    if (e.failure == ActiveDeliveryFailure.network) {
      return 'No internet connection';
    }
    return 'Unable to update status';
  }

  // AC7: delivery.status_transition log
  // ignore: avoid_print
  void _logTransition(JeeberDeliveryStatus from, JeeberDeliveryStatus to) {
    // ignore: avoid_print
    print('[delivery.status_transition] from=${from.apiValue} to=${to.apiValue}');
  }
}
