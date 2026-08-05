import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/background_gps/application/background_gps_cubit.dart';
import 'package:jeeb_mobile/features/background_gps/application/background_gps_state.dart';
import 'package:jeeb_mobile/features/background_gps/data/fake_geocapture_gateway.dart';
import 'package:jeeb_mobile/features/background_gps/data/in_memory_location_uploader.dart';
import 'package:jeeb_mobile/features/background_gps/domain/background_gps_config.dart';
import 'package:jeeb_mobile/features/background_gps/domain/geocapture_gateway.dart';
import 'package:jeeb_mobile/features/background_gps/domain/gps_sample.dart';
import 'package:jeeb_mobile/features/background_gps/domain/location_permission.dart';
import 'package:jeeb_mobile/features/background_gps/domain/location_uploader.dart';

// Compressed cadences so the unit tests stay in millisecond-land.
const _testConfig = BackgroundGpsConfig(
  activeInterval: Duration(milliseconds: 50),
  stationaryInterval: Duration(milliseconds: 300),
  maxAccuracyMeters: 50,
  stationaryThresholdMps: 0.5,
  maxConsecutiveUploadFailures: 3,
);

GpsSample _sample({
  double accuracy = 8,
  double speed = 6,
  DateTime? capturedAt,
}) {
  return GpsSample(
    latitude: 33.88,
    longitude: 35.5,
    accuracyMeters: accuracy,
    speedMps: speed,
    headingDegrees: 90,
    capturedAt: capturedAt ?? DateTime.utc(2026, 5, 17, 12),
  );
}

BackgroundGpsCubit _buildCubit({
  required FakeGeocaptureGateway gateway,
  required InMemoryLocationUploader uploader,
  BackgroundGpsConfig config = _testConfig,
  DateTime Function()? clock,
}) {
  final cubit = BackgroundGpsCubit(
    gateway: gateway,
    uploader: uploader,
    config: config,
    clock: clock ?? () => DateTime.utc(2026, 5, 17, 12),
  );
  addTearDown(cubit.close);
  addTearDown(gateway.dispose);
  return cubit;
}

class _ControlledPermissionGateway implements GeocaptureGateway {
  final permissionRequests = <Completer<LocationPermission>>[];
  final _samples = StreamController<GpsSample>.broadcast();

  int currentPermissionCalls = 0;
  int sampleListenCount = 0;
  int stopCount = 0;

  @override
  bool get supportsBackgroundTrackingWithWhileInUse => true;

  @override
  Future<LocationPermission> currentPermission() {
    currentPermissionCalls += 1;
    final request = Completer<LocationPermission>();
    permissionRequests.add(request);
    return request.future;
  }

  @override
  Future<LocationPermission> requestAlwaysPermission() =>
      Future<LocationPermission>.value(LocationPermission.always);

  @override
  Future<LocationPermission> requestWhileInUsePermission() =>
      Future<LocationPermission>.value(LocationPermission.whileInUse);

  @override
  Future<bool> openAppSettings() => Future<bool>.value(true);

