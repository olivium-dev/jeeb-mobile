import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

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
    this.transitionError,
    this.transitionErrorKind,
    this.errorMessage,
    this.proofPhotoStatus = ProofPhotoStatus.none,
    this.proofPhotoBytes,
    this.note,
    this.delivered = false,
    this.otpRequired = false,
    this.isVerifyingOtp = false,
    this.otpError,
    this.gpsPhase = BackgroundGpsPhase.idle,
    this.gpsNeedsSystemSettings = false,
  });

  final ActiveDeliveryMode mode;
  final JeeberDelivery? delivery;

  final BackgroundGpsPhase gpsPhase;

  final bool gpsNeedsSystemSettings;

  bool get isGpsBlocked => gpsPhase == BackgroundGpsPhase.permissionDenied;

  final String? transitionError;

  final ActiveDeliveryFailure? transitionErrorKind;

  final String? errorMessage;

  final ProofPhotoStatus proofPhotoStatus;

  final Uint8List? proofPhotoBytes;

  final String? note;

  final bool delivered;

  final bool otpRequired;

  final bool isVerifyingOtp;

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
    ActiveDeliveryFailure? transitionErrorKind,
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
    BackgroundGpsPhase? gpsPhase,
    bool? gpsNeedsSystemSettings,
  }) {
    return ActiveDeliveryState(
      mode: mode ?? this.mode,
      delivery: delivery ?? this.delivery,
      transitionError: clearTransitionError
          ? null
          : (transitionError ?? this.transitionError),
      transitionErrorKind: clearTransitionError
          ? null
          : (transitionErrorKind ?? this.transitionErrorKind),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      proofPhotoStatus: proofPhotoStatus ?? this.proofPhotoStatus,
      proofPhotoBytes: proofPhotoBytes ?? this.proofPhotoBytes,
      note: clearNote ? null : (note ?? this.note),
      delivered: delivered ?? this.delivered,
      otpRequired: otpRequired ?? this.otpRequired,
      isVerifyingOtp: isVerifyingOtp ?? this.isVerifyingOtp,
      otpError: clearOtpError ? null : (otpError ?? this.otpError),
      gpsPhase: gpsPhase ?? this.gpsPhase,
      gpsNeedsSystemSettings:
          gpsNeedsSystemSettings ?? this.gpsNeedsSystemSettings,
    );
  }

  @override
  List<Object?> get props => [
        mode,
        delivery,
        transitionError,
        transitionErrorKind,
        errorMessage,
        proofPhotoStatus,
        proofPhotoBytes,
        note,
        delivered,
        otpRequired,
        isVerifyingOtp,
        otpError,
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
  })  : _repository = repository,
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
    emit(state.copyWith(
      gpsPhase: gpsState.phase,
      gpsNeedsSystemSettings: gpsState.needsSystemSettings,
    ));
  }

  Future<void> retryGpsPermission() async {
    await _gpsUploader?.retryPermission();
  }

  Future<void> openGpsSettings() async {
    await _gpsUploader?.openSystemSettings();
  }

  Future<void> loadDelivery() async {
    emit(state.copyWith(mode: ActiveDeliveryMode.loading, clearError: true));
    try {
      final delivery = await _repository.fetchDelivery(deliveryId);
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: delivery,
        proofPhotoStatus: delivery.hasProofPhoto
            ? ProofPhotoStatus.captured
            : ProofPhotoStatus.none,
      ));
      _armPoll();
      _syncGpsUpload();
    } on ActiveDeliveryException catch (e) {
      emit(state.copyWith(
        mode: ActiveDeliveryMode.error,
        errorMessage: _mapLoadError(e),
      ));
    }
  }

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
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: merged,
        otpRequired: otpWindow && merged.status.isTerminal ? false : null,
        isVerifyingOtp: otpWindow && merged.status.isTerminal ? false : null,
        delivered: merged.status.isSuccessfulTerminal ? true : null,
      ));
      if (merged.status.isPollTerminal) {
        _retireRefreshSubscription();
      }
      _syncGpsUpload();
    } on ActiveDeliveryException {
      // GPS sync is best effort and must not fail the state transition.
    }
  }

  void _syncGpsUpload() {
    final gps = _gpsUploader;
    if (gps == null) return;
    final enRoute = state.delivery?.status == JeeberDeliveryStatus.inTransit;
    if (enRoute) {
      unawaited(gps.start(deliveryId));
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
      _syncGpsUpload();
    } on ActiveDeliveryException catch (e) {
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: current,
        transitionError: _mapTransitionError(e),
        transitionErrorKind: e.failure,
      ));
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
        transitionErrorKind: e.failure,
      ));
    }
  }

  void setNote(String value) {
    final trimmed = value.trim();
    emit(trimmed.isEmpty
        ? state.copyWith(clearNote: true)
        : state.copyWith(note: trimmed));
  }

  Future<void> markDelivered() async {
    final original = state.delivery;
    if (original == null) return;
    if (state.isTransitioning) return;
    if (original.status.isTerminal) return;

    if (original.status == JeeberDeliveryStatus.atDoor) {
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        otpRequired: true,
        clearTransitionError: true,
        clearOtpError: true,
      ));
      _syncGpsUpload();
      return;
    }

    emit(state.copyWith(
      mode: ActiveDeliveryMode.transitioning,
      delivery: _withStatus(original, JeeberDeliveryStatus.atDoor),
      clearTransitionError: true,
    ));

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
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: _withStatus(original, from),
        otpRequired: atDoor,
        delivered: from == JeeberDeliveryStatus.done,
        clearOtpError: true,
      ));
      _schedulePoll();
      _syncGpsUpload();
    } on ActiveDeliveryException catch (e) {
      if (e.failure == ActiveDeliveryFailure.otpRequired) {
        emit(state.copyWith(
          mode: ActiveDeliveryMode.ready,
          delivery: _withStatus(original, lastConfirmed),
          otpRequired: true,
          clearTransitionError: true,
          clearOtpError: true,
        ));
        _syncGpsUpload();
        return;
      }
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: _withStatus(original, lastConfirmed),
        transitionError: _mapTransitionError(e),
        transitionErrorKind: e.failure,
      ));
    }
  }

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
      _schedulePoll();
      _syncGpsUpload();
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

  void acknowledgeOtpError() {
    emit(state.copyWith(clearOtpError: true));
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
      return 'Enter the delivery OTP from the recipient to complete';
    }
    if (e.failure == ActiveDeliveryFailure.invalidTransition) {
      return 'That transition is not allowed';
    }
    if (e.failure == ActiveDeliveryFailure.badRequest) {
      return 'We couldn’t apply that update';
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
      case ActiveDeliveryFailure.badRequest:
      case ActiveDeliveryFailure.server:
        return 'Unable to verify the code';
    }
  }

  // ignore: avoid_print
  void _logTransition(JeeberDeliveryStatus from, JeeberDeliveryStatus to) {
    // ignore: avoid_print
    print('[delivery.status_transition] from=${from.apiValue} to=${to.apiValue}');
  }
}
