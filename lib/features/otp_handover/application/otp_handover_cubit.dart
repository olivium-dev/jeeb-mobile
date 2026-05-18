import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/otp_handover_repository.dart';
import 'otp_handover_state.dart';

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
      emit(state.copyWith(
        mode: OtpHandoverViewMode.error,
        errorMessage: _mapError(e.kind),
      ));
    }
  }

  Future<void> submitOtp(String otp) async {
    if (state.mode == OtpHandoverViewMode.submitting) return;
    emit(state.copyWith(mode: OtpHandoverViewMode.submitting, clearError: true));
    try {
      await _repository.submitOtp(deliveryId: deliveryId, otp: otp);
      emit(state.copyWith(mode: OtpHandoverViewMode.success));
    } on OtpHandoverException catch (e) {
      emit(state.copyWith(
        mode: OtpHandoverViewMode.ready,
        errorMessage: _mapError(e.kind),
      ));
    }
  }

  void retry() {
    if (isClient) {
      _loadHandoverCode();
    } else {
      emit(state.copyWith(mode: OtpHandoverViewMode.ready, clearError: true));
    }
  }

  String _mapError(OtpHandoverErrorKind kind) {
    switch (kind) {
      case OtpHandoverErrorKind.network:
        return 'Unable to connect. Check your internet.';
      case OtpHandoverErrorKind.server:
        return 'Server error. Please try again.';
      case OtpHandoverErrorKind.invalidOtp:
        return 'Invalid OTP. Please check and try again.';
      case OtpHandoverErrorKind.parse:
        return 'Unexpected response.';
    }
  }
}
