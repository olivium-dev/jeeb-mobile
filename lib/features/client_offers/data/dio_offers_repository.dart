import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/network/single_flight_get.dart';
import '../../../core/requests/server_request_status.dart';
import '../../otp_handover/domain/handover_code_store.dart';
import '../domain/jeeber_vehicle.dart';
import '../domain/offer.dart';
import '../domain/offers_repository.dart';

/// Dio-backed [OffersRepository].
///
/// Endpoints (gateway contract; `MockGatewayClient` rewrites the `/v1/...`
/// prefix to the `:4010` service prefix — 40_GUARDRAILS_ARCH §4):
///   GET  `/v1/offers?requestId=<id>` → current offer rows.
///   GET  `/v1/requests/:requestId`   → owner-scoped request status and an
///                                       optional server deadline.
///   POST /v1/offers/:offerId/accept  → `/offer-service/v1/offers/:id/accept` —
///                                       `{ offer, conversationId, ... }` on 200,
///                                       409 race-conflict, 410 gone.
///
/// The offer-list response does not own request lifecycle. The repository joins
/// it with the request row so Accept follows the server status. A countdown is
/// exposed only when either response carries a parseable server deadline.
///
/// Wire-shape note (mock + journey-seed `offers_received`): each offer row is
/// `{ id, requestId, jeeberId, amount: { value, currency }, price: { value },
/// etaMinutes, note, status, createdAt }`. The list endpoint does NOT enrich
/// the row with the Jeeber's display name or rating (those live on the chat
/// `offer_card` message body); we parse name/rating defensively and fall back
/// to sane defaults. Surfacing the real name/rating on the list row is a
/// backender enrichment gap — flagged O-list-enrich in 50_ROUTE_REQUESTS.md.
class DioOffersRepository implements OffersRepository {
  DioOffersRepository(
    Dio dio, {
    HandoverCodeStore? handoverCodeStore,
    SingleFlightGet? coalescer,
  })  : _dio = dio,
        _handoverCodeStore = handoverCodeStore,
        // FIX-A: route the `GET /v1/offers` reads through the SHARED
        // single-flight coalescer (DI injects one instance across the offers /
        // waiting / home repos) so a duplicate concurrent probe for the same
        // requestId collapses onto ONE wire call instead of fanning out into a
        // 429-tripping storm. Falls back to a private per-instance coalescer so
        // a bare `DioOffersRepository(dio)` (widget tests) still dedupes.
        _coalescer = coalescer ?? SingleFlightGet(dio);

  final Dio _dio;
  final SingleFlightGet _coalescer;

  /// G4: sink for the accept response's `handoverCode`. The accept response is
  /// the only wire moment the customer is given the code, so the parse site is
  /// the single choke point that persists it (fire-and-forget — a prefs write
  /// must never fail or delay the accept). Null in tests that don't exercise
  /// persistence.
  final HandoverCodeStore? _handoverCodeStore;

  /// Offer statuses that are still live (a client can accept them). Withdrawn /
  /// superseded / expired / accepted offers are filtered out of the review list
  /// — the screen only shows live bids.
  ///
  /// `pending` is the status the LIVE jeeb-gateway/offer-service stamps on a
  /// freshly-submitted, acceptable offer (`GET /v1/offers?requestId` returns
  /// `"status":"pending"`). The `:4010` mock used `submitted`/`edited`, so the
  /// client originally omitted `pending` — which silently filtered out every
  /// real offer and left the "Choose a Jeeber" screen stuck on "Waiting for
  /// offers" even though the offer arrived 200 on the wire. All three are live.
  static const Set<String> _liveStatuses = {'pending', 'submitted', 'edited'};

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    try {
      final offersResponse = await _coalescer.get(
        '/v1/offers',
        queryParameters: <String, dynamic>{'requestId': requestId},
      );
      final requestResponse = await _dio.get<dynamic>(
        '/v1/requests/${Uri.encodeComponent(requestId)}',
      );
      return _parseSnapshot(offersResponse.data, requestResponse.data);
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    try {
      final response = await _dio.post<dynamic>('/v1/offers/$offerId/accept');
      return _parseAcceptResult(response.data);
    } on DioException catch (e) {
      _rethrowAccept(e);
    }
  }

