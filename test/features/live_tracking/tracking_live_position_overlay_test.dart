// JEBV4-269: customer live-position overlay.
//
// b02 wave C / N7 — the OVERLAY is unchanged; only its SOURCE moved. It used to
// be a one-shot `GET /deliveries/{id}/tracking` read issued from inside every 5s
// poll tick; it is now the gateway's SSE position stream
// (`LivePositionStreamSource` / `SseLivePositionStream`), so the marker moves
// with no client cadence at all. The overlay assertions below are re-expressed
// against the STREAM and are otherwise identical. Proves:
//
//   * a LivePositionStreamSource repo → each pushed frame's position lands on
//     the emitted DeliveryTrackingInfo (the map now has data, and it MOVES);
//   * a plain repo (no stream capability) degrades silently — no crash, no
//     position (backwards-compatible with the demo/seam repos);
//   * an empty frame leaves the marker absent rather than crashing;
//   * DioLiveTrackingRepository.fetchLivePosition still parses the frozen
//     TrackingPolylineDto and is null on the legacy mock base — the one-shot
//     reader is RETAINED (it is the polyline-replay/route-screen view) even
//     though the tracking screen no longer calls it on a cadence.

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

/// Repo that serves the stage row AND a live position STREAM (production shape).
class _PositionRepo
    implements LiveTrackingRepository, LivePositionStreamSource {
  _PositionRepo(this._position);
  final GpsPoint? _position;

  final List<StreamController<DeliveryLivePosition>> streams = [];

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      _inTransitRow();

  @override
  Stream<DeliveryLivePosition> watchLivePosition({
    required String deliveryId,
  }) {
    final c = StreamController<DeliveryLivePosition>();
    streams.add(c);
    return c.stream;
  }

  /// Push one frame, mirroring what `SseLivePositionStream` emits. An absent
  /// position is modelled as NO frame at all, because the SSE layer drops empty
  /// overlays upstream (so the cubit can never be handed one).
  void emit() {
    final p = _position;
    if (p == null) return;
    streams.single.add(DeliveryLivePosition(
      jeeberPosition: p,
      polyline: [p, const GpsPoint(lat: 33.8, lng: 35.4)],
    ));
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
      repo.emit();
      await pumpEventQueue();

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
      await cubit.close();
    });

    test('no position frame leaves the map marker absent (no crash)',
        () async {
      final repo = _PositionRepo(null);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
      );
      await pumpEventQueue();
      repo.emit();
      await pumpEventQueue();

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
