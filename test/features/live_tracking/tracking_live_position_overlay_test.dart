// JEBV4-269: customer live-position overlay.
//
// The customer tracking screen polls the delivery row (stage + pinned summary)
// AND, when the repository can supply it, overlays the jeeber's live GPS
// position + route read back from the gateway tracking snapshot — the data the
// jeeber's uploader now feeds. Proves:
//
//   * a LivePositionSource repo → the jeeber marker position lands on the
//     emitted DeliveryTrackingInfo (the map now has data);
//   * a plain repo (no LivePositionSource) degrades silently — no crash, no
//     position (backwards-compatible with the demo/seam repos);
//   * DioLiveTrackingRepository.fetchLivePosition parses the frozen
//     TrackingPolylineDto and is null on the legacy mock base.

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

/// Repo that serves the stage row AND a live position (the production shape).
class _PositionRepo implements LiveTrackingRepository, LivePositionSource {
  const _PositionRepo(this._position);
  final GpsPoint? _position;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      _inTransitRow();

  @override
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  }) async =>
      _position == null
          ? null
          : DeliveryLivePosition(
              jeeberPosition: _position,
              polyline: [_position, const GpsPoint(lat: 33.8, lng: 35.4)],
            );
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
      final cubit = LiveTrackingCubit(
        repository: const _PositionRepo(pos),
        deliveryId: _id,
        pollInterval: const Duration(hours: 1),
      );
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
        pollInterval: const Duration(hours: 1),
      );
      await pumpEventQueue();

      expect(cubit.state.trackingInfo?.currentStage, TrackingStage.inTransit);
      expect(cubit.state.trackingInfo?.jeeberPosition, isNull);
      await cubit.close();
    });

    test('a null live position leaves the map marker absent (no crash)',
        () async {
      final cubit = LiveTrackingCubit(
        repository: const _PositionRepo(null),
        deliveryId: _id,
        pollInterval: const Duration(hours: 1),
      );
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
