import 'package:dio/dio.dart';

import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';

/// JM-032: order-tracking repository over the delivery-service.
///
/// Speaks the gateway-contract path `GET /v1/delivery/:deliveryId`
/// (30_BACKLOG JM-032 Mock line + 42_GUARDRAILS_MOCK §1.2 rewrite key
/// `/v1/delivery` → `/delivery-service/v1/delivery`). `MockGatewayClient`'s
/// `_PathRewriteInterceptor` rewrites the `/v1/...` prefix to the `:4010`
/// service prefix — never hardcode a host/prefix here (40_GUARDRAILS_ARCH §4).
///
/// The delivery row carries both the lifecycle `status`
/// (`Ordered/Picked/InTransit/AtDoor/Done`) that drives the 4-step
/// `tracking_stepper` AND the pinned-summary fields (price/tier/jeeber/item)
/// the `order_summary_pinned` header renders (D11/D71). The screen polls this
/// every 5s (LiveTrackingCubit); when the status reaches the terminal delivered
/// state the screen auto-advances to the receipt prompt (JM-033).
class DioLiveTrackingRepository implements LiveTrackingRepository {
  const DioLiveTrackingRepository(this._dio);

  final Dio _dio;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/delivery/$deliveryId',
      );
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
}
