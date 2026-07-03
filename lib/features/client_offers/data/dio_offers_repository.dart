import 'dart:async';

import 'package:dio/dio.dart';

import '../../otp_handover/domain/handover_code_store.dart';
import '../domain/jeeber_vehicle.dart';
import '../domain/offer.dart';
import '../domain/offers_repository.dart';

/// Dio-backed [OffersRepository].
///
/// Endpoints (gateway contract; `MockGatewayClient` rewrites the `/v1/...`
/// prefix to the `:4010` service prefix — 40_GUARDRAILS_ARCH §4):
///   GET  `/v1/offers?requestId=<id>` → `/offer-service/v1/offers` — JSON
///                                       `{ items: [...], cursor }` envelope
///                                       (JM-028, 42_GUARDRAILS_MOCK §1.2).
///   POST /v1/offers/:offerId/accept  → `/offer-service/v1/offers/:id/accept` —
///                                       `{ offer, conversationId, ... }` on 200,
///                                       409 race-conflict, 410 gone.
///
/// W1-INT (JM-028): the list path moved from the dead `/v1/requests/:id/offers`
/// (no mock route exists — it 404s) to the offer-service query-param endpoint
/// the mock actually serves. The offer-window deadline is derived from the
/// first offer's `createdAt` + 5 min because the list endpoint omits
/// `windowExpiresAt`.
///
/// Wire-shape note (mock + journey-seed `offers_received`): each offer row is
/// `{ id, requestId, jeeberId, amount: { value, currency }, price: { value },
/// etaMinutes, note, status, createdAt }`. The list endpoint does NOT enrich
/// the row with the Jeeber's display name or rating (those live on the chat
/// `offer_card` message body); we parse name/rating defensively and fall back
/// to sane defaults. Surfacing the real name/rating on the list row is a
/// backender enrichment gap — flagged O-list-enrich in 50_ROUTE_REQUESTS.md.
class DioOffersRepository implements OffersRepository {
  const DioOffersRepository(this._dio, {HandoverCodeStore? handoverCodeStore})
      : _handoverCodeStore = handoverCodeStore;

  final Dio _dio;

  /// G4: sink for the accept response's `handoverCode`. The accept response is
  /// the only wire moment the customer is given the code, so the parse site is
  /// the single choke point that persists it (fire-and-forget — a prefs write
  /// must never fail or delay the accept). Null in tests that don't exercise
  /// persistence.
  final HandoverCodeStore? _handoverCodeStore;

  static const Duration _defaultWindow = Duration(minutes: 5);

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
      final response = await _dio.get<dynamic>(
        '/v1/offers',
        queryParameters: <String, dynamic>{'requestId': requestId},
      );
      return _parseSnapshot(response.data);
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
    final deliveryId = _cleanString(data['deliveryId'] ?? data['delivery_id']);
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

  OffersSnapshot _parseSnapshot(dynamic data) {
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

    final deadline = _deriveDeadline(data, offers);
    // Honour an explicit `requestIsOpen` flag if the gateway sends one;
    // otherwise derive it from the accepted-offer presence.
    final open = data is Map<String, dynamic>
        ? (data['requestIsOpen'] as bool?) ?? !hasAccepted
        : !hasAccepted;
    return OffersSnapshot(
      offers: offers,
      windowExpiresAt: deadline,
      requestIsOpen: open,
    );
  }

  DateTime _deriveDeadline(dynamic data, List<Offer> offers) {
    if (data is Map<String, dynamic>) {
      final raw = data['windowExpiresAt'] as String?;
      if (raw != null) {
        return DateTime.tryParse(raw) ?? _fallbackDeadline(offers);
      }
    }
    return _fallbackDeadline(offers);
  }

  DateTime _fallbackDeadline(List<Offer> offers) {
    // The list endpoint omits `windowExpiresAt` entirely, so the client has no
    // server-authoritative deadline. The window is anchored on the first
    // offer's `submittedAt` (`createdAt`) + [_defaultWindow] — the
    // first-offer-opens-the-window contract documented at the top of this file.
    // When the list is empty there is no offer to anchor on, so we default to a
    // LIVE window from "now" (the review list only renders for an open,
    // offers-received request, so a freshly loaded list must not present a
    // retroactively expired window).
    if (offers.isEmpty) return DateTime.now().add(_defaultWindow);
    return offers.first.submittedAt.add(_defaultWindow);
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
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
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

  Never _rethrowDio(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw const OffersRepositoryException(OffersFailure.network);
    }
    throw const OffersRepositoryException(OffersFailure.unknown);
  }

  Never _rethrowAccept(DioException e) {
    final status = e.response?.statusCode;
    if (status == 409) {
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
        haystack.contains('not-acceptable') ||
        haystack.contains('not_acceptable') ||
        haystack.contains('already-accepted') ||
        haystack.contains('already_accepted') ||
        haystack.contains('request is no longer');
  }
}