  @override
  Stream<GpsSample> samples() {
    sampleListenCount += 1;
    return _samples.stream;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  Future<void> dispose() => _samples.close();
}

void main() {
  group('BackgroundGpsCubit — permission flow', () {
    test(
      'starts in idle and refuses to emit samples until start() is called',
      () async {
        final gateway = FakeGeocaptureGateway(
          initialPermission: LocationPermission.always,
        );
        final uploader = InMemoryLocationUploader();
        final cubit = _buildCubit(gateway: gateway, uploader: uploader);
        expect(cubit.state.phase, BackgroundGpsPhase.idle);

        await gateway.emit(_sample());
        expect(
          uploader.calls,
          isEmpty,
          reason: 'samples before start() must be dropped',
        );
      },
    );

    test(
      'skips the prompt when Always permission is already granted',
      () async {
        final gateway = FakeGeocaptureGateway(
          initialPermission: LocationPermission.always,
        );
        final cubit = _buildCubit(
          gateway: gateway,
          uploader: InMemoryLocationUploader(),
        );

        await cubit.start('delivery-1');
        expect(cubit.state.phase, BackgroundGpsPhase.tracking);
        expect(cubit.state.deliveryId, 'delivery-1');
        expect(
          gateway.requestCount,
          0,
          reason: 'no system prompt when permission is already always',
        );
      },
    );

    test(
      'prompts when current permission is not always, succeeds on grant',
      () async {
        final gateway = FakeGeocaptureGateway(
          permissionScript: [
            LocationPermission.whileInUse, // currentPermission
            LocationPermission.always, // requestAlwaysPermission
          ],
        );
        final cubit = _buildCubit(
          gateway: gateway,
          uploader: InMemoryLocationUploader(),
        );

        await cubit.start('delivery-1');
        expect(gateway.requestCount, 1);
        expect(cubit.state.phase, BackgroundGpsPhase.tracking);
      },
    );

    test('parks in permissionDenied when the user refuses', () async {
      final gateway = FakeGeocaptureGateway(
        permissionScript: [
          LocationPermission.notDetermined,
          LocationPermission.denied,
        ],
      );
      final cubit = _buildCubit(
        gateway: gateway,
        uploader: InMemoryLocationUploader(),
      );

      await cubit.start('delivery-1');
      expect(cubit.state.phase, BackgroundGpsPhase.permissionDenied);

      await gateway.emit(_sample());
      // No uploads in denied state — the stream isn't even subscribed.
      expect(cubit.state.uploadedCount, 0);
    });

    test(
      'whileInUse is denied when the gateway cannot continue in background',
      () async {
        final gateway = FakeGeocaptureGateway(
          permissionScript: [
            LocationPermission.whileInUse,
            LocationPermission.whileInUse,
          ],
        );
        final cubit = _buildCubit(
          gateway: gateway,
          uploader: InMemoryLocationUploader(),
        );

        await cubit.start('delivery-1');
        expect(cubit.state.phase, BackgroundGpsPhase.permissionDenied);
      },
    );

    test(
      'whileInUse starts tracking when backed by a foreground service',
      () async {
        final gateway = FakeGeocaptureGateway(
          initialPermission: LocationPermission.whileInUse,
          supportsBackgroundTrackingWithWhileInUse: true,
        );
        final cubit = _buildCubit(
          gateway: gateway,
          uploader: InMemoryLocationUploader(),
        );

        await cubit.start('delivery-1');

        expect(gateway.permissionCalls, ['current']);
        expect(gateway.requestCount, 0);
        expect(cubit.state.phase, BackgroundGpsPhase.tracking);
        expect(cubit.state.permission, LocationPermission.whileInUse);
        expect(cubit.state.needsSystemSettings, isFalse);
      },
    );
  });

  group('BackgroundGpsCubit — accuracy filter', () {
    test('discards samples worse than the accuracy ceiling', () async {
      final gateway = FakeGeocaptureGateway();
      final uploader = InMemoryLocationUploader();
      final cubit = _buildCubit(gateway: gateway, uploader: uploader);

      await cubit.start('delivery-1');
      await gateway.emit(_sample(accuracy: 120));

      expect(uploader.calls, isEmpty);
      expect(cubit.state.lastSkipReason, GpsSampleSkipReason.accuracyTooLow);
      expect(cubit.state.discardedCount, 1);
    });

    test('accepts samples right at the accuracy ceiling', () async {
      final gateway = FakeGeocaptureGateway();
      final uploader = InMemoryLocationUploader();
      final cubit = _buildCubit(gateway: gateway, uploader: uploader);

      await cubit.start('delivery-1');
      await gateway.emit(_sample(accuracy: 50));

      expect(uploader.calls, hasLength(1));
      expect(cubit.state.uploadedCount, 1);
    });
  });

  group('BackgroundGpsCubit — throttling', () {
    test('keeps the active interval while moving', () async {
      final gateway = FakeGeocaptureGateway();
      final uploader = InMemoryLocationUploader();
      final base = DateTime.utc(2026, 5, 17, 12);
      final cubit = _buildCubit(
        gateway: gateway,
        uploader: uploader,
        clock: () => base,
      );

      await cubit.start('delivery-1');
      await gateway.emit(_sample(capturedAt: base));
      // Same-instant sample — within interval, must be dropped.
      await gateway.emit(
        _sample(capturedAt: base.add(const Duration(milliseconds: 10))),
      );
      // Past the active interval — accepted.
      await gateway.emit(
        _sample(capturedAt: base.add(const Duration(milliseconds: 60))),
      );

      expect(uploader.calls, hasLength(2));
      expect(cubit.state.uploadedCount, 2);
      expect(cubit.state.discardedCount, 1);
    });

    test(
      'falls back to the stationary interval when the rider stops',
      () async {
        final gateway = FakeGeocaptureGateway();
        final uploader = InMemoryLocationUploader();
        final base = DateTime.utc(2026, 5, 17, 12);
        final cubit = _buildCubit(
          gateway: gateway,
          uploader: uploader,
          clock: () => base,
        );

        await cubit.start('delivery-1');
        await gateway.emit(_sample(speed: 0.1, capturedAt: base));
        expect(cubit.state.stationary, isTrue);

        // 100 ms later — past the active interval (50 ms) but below
        await gateway.emit(
          _sample(
            speed: 0.1,
            capturedAt: base.add(const Duration(milliseconds: 100)),
          ),
        );
        // Past the stationary interval — accepted.
        await gateway.emit(
          _sample(
            speed: 0.1,
            capturedAt: base.add(const Duration(milliseconds: 350)),
          ),
        );

        expect(uploader.calls, hasLength(2));
        expect(
          cubit.state.lastSkipReason,
          isNull,
          reason: 'cleared on the most recent successful upload',
        );
      },
    );
  });

  group('BackgroundGpsCubit — upload outcomes', () {
    test(
      'counts transient failures and emits error after the budget',
      () async {
        final gateway = FakeGeocaptureGateway();
        final uploader = InMemoryLocationUploader(
          outcomes: [
            LocationUploadOutcome.transientFailure,
            LocationUploadOutcome.transientFailure,
            LocationUploadOutcome.transientFailure,
          ],
        );
        final base = DateTime.utc(2026, 5, 17, 12);
        final cubit = _buildCubit(gateway: gateway, uploader: uploader);

        await cubit.start('delivery-1');
        await gateway.emit(_sample(capturedAt: base));
        await gateway.emit(
          _sample(capturedAt: base.add(const Duration(milliseconds: 60))),
        );
        await gateway.emit(
          _sample(capturedAt: base.add(const Duration(milliseconds: 120))),
        );

        expect(cubit.state.phase, BackgroundGpsPhase.error);
        expect(cubit.state.consecutiveFailures, 3);
        expect(
          gateway.stopped,
          isTrue,
          reason: 'gateway stopped to release the plugin / battery',
        );
      },
    );

    test('resets the failure counter on the next success', () async {
      final gateway = FakeGeocaptureGateway();
      final uploader = InMemoryLocationUploader(
        outcomes: [
          LocationUploadOutcome.transientFailure,
          LocationUploadOutcome.accepted,
        ],
      );
      final base = DateTime.utc(2026, 5, 17, 12);
      final cubit = _buildCubit(gateway: gateway, uploader: uploader);

      await cubit.start('delivery-1');
      await gateway.emit(_sample(capturedAt: base));
      expect(cubit.state.consecutiveFailures, 1);

      await gateway.emit(
        _sample(capturedAt: base.add(const Duration(milliseconds: 60))),
      );
      expect(cubit.state.consecutiveFailures, 0);
      expect(cubit.state.phase, BackgroundGpsPhase.tracking);
    });

    test('permanent failure stops the loop immediately', () async {
      final gateway = FakeGeocaptureGateway();
      final uploader = InMemoryLocationUploader(
        outcomes: [LocationUploadOutcome.permanentFailure],
      );
      final cubit = _buildCubit(gateway: gateway, uploader: uploader);

      await cubit.start('delivery-1');
      await gateway.emit(_sample());

      expect(cubit.state.phase, BackgroundGpsPhase.error);
      expect(gateway.stopped, isTrue);
    });
  });

  group('BackgroundGpsCubit — lifecycle', () {
    test('stop() tears down to idle and clears the delivery id', () async {
      final gateway = FakeGeocaptureGateway();
      final uploader = InMemoryLocationUploader();
      final cubit = _buildCubit(gateway: gateway, uploader: uploader);

      await cubit.start('delivery-1');
      await cubit.stop();

      expect(cubit.state.phase, BackgroundGpsPhase.idle);
      expect(cubit.state.deliveryId, isNull);
      expect(gateway.stopped, isTrue);
    });

    test('start() with a new delivery id resubscribes cleanly', () async {
      final gateway = FakeGeocaptureGateway();
      final uploader = InMemoryLocationUploader();
      final cubit = _buildCubit(gateway: gateway, uploader: uploader);

      await cubit.start('delivery-1');
      await cubit.start('delivery-2');

      expect(cubit.state.deliveryId, 'delivery-2');
      expect(cubit.state.phase, BackgroundGpsPhase.tracking);
    });

    test('start() with the same id is a no-op', () async {
      final gateway = FakeGeocaptureGateway();
      final uploader = InMemoryLocationUploader();
      final cubit = _buildCubit(gateway: gateway, uploader: uploader);

      await cubit.start('delivery-1');
      final firstRequestCount = gateway.requestCount;
      await cubit.start('delivery-1');

      expect(gateway.requestCount, firstRequestCount);
      expect(cubit.state.phase, BackgroundGpsPhase.tracking);
    });

    test(
      'stop invalidates an unresolved permission attempt without resurrection',
      () async {
        final gateway = _ControlledPermissionGateway();
        final cubit = BackgroundGpsCubit(
          gateway: gateway,
          uploader: InMemoryLocationUploader(),
        );
        addTearDown(cubit.close);
        addTearDown(gateway.dispose);
        final phasesAfterStop = <BackgroundGpsPhase>[];
        final subscription = cubit.stream.listen(
          (state) => phasesAfterStop.add(state.phase),
        );
        addTearDown(subscription.cancel);

        final start = cubit.start('delivery-1');
        await Future<void>.delayed(Duration.zero);
        expect(gateway.currentPermissionCalls, 1);
        expect(cubit.state.phase, BackgroundGpsPhase.requestingPermission);

        await cubit.stop();
        await Future<void>.delayed(Duration.zero);
        phasesAfterStop.clear();
        gateway.permissionRequests.single.complete(LocationPermission.always);
        await start;
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.phase, BackgroundGpsPhase.idle);
        expect(cubit.state.deliveryId, isNull);
        expect(gateway.sampleListenCount, 0);
        expect(phasesAfterStop, isEmpty);
      },
    );

    test(
      'stop cancels queued starts and preserves same-delivery deduplication',
      () async {
        final gateway = _ControlledPermissionGateway();
        final cubit = BackgroundGpsCubit(
          gateway: gateway,
          uploader: InMemoryLocationUploader(),
        );
        addTearDown(cubit.close);
        addTearDown(gateway.dispose);

        final first = cubit.start('delivery-1');
        final duplicate = cubit.start('delivery-1');
        final queued = cubit.start('delivery-2');
        expect(identical(first, duplicate), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(gateway.currentPermissionCalls, 1);

        await cubit.stop();
        gateway.permissionRequests.single.complete(LocationPermission.always);
        await Future.wait<void>([first, duplicate, queued]);

        expect(gateway.currentPermissionCalls, 1);
        expect(gateway.sampleListenCount, 0);
        expect(cubit.state.phase, BackgroundGpsPhase.idle);
        expect(cubit.state.deliveryId, isNull);
      },
    );

    test(
      'a fresh start after stop is independent of the stale attempt',
      () async {
        final gateway = _ControlledPermissionGateway();
        final cubit = BackgroundGpsCubit(
          gateway: gateway,
          uploader: InMemoryLocationUploader(),
        );
        addTearDown(cubit.close);
        addTearDown(gateway.dispose);

        final staleStart = cubit.start('delivery-1');
        await Future<void>.delayed(Duration.zero);
        await cubit.stop();

        final freshStart = cubit.start('delivery-2');
        await Future<void>.delayed(Duration.zero);
        expect(gateway.currentPermissionCalls, 2);
        gateway.permissionRequests[1].complete(LocationPermission.always);
        await freshStart;
        expect(cubit.state.phase, BackgroundGpsPhase.tracking);
        expect(cubit.state.deliveryId, 'delivery-2');

        gateway.permissionRequests.first.complete(LocationPermission.always);
        await staleStart;
        await Future<void>.delayed(Duration.zero);

        expect(gateway.sampleListenCount, 1);
        expect(cubit.state.phase, BackgroundGpsPhase.tracking);
        expect(cubit.state.deliveryId, 'delivery-2');
      },
    );
  });
}
