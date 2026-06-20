import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';

/// View-mode enum for the active-delivery Jeeber screen.
enum ActiveDeliveryMode { loading, ready, transitioning, error }

/// Lifecycle of the proof-of-delivery photo capture+upload (D3 / D1m, JM-051).
enum ProofPhotoStatus { none, uploading, captured, failed }

/// Where a proof-photo capture failed — distinguishes a user cancel (no error
/// shown) from a permission / hardware fault (the screen surfaces copy + a
/// settings affordance), mirroring [PhotoPickFailure].
enum ProofPhotoCaptureFailure { cancelled, permissionDenied, unavailable }

/// State emitted by [ActiveDeliveryCubit].
class ActiveDeliveryState extends Equatable {
  const ActiveDeliveryState({
    this.mode = ActiveDeliveryMode.loading,
    this.delivery,
    this.transitionError,
    this.errorMessage,
    this.proofPhotoStatus = ProofPhotoStatus.none,
    this.proofPhotoFailure,
    this.note,
    this.delivered = false,
  });

  final ActiveDeliveryMode mode;
  final JeeberDelivery? delivery;

  /// One-shot snack error after a failed transition (reverted).
  final String? transitionError;

  /// Full-screen error message on load failure.
  final String? errorMessage;

  /// Proof-of-delivery photo capture/upload lifecycle (JM-051 AC1).
  final ProofPhotoStatus proofPhotoStatus;

  /// Why the last proof-photo capture failed (camera permission/cancel/IO), or
  /// `null` when there is no outstanding capture failure. A `cancelled` failure
  /// is benign (the user backed out) — the screen shows no error for it.
  final ProofPhotoCaptureFailure? proofPhotoFailure;

  /// Optional Jeeber note attached to the delivery (JM-051 AC1).
  final String? note;

  /// One-shot signal that the delivery reached `Done` — the screen routes to
  /// `feedback-rate-delivery` (JM-051 AC2 / JM-034 / D56), NOT the OTP handover.
  final bool delivered;

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
    ProofPhotoCaptureFailure? proofPhotoFailure,
    bool clearProofPhotoFailure = false,
    String? note,
    bool clearNote = false,
    bool? delivered,
  }) {
    return ActiveDeliveryState(
      mode: mode ?? this.mode,
      delivery: delivery ?? this.delivery,
      transitionError: clearTransitionError
          ? null
          : (transitionError ?? this.transitionError),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      proofPhotoStatus: proofPhotoStatus ?? this.proofPhotoStatus,
      proofPhotoFailure: clearProofPhotoFailure
          ? null
          : (proofPhotoFailure ?? this.proofPhotoFailure),
      note: clearNote ? null : (note ?? this.note),
      delivered: delivered ?? this.delivered,
    );
  }

  @override
  List<Object?> get props => [
        mode,
        delivery,
        transitionError,
        errorMessage,
        proofPhotoStatus,
        proofPhotoFailure,
        note,
        delivered,
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
  })  : _repository = repository,
        _photoPicker = photoPicker,
        super(const ActiveDeliveryState());

  final ActiveDeliveryRepository _repository;
  final String deliveryId;

  /// Real device camera/gallery capture (JM-051). `null` in a bare regression
  /// harness — [captureProofPhoto] then degrades to the legacy filename-only
  /// upload (the in-memory mock seam) so existing tests keep their contract.
  final PhotoPickerService? _photoPicker;

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
    } on ActiveDeliveryException catch (e) {
      emit(state.copyWith(
        mode: ActiveDeliveryMode.error,
        errorMessage: _mapLoadError(e),
      ));
    }
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

  /// Capture + upload the proof-of-delivery photo (D3, JM-051 AC1).
  ///
  /// Real flow: capture from the device camera via [PhotoPickerService], then
  /// upload the bytes to the cdn-service via the gateway
  /// (`POST /v1/delivery/proof-photo`). The service mints a stable evidence URL
  /// which is stamped onto the delivery so the thumbnail renders and the
  /// `AtDoor → Done` transition can carry it.
  ///
  /// [filename] names the multipart part (defaults to a timestamped jpg). When
  /// no picker is wired (a bare regression harness) the flow degrades to the
  /// legacy filename-only upload against the in-memory mock seam. A user-
  /// cancelled capture is a benign no-op (no error surfaced); a permission /
  /// hardware fault sets [ActiveDeliveryState.proofPhotoFailure].
  Future<void> captureProofPhoto([String? filename]) async {
    final current = state.delivery;
    if (current == null) return;
    if (state.isUploadingProof) return;

    final name = filename ??
        'proof_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // 1) Capture device bytes (skipped when no picker — legacy mock path).
    Uint8List? bytes;
    if (_photoPicker != null) {
      try {
        final raw = await _photoPicker.pickFromCamera();
        bytes = raw.bytes;
      } on PhotoPickException catch (e) {
        if (e.failure == PhotoPickFailure.cancelled) {
          // User backed out — leave the placeholder untouched, no error.
          return;
        }
        emit(state.copyWith(
          proofPhotoStatus: ProofPhotoStatus.failed,
          proofPhotoFailure: e.failure == PhotoPickFailure.permissionDenied
              ? ProofPhotoCaptureFailure.permissionDenied
              : ProofPhotoCaptureFailure.unavailable,
        ));
        return;
      }
    }

    // 2) Upload (real bytes via multipart, or the legacy filename-only post).
    emit(state.copyWith(
      proofPhotoStatus: ProofPhotoStatus.uploading,
      clearTransitionError: true,
      clearProofPhotoFailure: true,
    ));
    try {
      final url = await _repository.uploadProofPhoto(
        deliveryId: deliveryId,
        filename: name,
        bytes: bytes,
      );
      emit(state.copyWith(
        delivery: current.withProofPhoto(url),
        proofPhotoStatus: ProofPhotoStatus.captured,
      ));
    } on ActiveDeliveryException catch (e) {
      emit(state.copyWith(
        proofPhotoStatus: ProofPhotoStatus.failed,
        proofPhotoFailure: ProofPhotoCaptureFailure.unavailable,
        transitionError: _mapTransitionError(e),
      ));
    }
  }

  /// Clear a one-shot proof-photo capture failure so a banner/snack doesn't
  /// replay on rebuild.
  void acknowledgeProofPhotoFailure() {
    if (state.proofPhotoFailure == null) return;
    emit(state.copyWith(clearProofPhotoFailure: true));
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
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: original,
        transitionError: _mapTransitionError(e),
      ));
    }
  }

  void acknowledgeTransitionError() {
    emit(state.copyWith(clearTransitionError: true));
  }

  /// Acknowledge the one-shot `delivered` navigation signal so a rebuild does
  /// not re-fire the rating route.
  void acknowledgeDelivered() {
    emit(state.copyWith(delivered: false));
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