  /// Pull the server-created delivery id + conversation id out of the accept
  /// response.
  ///
  /// The offer-accept saga returns an `OfferAcceptResultDto`. The golden
  /// response surfaces the created delivery as `deliveryId` and the promoted
  /// 1:1 order chat as `conversationId` (mock `POST /v1/offers/:offerId/accept`
  /// returns `{ offer, handoverCode, conversationId, conversationPhase }`); we
  /// also accept the snake_case variants so we stay compatible regardless of
  /// the gateway's serialization casing. Anything else (legacy body with no
  /// field, non-map payload, empty string) maps to a null field so the caller
  /// never crashes — JM-029 falls back to the request/delivery id when the
  /// conversation id is absent, and the "Track order" CTA stays hidden when the
  /// delivery id is absent.
  OfferAcceptResult _parseAcceptResult(dynamic data) {
    if (data is! Map) return OfferAcceptResult.empty;
    final deliveryId = acceptResponseDeliveryId(data);
    final conversationId =
        _cleanString(data['conversationId'] ?? data['conversation_id']);
    // G4 (sprint-009 P0): RETAIN the handover code. The accept response is the
    // only wire moment the customer's app receives it (`GET /otp` is an SMS
    // trigger with no `code` field), so discarding it here — the pre-fix
    // behavior — left the customer with nothing to show the Jeeber at the
    // door. Persisted keyed by delivery id so it survives app restarts.
    // NEVER log it (DiagRedaction masks `handoverCode` keys).
    final handoverCode =
        _cleanString(data['handoverCode'] ?? data['handover_code']);
    _persistHandoverCode(deliveryId: deliveryId, code: handoverCode);
    return OfferAcceptResult(
      deliveryId: deliveryId,
      conversationId: conversationId,
      handoverCode: handoverCode,
    );
  }

  /// Normalises a wire field: non-empty trimmed string or null.
  String? _cleanString(Object? raw) =>
      raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

  /// Fire-and-forget local persistence of the handover code — a prefs write
  /// must never fail, delay, or reorder the accept flow.
  void _persistHandoverCode({String? deliveryId, String? code}) {
    final store = _handoverCodeStore;
    if (store == null || deliveryId == null || code == null) return;
    unawaited(
      store.save(deliveryId: deliveryId, code: code).catchError((_) {}),
    );
  }

  OffersSnapshot _parseSnapshot(dynamic data, dynamic requestData) {
    // Tolerate every shape the gateway / mock can emit: the offer-service
    // `{ items: [...] }` envelope (current mock), a legacy `{ offers: [...] }`
    // key, or a bare top-level array.
    final List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic>) {
      items = (data['items'] as List?) ??
          (data['offers'] as List?) ??
          const <dynamic>[];
    } else {
      throw const OffersRepositoryException(OffersFailure.unknown);
    }
    final rows = items.whereType<Map<String, dynamic>>().toList(growable: false);

    // A request is closed once one of its offers has been accepted — the
    // review list should then render the closed banner rather than stale CTAs.
    final hasAccepted =
        rows.any((r) => (r['status'] as String?) == 'accepted');

    final offers = rows
        .where((r) {
          final status = r['status'] as String?;
          // Null status (lenient fixtures / legacy bodies) is treated as live.
          return status == null || _liveStatuses.contains(status);
        })
        .map(_parseOffer)
        .whereType<Offer>()
        .toList(growable: false);

