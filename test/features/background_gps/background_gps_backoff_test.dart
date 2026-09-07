// BGPS-02 / OFF-27 — the declared back-off is actually applied, a reconnect
// clears it, and a NON-retryable thrown error stops the loop instead of
// retrying it forever.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
import 'package:jeeb_mobile/features/background_gps/application/background_gps_cubit.dart';
import 'package:jeeb_mobile/features/background_gps/application/background_gps_state.dart';
import 'package:jeeb_mobile/features/background_gps/domain/background_gps_config.dart';
import 'package:jeeb_mobile/features/background_gps/domain/geocapture_gateway.dart';
import 'package:jeeb_mobile/features/background_gps/domain/gps_sample.dart';
import 'package:jeeb_mobile/features/background_gps/domain/location_permission.dart';
import 'package:jeeb_mobile/features/background_gps/domain/location_uploader.dart';

class _Gateway implements GeocaptureGateway {
  // ignore: close_sinks — every test closes it in its own teardown.
  final StreamController<GpsSample> controller =
      StreamController<GpsSample>.broadcast();

  @override
  bool get supportsBackgroundTrackingWithWhileInUse => true;

  @override
  Future<LocationPermission> currentPermission() async =>
      LocationPermission.always;

  @override
  Future<LocationPermission> requestAlwaysPermission() async =>
      LocationPermission.always;

  @override
  Future<LocationPermission> requestWhileInUsePermission() async =>
      LocationPermission.always;

  @override
  Stream<GpsSample> samples() => controller.stream;

  @override
  Future<void> stop() async {}

  @override
  Future<bool> openAppSettings() async => true;
}

class _Uploader implements LocationUploader {
  _Uploader(this.answer);

  final Future<LocationUploadOutcome> Function() answer;
  int calls = 0;

  @override
  Future<LocationUploadOutcome> upload({
    required String deliveryId,
    required GpsSample sample,
  }) {
    calls++;
    return answer();
  }
}

GpsSample _sample(DateTime at) => GpsSample(
      latitude: 33.88,
      longitude: 35.5,
      accuracyMeters: 5,
      speedMps: 8,
      headingDegrees: 0,
      capturedAt: at,
    );

void main() {
  late DateTime now;
  late NetworkReachabilitySignals reachability;

  setUp(() {
    now = DateTime.utc(2026, 9, 5, 12);
    reachability = NetworkReachabilitySignals();
  });

  Future<BackgroundGpsCubit> start(_Gateway gateway, _Uploader uploader) async {
    final cubit = BackgroundGpsCubit(
      gateway: gateway,
      uploader: uploader,
      clock: () => now,
      reachability: reachability,
      config: const BackgroundGpsConfig(
        activeInterval: Duration.zero,
        stationaryInterval: Duration.zero,
        uploadRetryBackoff: Duration(seconds: 30),
      ),
    );
    await cubit.start('DLV-1');
    return cubit;
  }

  test('a transient failure parks the next sample for uploadRetryBackoff',
      () async {
    final gateway = _Gateway();
    final uploader = _Uploader(
      () async => LocationUploadOutcome.transientFailure,
    );
    final cubit = await start(gateway, uploader);

    gateway.controller.add(_sample(now));
    await Future<void>.delayed(Duration.zero);
    expect(uploader.calls, 1);

    // Inside the window: parked, not uploaded.
    now = now.add(const Duration(seconds: 5));
    gateway.controller.add(_sample(now));
    await Future<void>.delayed(Duration.zero);
    expect(uploader.calls, 1);

    // Past the window: the loop resumes.
    now = now.add(const Duration(seconds: 40));
    gateway.controller.add(_sample(now));
    await Future<void>.delayed(Duration.zero);
    expect(uploader.calls, 2);

    await cubit.close();
    await gateway.controller.close();
  });

  test('a reconnect edge clears the back-off and the failure streak', () async {
    final gateway = _Gateway();
    final uploader = _Uploader(
      () async => LocationUploadOutcome.transientFailure,
    );
    final cubit = await start(gateway, uploader);

    gateway.controller.add(_sample(now));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.consecutiveFailures, 1);

    reachability
      ..debugObserve(online: false)
      ..debugObserve(online: true);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.consecutiveFailures, 0);

    now = now.add(const Duration(seconds: 1));
    gateway.controller.add(_sample(now));
    await Future<void>.delayed(Duration.zero);
    expect(uploader.calls, 2, reason: 'the back-off was forgotten');

    await cubit.close();
    await gateway.controller.close();
  });

  test('a NON-retryable thrown error goes straight to the error phase',
      () async {
    final gateway = _Gateway();
    final uploader = _Uploader(
      () async => throw const ForbiddenFailure(),
    );
    final cubit = await start(gateway, uploader);

    gateway.controller.add(_sample(now));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.phase, BackgroundGpsPhase.error);
    expect(cubit.state.isGpsFailed, isTrue);

    await cubit.close();
    await gateway.controller.close();
  });
}
