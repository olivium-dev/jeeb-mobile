import 'package:dio/dio.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';
import 'sse_live_position_stream.dart';

/// JM-032: order-tracking repository over the delivery-service.
///
/// BUG-8 (sprint-008 run-5): the CUSTOMER live-tracking screen read the SINGULAR
/// `GET /v1/delivery/{id}`, which the live origin gateway (`:10090`) answers with
/// 404 "Delivery not found" — the materialized delivery aggregate is served ONLY
/// at the PLURAL `GET /v1/deliveries/{id}` (Contract 8c), the same route the
/// jeeber `DioActiveDeliveryRepository.fetchDelivery` already reads successfully
/// (200). The customer is now aligned to that plural route.
///
/// Base-aware, reused verbatim from `DioActiveDeliveryRepository` (T-MOB-031):
/// the origin `:10090` gateway serves the FROZEN plural `/v1/deliveries/{id}`,
/// while the legacy `:4010` Express mock keeps the singular `/v1/delivery/{id}`
/// alias. `MockGatewayClient` selects the wire shape by BASE (not host string),
/// so [originGateway] defaults to `!MockGatewayClient.useMockPrefixes` — the same
/// flag that points Dio at the mock also selects the mock route. Never hardcode a
/// host/prefix here (40_GUARDRAILS_ARCH §4); `MockGatewayClient`'s
/// `_PathRewriteInterceptor` rewrites the `/v1/...` prefix to the `:4010` service
/// prefix in mock mode.
///
/// The delivery row carries both the lifecycle `status`
/// (`Ordered/Picked/InTransit/AtDoor/Done`) that drives the 4-step
/// `tracking_stepper` AND the pinned-summary fields (price/tier/jeeber/item)
/// the `order_summary_pinned` header renders (D11/D71). The screen polls this
/// every 5s (LiveTrackingCubit); when the status reaches the terminal delivered
/// state the screen auto-advances to the receipt prompt (JM-033).
class DioLiveTrackingRepository
    implements
        LiveTrackingRepository,
        LivePositionSource,
        LivePositionStreamSource {
  /// [originGateway] selects the wire shape. When `true` (the device/real
  /// default) the read speaks the FROZEN plural `:10090` route
  /// `GET /v1/deliveries/{id}` (the materialized aggregate — BUG-8 fix); when
  /// `false` it speaks the legacy `:4010` mock alias `GET /v1/delivery/{id}`.
  /// The default mirrors the base selection (`!MockGatewayClient.useMockPrefixes`)
  /// so the wire shape always tracks the base the same Dio is pointed at, exactly
  /// like `DioActiveDeliveryRepository`. Tests inject the flag explicitly to
  /// exercise both surfaces under a plain `flutter test`.
  DioLiveTrackingRepository(this._dio, {bool? originGateway})
      : originGateway = originGateway ?? !MockGatewayClient.useMockPrefixes;

  final Dio _dio;

  /// b02 wave C / N7: the server-sent-events position feed, replacing the 5s
  /// `GET /deliveries/{id}/tracking` cadence. Lazily built over the SAME Dio so
  /// it inherits the bearer-auth interceptor.
  late final SseLivePositionStream _positionStream =
      SseLivePositionStream(_dio);

  /// b02 wave C / N7. Streams the jeeber's position from the gateway's SSE route.
  ///
  /// Origin-only, for the same reason [fetchLivePosition] is: the `:4010` Express
  /// mock has no tracking route at all, so in mock mode this yields an empty
  /// stream and the screen simply shows no marker — the pre-existing degradation,
  /// unchanged.
  @override
  Stream<DeliveryLivePosition> watchLivePosition({required String deliveryId}) {
    if (!originGateway) return const Stream<DeliveryLivePosition>.empty();
    return _positionStream.watchLivePosition(deliveryId: deliveryId);
  }

  /// Whether to read the frozen origin-only `:10090` plural delivery route
  /// (`GET /v1/deliveries/{id}`) instead of the legacy `:4010` mock singular
  /// alias (`GET /v1/delivery/{id}`). See the constructor doc.
  final bool originGateway;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    try {
      // Origin `:10090` reads the plural `/v1/deliveries/{id}` (Contract 8c —
      // the materialized aggregate the jeeber side already reads); the `:4010`
      // mock keeps the legacy singular `/v1/delivery/{id}` alias.
      final path = originGateway
          ? '/v1/deliveries/$deliveryId'
          : '/v1/delivery/$deliveryId';
      final response = await _dio.get<Map<String, dynamic>>(path);
      final data = response.data;
      if (data == null) {
        throw const LiveTrackingException(LiveTrackingErrorKind.parse);
      }
      return DeliveryTrackingInfo.fromDeliveryJson(deliveryId, data);
    } on DioException catch (e) {
      // S9 live-tracking fix: a 404 means the delivery row was not found —
      // typically the surface was opened with a request id instead of the
      // server delivery id (`delivery-<offerId>`), or the accept-minted row has
      // not propagated yet. Map it to a dedicated kind so the screen renders a
      // distinct empty/error state with a retry instead of a generic
      // "Server error".
      final LiveTrackingErrorKind kind;
      if (e.response == null) {
        kind = LiveTrackingErrorKind.network;
      } else if (e.response!.statusCode == 404) {
        kind = LiveTrackingErrorKind.notFound;
      } else {
        kind = LiveTrackingErrorKind.server;
      }
      throw LiveTrackingException(kind, e);
    } on FormatException catch (e) {
      throw LiveTrackingException(LiveTrackingErrorKind.parse, e);
    }
  }

  /// JEBV4-269: best-effort read of the jeeber's live position + route from the
  /// shipped gateway tracking snapshot `GET /deliveries/{id}/tracking` (the same
  /// store the jeeber's uploader writes to; parsed via the frozen
  /// `TrackingPolylineDto` shape). A plain `Accept: application/json` (Dio's
  /// default) gets the one-shot polyline snapshot, NOT the held SSE stream.
  ///
  /// Deliberately total: ANY failure — 404 (no fix yet / not-a-party 403,
  /// transport error, malformed body) — returns null so the tracking screen
  /// keeps its stage/summary read and simply shows no marker yet. Only attempted
  /// on the origin gateway (the `:4010` mock has no tracking route); returns
  /// null in mock mode.
  @override
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  }) async {
    if (!originGateway) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/deliveries/$deliveryId/tracking',
      );
      final data = response.data;
      if (data == null) return null;
      final info = DeliveryTrackingInfo.fromTrackingJson(deliveryId, data);
      return DeliveryLivePosition(
        jeeberPosition: info.jeeberPosition,
        polyline: info.polyline,
      );
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }
}
