import 'package:dio/dio.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../domain/delivery_receipt.dart';
import '../domain/delivery_receipt_repository.dart';

/// Dio-backed [DeliveryReceiptRepository] (JM-033).
///
/// Endpoints (gateway contract; `MockGatewayClient` rewrites the `/v1/...`
/// prefix to the `:4010` service prefix — 40_GUARDRAILS_ARCH §4/§11). NEVER
/// hardcode a `:4010` host or a service prefix here.
///   GET  `/v1/deliveries/:deliveryId` → the delivery aggregate `{ id, status,
///           amount: { value, currency }, jeeberName, jeeberId,
///           proofPhotoUrl|evidenceUrl, ... }` (BUG-8: origin plural route).
///   PATCH `/v1/deliveries/:deliveryId/status` → `/delivery-service/...`
///         — SM-1 `AtDoor → Done` (D70). Body accepts `{to}` / `{trigger}` /
///           legacy `{status}`. Returns 422 `transition_not_allowed` when the
///           delivery is not at a receipt-pending state (already `Done`, etc.)
///           — treated as idempotent success. This is the ONLY confirm-receipt
///           write: it is a real, shipped gateway route (DeliveriesController
///           `PATCH /v1/deliveries/{id}/status`).
///
/// COD-COMPLETE FIX (fix/cod-complete): confirm-receipt used to POST two routes
/// the gateway never served — `POST /v1/payments/cod_jeeb/record` (404, HARD
/// failure that blocked rating with "Something went wrong") and
/// `POST /v1/delivery/status/transition` (404). Both were removed. The customer
/// is NOT the COD-settling party — the COD ledger is jeeber/server-owned and the
/// amount is server-authoritative (BR-16), so the client never records COD. The
/// only remaining, correct write is the idempotent status PATCH below.
///
/// BUG-8 (sprint-008 run-7): the delivery READ speaks the base-aware plural
/// `GET /v1/deliveries/{id}` (the singular alias 404s on the live origin
/// gateway; the materialized aggregate lives at the plural route — Contract 8c).
/// Pattern reused verbatim from `DioActiveDeliveryRepository` (T-MOB-031).
class DioDeliveryReceiptRepository implements DeliveryReceiptRepository {
  /// [originGateway] selects the wire shape for the delivery READ. When `true`
  /// (the device/real default) it speaks the FROZEN plural `:10090` route
  /// `GET /v1/deliveries/{id}` (BUG-8 fix); when `false` it speaks the legacy
  /// `:4010` mock alias `GET /v1/delivery/{id}`. The default mirrors the base
  /// selection (`!MockGatewayClient.useMockPrefixes`).
  const DioDeliveryReceiptRepository(this._dio, {bool? originGateway})
      : originGateway = originGateway ?? !MockGatewayClient.useMockPrefixes;

  final Dio _dio;

  /// Whether to read the frozen origin `:10090` plural delivery route
  /// (`GET /v1/deliveries/{id}`) instead of the legacy `:4010` mock singular
  /// alias (`GET /v1/delivery/{id}`). Only the READ is affected — the SM-1
  /// transition POST stays singular. See the constructor doc.
  final bool originGateway;

  /// SM-1 terminal reached when the customer confirms receipt (D70).
  static const String _confirmedStatus = 'Done';

  /// Whether [status] is an SM-1 terminal state in which a confirm-receipt
  /// transition would be an illegal self-move (S10 Defect B). Case-insensitive
  /// + trimmed so the gateway's `Done` and any tolerant variant match.
  static bool _isTerminalStatus(String status) {
    final s = status.trim().toLowerCase();
    return s == 'done' || s == 'delivered' || s == 'completed';
  }

