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

  /// The live request-scoped submit path (BUG-2 corrected route):
  /// `POST /requests/{requestId}/offers` — **NO `/v1` prefix**.
  ///
  /// LIVE GATEWAY TRUTH (verified against `:10090` + the gateway source): the
  /// offer-create action lives on `RequestOffersController`
  /// (`[HttpPost("requests/{requestId}/offers")]`) which carries **no**
  /// `[Route]` prefix and **no** API-version segment, so the live route is the
  /// origin-relative `/requests/{requestId}/offers`. The Dio base is
  /// ORIGIN-ONLY (`:10090`, ARCH-01), so this path is sent verbatim.
  ///
  /// This corrects two WRONG variants that both fail on the live wire
  /// (`docs/lessons-learned/live-api-route-corrections.md`):
  ///   * `POST /v1/offers`               → **405** (mock-only collection route).
  ///   * `POST /v1/requests/{id}/offers` → **404** (no such route is registered
  ///     — the prior `/v1`-prefixed value was wired on a uniform-versioning
  ///     assumption that the obsolete `RequestOffersController` does not honour).
  /// The accept leg is asymmetric and DOES carry `/v1`
  /// (`POST /v1/offers/{offerId}/accept`, `V1/JeebOffersController`), so the two
  /// legs deliberately differ.
  static String _pathFor(String requestId) => '/requests/$requestId/offers';

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
    // sprint-009: a 409 now carries a discriminator so the 20-offer CAP is told
    // apart from a closed request. The cap is a per-jeeber throttle (keep the
    // composer, offer to withdraw + retry); `request-not-open-for-offers` and
    // every other 409/404/410 mean the auction is gone for this jeeber (bounce
    // to the feed).
    if (status == 409 && _isOfferCap(e.response?.data)) {
      return const OfferSubmissionException(
        OfferSubmissionFailure.offerCapReached,
      );
    }
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

  /// Classifies a 409 body as the offer-CAP case vs the closed-request case.
  ///
  /// The gateway ProblemDetails carries the discriminator in `type`/`code`/
  /// `title`/`detail` depending on the surface, so probe them all defensively
  /// (40_GUARDRAILS_ARCH §4). The cap reads like `offer-cap-reached` /
  /// `too-many-offers` / `offer_limit`; `request-not-open-for-offers` is
  /// explicitly NOT the cap (it is a closed request → [requestGone]).
  bool _isOfferCap(Object? data) {
    if (data is! Map) return false;
    final haystack = [
      data['type'],
      data['code'],
      data['title'],
      data['detail'],
      data['error'],
    ].whereType<String>().map((s) => s.toLowerCase()).join(' ');
    if (haystack.contains('not-open') || haystack.contains('not_open')) {
      return false;
    }
    return haystack.contains('cap') ||
        haystack.contains('too-many') ||
        haystack.contains('too_many') ||
        haystack.contains('limit') ||
        haystack.contains('maximum') ||
        haystack.contains('20');
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
