// JEBV4-269: customer live-position overlay.
//
// MB1 W1.1 — the OVERLAY is unchanged; its SOURCE moved BACK. b02 wave C / N7
// had routed it through the gateway's server-sent-events feed, over an alias
// under `/v1/geo/`. The gateway deleted that route
// (`LocationController.cs:22-31`) 16 h after the consumer landed, so the stream
// never opened, the marker never moved, and the client re-armed a dead GET every
// 30 s for the life of the screen. The overlay now comes from the route the
// gateway still serves — the one-shot `GET /deliveries/{id}/tracking` snapshot
// (`LocationController.cs:227`) — read on screen-open / status-push / resume /
// retry. Proves:
//
//   * a LivePositionSource repo → each read's position lands on the emitted
//     DeliveryTrackingInfo (the map has data, and it MOVES);
//   * a plain repo (no position capability) degrades silently — no crash, no
//     position (backwards-compatible with the demo/seam repos);
//   * an empty snapshot leaves the marker as-is rather than blanking it;
//   * DioLiveTrackingRepository.fetchLivePosition parses the frozen
//     TrackingPolylineDto off the LIVE path and is null on the legacy mock base.
//
// Explicit NON-CLAIM (GATE.md §7): nothing here exercises a Firestore path.
// `Firebase.apps` is empty under `flutter test`, so a suite CANNOT speak to
// realtime transport — and this feature has no Firestore path at all. These are
// `suite`-class assertions about the cubit↔repository wire and nothing more.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/data/dio_live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

const _id = 'DLV-770001';

DeliveryTrackingInfo _inTransitRow() => DeliveryTrackingInfo.fromDeliveryJson(
      _id,
      <String, dynamic>{'id': _id, 'status': 'InTransit'},
    );

/// Repo that serves the stage row AND the live position snapshot (production
/// shape — `DioLiveTrackingRepository` implements exactly these two).
class _PositionRepo implements LiveTrackingRepository, LivePositionSource {
  _PositionRepo(this._position);
  final GpsPoint? _position;

  int positionReads = 0;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      _inTransitRow();

  @override
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  }) async {
    positionReads++;
    final p = _position;
    // No fix yet is modelled as null, which is exactly what
    // `DioLiveTrackingRepository.fetchLivePosition` returns on 403/404/parse.
    if (p == null) return null;
    return DeliveryLivePosition(
      jeeberPosition: p,
      polyline: [p, const GpsPoint(lat: 33.8, lng: 35.4)],
    );
  }
}

/// Repo with NO position capability (demo/seam parity).
class _StageOnlyRepo implements LiveTrackingRepository {
  const _StageOnlyRepo();

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      _inTransitRow();
}

/// Interceptor stub so the Dio repo never hits a real server.
class _ScriptedAdapter extends Interceptor {
  _ScriptedAdapter(this._respond);
  final void Function(RequestOptions, RequestInterceptorHandler) _respond;
  RequestOptions? lastRequest;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    lastRequest = options;
    _respond(options, handler);
  }
}

Dio _dio(_ScriptedAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..interceptors.add(adapter);

void main() {
  group('JEBV4-269 customer live-position overlay', () {
    test('overlays the jeeber position onto the stage snapshot', () async {
      const pos = GpsPoint(lat: 33.9, lng: 35.51);
      final repo = _PositionRepo(pos);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
      );
      await pumpEventQueue();

      expect(repo.positionReads, 1);
      expect(cubit.state.trackingInfo?.jeeberPosition, pos);
      expect(cubit.state.trackingInfo?.polyline, isNotEmpty);
      // The stage from the delivery row is preserved through the merge.
      expect(cubit.state.trackingInfo?.currentStage, TrackingStage.inTransit);
      await cubit.close();
    });

    test('degrades silently when the repo has no live position', () async {
      final cubit = LiveTrackingCubit(
        repository: const _StageOnlyRepo(),
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
      );
      await pumpEventQueue();

      expect(cubit.state.trackingInfo?.currentStage, TrackingStage.inTransit);
      expect(cubit.state.trackingInfo?.jeeberPosition, isNull);
      expect(cubit.debugPositionReadCount, 0);
      await cubit.close();
    });

    test('no position fix leaves the map marker absent (no crash)', () async {
      final repo = _PositionRepo(null);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
      );
      await pumpEventQueue();

      expect(repo.positionReads, 1, reason: 'the read WAS attempted');
      expect(cubit.state.trackingInfo?.jeeberPosition, isNull);
      await cubit.close();
    });

    test('DioLiveTrackingRepository.fetchLivePosition parses the tracking '
        'snapshot on the origin gateway', () async {
      final adapter = _ScriptedAdapter((options, handler) {
        handler.resolve(Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'deliveryId': _id,
            'jeeberId': 'jeeber-1',
            'position': {'lat': 33.9, 'lng': 35.51, 'accuracy': 8.0},
            'polyline': [
              [33.9, 35.51],
              [33.8, 35.4],
            ],
          },
        ));
      });
      final repo =
          DioLiveTrackingRepository(_dio(adapter), originGateway: true);

      final overlay = await repo.fetchLivePosition(deliveryId: _id);

      expect(adapter.lastRequest?.path, '/deliveries/$_id/tracking');
      expect(overlay, isNotNull);
      expect(overlay!.jeeberPosition?.lat, closeTo(33.9, 1e-9));
      expect(overlay.jeeberPosition?.lng, closeTo(35.51, 1e-9));
      expect(overlay.polyline, hasLength(2));
    });

    test('fetchLivePosition is null on the legacy mock base (no tracking route)',
        () async {
      final adapter = _ScriptedAdapter((options, handler) {
        handler.resolve(Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 200,
          data: const <String, dynamic>{},
        ));
      });
      final repo =
          DioLiveTrackingRepository(_dio(adapter), originGateway: false);

      expect(await repo.fetchLivePosition(deliveryId: _id), isNull);
      // Mock base must not even attempt the origin-only tracking route.
      expect(adapter.lastRequest, isNull);
    });
  });
}
