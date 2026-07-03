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
///   POST `/v1/payments/cod_jeeb/record` → `/unified-payment-gateway/...`
///         — records the cash-on-delivery settlement (D11). Idempotent on
///           `deliveryId` (mock returns the existing record on replay).
///   POST `/v1/delivery/status/transition` → `/delivery-service/...`
///         — SM-1 `AtDoor → Done` (D70). 422 `transition_not_allowed` when the
///           delivery is not at a receipt-pending state. This is a GENUINELY
///           different endpoint (a status-transition command, NOT the delivery
///           read) — it stays SINGULAR and is deliberately NOT base-rewritten.
///
/// The cash settlement is recorded BEFORE the status transition so that a
/// confirmed (`Done`) delivery always has a matching COD record. Both calls are
/// idempotent server-side, so a retry after a partial failure is safe.
///
/// BUG-8 (sprint-008 run-7): only the delivery READ moved to the base-aware
/// plural `GET /v1/deliveries/{id}` (the singular alias 404s on the live origin
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
    // 1) Record the cash-on-delivery settlement (D11). The customer pays the
    //    Jeeber in person; this stamps the COD ledger. No fee is sent — the
    //    platform commission is a server/jeeber concern, never the customer's.
    //    This is the load-bearing step for rating: once it 2xx's, the customer
    //    has confirmed receipt and MUST reach the star-rating screen.
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/payments/cod_jeeb/record',
        data: <String, dynamic>{
          'deliveryId': receipt.deliveryId,
          if (receipt.jeeberId != null) 'jeeberId': receipt.jeeberId,
          // Run-22 P1-A: when the gateway dropped the amount (unknown), omit
          // the money object entirely — the ledger derives the amount from the
          // accepted offer server-side. NEVER stamp a fabricated 0.00 record.
          if (receipt.hasKnownAmount)
            'amount': <String, dynamic>{
              'value': receipt.cashAmount,
              'currency': receipt.currency,
            },
        },
      );
    } on DioException catch (e) {
      // COD-record failure is the only HARD failure that blocks rating.
      _rethrowDio(e);
    }

    // 2) Transition the delivery to Done (SM-1 `AtDoor → Done`, D70).
    //    IDEMPOTENT: in the real two-sided flow the delivery is frequently
    //    ALREADY `Done` by the time the customer confirms receipt (the handover
    //    OTP path drives `AtDoor → Done` server-side). Re-issuing the transition
    //    then returns 422 `transition_not_allowed`. That 422 is NOT a failure —
    //    it means the delivery is already in the confirmed terminal state we
    //    were transitioning toward, so we treat it as success and let the
    //    customer proceed to rate. We only surface non-422 transition errors.
    //
    // S10 Defect B — DO NOT fire an illegal `Done → Done` transition. When the
    // loaded receipt is ALREADY terminal (the OTP handover completed it before
    // the customer tapped "Yes, I received it"), skip the transition POST
    // entirely: the frozen SM-1 table correctly rejects `Done → Done` with 422,
    // so the request is wasted round-trip + error-log noise. The COD record
    // above (idempotent, load-bearing) still runs; the 422 swallow below stays
    // as a belt-and-braces guard for the race where the server flips to Done
    // between fetchReceipt and confirm. We never relax SM-1 or touch the
    // backend 422 — we just stop asking for an invalid transition.
    if (_isTerminalStatus(receipt.status)) {
      return;
    }
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/delivery/status/transition',
        data: <String, dynamic>{
          'deliveryId': receipt.deliveryId,
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
