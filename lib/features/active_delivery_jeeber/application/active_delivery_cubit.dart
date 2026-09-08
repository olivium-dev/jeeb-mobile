import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/lifecycle/app_lifecycle_gate.dart';
import '../../../core/network/app_failure.dart';
import '../../background_gps/application/background_gps_cubit.dart';
import '../../background_gps/application/background_gps_state.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../photo_attachment/domain/photo_compressor.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';

enum ActiveDeliveryMode { loading, ready, transitioning, error }

enum ProofPhotoStatus { none, uploading, captured, failed }

class ActiveDeliveryState extends Equatable {
  const ActiveDeliveryState({
    this.mode = ActiveDeliveryMode.loading,
    this.delivery,
    this.transitionErrorKind,
    this.failureTypeSuffix,
    this.loadFailureKind,
    this.refreshFailure,
    this.proofPhotoStatus = ProofPhotoStatus.none,
    this.proofPhotoBytes,
    this.proofPhotoFailure,
    this.note,
    this.delivered = false,
    this.otpRequired = false,
    this.isVerifyingOtp = false,
    this.otpErrorKind,
    this.otpAttemptsRemaining,
    this.otpEscalationId,
    this.gpsPhase = BackgroundGpsPhase.idle,
    this.gpsNeedsSystemSettings = false,
  });

  final ActiveDeliveryMode mode;
  final JeeberDelivery? delivery;

  final BackgroundGpsPhase gpsPhase;

  final bool gpsNeedsSystemSettings;

  bool get isGpsBlocked => gpsPhase == BackgroundGpsPhase.permissionDenied;

  /// The uploader tore itself down; the banner offers Resume, not Grant.
  bool get isGpsFailed => gpsPhase == BackgroundGpsPhase.error;

  final ActiveDeliveryFailure? transitionErrorKind;

  /// RFC 7807 `type` last segment behind the last transition failure.
  final String? failureTypeSuffix;

  /// Why the cold load failed. Replaces the English `errorMessage`.
  final ActiveDeliveryFailure? loadFailureKind;

  /// A warm refresh failed while the rows are still on screen.
  final ActiveDeliveryFailure? refreshFailure;

  final ProofPhotoStatus proofPhotoStatus;

  final Uint8List? proofPhotoBytes;

  /// Why the camera leg failed, so the screen picks permission vs unavailable.
  final PhotoPickFailure? proofPhotoFailure;

  final String? note;

  final bool delivered;

  final bool otpRequired;

  final bool isVerifyingOtp;

  /// Why the door OTP was refused. Replaces the English `otpError`.
  final ActiveDeliveryFailure? otpErrorKind;

  final int? otpAttemptsRemaining;

  final String? otpEscalationId;

  bool get isTransitioning => mode == ActiveDeliveryMode.transitioning;

  bool get isUploadingProof => proofPhotoStatus == ProofPhotoStatus.uploading;

  bool get hasProofPhoto =>
      proofPhotoStatus == ProofPhotoStatus.captured &&
      (delivery?.hasProofPhoto ?? false);

