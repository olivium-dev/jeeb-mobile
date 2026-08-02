import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/handover_code_store.dart';
import '../domain/otp_handover_repository.dart';
import 'otp_handover_state.dart';

class OtpHandoverCubit extends Cubit<OtpHandoverState> {
  OtpHandoverCubit({
    required OtpHandoverRepository repository,
    required this.deliveryId,
    required this.isClient,
    HandoverCodeStore? codeStore,
  })  : _repository = repository,
        _codeStore = codeStore,
        super(const OtpHandoverState()) {
    if (isClient) {
      _loadHandoverCode();
    } else {
      emit(state.copyWith(mode: OtpHandoverViewMode.ready));
    }
  }

  final OtpHandoverRepository _repository;
  final HandoverCodeStore? _codeStore;
  final String deliveryId;
  final bool isClient;

  Future<void> _loadHandoverCode() async {
    emit(state.copyWith(mode: OtpHandoverViewMode.loading, clearError: true));
    final stored = await _readStoredCode();
    if (isClosed) return;
    if (stored != null) {
      emit(state.copyWith(
        mode: OtpHandoverViewMode.ready,
        handoverCode: stored,
      ));
      return;
    }
    await _fetchFromGateway();
  }

  Future<void> _fetchFromGateway() async {
    try {
      final result =
          await _repository.fetchHandoverCode(deliveryId: deliveryId);
      if (isClosed) return;
      final code = result.code;
      if (code != null && code.isNotEmpty) {
        unawaited(
          _codeStore
              ?.save(deliveryId: deliveryId, code: code)
              .catchError((_) {}),
        );
        emit(state.copyWith(
          mode: OtpHandoverViewMode.ready,
          handoverCode: code,
          smsSent: result.smsTriggered,
        ));
        return;
      }
      emit(state.copyWith(
        mode: OtpHandoverViewMode.ready,
        smsSent: true,
        clearError: true,
      ));
    } on OtpHandoverException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        mode: OtpHandoverViewMode.error,
        errorMessage: _mapError(e.kind),
      ));
    }
  }

  Future<void> resendSms() async {
    if (!isClient) return;
    if (state.mode == OtpHandoverViewMode.loading) return;
    emit(state.copyWith(mode: OtpHandoverViewMode.loading, clearError: true));
    await _fetchFromGateway();
  }

  Future<String?> _readStoredCode() async {
    final store = _codeStore;
    if (store == null) return null;
    try {
      return await store.read(deliveryId: deliveryId);
    } catch (_) {
      // A broken prefs read must never dead-end the screen — fall through to
      return null;
    }
  }

  Future<void> submitOtp(String otp) async {
    if (state.mode == OtpHandoverViewMode.submitting) return;
    if (state.escalate) return;
    emit(state.copyWith(mode: OtpHandoverViewMode.submitting, clearError: true));
    try {
      await _repository.submitOtp(deliveryId: deliveryId, otp: otp);
      unawaited(_codeStore?.clear(deliveryId: deliveryId).catchError((_) {}));
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
