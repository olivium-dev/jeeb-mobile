import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../domain/submitted_offer.dart';
import '../domain/submitted_offers_repository.dart';

/// Dio-backed [SubmittedOffersRepository] (JM-048 AC3).
///
/// Endpoint contract (mock gateway paths → `MockGatewayClient` rewrite →
/// :4010 `offer-service`):
///   GET    /v1/offers?jeeberId=`id`  → { items: [ { id, requestId, jeeberId,
///                                       price:{value,currency}, etaMinutes,
///                                       note, status } ], cursor }
///   DELETE /v1/offers/:offerId       → 200 (released, D15)
///
/// Only `status == 'submitted'` offers are surfaced — accepted/withdrawn/
/// rejected ones are not "awaiting a customer decision" and belong to other
/// surfaces. The jeeber id is the seeded `user-jeeber-002` for the W2 seam
/// (the mock filters by the `jeeberId` query param, not the bearer).
class DioSubmittedOffersRepository implements SubmittedOffersRepository {
  const DioSubmittedOffersRepository({
    required Dio dio,
    String? jeeberId,
    AuthTokenStore? tokenStore,
  }) : _dio = dio,
       _jeeberId = jeeberId,
       _tokenStore = tokenStore;

  final Dio _dio;
  final String? _jeeberId;
  final AuthTokenStore? _tokenStore;

  static const String _path = '/v1/offers';

  @override
  Future<List<SubmittedOffer>> listSubmitted() async {
    try {
      final jeeberId = _jeeberId ?? await _tokenStore?.userId;
      final response = await _dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: jeeberId == null || jeeberId.isEmpty
            ? null
            : {'jeeberId': jeeberId},
      );
      return _parse(response.data ?? const {});
    } on DioException {
      // A feed sub-tab that can't reach the offer service shows its empty
      // state rather than an error banner (the request tab owns connectivity
      // surfacing) — return an empty list and let the next refresh retry.
      return const <SubmittedOffer>[];
    }
  }

  @override
  Future<bool> withdraw(String offerId) async {
    // sprint-009: `DELETE /v1/offers/{offerId}` now returns 204 (withdrawn),
    // 404 (already gone — idempotent), 403 (not the owner) or 409 (no longer
    // withdrawable, e.g. already accepted). Treat 204 AND 404 as success so an
    // already-removed offer clears its row on retry; 403/409 keep the row so
    // the jeeber isn't misled into thinking a non-withdrawable offer is gone.
    try {
      await _dio.delete<void>('$_path/$offerId');
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) return true;
      return false;
    }
  }

  List<SubmittedOffer> _parse(Map<String, dynamic> data) {
    // sprint-009 offer-lifecycle: surface EVERY offer this jeeber submitted,
    // not only `status == 'submitted'`. The row renders an Accepted / Not
    // selected / awaiting badge off [SubmittedOffer.status], so the jeeber sees
    // the outcome of a bid the customer just decided (an `offer_accepted` /
    // `offer_lost` push re-pulls this list). Withdraw is gated to the
    // still-open rows in the row widget, not by dropping terminal rows here.
    final items = data['items'] as List? ?? const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(_parseOffer)
        .whereType<SubmittedOffer>()
        .toList(growable: false);
  }

  SubmittedOffer? _parseOffer(Map<String, dynamic> json) {
    // The self-scoped list returns the offer id as `id`; tolerate the flat
    // `offerId` the lifecycle push carries so a defensive parse never drops a
    // row on a shape variant.
    final id = (json['id'] as String?) ?? (json['offerId'] as String?);
    if (id == null) return null;
    final requestId =
        (json['requestId'] as String?) ?? (json['request_id'] as String?) ?? '';
    // Fee is returned in dollars on the self-scoped list (gateway note); the
    // money-object `{value,currency}` variant is still tolerated.
    final price = _amount(json['price']) ??
        _amount(json['amount']) ??
        _amount(json['fee']);
    final currency = _currency(json['price']) ?? _currency(json['amount']);
    return SubmittedOffer(
      id: id,
      requestId: requestId,
      price: price ?? 0.0,
      currency: currency ?? 'USD',
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      note: json['note'] as String?,
      status: OfferStatus.fromWire(json['status'] as String?),
    );
  }

  /// Tolerates both the W2 `{value,currency}` money object and a bare number
  /// (defensive parse, 40_GUARDRAILS_ARCH §4).
  double? _amount(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is Map && raw['value'] is num) {
      return (raw['value'] as num).toDouble();
    }
    return null;
  }

  String? _currency(Object? raw) {
    if (raw is Map && raw['currency'] is String) {
      return raw['currency'] as String;
    }
    return null;
  }
}
