import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/background_gps_config.dart';
import '../domain/geocapture_gateway.dart';
import '../domain/gps_sample.dart';
import '../domain/location_permission.dart';
import '../domain/location_uploader.dart';
import 'background_gps_state.dart';

/// Owns the background-GPS pipeline for a single active delivery.
///
/// Lifecycle, exactly as JEEB-73 spells it out:
///   1. `start(deliveryId)` is called when the Jeeber accepts a pickup.
///   2. The cubit asks the gateway for Always-on permission. Anything
///      short of [LocationPermission.always] parks us in
///      [BackgroundGpsPhase.permissionDenied] — UI surfaces the prompt.
///   3. Subscribes to `gateway.samples()`. Every fix runs the accuracy
///      filter, then the time-based throttle. Surviving fixes hit
///      `uploader.upload(deliveryId, sample)`.
///   4. Stationary samples (speed below
///      [BackgroundGpsConfig.stationaryThresholdMps]) flip the throttle
///      to the stationary interval — biggest battery win.
///   5. `stop()` tears down the subscription + plugin.
///
/// The cubit is pure state — it never imports the `geocapture-flutter`
/// plugin directly. Boundaries §F9.
///
/// JEBV4-269 (2026-07-14): WIRED. Previously an orphan (JEBV4-227) — the whole
/// pipeline was built for JEEB-73 but never mounted, so a jeeber's GPS never
/// reached the gateway and the customer's live-tracking map had no data. It is
/// now owned by [ActiveDeliveryCubit], which calls [start]/[stop] as the
/// delivery enters/leaves the `InTransit` phase (see its `_syncGpsUpload`).
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

  /// Begins tracking the given delivery. Re-entrant: calling [start] twice
  /// with the same delivery id is a no-op, calling it with a different id
  /// stops the previous stream first.
  Future<void> start(String deliveryId) async {
    if (state.phase == BackgroundGpsPhase.tracking &&
        state.deliveryId == deliveryId) {
      return;
    }
    await _teardown();
    emit(BackgroundGpsState(
      phase: BackgroundGpsPhase.requestingPermission,
      deliveryId: deliveryId,
    ));

    var permission = await _gateway.currentPermission();
    // JEBV4-269 (Option A): a foreground ("while in use") grant is sufficient —
    // the uploader only streams while the active-delivery screen is foregrounded,
    // and background "always" is unobtainable on this build (no manifest perm).
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      permission = await _gateway.requestAlwaysPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      emit(state.copyWith(phase: BackgroundGpsPhase.permissionDenied));
      return;
    }

    _subscription = _gateway.samples().listen(
          _onSample,
          onError: (_) => _onStreamError(),
          cancelOnError: false,
        );
    emit(state.copyWith(
      phase: BackgroundGpsPhase.tracking,
      consecutiveFailures: 0,
      lastSkipReason: null,
    ));
  }

  /// Stops the pipeline and returns to [BackgroundGpsPhase.idle].
  Future<void> stop() async {
    await _teardown();
    emit(const BackgroundGpsState());
  }

  /// Re-runs the permission flow without restarting the cubit. Wired to
  /// the "Open system settings" CTA on the permission-denied banner.
  Future<void> retryPermission() async {
    final id = state.deliveryId;
    if (id == null) return;
    await start(id);
  }

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

    // Single-flight: if a prior upload hasn't returned, drop this sample
    // rather than queue. The next emission will fall through naturally.
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
        emit(state.copyWith(
          phase: BackgroundGpsPhase.error,
          stationary: stationary,
        ));
    }
  }

  void _onUploadFailure(bool stationary) {
    final next = state.consecutiveFailures + 1;
    if (next >= _config.maxConsecutiveUploadFailures) {
      _teardown();
      emit(state.copyWith(
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
