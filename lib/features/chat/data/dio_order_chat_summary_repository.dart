import 'package:dio/dio.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/network/mock_gateway_client.dart';
import '../domain/order_chat_summary.dart';

/// Dio-backed [OrderChatSummaryRepository] (JM-025 AC2).
///
/// Reads the locked pinned-summary fields from the existing mock services via
/// the gateway-contract paths (the `MockGatewayClient` interceptor rewrites the
/// `/v1/...` prefix to the `:4010` service prefix — never hardcode a prefix):
///
///   GET /v1/deliveries/:deliveryId  → price (amount), tier, jeeberName, requestId,
///                                     description (P3 — the INITIAL REQUIREMENT)
///   GET /v1/requests/:requestId     → orderRef (displayId), tier fallback, amount fallback,
///                                     description fallback
///   GET /v1/offers?requestId=…       → accepted offer's etaMinutes
///
/// P3 (b01-20260725): with `ownerScopedReads: false` (the Jeeber leg) legs 2 and
/// 3 are SKIPPED entirely — both are owner-scoped and 403 for a non-owner. Only
/// the participant-scoped delivery read runs, and it is the one that now carries
/// `description`.
///
/// BUG-8 (sprint-008 run-7): the pinned summary is the FIRST read on both the
/// customer chat AND tracking surfaces, and it read the SINGULAR
/// `GET /v1/delivery/{id}` — which the live origin gateway (`:10090`) answers
/// with 404 (run-7 `wire-step5-chat.txt`: `GET /v1/delivery/2896… → 404`, then
/// the request/offer follow-ups also 404). The materialized delivery aggregate
/// is served ONLY at the PLURAL `GET /v1/deliveries/{id}` (Contract 8c) — the
/// same route the jeeber `DioActiveDeliveryRepository.fetchDelivery` and the
/// customer `DioLiveTrackingRepository.fetchDeliveryStatus` already read with
/// 200. This repo now uses that plural route on the origin gateway (base-aware
/// pattern reused verbatim from `DioActiveDeliveryRepository`, T-MOB-031), while
/// the legacy `:4010` Express mock keeps the singular `/v1/delivery/{id}` alias.
///
/// Every read is defensive: a missing delivery falls back to the request row,
/// a missing field is simply omitted from the summary (the strip hides that
/// chip). Only a hard transport failure raises [OrderChatSummaryException]; a
/// 404 maps to [OrderChatSummaryFailure.notFound] so the caller can hide the
/// strip rather than break the chat thread.
class DioOrderChatSummaryRepository implements OrderChatSummaryRepository {
  /// [originGateway] selects the wire shape. When `true` (the device/real
  /// default) the read speaks the FROZEN plural `:10090` route
  /// `GET /v1/deliveries/{id}` (the materialized aggregate — BUG-8 fix); when
  /// `false` it speaks the legacy `:4010` mock alias `GET /v1/delivery/{id}`.
  /// The default mirrors the base selection (`!MockGatewayClient.useMockPrefixes`)
  /// so the wire shape always tracks the base the same Dio is pointed at.
  ///
  /// P3: when [ownerScopedReads] is `false` the caller is NOT the request owner
  /// (the Jeeber leg), so the two OWNER-SCOPED reads are skipped entirely:
  ///   GET /v1/requests/{id}        → 403 for a non-owner (JeebRequestsController.Get)
  ///   GET /v1/offers?requestId=…   → 403 for a non-owner (ListOffersFlat)
  /// The delivery read is participant-scoped (client OR assigned jeeber) and
  /// always runs. Skipping — rather than tolerating the 403 — is what keeps the
  /// Jeeber leg free of the chat READ-404/403 storm.
  const DioOrderChatSummaryRepository(
    this._dio, {
    bool? originGateway,
    this.ownerScopedReads = true,
  }) : originGateway = originGateway ?? !MockGatewayClient.useMockPrefixes;

  final Dio _dio;

  /// Whether to read the frozen origin `:10090` plural delivery route
  /// (`GET /v1/deliveries/{id}`) instead of the legacy `:4010` mock singular
  /// alias (`GET /v1/delivery/{id}`). See the constructor doc.
  final bool originGateway;