  ActiveDeliveryState copyWith({
    ActiveDeliveryMode? mode,
    JeeberDelivery? delivery,
    ActiveDeliveryFailure? transitionErrorKind,
    String? failureTypeSuffix,
    bool clearTransitionError = false,
    ActiveDeliveryFailure? loadFailureKind,
    ActiveDeliveryFailure? refreshFailure,
    bool clearRefreshFailure = false,
    bool clearError = false,
    ProofPhotoStatus? proofPhotoStatus,
    Uint8List? proofPhotoBytes,
    PhotoPickFailure? proofPhotoFailure,
    String? note,
    bool clearNote = false,
    bool? delivered,
    bool? otpRequired,
    bool? isVerifyingOtp,
    ActiveDeliveryFailure? otpErrorKind,
    int? otpAttemptsRemaining,
    String? otpEscalationId,
    bool clearOtpError = false,
    BackgroundGpsPhase? gpsPhase,
    bool? gpsNeedsSystemSettings,
  }) {
    return ActiveDeliveryState(
      mode: mode ?? this.mode,
      delivery: delivery ?? this.delivery,
      transitionErrorKind: clearTransitionError
          ? null
          : (transitionErrorKind ?? this.transitionErrorKind),
      failureTypeSuffix: clearTransitionError
          ? null
          : (failureTypeSuffix ?? this.failureTypeSuffix),
      loadFailureKind:
          clearError ? null : (loadFailureKind ?? this.loadFailureKind),
      refreshFailure: clearRefreshFailure
          ? null
          : (refreshFailure ?? this.refreshFailure),
      proofPhotoStatus: proofPhotoStatus ?? this.proofPhotoStatus,
      proofPhotoBytes: proofPhotoBytes ?? this.proofPhotoBytes,
      proofPhotoFailure: proofPhotoStatus == ProofPhotoStatus.failed
          ? (proofPhotoFailure ?? this.proofPhotoFailure)
          : (proofPhotoStatus == null ? this.proofPhotoFailure : null),
      note: clearNote ? null : (note ?? this.note),
      delivered: delivered ?? this.delivered,
      otpRequired: otpRequired ?? this.otpRequired,
      isVerifyingOtp: isVerifyingOtp ?? this.isVerifyingOtp,
      otpErrorKind: clearOtpError ? null : (otpErrorKind ?? this.otpErrorKind),
      otpAttemptsRemaining: clearOtpError
          ? null
          : (otpAttemptsRemaining ?? this.otpAttemptsRemaining),
      otpEscalationId:
          clearOtpError ? null : (otpEscalationId ?? this.otpEscalationId),
      gpsPhase: gpsPhase ?? this.gpsPhase,
      gpsNeedsSystemSettings:
          gpsNeedsSystemSettings ?? this.gpsNeedsSystemSettings,
    );
  }

  @override
  List<Object?> get props => [
    mode,
    delivery,
    transitionErrorKind,
    failureTypeSuffix,
    loadFailureKind,
    refreshFailure,
    proofPhotoStatus,
    proofPhotoBytes,
    proofPhotoFailure,
    note,
    delivered,
    otpRequired,
    isVerifyingOtp,
    otpErrorKind,
    otpAttemptsRemaining,
    otpEscalationId,
    gpsPhase,
    gpsNeedsSystemSettings,
  ];
}

class ActiveDeliveryCubit extends Cubit<ActiveDeliveryState> {
  ActiveDeliveryCubit({
    required ActiveDeliveryRepository repository,
    required this.deliveryId,
    PhotoPickerService? photoPicker,
    PhotoCompressor compressor = const HalvingPhotoCompressor(),
    Stream<void>? refreshSignals,
    BackgroundGpsCubit? gpsUploader,
  }) : _repository = repository,
       _photoPicker = photoPicker ?? StubPhotoPickerService(),
       _compressor = compressor,
       _refreshSignals = refreshSignals,
       _gpsUploader = gpsUploader,
       super(const ActiveDeliveryState()) {
    _armGpsMirror();
  }

  final ActiveDeliveryRepository _repository;
  final String deliveryId;

  final BackgroundGpsCubit? _gpsUploader;

  final PhotoPickerService _photoPicker;

  final PhotoCompressor _compressor;

  final Stream<void>? _refreshSignals;

  StreamSubscription<void>? _refreshSubscription;

  StreamSubscription<BackgroundGpsState>? _gpsSubscription;

  @visibleForTesting
  bool get debugPushRefreshWired => _refreshSubscription != null;

  @visibleForTesting
  bool get debugGpsMirrorWired => _gpsSubscription != null;

  void _armGpsMirror() {
    final gps = _gpsUploader;
    if (gps == null || _gpsSubscription != null) return;
    _mirrorGpsState(gps.state);
    _gpsSubscription = gps.stream.listen(_mirrorGpsState);
  }

  void _mirrorGpsState(BackgroundGpsState gpsState) {
    if (isClosed) return;
    // The uploader is an app-wide singleton: mirroring it unfiltered showed a
    // PREVIOUS delivery's permission banner on a freshly opened one.
    final isOurs = gpsState.deliveryId == null ||
        gpsState.deliveryId == deliveryId;
    emit(
      state.copyWith(
        gpsPhase: isOurs ? gpsState.phase : BackgroundGpsPhase.idle,
        gpsNeedsSystemSettings: isOurs && gpsState.needsSystemSettings,
      ),
    );
  }

  Future<void> retryGpsPermission() async {
    await _gpsUploader?.retryPermission();
  }

