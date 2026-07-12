import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../photo_attachment/domain/photo_compressor.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';

/// View-mode enum for the active-delivery Jeeber screen.
enum ActiveDeliveryMode { loading, ready, transitioning, error }

/// Lifecycle of the proof-of-delivery photo capture+upload (D3 / D1m, JM-051).
enum ProofPhotoStatus { none, uploading, captured, failed }

/// State emitted by [ActiveDeliveryCubit].
class ActiveDeliveryState extends Equatable {
  const ActiveDeliveryState({
    this.mode = ActiveDeliveryMode.loading,
    this.delivery,
    this.transitionError,
    this.errorMessage,
    this.proofPhotoStatus = ProofPhotoStatus.none,
    this.proofPhotoBytes,
    this.note,
    this.delivered = false,
    this.otpRequired = false,
    this.isVerifyingOtp = false,
    this.otpError,
  });

  final ActiveDeliveryMode mode;
  final JeeberDelivery? delivery;

  /// One-shot snack error after a failed transition (reverted).
  final String? transitionError;

  /// Full-screen error message on load failure.
  final String? errorMessage;

  /// Proof-of-delivery photo capture/upload lifecycle (JM-051 AC1).
  final ProofPhotoStatus proofPhotoStatus;

  /// JEBV4-200: the locally captured proof-photo bytes, retained so the jeeber
  /// sees the ACTUAL image they just took (rendered from memory) while the
  /// stamped `evidenceUrl` is a durable `object_ref` the gateway resolves on the
  /// customer receipt read. Null until a photo is captured this session.
  final Uint8List? proofPhotoBytes;

  /// Optional Jeeber note attached to the delivery (JM-051 AC1).
  final String? note;

  /// One-shot signal that the delivery reached `Done` — the screen routes to
  /// `feedback-rate-delivery` (JM-051 AC2 / JM-034 / D56), NOT the OTP handover.
  final bool delivered;

  /// iter6 close-tail: true once `AtDoor → Done` came back **422 `otp_required`**
  /// — the delivery carries a recipient phone, so the screen surfaces a
  /// door-OTP entry. The recipient gives the jeeber the code; the jeeber enters
  /// it and [ActiveDeliveryCubit.submitDoorOtp] completes the delivery.
  final bool otpRequired;

  /// True while a submitted door OTP is being verified against the gateway.
  final bool isVerifyingOtp;

  /// Inline error under the door-OTP field (wrong code / locked / network).
  final String? otpError;

  bool get isTransitioning => mode == ActiveDeliveryMode.transitioning;

  bool get isUploadingProof => proofPhotoStatus == ProofPhotoStatus.uploading;

  bool get hasProofPhoto =>
      proofPhotoStatus == ProofPhotoStatus.captured &&
      (delivery?.hasProofPhoto ?? false);

  ActiveDeliveryState copyWith({
    ActiveDeliveryMode? mode,
    JeeberDelivery? delivery,
    String? transitionError,
    bool clearTransitionError = false,
    String? errorMessage,
    bool clearError = false,
    ProofPhotoStatus? proofPhotoStatus,
    Uint8List? proofPhotoBytes,
    String? note,
    bool clearNote = false,
    bool? delivered,
    bool? otpRequired,
    bool? isVerifyingOtp,
    String? otpError,
    bool clearOtpError = false,
  }) {
    return ActiveDeliveryState(
      mode: mode ?? this.mode,
      delivery: delivery ?? this.delivery,
      transitionError: clearTransitionError
          ? null
          : (transitionError ?? this.transitionError),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      proofPhotoStatus: proofPhotoStatus ?? this.proofPhotoStatus,
      proofPhotoBytes: proofPhotoBytes ?? this.proofPhotoBytes,
      note: clearNote ? null : (note ?? this.note),
      delivered: delivered ?? this.delivered,
      otpRequired: otpRequired ?? this.otpRequired,
      isVerifyingOtp: isVerifyingOtp ?? this.isVerifyingOtp,
      otpError: clearOtpError ? null : (otpError ?? this.otpError),
    );
  }

  @override
  List<Object?> get props => [
        mode,
        delivery,
        transitionError,
        errorMessage,
        proofPhotoStatus,
        proofPhotoBytes,
        note,
        delivered,
        otpRequired,
        isVerifyingOtp,
        otpError,
      ];
}

