// JEBV4-269: customer live-position overlay.
//
// P0 2026-07-31 — the OVERLAY is unchanged; its SOURCE moved back. The SSE
// variant this file used to exercise (`LivePositionStreamSource` /
// `SseLivePositionStream` over `GET /v1/geo/jeeb/stream/{id}`) is DELETED,
// because jeeb-gateway #333 (`b6fe888`) deleted the route: on the deployed MSI
// binary a grep of `publish/gateway/JeebGateway.dll` finds
// `deliveries/{deliveryId}/tracking` and finds `v1/geo/jeeb/stream` zero times.
// The customer read 404ed on a 30 s re-arm loop for four days while the
// jeeber's `POST /location/update` was 200-ing — the courier-marker P0.
//
// Proves:
//   * a LivePositionSource repo → the position read on the SAME event as the
//     status lands on the emitted DeliveryTrackingInfo (the map has data);
//   * a plain repo (no position capability) degrades silently — no crash, no
//     position (backwards-compatible with the demo/seam repos);
//   * a null overlay leaves the marker absent rather than crashing;
//   * NEGATIVE CONTROL: a STALE snapshot is merged but `markerIsLive` goes
//     false, so no phantom marker is drawn at a position the courier left;
//   * DioLiveTrackingRepository.fetchLivePosition parses the frozen
//     TrackingPolylineDto (including the `stale`/`secondsSinceUpdate` pair that
//     moved onto it when the stream's `last-seen` event died) and is null on
//     the legacy mock base.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/data/dio_live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_google_map.dart';

const _id = 'DLV-770001';

DeliveryTrackingInfo _inTransitRow() => DeliveryTrackingInfo.fromDeliveryJson(
      _id,
      <String, dynamic>{'id': _id, 'status': 'InTransit'},
    );

/// Repo that serves the stage row AND the position snapshot (production shape).
class _PositionRepo implements LiveTrackingRepository, LivePositionSource {
  _PositionRepo(this._position, {this.stale = false, this.ageSeconds});
  final GpsPoint? _position;
  final bool stale;
  final double? ageSeconds;

  /// How many times the cubit asked for a position. The point of the P0 fix is
  /// that this tracks EVENTS, not a clock, so the count is asserted directly.
  int reads = 0;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      _inTransitRow();

  @override
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  }) async {
    reads++;
    final p = _position;
    // Null models "the gateway had nothing / the read failed" — exactly what
    // the real Dio implementation returns, which is total by contract.
    if (p == null) return null;
    return DeliveryLivePosition(
      jeeberPosition: p,
      polyline: [p, const GpsPoint(lat: 33.8, lng: 35.4)],
      stale: stale,
      secondsSinceUpdate: ageSeconds,
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

      expect(cubit.state.trackingInfo?.jeeberPosition, pos);
      expect(cubit.state.trackingInfo?.polyline, isNotEmpty);
      // The stage from the delivery row is preserved through the merge.
      expect(cubit.state.trackingInfo?.currentStage, TrackingStage.inTransit);
      // A fresh fix is drawable, and the read happened exactly once — on the
      // mount event, not on a cadence.
      expect(cubit.state.trackingInfo?.markerIsLive, isTrue);
      expect(trackingMarkers(cubit.state.trackingInfo!), hasLength(1));
      expect(repo.reads, 1);
      expect(cubit.debugPositionReadCount, 1);
      await cubit.close();
    });

    test('NEGATIVE CONTROL: a stale snapshot draws no marker', () async {
      // The gateway says it holds a fix but it is older than StaleThreshold.
      // The overlay must still be MERGED (the screen keeps the age so it can
      // explain itself) while the map refuses to draw it: a pin where the
      // courier was ten minutes ago reads as live and sends the customer to
      // the wrong corner.
      const pos = GpsPoint(lat: 33.9, lng: 35.51);
      final repo = _PositionRepo(pos, stale: true, ageSeconds: 612.0);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
      );
      await pumpEventQueue();

      final info = cubit.state.trackingInfo!;
      expect(info.jeeberPosition, pos, reason: 'the fix is retained…');
      expect(info.positionAgeSeconds, closeTo(612.0, 1e-9));
      expect(info.markerIsLive, isFalse, reason: '…but is not drawable');
      expect(trackingMarkers(info), isEmpty);
      // POSITIVE CONTROL for this assertion: the same builder, same position,
      // fresh — must produce a marker. Otherwise `isEmpty` above would pass
      // even if trackingMarkers were broken outright.
      expect(
        trackingMarkers(info.withLivePosition(jeeberPosition: pos)),
        hasLength(1),
      );
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
      await cubit.close();
    });

    test('no position available leaves the map marker absent (no crash)',
        () async {
      final repo = _PositionRepo(null);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
      );
      await pumpEventQueue();

      expect(cubit.state.trackingInfo?.jeeberPosition, isNull);
      expect(trackingMarkers(cubit.state.trackingInfo!), isEmpty);
      // The read was ATTEMPTED (so a missing marker means "no fix", not "never
      // asked") but is not counted as an arrival.
      expect(repo.reads, 1);
      expect(cubit.debugPositionReadCount, 0);
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
            // Moved onto TrackingPolylineDto by jeeb-gateway #333 when the
            // stream's `last-seen` EVENT NAME (which used to carry the same
            // verdict) was deleted with the stream.
            'stale': false,
            'secondsSinceUpdate': 3.5,
          },
        ));
      });
      final repo =
          DioLiveTrackingRepository(_dio(adapter), originGateway: true);

      final overlay = await repo.fetchLivePosition(deliveryId: _id);

      // THE P0 ASSERTION: the surviving route, not the deleted
      // `/v1/geo/jeeb/stream/{id}` alias that 404s on the live gateway.
      expect(adapter.lastRequest?.path, '/deliveries/$_id/tracking');
      expect(overlay, isNotNull);
      expect(overlay!.jeeberPosition?.lat, closeTo(33.9, 1e-9));
      expect(overlay.jeeberPosition?.lng, closeTo(35.51, 1e-9));
      expect(overlay.polyline, hasLength(2));
      expect(overlay.stale, isFalse);
      expect(overlay.secondsSinceUpdate, closeTo(3.5, 1e-9));
    });

    test('fetchLivePosition carries the gateway staleness verdict', () async {
      final adapter = _ScriptedAdapter((options, handler) {
        handler.resolve(Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'deliveryId': _id,
            'position': {'lat': 33.9, 'lng': 35.51},
            'stale': true,
            'secondsSinceUpdate': 240.0,
          },
        ));
      });
      final repo =
          DioLiveTrackingRepository(_dio(adapter), originGateway: true);

      final overlay = await repo.fetchLivePosition(deliveryId: _id);

      expect(overlay!.stale, isTrue);
      expect(overlay.secondsSinceUpdate, closeTo(240.0, 1e-9));
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
