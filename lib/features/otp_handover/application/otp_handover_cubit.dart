import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../live_tracking/domain/delivery_tracking_info.dart';
import '../../live_tracking/domain/live_tracking_repository.dart';
import '../domain/handover_arrival.dart';
import '../domain/handover_code_store.dart';
import '../domain/otp_handover_repository.dart';
import 'otp_handover_state.dart';

/// T-MOB-018: Manages client OTP display and Jeeber OTP entry flow.
///
/// AC2: success → emits `OtpHandoverViewMode.success`.
/// AC3: wrong code → increments `wrongAttempts`, increments `shakeKey`.
/// AC4: 3rd wrong code (or 423 locked) → sets `escalate = true`.
///
/// G4 (sprint-009 P0) client-code sourcing, in priority order:
///   1. [HandoverCodeStore] — the code persisted at offer-accept time (the
///      only wire moment the gateway hands it to the customer). Survives app
///      restarts; costs no network call and triggers no SMS.
///   2. `GET /v1/deliveries/{id}/otp` — reached only on a store miss (e.g.
///      app reinstalled mid-delivery). On the live gateway this TRIGGERS an
///      SMS to the recipient and returns no code; the state then carries
///      `smsSent` so the UI says exactly that. The customer is NEVER flipped
///      into a code-entry grid (the removed `allowManualEntry` dead end).
class OtpHandoverCubit extends Cubit<OtpHandoverState> {
  OtpHandoverCubit({
    required OtpHandoverRepository repository,
    required this.deliveryId,
    required this.isClient,
    HandoverCodeStore? codeStore,
    LiveTrackingRepository? deliveryInfo,
  })  : _repository = repository,
        _codeStore = codeStore,
        _deliveryInfo = deliveryInfo,
        super(const OtpHandoverState()) {
    if (isClient) {
      _loadHandoverCode();
      // Parallel and fire-and-forget on purpose: the banner must never delay
      // the code by one frame, and a tracking outage must never blank it.
      if (deliveryInfo != null) unawaited(_loadArrival());
    } else {
      emit(state.copyWith(mode: OtpHandoverViewMode.ready));
    }
  }

  final OtpHandoverRepository _repository;
  final HandoverCodeStore? _codeStore;

  /// Screen 13's best-effort arrival read. Optional: every call site that does
  /// not pass one simply renders no banner.
  final LiveTrackingRepository? _deliveryInfo;
  final String deliveryId;
  final bool isClient;

  /// Reads `GET /v1/deliveries/{id}` for the banner's name / vehicle / cash /
  /// stage. Emits `arrival:` and nothing else — never [OtpHandoverState.mode],
  /// never an error — and swallows every failure.
  Future<void> _loadArrival() async {
    final repo = _deliveryInfo;
    if (repo == null) return;
    try {
      final info = await repo.fetchDeliveryStatus(deliveryId: deliveryId);
      if (isClosed) return;
      final jeeber = info.jeeber;
      // Honesty gate: past handover, both "at your door" and "on the way"
      // would be lies, so no banner is built at all.
      if (jeeber == null || info.currentStage == TrackingStage.delivered) {
        return;
      }
      emit(state.copyWith(
        arrival: HandoverArrival(
          name: jeeber.displayName,
          vehicleLabel: jeeber.vehicleLabel,
          atDoor: info.currentStage == TrackingStage.atDoor,
          cashAmount: info.price,
          currency: info.currency,
        ),
      ));
    } catch (_) {
      // Garnish, not content — a failed banner read is not a screen state.
    }
  }

  Future<void> _loadHandoverCode() async {
    emit(state.copyWith(mode: OtpHandoverViewMode.loading, clearError: true));
    // 1) Local-first: the accept-time code (persisted, restart-safe). No
    //    network, no SMS side effect.
    final stored = await _readStoredCode();
    if (isClosed) return;
    if (stored != null) {
      emit(state.copyWith(
        mode: OtpHandoverViewMode.ready,
        handoverCode: stored,
      ));
      return;
    }
    // 2) Store miss → ask the gateway. On the live contract this triggers the
    //    SMS to the recipient (an honest, user-visible outcome — not an error).
    await _fetchFromGateway();
  }

  Future<void> _fetchFromGateway() async {
    try {
      final result =
          await _repository.fetchHandoverCode(deliveryId: deliveryId);
      if (isClosed) return;
      final code = result.code;
      if (code != null && code.isNotEmpty) {
        // The gateway DID return a displayable code (mock/wave-11 shape).
        // Persist it so subsequent opens (and restarts) are local-only.
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
      // Live gateway shape: SMS triggered, nothing to display in-app.
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

  /// G4: user-initiated "Send the code again" — the SMS-fallback surface's
  /// resend and the code surface's "Send by SMS" link both land here. Re-hits
  /// the trigger endpoint (each call re-sends the SMS server-side).
  ///
  /// It runs on its own [OtpHandoverState.resending] axis and never touches
  /// [OtpHandoverState.mode]: emitting `loading` blanked the entire screen mid
  /// handover, and a failure then landed `error`, destroying a code the
  /// customer was reading off the screen. `mode` transitions belong to the
  /// initial load alone.
  Future<void> resendSms() async {
    if (!isClient || state.resending) return;
    emit(state.copyWith(resending: true, resendFailed: false));
    try {
      final result =
          await _repository.fetchHandoverCode(deliveryId: deliveryId);
      if (isClosed) return;
      final code = result.code;
      emit(state.copyWith(
        resending: false,
        // null keeps the existing code (copyWith's null-keeps semantics) —
        // the live gateway answers a trigger with no code at all.
        handoverCode: (code != null && code.isNotEmpty) ? code : null,
        smsSent: true,
      ));
    } on OtpHandoverException {
      if (isClosed) return;
      emit(state.copyWith(resending: false, resendFailed: true));
    }
  }

  Future<String?> _readStoredCode() async {
    final store = _codeStore;
    if (store == null) return null;
    try {
      return await store.read(deliveryId: deliveryId);
    } catch (_) {
      // A broken prefs read must never dead-end the screen — fall through to
      // the gateway path.
      return null;
    }
  }

  Future<void> submitOtp(String otp) async {
    if (state.mode == OtpHandoverViewMode.submitting) return;
    if (state.escalate) return;
    emit(state.copyWith(mode: OtpHandoverViewMode.submitting, clearError: true));
    try {
      await _repository.submitOtp(deliveryId: deliveryId, otp: otp);
      // Handover complete — the single-use code has no further value; drop the
      // persisted copy (hygiene; both roles, harmless when absent).
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