  @override
  Future<DeliveryReceipt> fetchReceipt(String deliveryId) async {
    try {
      // Origin `:10090` reads the plural `/v1/deliveries/{id}` (Contract 8c);
      // the `:4010` mock keeps the legacy singular `/v1/delivery/{id}` alias.
      final response = await _dio.get<Map<String, dynamic>>(
        originGateway
            ? '/v1/deliveries/$deliveryId'
            : '/v1/delivery/$deliveryId',
      );
      return _parseReceipt(deliveryId, response.data);
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  @override
  Future<void> confirmReceipt(DeliveryReceipt receipt) async {
    // COD-COMPLETE FIX: the customer's "Yes, I received it" is a single,
    // idempotent SM-1 transition to `Done` — nothing more. There is NO
    // customer-side COD write: the COD ledger is jeeber/server-owned and the
    // amount is server-authoritative (BR-16). The old `POST
    // /v1/payments/cod_jeeb/record` was a route the gateway never served (404),
    // and being the only HARD failure it dead-ended the customer at "Something
    // went wrong" before they could rate. Removing it unblocks the rating step.
    //
    // Transition the delivery to Done via the REAL, shipped gateway route
    // `PATCH /v1/deliveries/{id}/status` (DeliveriesController), whose body
    // accepts `{to}` / `{trigger}` / legacy `{status}`.
    //
    // IDEMPOTENT: in the real two-sided flow the delivery is frequently ALREADY
    // `Done` by the time the customer confirms receipt (the handover-OTP path
    // drove `AtDoor → Done` server-side). Two guards keep this a safe no-op:
    //
    //   1) S10 Defect B — when the LOADED receipt is already terminal, skip the
    //      PATCH entirely: the frozen SM-1 table rejects `Done → Done` with 422,
    //      so firing it is a wasted round-trip + error-log noise.
    //   2) Race guard — if the server flips to `Done` between fetchReceipt and
    //      confirm, the PATCH returns 422 `transition_not_allowed`. That 422 is
    //      NOT a failure: the delivery is already in the terminal state we were
    //      transitioning toward, so we swallow it and let the customer rate.
    //
    // We never relax SM-1 or touch the backend 422 — we just stop asking for an
    // invalid transition.
    if (_isTerminalStatus(receipt.status)) {
      return;
    }
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/v1/deliveries/${receipt.deliveryId}/status',
        data: <String, dynamic>{
          'to': _confirmedStatus,
          'trigger': 'customer_confirmed_receipt',
        },
      );
    } on DioException catch (e) {
      // 422 = already Done / not in a transitionable state → idempotent success.
      // Any other transition error (5xx, transport) still surfaces.
      if (e.response?.statusCode == 422) {
        return;
      }
      _rethrowDio(e);
    }
  }

  /// Defensive parse — accept snake_case + camelCase, the nested
  /// `{ value, currency }` money object or a flat numeric, and either
  /// `proofPhotoUrl` or `evidenceUrl` for the photo (the mock stamps both). A
  /// malformed body degrades (empty name, null photo) rather than crashing.
  DeliveryReceipt _parseReceipt(String deliveryId, Map<String, dynamic>? data) {
    if (data == null) {
      throw const DeliveryReceiptRepositoryException(
        DeliveryReceiptFailure.unknown,
      );
    }
    final rawProof = (data['proofPhotoUrl'] ?? data['evidenceUrl']) as String?;
    final proof =
        (rawProof != null && rawProof.trim().isNotEmpty) ? rawProof : null;
    final rawJeeberId = (data['jeeberId'] ?? data['jeeber_id']) as String?;
    final jeeberId = (rawJeeberId != null && rawJeeberId.trim().isNotEmpty)
        ? rawJeeberId
        : null;
    return DeliveryReceipt(
      deliveryId: (data['id'] as String?) ?? deliveryId,
      jeeberName: (data['jeeberName'] ?? data['jeeber_name']) as String? ?? '',
      jeeberId: jeeberId,
      cashAmount: _parseAmount(data),
      currency: _parseCurrency(data),
      status: (data['status'] as String?) ?? '',
      proofPhotoUrl: proof,
    );
  }

  /// Run-22 P1-A: the live gateway drops the `amount` key from
  /// `GET /v1/deliveries/{id}` once the delivery reaches `Done` (it was present
  /// with the real fee while `Ordered` — wire evidence in
  /// docs/sprints/sprint-009/proof-run22/wire/diag-statusbuckets.txt). An
  /// ABSENT amount is unknown, NOT zero — returning `0.0` here is what
  /// rendered "Pay $0.00 cash to the Jeeber". Return null so the screen can
  /// degrade to amount-less copy instead of fabricating a price.
  double? _parseAmount(Map<String, dynamic> json) {
    final flat = json['amount'];
    if (flat is num) return flat.toDouble();
    return _moneyValue(json['amount']) ?? _moneyValue(json['price']);
  }

  String _parseCurrency(Map<String, dynamic> json) {
    final fromObject =
        _moneyCurrency(json['amount']) ?? _moneyCurrency(json['price']);
    if (fromObject != null) return fromObject;
    final flat = json['currency'];
    if (flat is String && flat.isNotEmpty) return flat;
    return 'USD';
  }

  double? _moneyValue(dynamic money) {
    if (money is Map) {
      final v = money['value'];
      if (v is num) return v.toDouble();
      // Some gateway DTOs carry money as { minorUnits, currency } (e.g. the
      // requests list). Tolerate it here so the receipt survives shape drift.
      final minor = money['minorUnits'];
      if (minor is num) return minor.toDouble() / 100;
    }
    return null;
  }

  String? _moneyCurrency(dynamic money) {
    if (money is Map) {
      final c = money['currency'];
      if (c is String && c.isNotEmpty) return c;
    }
    return null;
  }

  Never _rethrowDio(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw const DeliveryReceiptRepositoryException(
        DeliveryReceiptFailure.network,
      );
    }
    if (e.response?.statusCode == 404) {
      throw const DeliveryReceiptRepositoryException(
        DeliveryReceiptFailure.notFound,
      );
    }
    throw const DeliveryReceiptRepositoryException(
      DeliveryReceiptFailure.unknown,
    );
  }

}