  Future<void> openGpsSettings() async {
    await _gpsUploader?.openSystemSettings();
  }

  /// Re-arms an uploader that tore itself down (BackgroundGpsPhase.error).
  Future<void> resumeGps() async {
    await _gpsUploader?.resume();
  }

  bool _loadInFlight = false;

  Future<void> loadDelivery() async {
    if (_loadInFlight) return;
    _loadInFlight = true;
    emit(state.copyWith(
      mode: ActiveDeliveryMode.loading,
      clearError: true,
      clearRefreshFailure: true,
    ));
    try {
      final delivery = await _repository.fetchDelivery(deliveryId);
      emit(
        state.copyWith(
          mode: ActiveDeliveryMode.ready,
          delivery: delivery,
          proofPhotoStatus: delivery.hasProofPhoto
              ? ProofPhotoStatus.captured
              : ProofPhotoStatus.none,
        ),
      );
      _armPoll();
      _syncGpsUpload();
    } on ActiveDeliveryException catch (e) {
      emit(
        state.copyWith(
          mode: ActiveDeliveryMode.error,
          loadFailureKind: e.failure,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          mode: ActiveDeliveryMode.error,
          loadFailureKind: _failureOf(e),
        ),
      );
    } finally {
      _loadInFlight = false;
    }
  }

  /// The one place an untyped throw (a `TypeError` out of `fromJson`, say)
  /// becomes a kind the screen can render.
  static ActiveDeliveryFailure _failureOf(Object error) =>
      switch (AppFailure.of(error).kind) {
        AppFailureKind.network ||
        AppFailureKind.timeout =>
          ActiveDeliveryFailure.network,
        AppFailureKind.notFound ||
        AppFailureKind.gone =>
          ActiveDeliveryFailure.notFound,
        _ => ActiveDeliveryFailure.server,
      };

  void _armPoll() {
    final delivery = state.delivery;
    if (delivery == null || delivery.status.isPollTerminal) {
      _retireRefreshSubscription();
      return;
    }
    _refreshSubscription ??= _refreshSignals?.listen((_) => _refreshFromPush());
  }

  void _retireRefreshSubscription() {
    unawaited(_refreshSubscription?.cancel());
    _refreshSubscription = null;
  }

  void _schedulePoll() => _armPoll();

  Future<void> _refreshFromPush() async {
    if (isClosed || _pushRefreshInFlight) return;
    _pushRefreshInFlight = true;
    try {
      await _poll();
    } finally {
      _pushRefreshInFlight = false;
    }
  }

  bool _pushRefreshInFlight = false;

