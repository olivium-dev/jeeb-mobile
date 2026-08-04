import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../domain/background_gps_config.dart';
import '../domain/geocapture_gateway.dart';
import '../domain/gps_sample.dart';
import '../domain/location_permission.dart';
import '../domain/location_uploader.dart';
import 'background_gps_state.dart';

class BackgroundGpsCubit extends Cubit<BackgroundGpsState> {
  BackgroundGpsCubit({
    required GeocaptureGateway gateway,
    required LocationUploader uploader,
    BackgroundGpsConfig config = const BackgroundGpsConfig(),
    DateTime Function() clock = _systemClock,
  })  : _gateway = gateway,
        _uploader = uploader,
        _config = config,
        _clock = clock,
        super(const BackgroundGpsState());

  final GeocaptureGateway _gateway;
  final LocationUploader _uploader;
  final BackgroundGpsConfig _config;
  final DateTime Function() _clock;

  StreamSubscription<GpsSample>? _subscription;
  Future<void>? _inFlightUpload;

  static DateTime _systemClock() => DateTime.now();

  Future<void> start(String deliveryId) async {
    if (state.phase == BackgroundGpsPhase.tracking &&
        state.deliveryId == deliveryId) {
      return;
    }
    await _teardown();
    _emitPhase(BackgroundGpsState(
      phase: BackgroundGpsPhase.requestingPermission,
      permission: state.permission,
      deliveryId: deliveryId,
    ));

    final permission = await _resolvePermission();
    if (permission != LocationPermission.always) {
      _emitPhase(state.copyWith(
        phase: BackgroundGpsPhase.permissionDenied,
        permission: permission,
      ));
      return;
    }

    _subscription = _gateway.samples().listen(
          _onSample,
          onError: (_) => _onStreamError(),
          cancelOnError: false,
        );
    _emitPhase(state.copyWith(
      phase: BackgroundGpsPhase.tracking,
      permission: permission,
      consecutiveFailures: 0,
      lastSkipReason: null,
    ));
  }

  Future<LocationPermission> _resolvePermission() async {
    var permission = await _gateway.currentPermission();
    if (permission == LocationPermission.always) return permission;
    if (permission == LocationPermission.deniedForever) return permission;

    if (permission == LocationPermission.notDetermined ||
        permission == LocationPermission.denied) {
      permission = await _gateway.requestWhileInUsePermission();
    }
    if (permission != LocationPermission.whileInUse) return permission;

    return _gateway.requestAlwaysPermission();
  }

  Future<void> stop() async {
    await _teardown();
    _emitPhase(BackgroundGpsState(permission: state.permission));
  }

  Future<void> retryPermission() async {
    final id = state.deliveryId;
    if (id == null) return;
    await start(id);
  }

  Future<bool> openSystemSettings() => _gateway.openAppSettings();

  Future<void> _onSample(GpsSample sample) async {
    if (state.phase != BackgroundGpsPhase.tracking) return;

    if (sample.accuracyMeters > _config.maxAccuracyMeters) {
      emit(state.copyWith(
        lastSkipReason: GpsSampleSkipReason.accuracyTooLow,
        discardedCount: state.discardedCount + 1,
      ));
      return;
    }

    final stationary = sample.speedMps < _config.stationaryThresholdMps;
    final interval = stationary
        ? _config.stationaryInterval
        : _config.activeInterval;
    final last = state.lastUploadAt;
    if (last != null && sample.capturedAt.difference(last) < interval) {
      emit(state.copyWith(
        stationary: stationary,
        lastSkipReason: GpsSampleSkipReason.throttled,
        discardedCount: state.discardedCount + 1,
      ));
      return;
    }

    if (_inFlightUpload != null) {
      emit(state.copyWith(
        stationary: stationary,
        lastSkipReason: GpsSampleSkipReason.throttled,
        discardedCount: state.discardedCount + 1,
      ));
      return;
    }

    final delivery = state.deliveryId;
    if (delivery == null) return;

    final pending = _uploader.upload(deliveryId: delivery, sample: sample);
    _inFlightUpload = pending.then((_) {}, onError: (_) {});
    final LocationUploadOutcome outcome;
    try {
      outcome = await pending;
    } catch (_) {
      _inFlightUpload = null;
      _onUploadFailure(stationary);
      return;
    }
    _inFlightUpload = null;

    switch (outcome) {
      case LocationUploadOutcome.accepted:
        emit(state.copyWith(
          stationary: stationary,
          lastUploaded: sample,
          lastUploadAt: _clock(),
          lastSkipReason: null,
          consecutiveFailures: 0,
          uploadedCount: state.uploadedCount + 1,
        ));
      case LocationUploadOutcome.transientFailure:
        _onUploadFailure(stationary);
      case LocationUploadOutcome.permanentFailure:
        await _teardown();
        _emitPhase(state.copyWith(
          phase: BackgroundGpsPhase.error,
          stationary: stationary,
        ));
    }
  }

  void _onUploadFailure(bool stationary) {
    final next = state.consecutiveFailures + 1;
    if (next >= _config.maxConsecutiveUploadFailures) {
      _teardown();
      _emitPhase(state.copyWith(
        phase: BackgroundGpsPhase.error,
        stationary: stationary,
        consecutiveFailures: next,
      ));
      return;
    }
    emit(state.copyWith(
      stationary: stationary,
      consecutiveFailures: next,
    ));
  }

  void _onStreamError() {
    if (state.phase != BackgroundGpsPhase.tracking) return;
    _onUploadFailure(state.stationary);
  }

  void _emitPhase(BackgroundGpsState next) {
    final changed =
        next.phase != state.phase || next.permission != state.permission;
    emit(next);
    if (!changed) return;
    Diag.event('bg_gps_phase', <String, Object?>{
      'phase': next.phase.name,
      'permission': next.permission.name,
      'deliveryId': next.deliveryId,
      'uploaded': next.uploadedCount,
      'discarded': next.discardedCount,
    });
    if (next.phase == BackgroundGpsPhase.permissionDenied) {
      Diag.event('bg_gps_permission_failure', <String, Object?>{
        'permission': next.permission.name,
        'deliveryId': next.deliveryId,
        'needsSystemSettings': next.needsSystemSettings,
        'why': 'ACCESS_BACKGROUND_LOCATION not granted — no fix will be '
            'uploaded and the customer live-tracking map stays empty',
      });
    } else if (next.phase == BackgroundGpsPhase.error) {
      Diag.event('bg_gps_upload_failure', <String, Object?>{
        'consecutiveFailures': next.consecutiveFailures,
        'deliveryId': next.deliveryId,
      });
    }
  }

  Future<void> _teardown() async {
    await _subscription?.cancel();
    _subscription = null;
    _inFlightUpload = null;
    await _gateway.stop();
  }

  @override
  Future<void> close() async {
    await _teardown();
    return super.close();
  }
}
