import 'package:dio/dio.dart';

import '../domain/offer_submission_repository.dart';

/// Dio-backed [OfferSubmissionRepository].
///
/// LIVE gateway contract (iter6 offer-405 fix — `RequestOffersController.cs:98`,
/// `[HttpPost("requests/{requestId}/offers")]`, verified against the live
/// gateway on :10090):
///   POST /requests/{requestId}/offers
///   body: { fee, etaMinutes, note? }            ← gateway `CreateOfferBody`
///          field names: `fee` (gross, in the client's currency, >= $1),
///          `etaMinutes` (positive int), optional `note` (<= 500 chars). The
///          gateway re-validates every field; the cubit floors price/eta > 0
///          client-side first.
///   201 Created → OfferDto
///          { id, requestId, jeeberId, status, fee, etaMinutes, note,
///            createdAt, updatedAt }
///        — `id` is the server-minted offerId. The 201 body does NOT carry a
///          `conversationId`: the gateway seats the offering jeeber on the
///          request's conversation server-side (`SeatOfferingJeeberAsync`,
///          keyed by `correlation_key == requestId`), so the subsequent chat is
///          resolved by the requestId — consistent with the chat-contract
///          rewrite (PR #69). We still parse a `conversationId` defensively if
///          the gateway ever adds one; otherwise we fall back to the requestId.
///   400 → ProblemDetails (fee-too-low / eta-invalid / note-too-long) — surfaced
///         as a generic submit failure (the cubit floors fee/eta first).
///   402 → insufficient balance (legacy O1) — still mapped to
///         [OfferSubmissionFailure.insufficientBalance] if ever returned.
///   404 → request not found (treated as requestGone).
///   409 → no longer accepting offers / duplicate live offer / cap reached —
///         mapped to [OfferSubmissionFailure.requestGone] (bounce to feed).
///   422 → offer-service rejected the payload.
///
/// PRE-FIX (the iter6 405 blocker): this repo POSTed to the MOCK route
/// `/v1/offers {requestId, priceUsd, etaMinutes}` (the :4010
/// `/offer-service/v1/offers` shape). The LIVE gateway has no bare
/// `POST /v1/offers` action, so the authenticated POST returned 405 and the
/// jeeber could never submit an offer. Repointed to the live request-scoped
/// route above.
class DioOfferSubmissionRepository implements OfferSubmissionRepository {
  const DioOfferSubmissionRepository(this._dio);

  final Dio _dio;

  /// The live request-scoped submit path (Sprint-2 Contract 4a, FROZEN):
  /// `POST /v1/requests/{requestId}/offers`.
  ///
  /// ARCH-01 / Contract 4a: the Dio base is ORIGIN-ONLY (no `/v1`), so EVERY
  /// path must carry exactly one `/v1` (e.g. the accept path
  /// `/v1/offers/{offerId}/accept`). The earlier `/requests/{id}/offers` value
  /// dropped the `/v1` — it only worked back when the Dio base still ended in
  /// `/v1`; once ARCH-01 moved the base to origin-only it silently resolved to
  /// `:10090/requests/{id}/offers` (missing `/v1`), the same class of defect as
  /// the S16 `/v1/v1` availability NO-GO. Restored to the single-`/v1` contract
  /// path.
  static String _pathFor(String requestId) => '/v1/requests/$requestId/offers';

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _pathFor(requestId),
        data: _buildBody(priceUsd, etaMinutes, note),
      );
      return _parseResult(response.data, requestId);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Map<String, dynamic> _buildBody(
    double priceUsd,
    int etaMinutes,
    String? note,
  ) {
    return {
      // Gateway `CreateOfferBody`: `fee` (gross, client currency), `etaMinutes`,
      // optional `note`. NOT `priceUsd`/`requestId` — those were the mock-only
      // shape; the requestId now travels in the URL path.
      'fee': priceUsd,
      'etaMinutes': etaMinutes,
      if (note != null && note.isNotEmpty) 'note': note,
    };
  }

  OfferSubmissionResult _parseResult(
    Map<String, dynamic>? data,
    String requestId,
  ) {
    // The live `OfferDto` returns the offer id as `id`; tolerate `offerId` too
    // (older mock shape) for safety.
    final offerId =
        (data?['id'] as String?) ?? (data?['offerId'] as String?) ?? '';
    // The live 201 does NOT carry a conversationId (the jeeber is seated on the
    // request's conversation server-side, keyed by requestId). Parse it
    // defensively if present, else fall back to the requestId so the subsequent
    // chat resolves the server-minted conversation by its correlation key —
    // consistent with the chat-contract rewrite (PR #69).
    final rawConversationId = (data?['conversationId'] as String?)?.trim();
    final conversationId = (rawConversationId != null &&
            rawConversationId.isNotEmpty)
        ? rawConversationId
        : requestId;
    return OfferSubmissionResult(
      offerId: offerId,
      conversationId: conversationId,
    );
  }

  OfferSubmissionException _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    // 402 (O1) is the insufficient-balance signal — NOT a generic error. Parse
    // {needed, available, currency} for the JM-046 sheet (42_GUARDRAILS_MOCK
    // §5.1). Defensive parse (40_GUARDRAILS_ARCH §4): tolerate snake_case and a
    // missing/malformed body (the cubit still surfaces the sheet; amounts fall
    // back to 0 / the wallet source).
    if (status == 402) {
      return OfferSubmissionException(
        OfferSubmissionFailure.insufficientBalance,
        balance: _parseBalance(e.response?.data),
      );
    }
    // 404 (request not found), 409 (no longer accepting offers / duplicate live
    // offer / cap reached) and 410 (expired) all mean the auction is gone for
    // this jeeber — bounce the user back to the feed.
    if (status == 404 || status == 409 || status == 410) {
      return const OfferSubmissionException(OfferSubmissionFailure.requestGone);
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const OfferSubmissionException(OfferSubmissionFailure.network);
    }
    return OfferSubmissionException(
      OfferSubmissionFailure.server,
      message: 'HTTP $status',
    );
  }

  InsufficientBalanceInfo? _parseBalance(Object? data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    return InsufficientBalanceInfo(
      needed: _num(map['needed'] ?? map['needed_amount']),
      available: _num(map['available'] ?? map['available_balance']),
      currency: _str(map['currency']) ?? 'USD',
    );
  }

  double _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
