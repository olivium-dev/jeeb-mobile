import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/otp_handover_repository.dart';
import 'otp_handover_state.dart';

/// T-MOB-018: Manages client OTP display and Jeeber OTP entry flow.
///
/// AC2: success → emits `OtpHandoverViewMode.success`.
/// AC3: wrong code → increments `wrongAttempts`, increments `shakeKey`.
/// AC4: 3rd wrong code (or 423 locked) → sets `escalate = true`.
class OtpHandoverCubit extends Cubit<OtpHandoverState> {
  OtpHandoverCubit({
    required OtpHandoverRepository repository,
    required this.deliveryId,
    required this.isClient,
  })  : _repository = repository,
        super(const OtpHandoverState()) {
    if (isClient) {
      _loadHandoverCode();
    } else {
      emit(state.copyWith(mode: OtpHandoverViewMode.ready));
    }
  }

  final OtpHandoverRepository _repository;
  final String deliveryId;
  final bool isClient;

  Future<void> _loadHandoverCode() async {
    emit(state.copyWith(mode: OtpHandoverViewMode.loading, clearError: true));
    try {
      final code =
          await _repository.fetchHandoverCode(deliveryId: deliveryId);
      emit(state.copyWith(
        mode: OtpHandoverViewMode.ready,
        handoverCode: code,
      ));
    } on OtpHandoverException catch (e) {
      // iter6 OTP-phone v2: the LIVE gateway `GET /v1/deliveries/{id}/otp` does
      // NOT return a `code` field (it returns {deliveryId, triggered, message}),
      // so the client has nothing to DISPLAY. Rather than dead-end on a generic
      // "Something went wrong", let the client ENTER the code (server-validated)
      // and submit verify — the handover still completes. A genuine network
      // fault still surfaces the retryable error.
      if (e.kind == OtpHandoverErrorKind.parse ||
          e.kind == OtpHandoverErrorKind.server) {
        emit(state.copyWith(
          mode: OtpHandoverViewMode.ready,
          allowManualEntry: true,
          clearError: true,
        ));
        return;
      }
      emit(state.copyWith(
        mode: OtpHandoverViewMode.error,
        errorMessage: _mapError(e.kind),
      ));
    }
  }

  Future<void> submitOtp(String otp) async {
    if (state.mode == OtpHandoverViewMode.submitting) return;
    if (state.escalate) return;
    emit(state.copyWith(mode: OtpHandoverViewMode.submitting, clearError: true));
    try {
      await _repository.submitOtp(deliveryId: deliveryId, otp: otp);
      emit(state.copyWith(mode: OtpHandoverViewMode.success));
    } on OtpHandoverException catch (e) {
      _handleSubmitError(e);
    }
  }

  void _handleSubmitError(OtpHandoverException e) {
    if (e.kind == OtpHandoverErrorKind.invalidOtp) {
      _incrementWrongAttempts();
      return;
    }
    if (e.kind == OtpHandoverErrorKind.locked) {
      emit(state.copyWith(
        mode: OtpHandoverViewMode.ready,
        escalate: true,
        errorMessage: _mapError(e.kind),
      ));
      return;
    }
    emit(state.copyWith(
      mode: OtpHandoverViewMode.ready,
      errorMessage: _mapError(e.kind),
    ));
  }

  void _incrementWrongAttempts() {
    final next = state.wrongAttempts + 1;
    final shouldEscalate = next >= OtpHandoverState.maxAttempts;
    emit(state.copyWith(
      mode: OtpHandoverViewMode.ready,
      wrongAttempts: next,
      shakeKey: state.shakeKey + 1,
      errorMessage: _mapError(OtpHandoverErrorKind.invalidOtp),
      escalate: shouldEscalate,
    ));
  }

  void retry() {
    if (isClient) {
      _loadHandoverCode();
    } else {
      emit(state.copyWith(mode: OtpHandoverViewMode.ready, clearError: true));
    }
  }

  void dismissEscalate() {
    emit(state.copyWith(escalate: false, clearError: true));
  }

  String _mapError(OtpHandoverErrorKind kind) {
    switch (kind) {
      case OtpHandoverErrorKind.network:
        return 'network';
      case OtpHandoverErrorKind.server:
        return 'server';
      case OtpHandoverErrorKind.invalidOtp:
        return 'invalid_otp';
      case OtpHandoverErrorKind.locked:
        return 'locked';
      case OtpHandoverErrorKind.parse:
        return 'parse';
    }
  }
}