/// Drives the Jeeber active-delivery screen (T-MOB-031, extended by JM-051).
///
/// Loads the delivery snapshot from [ActiveDeliveryRepository] and lets the
/// Jeeber advance the early stages ([advanceStatus]) and finally mark the
/// delivery as delivered ([markDelivered]) — which captures a proof photo (D3),
/// transitions `AtDoor → Done` carrying the evidence URL, and emits
/// `delivered: true` so the screen chains to the mandatory rating (JM-034/D56),
/// never the OTP handover.
class ActiveDeliveryCubit extends Cubit<ActiveDeliveryState> {
  ActiveDeliveryCubit({
    required ActiveDeliveryRepository repository,
    required this.deliveryId,
    PhotoPickerService? photoPicker,
    PhotoCompressor compressor = const HalvingPhotoCompressor(),
    Duration pollInterval = const Duration(seconds: 5),
  })  : _repository = repository,
        _photoPicker = photoPicker ?? StubPhotoPickerService(),
        _compressor = compressor,
        _pollInterval = pollInterval,
        super(const ActiveDeliveryState());

  final ActiveDeliveryRepository _repository;
  final String deliveryId;

  /// Captures the proof-of-delivery photo from the device camera (JEBV4-200).
  /// Defaults to [StubPhotoPickerService] (canned bytes) so devtool/tests run
  /// without a real camera; production injects [ImagePickerPhotoPickerService].
  final PhotoPickerService _photoPicker;

  /// Shrinks the captured photo under the upload ceiling before it streams to
  /// the CDN broker — reused from the KYC/attachment capture path.
  final PhotoCompressor _compressor;

  /// JEBV4-282: while the active-delivery screen is open the cubit re-polls the
  /// delivery so a backend-side transition (the customer/system advancing or
  /// cancelling the row) surfaces WITHOUT the jeeber having to leave and
  /// re-enter. Pre-fix the stepper only ever moved on the jeeber's own
  /// optimistic taps and otherwise stayed frozen at step 1. Injectable so
  /// timing-sensitive tests can pin a long interval; the poll never fights an
  /// in-flight transition / OTP entry (see [_poll]).
  final Duration _pollInterval;
  Timer? _pollTimer;