  /// P3: whether the caller owns the request (the customer leg). False on the
  /// Jeeber leg — see the constructor doc.
  final bool ownerScopedReads;

  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) async {
    try {
      // Origin `:10090` reads the plural `/v1/deliveries/{id}` (Contract 8c);
      // the `:4010` mock keeps the legacy singular `/v1/delivery/{id}` alias.
      final deliveryPath = originGateway
          ? '/v1/deliveries/$deliveryId'
          : '/v1/delivery/$deliveryId';
      final delivery = await _getMap(deliveryPath);
      final requestId =
          _str(delivery?['requestId']) ?? _str(delivery?['id']) ?? deliveryId;

      // The request row carries the human order ref (`displayId`) + tier; the
      // delivery row carries the locked price + winner name. Fetch the request
      // for the ref/tier; tolerate its absence.
      final request = (!ownerScopedReads || requestId.isEmpty)
          ? null
          : await _getMap('/v1/requests/$requestId');

      // ETA is the *winning* (accepted) offer's eta — read from the offers
      // list for this request. Tolerate an empty/absent list.
      final etaMinutes = (!ownerScopedReads || requestId.isEmpty)
          ? null
          : await _acceptedOfferEta(requestId);

      final priceLabel = _formatAmount(
        delivery?['amount'] ?? request?['amount'],
      );
      // WIRE KEY: `tierId` FIRST — see the note in
      // `dio_order_summary_repository.dart`. The gateway's `DeliveryRequestDto`
      // serializes `TierId` as `tierId` on BOTH `/v1/deliveries/{id}` and
      // `/v1/requests/{id}`; neither route emits `tier`, so reading only `tier`
      // pinned this to '' and the chat header's Tier chip permanently showed
      // its "Pending" placeholder. `tier` stays as the trailing legacy alias.
      final tierId = _str(delivery?['tierId']) ??
          _str(delivery?['tier_id']) ??
          _str(request?['tierId']) ??
          _str(request?['tier_id']) ??
          _str(delivery?['tier']) ??
          _str(request?['tier']) ??
          '';
      final orderRef = _str(request?['displayId']) ??
          _str(delivery?['displayId']) ??
          '';
      final jeeberName = _str(delivery?['jeeberName']) ??
          _str(request?['jeeberName']) ??
          '';
      final rating = _num(delivery?['jeeberRating']) ??
          _num(request?['jeeberRating']) ??
          0;
      // Delivery lifecycle status for the strip's canonical status label
      // (deliveryStage* vocab). The delivery row is authoritative; the request
      // row's status (`accepted`/`pending`) is a tolerated fallback.
      final statusId =
          _str(delivery?['status']) ?? _str(request?['status']) ?? '';

      // P3: the INITIAL REQUIREMENT. Delivery-FIRST because the Jeeber leg never
      // reads /v1/requests/{id} (owner-scoped) — the gateway now carries
      // `description` on GET /v1/deliveries/{id} for both participants. `title`
      // is kept last as the legacy `:4010` mock alias.
      final description = _str(delivery?['description']) ??
          _str(request?['description']) ??
          _str(delivery?['title']) ??
          '';

      if (delivery == null && request == null) {
        throw const OrderChatSummaryException(OrderChatSummaryFailure.notFound);
      }

      return OrderChatSummary(
        deliveryId: deliveryId,
        requestId: requestId,
        priceLabel: priceLabel,
        jeeberName: jeeberName,
        rating: rating,
        etaMinutes: etaMinutes,
        tierId: tierId,
        orderRef: orderRef,
        statusId: statusId,
        description: description,
      );
    } on OrderChatSummaryException {
      rethrow;
    } on DioException catch (e) {
      throw OrderChatSummaryException(_map(e));
    } catch (_) {
      throw const OrderChatSummaryException(OrderChatSummaryFailure.unknown);
    }
  }

  /// GET a JSON object, returning null on 404 (so the caller can fall back to
  /// the other source) and rethrowing any other transport error.
  Future<Map<String, dynamic>?> _getMap(String path) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      return res.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Reads the accepted offer's ETA for [requestId]. Returns null when no
  /// offer is accepted yet or the field is absent.
  Future<int?> _acceptedOfferEta(String requestId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/offers',
        queryParameters: <String, Object?>{'requestId': requestId},
      );
      final items = res.data?['items'];
      if (items is! List) return null;
      // Prefer an explicitly accepted offer; fall back to the first offer so a
      // not-yet-accepted-but-matched order still shows an indicative ETA.
      Map<String, dynamic>? chosen;
      for (final raw in items) {
        if (raw is! Map<String, dynamic>) continue;
        if (_str(raw['status']) == 'accepted') {
          chosen = raw;
          break;
        }
        chosen ??= raw;
      }
      final eta = chosen?['etaMinutes'];
      return eta is num ? eta.toInt() : null;
    } on DioException {
      return null;
    }
  }

  OrderChatSummaryFailure _map(DioException e) {
    if (e.response?.statusCode == 404) return OrderChatSummaryFailure.notFound;
    return (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout)
        ? OrderChatSummaryFailure.network
        : OrderChatSummaryFailure.unknown;
  }

  /// Formats an amount object (`{ value, minorUnits, currency }` per the mock
  /// `usd()` shape) or a bare number into the app-wide [MoneyFormat] label
  /// (`$9.00` / `LBP 15,000.00`). Returns '' when the input carries no usable
  /// value (the strip then shows the pending placeholder).
  String _formatAmount(Object? amount) {
    double? value;
    String currency = 'USD';
    if (amount is Map) {
      final v = amount['value'];
      if (v is num) value = v.toDouble();
      final c = amount['currency'];
      if (c is String && c.isNotEmpty) currency = c;
    } else if (amount is num) {
      value = amount.toDouble();
    }
    if (value == null) return '';
    return MoneyFormat.format(value, currency: currency);
  }

  String? _str(Object? v) {
    if (v is String && v.trim().isNotEmpty) return v;
    return null;
  }

  double? _num(Object? v) => v is num ? v.toDouble() : null;
}
