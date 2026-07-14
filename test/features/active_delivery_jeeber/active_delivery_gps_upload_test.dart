// JEBV4-269: the jeeber GPS uploader wiring.
//
// Proves the previously-orphan BackgroundGpsCubit pipeline is now driven by the
// ActiveDeliveryCubit lifecycle — the missing wire that left the customer's
// live-tracking map empty:
//
//   * uploads start ONLY while the delivery is en route (InTransit) — the one
//     phase the gateway ingests fixes for and the customer needs a live map;
//   * a fix that survives the filter is POSTed carrying THIS delivery's id
//     (delivery-scoped so the gateway's party + in-transit gate applies);
//   * the uploader stays idle before pickup / on arrival (battery) and is torn
//     down when the delivery completes or the screen closes.
//
// The battery cadence/accuracy-filter itself is covered by
// background_gps_cubit_test.dart; this suite is the lifecycle wiring.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/background_gps/application/background_gps_cubit.dart';
import 'package:jeeb_mobile/features/background_gps/application/background_gps_state.dart';
import 'package:jeeb_mobile/features/background_gps/data/fake_geocapture_gateway.dart';
import 'package:jeeb_mobile/features/background_gps/data/in_memory_location_uploader.dart';
import 'package:jeeb_mobile/features/background_gps/domain/gps_sample.dart';

const _deliveryId = 'DLV-770001';
const _dropOff = DropOffAddress(label: 'Verdun', lat: 33.88, lng: 35.49);

JeeberDelivery _delivery(JeeberDeliveryStatus status) => JeeberDelivery(
      id: _deliveryId,
      status: status,
      dropOff: _dropOff,
    );

GpsSample _sample({double accuracy = 12}) => GpsSample(
      latitude: 33.9,
      longitude: 35.51,
      accuracyMeters: accuracy,
      speedMps: 6,
      headingDegrees: 90,
      capturedAt: DateTime.utc(2026, 7, 14, 10, 0, 0),
    );

/// Minimal repository stub: hands back a delivery at a fixed status and echoes
/// transition targets (so markDelivered walks InTransit → AtDoor → Done).
class _FakeRepo implements ActiveDeliveryRepository {
  _FakeRepo(this._status);

  final JeeberDeliveryStatus _status;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async =>
      _delivery(_status);

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) async =>
      to;

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async =>
      JeeberDeliveryStatus.done;

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async =>
      'object-ref';
}

void main() {
  group('JEBV4-269 active-delivery GPS upload wiring', () {
    late FakeGeocaptureGateway gateway;
    late InMemoryLocationUploader uploader;
    late BackgroundGpsCubit gps;

    BackgroundGpsCubit buildGps() {
      gateway = FakeGeocaptureGateway();
      uploader = InMemoryLocationUploader();
      gps = BackgroundGpsCubit(gateway: gateway, uploader: uploader);
      return gps;
    }

    // A long poll interval keeps the JEBV4-282 re-poll from firing mid-test.
    ActiveDeliveryCubit buildCubit(JeeberDeliveryStatus status) =>
        ActiveDeliveryCubit(
          repository: _FakeRepo(status),
          deliveryId: _deliveryId,
          gpsUploader: buildGps(),
          pollInterval: const Duration(hours: 1),
        );

    test('starts the uploader on an InTransit delivery and POSTs a fix '
        'carrying the delivery id', () async {
      final cubit = buildCubit(JeeberDeliveryStatus.inTransit);
      await cubit.loadDelivery();
      await pumpEventQueue();

      // En route → the GPS pipeline is live.
      expect(gps.state.phase, BackgroundGpsPhase.tracking);

      // A device fix flows through to the gateway ingest, delivery-scoped.
      await gateway.emit(_sample());
      await pumpEventQueue();
      expect(uploader.calls, hasLength(1));
      expect(uploader.calls.single.deliveryId, _deliveryId);

      await cubit.close();
    });

    test('stays idle before pickup and starts only when the delivery goes '
        'InTransit', () async {
      final cubit = buildCubit(JeeberDeliveryStatus.picked);
      await cubit.loadDelivery();
      await pumpEventQueue();

      // Picked (still at pickup) → no streaming, no uploads (battery).
      expect(gps.state.phase, BackgroundGpsPhase.idle);
      await gateway.emit(_sample());
      await pumpEventQueue();
      expect(uploader.calls, isEmpty);

      // Jeeber taps "start delivery": Picked → InTransit starts the upload.
      await cubit.advanceStatus();
      await pumpEventQueue();
      expect(gps.state.phase, BackgroundGpsPhase.tracking);

      await gateway.emit(_sample());
      await pumpEventQueue();
      expect(uploader.calls, hasLength(1));

      await cubit.close();
    });

    test('stops the uploader when the delivery is marked delivered', () async {
      final cubit = buildCubit(JeeberDeliveryStatus.inTransit);
      await cubit.loadDelivery();
      await pumpEventQueue();
      expect(gps.state.phase, BackgroundGpsPhase.tracking);

      // Walk InTransit → AtDoor → Done.
      await cubit.markDelivered();
      await pumpEventQueue();

      // Arrived/completed → uploader stopped (idle + stream torn down).
      expect(gps.state.phase, BackgroundGpsPhase.idle);
      expect(gateway.stopped, isTrue);

      // A late fix after completion uploads nothing.
      await gateway.emit(_sample());
      await pumpEventQueue();
      expect(uploader.calls, isEmpty);

      await cubit.close();
    });

    test('tears the uploader down when the screen closes', () async {
      final cubit = buildCubit(JeeberDeliveryStatus.inTransit);
      await cubit.loadDelivery();
      await pumpEventQueue();
      expect(gps.state.phase, BackgroundGpsPhase.tracking);

      await cubit.close();
      await pumpEventQueue();

      // Stream cancelled + cubit closed — no fixes leak past the screen.
      expect(gateway.stopped, isTrue);
      expect(gps.isClosed, isTrue);
    });
  });
}