  Future<void> loadDelivery() async {
    emit(state.copyWith(mode: ActiveDeliveryMode.loading, clearError: true));
    try {
      final delivery = await _repository.fetchDelivery(deliveryId);
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: delivery,
        // Reflect a pre-stamped proof photo (seam may seed evidenceUrl).
        proofPhotoStatus: delivery.hasProofPhoto
            ? ProofPhotoStatus.captured
            : ProofPhotoStatus.none,
      ));
      // JEBV4-282: begin re-polling once we have a live (non-terminal) row.
      _schedulePoll();
    } on ActiveDeliveryException catch (e) {
      emit(state.copyWith(
        mode: ActiveDeliveryMode.error,
        errorMessage: _mapLoadError(e),
      ));
    }
  }

  /// JEBV4-282: (re)arm the background poll. No-op once the delivery is terminal
  /// (`Done`) — a completed row never changes again, so we stop hitting the
  /// gateway (mirrors [LiveTrackingCubit]'s terminal-stop).
  void _schedulePoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
    final delivery = state.delivery;
    if (delivery == null || delivery.status.isTerminal) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  /// Silent background re-fetch (no loading flash). Skips while a user-driven
  /// transition / proof upload / door-OTP entry is in flight so the poll never
  /// clobbers optimistic state or the OTP surface; a fetch failure is swallowed
  /// (the last good snapshot stays on screen and the next tick retries).
  Future<void> _poll() async {
    if (isClosed) return;
    if (!_canPoll(state)) return;
    try {
      final fresh = await _repository.fetchDelivery(deliveryId);
      if (isClosed || !_canPoll(state)) return;
      // Preserve a proof photo captured locally this session that the backend
      // snapshot may not carry yet.
      final localProof = state.delivery?.proofPhotoUrl;
      final merged = (fresh.proofPhotoUrl == null && localProof != null)
          ? fresh.withProofPhoto(localProof)
          : fresh;
      emit(state.copyWith(mode: ActiveDeliveryMode.ready, delivery: merged));
      if (merged.status.isTerminal) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    } on ActiveDeliveryException {
      // Swallow — keep the last good snapshot; the next tick retries.
    }
  }

  /// True when a silent poll may safely overwrite [delivery] with the backend
  /// snapshot — i.e. we have a live, non-terminal row and no user-driven flow
  /// (transition / proof upload / door OTP) is mid-flight.
  bool _canPoll(ActiveDeliveryState s) {
    final delivery = s.delivery;
    return delivery != null &&
        !delivery.status.isTerminal &&
        !s.isTransitioning &&
        !s.isUploadingProof &&
        !s.otpRequired &&
        !s.isVerifyingOtp;
  }

  /// JEBV4-282: force an immediate silent re-fetch + re-arm the poll. The screen
  /// wires this to app-resume so a delivery advanced while the app was
  /// backgrounded (Dart timers are suspended there) surfaces on return.
  Future<void> refresh() async {
    await _poll();
    _schedulePoll();
  }

  /// Advance status to the next valid stage (Ordered → Picked → InTransit).
  ///
  /// Emits transitioning immediately (optimistic UI), then either confirms on
  /// success or reverts + sets [transitionError] on failure. The delivering
  /// phase (`InTransit → AtDoor → Done`) is driven by [markDelivered] (it needs
  /// the proof photo + done→rating chain), so this no-ops from `InTransit` on.
  Future<void> advanceStatus() async {
    final current = state.delivery;
    if (current == null) return;
    if (current.status == JeeberDeliveryStatus.inTransit ||
        current.status == JeeberDeliveryStatus.atDoor) {
      return;
    }
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

  /// Capture + upload the proof-of-delivery photo (D3, JM-051 AC1, JEBV4-200).
  ///
  /// Opens the device camera, compresses the captured frame, and streams the
  /// REAL image BYTES through the gateway CDN signed-PUT proxy — never a
  /// filename stand-in. The durable `object_ref` the upload returns is stamped
  /// as the delivery's `evidenceUrl` so the `AtDoor → Done` transition carries
  /// it; the captured bytes are retained in state so the jeeber sees the actual
  /// photo they just took.
  ///
  /// A cancelled capture is a silent no-op (the jeeber backed out of the camera);
  /// a permission/hardware failure reverts to the tappable placeholder to retry.
  Future<void> captureProofPhoto() async {
    final current = state.delivery;
    if (current == null) return;
    if (state.isUploadingProof) return;

    final Uint8List bytes;
    try {
      final raw = await _photoPicker.pickFromCamera();
      bytes = await _compressor.compress(raw.bytes);
    } on PhotoPickException catch (e) {
      // Cancelled → leave the capture affordance untouched. Any other pick
      // failure (permission/hardware) → drop back to the retryable placeholder.
      if (e.failure != PhotoPickFailure.cancelled) {
        emit(state.copyWith(proofPhotoStatus: ProofPhotoStatus.none));
      }
      return;
    }

    emit(state.copyWith(
      proofPhotoStatus: ProofPhotoStatus.uploading,
      proofPhotoBytes: bytes,
      clearTransitionError: true,
    ));
    try {
      final url = await _repository.uploadProofPhoto(
        deliveryId: deliveryId,
        bytes: bytes,
      );
      emit(state.copyWith(
        delivery: current.withProofPhoto(url),
        proofPhotoStatus: ProofPhotoStatus.captured,
      ));
    } on ActiveDeliveryException catch (e) {
      emit(state.copyWith(
        proofPhotoStatus: ProofPhotoStatus.failed,
        transitionError: _mapTransitionError(e),
      ));
    }
  }

  /// Record the optional Jeeber note (JM-051 AC1).
  void setNote(String value) {
    final trimmed = value.trim();
    emit(trimmed.isEmpty
        ? state.copyWith(clearNote: true)
        : state.copyWith(note: trimmed));
  }

  /// Mark the delivery as delivered (JM-051 AC2).
  ///
  /// Walks the remaining SM-1 forward steps from the current status to `Done`
  /// (`InTransit → AtDoor → Done`, or just `AtDoor → Done`), stamping the proof
  /// [evidenceUrl] on the terminal `AtDoor → Done` step (D3). On success emits
  /// `delivered: true` so the screen routes to the mandatory rating — NOT the
  /// OTP handover (D56). On any step failure the whole walk reverts.
  Future<void> markDelivered() async {
    final original = state.delivery;
    if (original == null) return;
    if (state.isTransitioning) return;
    if (original.status == JeeberDeliveryStatus.done) return;

    emit(state.copyWith(
      mode: ActiveDeliveryMode.transitioning,
      delivery: _withStatus(original, JeeberDeliveryStatus.done),
      clearTransitionError: true,
    ));

    var from = original.status;
    try {
      while (from != JeeberDeliveryStatus.done) {
        final to = from.next;
        if (to == null) break;
        final isFinal = to == JeeberDeliveryStatus.done;
        final confirmed = await _repository.transition(
          deliveryId: deliveryId,
          from: from,
          to: to,
          // Carry the proof evidence on the terminal step only.
          evidenceUrl: isFinal ? original.proofPhotoUrl : null,
        );
        _logTransition(from, confirmed);
        from = confirmed;
        // Guard against a server that refuses to advance (avoid an infinite
        // loop if `confirmed` echoes `from`).
        if (confirmed != to) break;
      }
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: _withStatus(original, from),
        delivered: from == JeeberDeliveryStatus.done,
      ));
    } on ActiveDeliveryException catch (e) {
      // iter6 close-tail: a phone-bearing delivery answers the terminal
      // `AtDoor → Done` with 422 `otp_required`. Don't show "transition not
      // allowed" — surface the door-OTP entry instead. The delivery is held at
      // `AtDoor` (the last confirmed stage) so the recipient OTP can complete it.
      if (e.failure == ActiveDeliveryFailure.otpRequired) {
        emit(state.copyWith(
          mode: ActiveDeliveryMode.ready,
          delivery: _withStatus(original, from),
          otpRequired: true,
          clearTransitionError: true,
          clearOtpError: true,
        ));
        return;
      }
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: original,
        transitionError: _mapTransitionError(e),
      ));
    }
  }

  /// iter6 close-tail: verify the recipient's door OTP to complete a
  /// phone-bearing delivery `AtDoor → Done` (live :10090 ground truth:
  /// `POST /v1/deliveries/{id}/otp/verify {code}` → 200 { verified, status:Done }).
  /// The recipient hands the jeeber the code at the door; the jeeber enters it
  /// on the complete screen.
  ///
  /// On success emits `delivered: true` so the screen chains to the mandatory
  /// rating (JM-034 / D56). A wrong code keeps the entry open with an inline
  /// error; a network fault is retryable.
  Future<void> submitDoorOtp(String code) async {
    final current = state.delivery;
    if (current == null) return;
    if (state.isVerifyingOtp) return;
    final trimmed = code.trim();
    if (trimmed.length < 4) {
      emit(state.copyWith(otpError: 'Enter the 4-digit delivery code'));
      return;
    }
    emit(state.copyWith(isVerifyingOtp: true, clearOtpError: true));
    try {
      final status = await _repository.verifyDoorOtp(
        deliveryId: deliveryId,
        code: trimmed,
      );
      _logTransition(JeeberDeliveryStatus.atDoor, status);
      final done = status == JeeberDeliveryStatus.done;
      emit(state.copyWith(
        isVerifyingOtp: false,
        delivery: _withStatus(current, status),
        otpRequired: !done,
        delivered: done,
        clearOtpError: true,
      ));
    } on ActiveDeliveryException catch (e) {
      emit(state.copyWith(
        isVerifyingOtp: false,
        otpError: _mapOtpError(e),
      ));
    }
  }

  void acknowledgeTransitionError() {
    emit(state.copyWith(clearTransitionError: true));
  }

  /// Clear the inline door-OTP error after the snackbar/field rebuild reads it.
  void acknowledgeOtpError() {
    emit(state.copyWith(clearOtpError: true));
  }

  /// Acknowledge the one-shot `delivered` navigation signal so a rebuild does
  /// not re-fire the rating route.
  void acknowledgeDelivered() {
    emit(state.copyWith(delivered: false));
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }

  JeeberDelivery _withStatus(JeeberDelivery d, JeeberDeliveryStatus s) {
    return JeeberDelivery(
      id: d.id,
      status: s,
      dropOff: d.dropOff,
      clientName: d.clientName,
      conversationId: d.conversationId,
      amountText: d.amountText,
      cashNote: d.cashNote,
      proofPhotoUrl: d.proofPhotoUrl,
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
    if (e.failure == ActiveDeliveryFailure.otpRequired) {
      // Defensive: markDelivered handles otpRequired before this maps it, so
      // this is only hit if an EARLY step somehow returns the gate. Point the
      // jeeber at the code rather than the misleading "not allowed".
      return 'Enter the delivery OTP from the recipient to complete';
    }
    if (e.failure == ActiveDeliveryFailure.invalidTransition) {
      return 'That transition is not allowed';
    }
    if (e.failure == ActiveDeliveryFailure.network) {
      return 'No internet connection';
    }
    return 'Unable to update status';
  }

  String _mapOtpError(ActiveDeliveryException e) {
    switch (e.failure) {
      case ActiveDeliveryFailure.invalidOtp:
        return 'Incorrect code — ask the recipient and try again';
      case ActiveDeliveryFailure.otpLocked:
        return 'Too many attempts — contact support';
      case ActiveDeliveryFailure.network:
        return 'No internet connection';
      case ActiveDeliveryFailure.notFound:
        return 'Delivery not found';
      case ActiveDeliveryFailure.otpRequired:
      case ActiveDeliveryFailure.invalidTransition:
      case ActiveDeliveryFailure.server:
        return 'Unable to verify the code';
    }
  }

  // AC7: delivery.status_transition log
  // ignore: avoid_print
  void _logTransition(JeeberDeliveryStatus from, JeeberDeliveryStatus to) {
    // ignore: avoid_print
    print('[delivery.status_transition] from=${from.apiValue} to=${to.apiValue}');
  }
}
