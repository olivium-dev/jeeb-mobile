import 'dart:async';

import '../domain/geocapture_gateway.dart';
import '../domain/gps_sample.dart';
import '../domain/location_permission.dart';

/// Test double for [GeocaptureGateway].
///
/// `permissionScript` is consumed left-to-right per `currentPermission()` /
/// `requestWhileInUsePermission()` / `requestAlwaysPermission()` call — once
/// exhausted, the last value sticks. `emit` pushes a sample through the
/// broadcast stream so the cubit's listener fires synchronously.
///
/// The two request methods are counted SEPARATELY ([whileInUseRequestCount],
/// [alwaysRequestCount]) so a test can assert the Android 10+ incremental
/// order — foreground first, background second — and not merely that "a
/// prompt happened". [requestCount] is their sum, kept for the older
/// assertions.
class FakeGeocaptureGateway implements GeocaptureGateway {
  FakeGeocaptureGateway({
    List<LocationPermission>? permissionScript,
    LocationPermission initialPermission = LocationPermission.always,
    this.settingsOpenResult = true,
  })  : _permissionScript = List<LocationPermission>.from(
          permissionScript ?? <LocationPermission>[],
        ),
        _lastPermission = initialPermission;

  /// What [openAppSettings] reports back — `false` models a device where the
  /// settings intent could not be resolved.
  final bool settingsOpenResult;

  final List<LocationPermission> _permissionScript;
  LocationPermission _lastPermission;
  final StreamController<GpsSample> _controller =
      StreamController<GpsSample>.broadcast();
  /// Latches on the FIRST [stop] and never clears. Note that
  /// `BackgroundGpsCubit.start()` tears down before it subscribes, so this is
  /// already `true` by the time the pipeline reaches `tracking` — asserting it
  /// is `true` after a delivery completes proves nothing. Use [stopCount].
  bool stopped = false;

  /// How many times [stop] was called. Unlike [stopped] this can distinguish
  /// "the stream was torn down again" from "it was torn down once, at start" —
  /// which is the difference between an uploader that survives the screen and
  /// one that dies with it (the 2026-08-01 P1).
  int stopCount = 0;

  /// Ordered log of the permission calls the cubit made, by port method name
  /// (`current`, `whileInUse`, `always`). Lets a test assert the SEQUENCE, not
  /// just the counts — the sequence is the whole point of the incremental flow.
  final List<String> permissionCalls = <String>[];

  /// Number of times the cubit asked for the FOREGROUND prompt (step 1).
  int whileInUseRequestCount = 0;

  /// Number of times the cubit asked for the BACKGROUND escalation (step 2).
  int alwaysRequestCount = 0;

  /// Number of times [openAppSettings] was called.
  int openAppSettingsCount = 0;

  /// Total prompts raised, either kind.
  int get requestCount => whileInUseRequestCount + alwaysRequestCount;

  @override
  Future<LocationPermission> currentPermission() async {
    permissionCalls.add('current');
    return _next();
  }

  @override
  Future<LocationPermission> requestWhileInUsePermission() async {
    permissionCalls.add('whileInUse');
    whileInUseRequestCount += 1;
    return _next();
  }

  @override
  Future<LocationPermission> requestAlwaysPermission() async {
    permissionCalls.add('always');
    alwaysRequestCount += 1;
    return _next();
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCount += 1;
    return settingsOpenResult;
  }

  LocationPermission _next() {
    if (_permissionScript.isEmpty) return _lastPermission;
    final next = _permissionScript.removeAt(0);
    _lastPermission = next;
    return next;
  }

  @override
  Stream<GpsSample> samples() => _controller.stream;

  @override
  Future<void> stop() async {
    stopped = true;
    stopCount += 1;
  }

  /// Pushes a sample through and yields so the cubit's listener runs
  /// before the test continues. Tests should `await` this.
  Future<void> emit(GpsSample sample) async {
    _controller.add(sample);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> emitError(Object error) async {
    _controller.addError(error);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