    final requestStatus = ServerRequestStatus.normalize(
      requestData is Map ? requestData['status'] : null,
    );
    final deadline = _serverDeadline(requestData) ?? _serverDeadline(data);
    final explicitlyOpen = _explicitOpen(requestData) ?? _explicitOpen(data);
    final statusIsOpen = ServerRequestStatus.isOpen(requestStatus);
    final open = !hasAccepted &&
        (requestStatus.isNotEmpty ? statusIsOpen : explicitlyOpen ?? false);
    return OffersSnapshot(
      offers: offers,
      windowExpiresAt: deadline,
      requestIsOpen: open,
      requestIsExpired: ServerRequestStatus.isExpired(requestStatus),
    );
  }

  bool? _explicitOpen(dynamic data) {
    if (data is! Map) return null;
    final raw = data['requestIsOpen'];
    return raw is bool ? raw : null;
  }

  DateTime? _serverDeadline(dynamic data) {
    if (data is! Map) return null;
    final raw = data['windowExpiresAt'] ??
        data['offerWindowExpiresAt'] ??
        data['broadcastExpiresAt'] ??
        data['expiresAt'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  Offer? _parseOffer(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final jeeberId = json['jeeberId'] as String?;
    if (id == null || jeeberId == null) return null;
    final fee = _parseFee(json);
    final eta = (json['etaMinutes'] as num?)?.toInt() ?? 0;
    final submitted = _parseDate(
      json['submittedAt'] as String? ?? json['createdAt'] as String?,
    );
    return Offer(
      id: id,
      jeeberId: jeeberId,
      jeeberName: json['jeeberName'] as String? ?? jeeberId,
      fee: fee,
      currency: _parseCurrency(json),
      etaMinutes: eta,
      vehicle: _parseVehicle(
        json['vehicleType'] as String? ?? json['vehicle'] as String?,
      ),
      // W6/SW-08: when the row carries no rating, default to an HONEST 0.0 with
      // a 0 count — never a fabricated 4.5. The offer card guards on
      // `ratingCount > 0` and renders "No ratings yet" for the zero case, so a
      // real score is only ever shown when the gateway actually sent one.
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      submittedAt: submitted,
      avatarUrl: json['avatarUrl'] as String? ??
          json['jeeberAvatarUrl'] as String?,
      note: (json['note'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['note'] as String).trim(),
    );
  }

  /// Reads the quoted fee from whichever money shape the gateway used. The
  /// offer-service rows carry the amount as a nested `{ value, currency }`
  /// object under `amount` (or `price`); legacy/test bodies may carry a flat
  /// numeric `fee`. Tolerate all three so the card never shows 0.00 for a
  /// well-formed offer.
  double _parseFee(Map<String, dynamic> json) {
    final flat = json['fee'];
    if (flat is num) return flat.toDouble();
    final value = _moneyValue(json['amount']) ?? _moneyValue(json['price']);
    return value ?? 0.0;
  }

  String _parseCurrency(Map<String, dynamic> json) {
    final flat = json['currency'];
    if (flat is String && flat.isNotEmpty) return flat;
    final fromAmount = _moneyCurrency(json['amount']) ??
        _moneyCurrency(json['price']);
    return fromAmount ?? 'USD';
  }

  double? _moneyValue(dynamic money) {
    if (money is Map) {
      final v = money['value'];
      if (v is num) return v.toDouble();
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

  DateTime _parseDate(String? raw) {
    if (raw == null) return DateTime.now();
    return DateTime.tryParse(raw) ?? DateTime.now();
  }

  JeeberVehicle _parseVehicle(String? raw) {
    switch (raw) {
      case 'car':
        return JeeberVehicle.car;
      case 'motorcycle':
        return JeeberVehicle.motorcycle;
      case 'bicycle':
        return JeeberVehicle.bicycle;
      case 'scooter':
        return JeeberVehicle.scooter;
      case 'van':
        return JeeberVehicle.van;
      case 'walker':
        return JeeberVehicle.walker;
    }
    return JeeberVehicle.scooter;
  }

  /// Small default back-off for a rate-limited read when the server sent no
  /// (parseable) `Retry-After`. The [RateLimitInterceptor] still owns the exact
  /// suppression window; this only paces the cubit's cold-load auto-retry.
  static const Duration _rateLimitRetryFallback = Duration(seconds: 5);

  Never _rethrowDio(DioException e) {
    // FIX-A: a 429 — or the RateLimitInterceptor's local suppression rejection
    // (a synthetic `DioExceptionType.cancel` raised while a Retry-After window
    // is open) — is TRANSIENT back-pressure, never a fatal cold-load failure.
    // Map it to the retryable [OffersFailure.rateLimited] so the offers screen
    // stays in loading and auto-retries after Retry-After, instead of dropping
    // to the connection-error page.
    if (_isRateLimited(e)) {
      throw OffersRepositoryException(
        OffersFailure.rateLimited,
        'rate limited',
        _retryAfterOf(e),
      );
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw const OffersRepositoryException(OffersFailure.network);
    }
    throw const OffersRepositoryException(OffersFailure.unknown);
  }

  /// True when [e] is a rate-limit signal: a gateway 429 OR the local
  /// [RateLimitInterceptor] suppression rejection (the ONLY source of a
  /// `DioExceptionType.cancel` on this read path — this repo never cancels a
  /// request itself).
  static bool _isRateLimited(DioException e) =>
      e.response?.statusCode == 429 || e.type == DioExceptionType.cancel;

  /// Best-effort `Retry-After` (delta-seconds) off a real 429; the local
  /// suppression rejection carries no response, so it falls back to
  /// [_rateLimitRetryFallback]. The interceptor still enforces the precise
  /// window, so an early retry simply re-suppresses and the loop self-heals.
  Duration _retryAfterOf(DioException e) {
    final raw = e.response?.headers.value('retry-after')?.trim();
    final seconds = raw == null ? null : int.tryParse(raw);
    if (seconds != null && seconds > 0) return Duration(seconds: seconds);
    return _rateLimitRetryFallback;
  }

  Never _rethrowAccept(DioException e) {
    final status = e.response?.statusCode;
    if (status == 409) {
      // A 409 is NOT always "offer gone". The gateway BR-10 pre-check returns a
      // 409 with ProblemDetails `type`
      // `https://jeeb.dev/errors/too-many-active-deliveries` when the winning
      // Jeeber already holds the max concurrent active deliveries — the offer is
      // still pending upstream. Distinguish it so the UI shows the correct
      // reason ("choose another offer") instead of the misleading "this offer is
      // no longer available". (JEBV4-158)
      if (_isTooManyActiveDeliveries(e.response?.data)) {
        throw const OffersRepositoryException(OffersFailure.jeeberAtCapacity);
      }
      // sprint-009 scenario matrix #7: the gateway reuses 409 for several
      // distinct accept conflicts and discriminates via the ProblemDetails
      // body (`OffersController.cs`). Request-level closure (the auction is
      // already won / cancelled / expired — `request_not_open`,
      // `request-not-acceptable`, `already-accepted`) must render "This
      // request is no longer open", NOT the offer-level "offer no longer
      // available" copy a withdrawn/superseded single offer gets.
      throw OffersRepositoryException(
        _isRequestClosedConflict(e.response?.data)
            ? OffersFailure.requestNotOpen
            : OffersFailure.offerNotPending,
      );
    }
    // 410 offer-expired: the request expired before the accept landed.
    // 404: the offer/request vanished server-side (superseded + pruned) —
    // same user-facing truth as a closed request, never a generic failure.
    if (status == 410 || status == 404) {
      throw const OffersRepositoryException(OffersFailure.requestNotOpen);
    }
    _rethrowDio(e);
  }

  /// Classifies a 409 accept body as a REQUEST-level closure (auction gone:
  /// `request_not_open` / `request-not-acceptable` / `already-accepted`) vs an
  /// OFFER-level conflict (`offer-not-pending`, BR-1/BR-10 violations). The
  /// gateway ProblemDetails carries the discriminator in `type`/`code`/`title`/
  /// `detail` depending on the surface, so probe them all defensively
  /// (40_GUARDRAILS_ARCH §4; mirrors `DioOfferSubmissionRepository._isOfferCap`).
  /// An undiscriminated body stays offer-level (the pre-fix behavior).
  bool _isRequestClosedConflict(Object? data) {
    if (data is! Map) return false;
    final haystack = [
      data['type'],
      data['code'],
      data['title'],
      data['detail'],
      data['error'],
    ].whereType<String>().map((s) => s.toLowerCase()).join(' ');
    return haystack.contains('request_not_open') ||
        haystack.contains('request-not-open') ||
        haystack.contains('request-not-acceptable') ||
        haystack.contains('request_not_acceptable') ||
        haystack.contains('already-accepted') ||
        haystack.contains('already_accepted') ||
        haystack.contains('request is no longer');
  }

  /// True when a 409 body is the gateway's BR-10 too-many-active-deliveries
  /// ProblemDetails. Matches on the stable `type` URI (preferred); tolerant of
  /// the body arriving as a decoded `Map` or a raw JSON `String`.
  static bool _isTooManyActiveDeliveries(Object? body) {
    const marker = 'too-many-active-deliveries';
    if (body is Map) {
      final type = body['type'];
      if (type is String && type.contains(marker)) return true;
    }
    if (body is String && body.contains(marker)) return true;
    return false;
  }
}
