import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
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
///   2. The cubit walks the Android 10+ INCREMENTAL permission escalation (see
///      [start]). Anything short of [LocationPermission.always] parks us in
///      [BackgroundGpsPhase.permissionDenied] — UI surfaces the banner.
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
///
/// ## P0, 2026-07-31 — wired but still dead, and SILENTLY so
///
/// Being mounted was not enough. `ACCESS_BACKGROUND_LOCATION` was never
/// declared in `AndroidManifest.xml`, and geolocator refuses to report
/// `always` on Android 10+ unless the app declares it
/// (`PermissionManager.java:71-76`). So step 2 above ALWAYS failed, every
/// delivery parked in [BackgroundGpsPhase.permissionDenied], and
/// `POST /location/update` was never called even once — measured over a full
/// jeeber session: 0 rows, and every customer tracking read came back
/// `"position":null`, never a stale one.
///
/// The reason it survived so long is the second half of the bug: **nothing
/// reported it.** The park emitted no log line and raised no UI, so a jeeber,
/// a customer, and an engineer reading logcat all saw exactly the same thing
/// they would have seen if it were working. Both halves are fixed together —
/// every phase transition now emits a `bg_gps_phase` `[jeeb-diag]` breadcrumb
/// ([_emitPhase]) and the park raises an OMDS banner on the Active Delivery
/// screen. Do not remove either: a silent park is the defect, not the symptom.
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

  /// Walks the Android 10+ (API 29+) INCREMENTAL background-location
  /// escalation and returns the best permission we ended up holding.
  ///
  /// The order is imposed by the platform, not a preference. From Android 11
  /// (API 30) on, requesting a foreground location permission together with
  /// `ACCESS_BACKGROUND_LOCATION` in one call makes the system **ignore the
  /// whole request and grant neither**. So:
  ///
  ///   1. already `always` → nothing to do (re-prompting would be user-hostile);
  ///   2. `deniedForever` → the OS will not prompt again; asking is a silent
  ///      no-op, so return immediately and let the UI offer settings instead of
  ///      pretending a prompt happened;
  ///   3. `notDetermined`/`denied` → request FOREGROUND only, then fall through;
  ///   4. `whileInUse` → a SECOND, separate request escalates to background.
  ///
  /// Step 4 is explicitly allowed to fail: on Android 11+ the platform does not
  /// grant "Allow all the time" from a dialog at all — it sends the user to the
  /// app's location settings page — so `whileInUse` coming back out of step 4
  /// is the NORMAL first-run outcome, not an error. The caller parks, logs, and
  /// shows the banner; the jeeber recovers via [openSystemSettings].
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

  /// Stops the pipeline and returns to [BackgroundGpsPhase.idle].
  Future<void> stop() async {
    await _teardown();
    _emitPhase(BackgroundGpsState(permission: state.permission));
  }

  /// Re-runs the permission flow without restarting the cubit. Wired to the
  /// "Try again" CTA on the permission banner, and called on app resume so a
  /// grant the jeeber just made in system settings is picked up without them
  /// having to leave and re-enter the delivery.
  Future<void> retryPermission() async {
    final id = state.deliveryId;
    if (id == null) return;
    await start(id);
  }

  /// Opens this app's OS settings page — the ONLY route to "Allow all the
  /// time" on Android 11+, and the only recovery at all from a permanent
  /// denial. Wired to the banner's "Open settings" CTA. Returns whether the
  /// page opened; the grant itself is picked up by [retryPermission] on resume.
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

  /// Emits [next] AND, when the phase or the permission actually changed, drops
  /// a `bg_gps_phase` record on the `[jeeb-diag]` logcat stream.
  ///
  /// This is the observability half of the P0. The uploader's whole state
  /// machine used to be invisible: a delivery that parked in
  /// [BackgroundGpsPhase.permissionDenied] produced byte-for-byte the same log
  /// output as one that was uploading fine, so
  /// `adb logcat | grep '\[jeeb-diag\]'` could not tell a working jeeber from a
  /// broken one. Now it can:
  ///
  ///   [jeeb-diag] {"t":"evt","name":"bg_gps_phase",
  ///                "data":{"phase":"tracking","permission":"always",…}}
  ///   [jeeb-diag] {"t":"evt","name":"bg_gps_permission_failure",
  ///                "data":{"permission":"whileInUse",…}}
  ///
  /// Gated on a REAL transition so the per-fix skip/throttle emissions (several
  /// a minute while en route) do not flood the stream — a phase line means
  /// something actually moved.
  ///
  /// The second record is emitted only for the two dead-end phases. Its name
  /// ends in `_failure` on purpose: `Diag._isFailureRecord` matches on that and
  /// flushes the persistence buffer promptly, so an exported session keeps the
  /// evidence even if the app dies right after.
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
