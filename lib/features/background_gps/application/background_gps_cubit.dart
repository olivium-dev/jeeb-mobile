import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/network_reachability_signals.dart';
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
    NetworkReachabilitySignals? reachability,
  }) : _gateway = gateway,
       _uploader = uploader,
       _config = config,
       _clock = clock,
       super(const BackgroundGpsState()) {
    // A reconnect is the one honest reason to forget a back-off: the reason
    // the uploads were failing has just gone away.
    _reconnect = (reachability ?? NetworkReachabilitySignals.instance)
        .stream
        .listen((_) => _onReconnect());
  }

  final GeocaptureGateway _gateway;
  final LocationUploader _uploader;
  final BackgroundGpsConfig _config;
  final DateTime Function() _clock;

  StreamSubscription<GpsSample>? _subscription;
  StreamSubscription<void>? _reconnect;

  /// Set after a transient failure; samples before it are parked, not dropped
  /// silently, so `uploadRetryBackoff` finally means something.
  DateTime? _backoffUntil;
  Future<void>? _inFlightUpload;
  Future<void>? _inFlightStart;
  String? _startingDeliveryId;
  int _startGeneration = 0;

  static DateTime _systemClock() => DateTime.now();

  Future<void> start(String deliveryId) {
    if (state.phase == BackgroundGpsPhase.tracking &&
        state.deliveryId == deliveryId) {
      return Future<void>.value();
    }
    final generation = _startGeneration;
    final inFlight = _inFlightStart;
    if (inFlight != null) {
      if (_startingDeliveryId == deliveryId) return inFlight;
      return inFlight.then((_) {
        if (!_isCurrentStart(generation)) return Future<void>.value();
        return start(deliveryId);
      });
    }

    _startingDeliveryId = deliveryId;
    late final Future<void> guarded;
    guarded = _start(deliveryId, generation).whenComplete(() {
      if (!identical(_inFlightStart, guarded)) return;
      _inFlightStart = null;
      _startingDeliveryId = null;
    });
    _inFlightStart = guarded;
    return guarded;
  }

  Future<void> _start(String deliveryId, int generation) async {
    await _teardown();
    if (!_isCurrentStart(generation)) return;
    _emitPhase(
      BackgroundGpsState(
        phase: BackgroundGpsPhase.requestingPermission,
        permission: state.permission,
        deliveryId: deliveryId,
      ),
    );

    final permission = await _resolvePermission(generation);
    if (permission == null || !_isCurrentStart(generation)) return;
    if (!_canTrackWith(permission)) {
      _emitPhase(
        state.copyWith(
          phase: BackgroundGpsPhase.permissionDenied,
          permission: permission,
        ),
      );
      return;
    }

    _subscription = _gateway.samples().listen(
      _onSample,
      onError: (_) => _onStreamError(),
      cancelOnError: false,
    );
    _emitPhase(
      state.copyWith(
        phase: BackgroundGpsPhase.tracking,
        permission: permission,
        consecutiveFailures: 0,
        lastSkipReason: null,
      ),
    );
  }

  Future<LocationPermission?> _resolvePermission(int generation) async {
    var permission = await _gateway.currentPermission();
    if (!_isCurrentStart(generation)) return null;
    if (_canTrackWith(permission)) return permission;
    if (permission == LocationPermission.deniedForever) return permission;

    if (permission == LocationPermission.notDetermined ||
        permission == LocationPermission.denied) {
      permission = await _gateway.requestWhileInUsePermission();
      if (!_isCurrentStart(generation)) return null;
    }
    if (_canTrackWith(permission)) return permission;
    if (permission != LocationPermission.whileInUse) return permission;

    permission = await _gateway.requestAlwaysPermission();
    return _isCurrentStart(generation) ? permission : null;
  }

  bool _isCurrentStart(int generation) =>
      !isClosed && generation == _startGeneration;

  bool _canTrackWith(LocationPermission permission) =>
      permission == LocationPermission.always ||
      (permission == LocationPermission.whileInUse &&
          _gateway.supportsBackgroundTrackingWithWhileInUse);

  Future<void> stop() async {
    _invalidatePendingStarts();
    await _teardown();
    _emitPhase(BackgroundGpsState(permission: state.permission));
  }

  void _invalidatePendingStarts() {
    _startGeneration += 1;
    _inFlightStart = null;
    _startingDeliveryId = null;
  }

  Future<void> retryPermission() async {
    final id = state.deliveryId;
    if (id == null) return;
    await start(id);
  }

  /// Re-arms the loop after [BackgroundGpsPhase.error] — same act as a
  /// permission retry, different reason.
  Future<void> resume() async {
    _backoffUntil = null;
    final id = state.deliveryId;
    if (id == null) return;
    await start(id);
  }

  void _onReconnect() {
    if (isClosed) return;
    _backoffUntil = null;
    if (state.consecutiveFailures > 0) {
      emit(state.copyWith(consecutiveFailures: 0));
    }
    if (state.phase == BackgroundGpsPhase.error) {
      unawaited(resume());
    }
  }

  Future<bool> openSystemSettings() => _gateway.openAppSettings();

  Future<void> _onSample(GpsSample sample) async {
    if (state.phase != BackgroundGpsPhase.tracking) return;

    final backoff = _backoffUntil;
    if (backoff != null) {
      if (_clock().isBefore(backoff)) {
        emit(
          state.copyWith(
            lastSkipReason: GpsSampleSkipReason.throttled,
            discardedCount: state.discardedCount + 1,
          ),
        );
        return;
      }
      _backoffUntil = null;
    }

    if (sample.accuracyMeters > _config.maxAccuracyMeters) {
      emit(
        state.copyWith(
          lastSkipReason: GpsSampleSkipReason.accuracyTooLow,
          discardedCount: state.discardedCount + 1,
        ),
      );
      return;
    }

    final stationary = sample.speedMps < _config.stationaryThresholdMps;
    final interval = stationary
        ? _config.stationaryInterval
        : _config.activeInterval;
    final last = state.lastUploadAt;
    if (last != null && sample.capturedAt.difference(last) < interval) {
      emit(
        state.copyWith(
          stationary: stationary,
          lastSkipReason: GpsSampleSkipReason.throttled,
          discardedCount: state.discardedCount + 1,
        ),
      );
      return;
    }

    if (_inFlightUpload != null) {
      emit(
        state.copyWith(
          stationary: stationary,
          lastSkipReason: GpsSampleSkipReason.throttled,
          discardedCount: state.discardedCount + 1,
        ),
      );
      return;
    }

    final delivery = state.deliveryId;
    if (delivery == null) return;

    final pending = _uploader.upload(deliveryId: delivery, sample: sample);
    _inFlightUpload = pending.then((_) {}, onError: (_) {});
    final LocationUploadOutcome outcome;
    try {
      outcome = await pending;
    } catch (e) {
      // A thrown 403 is a verdict, not a blip: retrying it forever burns the
      // battery on a loop that can never succeed.
      _inFlightUpload = null;
      final AppFailure failure = AppFailure.of(e);
      if (failure.isRetryable) {
        _onUploadFailure(stationary);
      } else {
        await _teardown();
        _emitPhase(
          state.copyWith(
            phase: BackgroundGpsPhase.error,
            stationary: stationary,
          ),
        );
      }
      return;
    }
    _inFlightUpload = null;

    switch (outcome) {
      case LocationUploadOutcome.accepted:
        emit(
          state.copyWith(
            stationary: stationary,
            lastUploaded: sample,
            lastUploadAt: _clock(),
            lastSkipReason: null,
            consecutiveFailures: 0,
            uploadedCount: state.uploadedCount + 1,
          ),
        );
        _backoffUntil = null;
        // `bg_gps_phase` only fires when the PHASE changes, i.e. before the
        // first upload — which is why its `uploaded` always read 0.
        Diag.event('bg_gps_upload', <String, Object?>{
          'deliveryId': delivery,
          'uploaded': state.uploadedCount,
          'discarded': state.discardedCount,
          'stationary': stationary,
        });
      case LocationUploadOutcome.transientFailure:
        _onUploadFailure(stationary);
      case LocationUploadOutcome.permanentFailure:
        await _teardown();
        _emitPhase(
          state.copyWith(
            phase: BackgroundGpsPhase.error,
            stationary: stationary,
          ),
        );
    }
  }

  void _onUploadFailure(bool stationary) {
    _backoffUntil = _clock().add(_config.uploadRetryBackoff);
    final next = state.consecutiveFailures + 1;
    if (next >= _config.maxConsecutiveUploadFailures) {
      _teardown();
      _emitPhase(
        state.copyWith(
          phase: BackgroundGpsPhase.error,
          stationary: stationary,
          consecutiveFailures: next,
        ),
      );
      return;
    }
    emit(state.copyWith(stationary: stationary, consecutiveFailures: next));
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
        'why':
            'Location permission is insufficient for the configured '
            'background capture mode',
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
    _invalidatePendingStarts();
    await _reconnect?.cancel();
    _reconnect = null;
    await _teardown();
    return super.close();
  }
}