  Future<void> _poll() async {
    if (isClosed) return;
    if (!_canPoll(state)) return;
    final otpWindow = state.otpRequired || state.isVerifyingOtp;
    try {
      final fresh = await _repository.fetchDelivery(deliveryId);
      if (isClosed || !_canPoll(state)) return;
      if (otpWindow && !fresh.status.isTerminal) return;
      final localProof = state.delivery?.proofPhotoUrl;
      final merged = (fresh.proofPhotoUrl == null && localProof != null)
          ? fresh.withProofPhoto(localProof)
          : fresh;
      emit(
        state.copyWith(
          mode: ActiveDeliveryMode.ready,
          delivery: merged,
          otpRequired: otpWindow && merged.status.isTerminal ? false : null,
          isVerifyingOtp: otpWindow && merged.status.isTerminal ? false : null,
          delivered: merged.status.isSuccessfulTerminal ? true : null,
          clearRefreshFailure: true,
        ),
      );
      if (merged.status.isPollTerminal) {
        _retireRefreshSubscription();
      }
      _syncGpsUpload();
    } on ActiveDeliveryException catch (e) {
      // A failed push refresh keeps the rows it already has — refresh never
      // flips back to loading — but it must not be silent either.
      if (!isClosed) emit(state.copyWith(refreshFailure: e.failure));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(refreshFailure: _failureOf(e)));
    }
  }

  void _syncGpsUpload() {
    final gps = _gpsUploader;
    if (gps == null) return;
    final enRoute = state.delivery?.status == JeeberDeliveryStatus.inTransit;
    if (enRoute) {
      // Android's while-in-use grant can back a location foreground service,
      // but the service must be started while an activity is visible. A push
      // received in the background is picked up by the existing resume refresh.
      if (AppLifecycleGate.instance.isForeground) {
        unawaited(gps.start(deliveryId));
      }
    } else if (_uploaderIsDrivingThisDelivery(gps)) {
      unawaited(gps.stop());
    }
  }

  bool _uploaderIsDrivingThisDelivery(BackgroundGpsCubit gps) =>
      gps.state.phase != BackgroundGpsPhase.idle &&
      gps.state.deliveryId == deliveryId;

  bool _canPoll(ActiveDeliveryState s) {
    final delivery = s.delivery;
    return delivery != null &&
        !delivery.status.isPollTerminal &&
        !s.isTransitioning &&
        !s.isUploadingProof;
  }

  Future<void> refresh() async {
    if (isClosed || _pushRefreshInFlight) return;
    _pushRefreshInFlight = true;
    try {
      await _poll();
    } finally {
      _pushRefreshInFlight = false;
    }
    _armPoll();
  }

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
    emit(
      state.copyWith(
        mode: ActiveDeliveryMode.transitioning,
        delivery: optimistic,
        clearTransitionError: true,
      ),
    );

    try {
      final confirmed = await _repository.transition(
        deliveryId: deliveryId,
        from: current.status,
        to: nextStatus,
      );
      _logTransition(current.status, confirmed);
      final confirmedDelivery = _withStatus(current, confirmed);
      emit(
        state.copyWith(
          mode: ActiveDeliveryMode.ready,
          delivery: confirmedDelivery,
        ),
      );
      _syncGpsUpload();
    } on ActiveDeliveryException catch (e) {
      emit(
        state.copyWith(
          mode: ActiveDeliveryMode.ready,
          delivery: current,
          transitionErrorKind: e.failure,
          failureTypeSuffix: e.typeSuffix,
        ),
      );
    }
  }

  Future<void> captureProofPhoto() async {
    final current = state.delivery;
    if (current == null) return;
    if (state.isUploadingProof) return;

    final Uint8List bytes;
    try {
      final raw = await _photoPicker.pickFromCamera();
      bytes = await _compressor.compress(raw.bytes);
    } on PhotoPickException catch (e) {
      // `cancelled` is the user's own act and stays silent; everything else
      // was invisible before, which read as a camera that did nothing.
      if (e.failure != PhotoPickFailure.cancelled) {
        emit(state.copyWith(
          proofPhotoStatus: ProofPhotoStatus.failed,
          proofPhotoFailure: e.failure,
        ));
      }
      return;
    } catch (e) {
      emit(state.copyWith(
        proofPhotoStatus: ProofPhotoStatus.failed,
        proofPhotoFailure: PhotoPickFailure.unavailable,
      ));
      Diag.event('active_delivery.proof_photo_failed', <String, Object?>{
        'kind': AppFailure.of(e).kind.name,
      });
      return;
    }

    emit(
      state.copyWith(
        proofPhotoStatus: ProofPhotoStatus.uploading,
        proofPhotoBytes: bytes,
        clearTransitionError: true,
      ),
    );
    try {
      final url = await _repository.uploadProofPhoto(
        deliveryId: deliveryId,
        bytes: bytes,
      );
      emit(
        state.copyWith(
          delivery: current.withProofPhoto(url),
          proofPhotoStatus: ProofPhotoStatus.captured,
        ),
      );
    } on ActiveDeliveryException catch (e) {
      emit(
        state.copyWith(
          proofPhotoStatus: ProofPhotoStatus.failed,
          transitionErrorKind: e.failure,
          failureTypeSuffix: e.typeSuffix,
        ),
      );
    }
  }

  void setNote(String value) {
    final trimmed = value.trim();
    emit(
      trimmed.isEmpty
          ? state.copyWith(clearNote: true)
          : state.copyWith(note: trimmed),
    );
  }

  Future<void> markDelivered() async {
    final original = state.delivery;
    if (original == null) return;
    if (state.isTransitioning) return;
    if (original.status.isTerminal) return;

    if (original.status == JeeberDeliveryStatus.atDoor) {
      emit(
        state.copyWith(
          mode: ActiveDeliveryMode.ready,
          otpRequired: true,
          clearTransitionError: true,
          clearOtpError: true,
        ),
      );
      _syncGpsUpload();
      return;
    }

    emit(
      state.copyWith(
        mode: ActiveDeliveryMode.transitioning,
        delivery: _withStatus(original, JeeberDeliveryStatus.atDoor),
        clearTransitionError: true,
      ),
    );

    var from = original.status;
    var lastConfirmed = original.status;
    try {
      while (from != JeeberDeliveryStatus.atDoor) {
        final to = from.next;
        if (to == null) break;
        final isLastWalkedStep = to == JeeberDeliveryStatus.atDoor;
        final confirmed = await _repository.transition(
          deliveryId: deliveryId,
          from: from,
          to: to,
          evidenceUrl: isLastWalkedStep ? original.proofPhotoUrl : null,
        );
        _logTransition(from, confirmed);
        lastConfirmed = confirmed;
        from = confirmed;
        if (confirmed != to) break;
      }
      final atDoor = from == JeeberDeliveryStatus.atDoor;
      emit(
        state.copyWith(
          mode: ActiveDeliveryMode.ready,
          delivery: _withStatus(original, from),
          otpRequired: atDoor,
          delivered: from == JeeberDeliveryStatus.done,
          clearOtpError: true,
        ),
      );
      _schedulePoll();
      _syncGpsUpload();
    } on ActiveDeliveryException catch (e) {
      if (e.failure == ActiveDeliveryFailure.otpRequired) {
        emit(
          state.copyWith(
            mode: ActiveDeliveryMode.ready,
            delivery: _withStatus(original, lastConfirmed),
            otpRequired: true,
            clearTransitionError: true,
            clearOtpError: true,
          ),
        );
        _syncGpsUpload();
        return;
      }
      emit(
        state.copyWith(
          mode: ActiveDeliveryMode.ready,
          delivery: _withStatus(original, lastConfirmed),
          transitionErrorKind: e.failure,
          failureTypeSuffix: e.typeSuffix,
        ),
      );
    }
  }

  Future<void> submitDoorOtp(String code) async {
    final current = state.delivery;
    if (current == null) return;
    if (state.isVerifyingOtp) return;
    final trimmed = code.trim();
    if (trimmed.length < 4) {
      emit(state.copyWith(
        otpErrorKind: ActiveDeliveryFailure.otpCodeRequired,
      ));
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
      emit(
        state.copyWith(
          isVerifyingOtp: false,
          delivery: _withStatus(current, status),
          otpRequired: !done,
          delivered: done,
          clearOtpError: true,
        ),
      );
      _schedulePoll();
      _syncGpsUpload();
    } on ActiveDeliveryException catch (e) {
      emit(state.copyWith(
        isVerifyingOtp: false,
        otpErrorKind: e.failure,
        otpAttemptsRemaining: e.attemptsRemaining,
        otpEscalationId: e.escalationId,
      ));
    } catch (e) {
      emit(state.copyWith(
        isVerifyingOtp: false,
        otpErrorKind: _failureOf(e),
      ));
    }
  }

  void acknowledgeTransitionError() {
    emit(state.copyWith(clearTransitionError: true));
  }

  void acknowledgeOtpError() {
    emit(state.copyWith(clearOtpError: true));
  }

  /// Dismisses the warm refresh strip; the rows underneath stay.
  void acknowledgeRefreshFailure() {
    emit(state.copyWith(clearRefreshFailure: true));
  }

  /// Clears the proof-photo verdict so its snack fires once, not on every emit.
  void acknowledgeProofPhotoFailure() {
    if (state.proofPhotoStatus != ProofPhotoStatus.failed) return;
    emit(state.copyWith(proofPhotoStatus: ProofPhotoStatus.none));
  }

  void acknowledgeDelivered() {
    emit(state.copyWith(delivered: false));
  }

  @override
  Future<void> close() async {
    _retireRefreshSubscription();
    await _gpsSubscription?.cancel();
    _gpsSubscription = null;
    final gps = _gpsUploader;
    final status = state.delivery?.status;
    if (gps != null &&
        status != null &&
        status != JeeberDeliveryStatus.inTransit &&
        _uploaderIsDrivingThisDelivery(gps)) {
      await gps.stop();
    }
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




  void _logTransition(JeeberDeliveryStatus from, JeeberDeliveryStatus to) {
    Diag.event('delivery.status_transition', <String, Object?>{
      'from': from.apiValue,
      'to': to.apiValue,
    });
  }
}
