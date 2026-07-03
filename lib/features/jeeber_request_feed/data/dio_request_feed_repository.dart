import 'dart:async';

import 'package:dio/dio.dart';

import 'request_feed_models.dart';
import 'request_feed_repository.dart';

/// Dio-backed [RequestFeedRepository].
///
/// Uses REST polling (no WebSocket in this implementation) against the W2
/// delivery-service contract. Emits [FeedTransport.polling].
///
/// Live jeeb-gateway endpoint (Contract B — `jeeb-gateway/jeeber-feed`
/// v1.0.0, FROZEN, request-centric):
///   GET  /v1/jeebers/me/feed?status=pending  → 200 `JeeberFeedResponse`
///          { items: [JeeberFeedItem...], totalCount }
///   POST /v1/delivery/requests/{id}/accept
///   POST /v1/delivery/requests/{id}/decline
///
/// The feed returns the PENDING delivery requests an ONLINE jeeber may bid on
/// (server-side visibility predicate: online + status=pending + clientId !=
/// jeeberId). It is online-gated — an offline jeeber receives `{items:[],
/// totalCount:0}`. Each `JeeberFeedItem` is keyed by `requestId` and annotated
/// with this jeeber's existing `myOffer` (nullable). Items with no `myOffer`
/// render as `incoming` (Ignore/Offer card, JM-048 AC1/AC2); items already
/// annotated render as `pendingResponse`.
///
/// NOTE: this previously polled `GET /requests?status=pending`, which returns
/// the CALLER'S OWN client requests and ignores status → a jeeber always saw 0
/// rows. Pointed at the correct request-centric feed per the S02 freeze.
class DioRequestFeedRepository implements RequestFeedRepository {
  DioRequestFeedRepository({
    required Dio dio,
    Duration pollInterval = const Duration(seconds: 10),
  }) : _dio = dio,
       _pollInterval = pollInterval;

  final Dio _dio;
  final Duration _pollInterval;

  /// The jeeb-gateway request-centric discovery feed (Contract B). Online-gated
  /// pending requests the jeeber may bid on. Was `/requests?status=pending`
  /// (returned the caller's own requests → always 0 for a jeeber).
  static const String _feedPath = '/v1/jeebers/me/feed?status=pending';

  final StreamController<DeliveryRequest> _requestsCtrl =
      StreamController<DeliveryRequest>.broadcast();
  final StreamController<FeedTransportUpdate> _transportCtrl =
      StreamController<FeedTransportUpdate>.broadcast(onListen: () {});

  Timer? _pollTimer;
  bool _disposed = false;

  @override
  Stream<DeliveryRequest> get requests => _requestsCtrl.stream;

  @override
  Stream<FeedTransportUpdate> get transport => _transportCtrl.stream;

  @override
  Future<List<DeliveryRequest>> refresh() async {
    _ensurePolling();
    try {
      final response = await _dio.get<dynamic>(_feedPath);
      return _parseRequests(response.data ?? {});
    } on DioException {
      return const <DeliveryRequest>[];
    }
  }

  @override
  Future<RequestActionOutcome> accept(String id) async {
    try {
      await _dio.post<void>('/v1/delivery/requests/$id/accept');
      return RequestActionOutcome.accepted;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 409) return RequestActionOutcome.alreadyTaken;
      if (status == 410) return RequestActionOutcome.expired;
      return RequestActionOutcome.networkError;
    }
  }

  @override
  Future<RequestActionOutcome> decline(String id) async {
    try {
      await _dio.post<void>('/v1/delivery/requests/$id/decline');
      return RequestActionOutcome.declined;
    } on DioException {
      return RequestActionOutcome.networkError;
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _pollTimer?.cancel();
    await _requestsCtrl.close();
    await _transportCtrl.close();
  }

  void _ensurePolling() {
    if (_pollTimer != null || _disposed) return;
    _transportCtrl.add(const FeedTransportUpdate(FeedTransport.polling));
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_disposed) return;
    try {
      final response = await _dio.get<dynamic>(_feedPath);
      final requests = _parseRequests(response.data ?? {});
      for (final r in requests) {
        _requestsCtrl.add(r);
      }
    } on DioException {
      // Swallow poll errors — UI shows stale feed rather than error banner.
    }
  }

  List<DeliveryRequest> _parseRequests(Object? data) {
    final items = data is List
        ? data
        : data is Map<String, dynamic> && data['items'] is List
        ? data['items'] as List
        : const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(_parseRequest)
        .whereType<DeliveryRequest>()
        .toList(growable: false);
  }

  DeliveryRequest? _parseRequest(Map<String, dynamic> json) {
    // Contract B `JeeberFeedItem` is keyed by `requestId`. Tolerate the legacy
    // `/requests` `id` key so the parser is shape-agnostic.
    final id = (json['requestId'] as String?) ?? (json['id'] as String?);
    if (id == null) return null;
    // `pickup`/`dropoff` are RECOMMENDED-nullable in the frozen feed (§3.3).
    // Parse the FeedLocation shape `{ address, location:{lat,lng} }` (and the
    // legacy flat shape), but DEGRADE-DON'T-DROP: fall back to an unknown
    // location so the request card still renders for an online jeeber even
    // when routing fields are absent. Dropping here was a second cause of the
    // empty feed.
    final pickup =
        _parseFeedLocation(json['pickup']) ??
        _parseLiveLocation(json, 'pickup') ??
        const RequestLocation(label: '', latitude: 0, longitude: 0);
    final dropoff =
        _parseFeedLocation(json['dropoff']) ??
        _parseLiveLocation(json, 'dropoff') ??
        const RequestLocation(label: '', latitude: 0, longitude: 0);
    final tier = _parseTier(
      json['tierId'] as String? ?? json['tier'] as String?,
    );
    // `myOffer` (nullable) = this jeeber's existing offer on the request. When
    // present the jeeber has already bid → render the Pending affordance and
    // surface the offered fee (`feeCents`) as the card earnings line.
    final myOffer = json['myOffer'];
    final hasOffer = myOffer is Map<String, dynamic>;
    final feedStatus = hasOffer
        ? JeeberFeedItemStatus.pendingResponse
        : JeeberFeedItemStatus.incoming;
    // The frozen feed item carries no request budget; earnings is only known
    // once the jeeber has offered (`myOffer.feeCents`, cents). Tolerate legacy
    // `potentialEarnings`/`amount` shapes too.
    final amount = json['amount'];
    final earnings =
        (json['potentialEarnings'] as num?)?.toDouble() ??
        _amountValue(amount) ??
        (hasOffer
            ? ((myOffer['feeCents'] as num?)?.toDouble() ?? 0.0) / 100.0
            : 0.0);
    final currency =
        (json['currency'] as String?) ?? _amountCurrency(amount) ?? 'USD';
    // `distanceMeters` (feed) = jeeber→pickup distance → the "away from you"
    // line; `estimatedDistanceKm` is the legacy end-to-end value.
    final distanceMeters = (json['distanceMeters'] as num?)?.toDouble();
    final expiresRaw =
        json['broadcastExpiresAt'] as String? ?? json['expiresAt'] as String?;
    final expires = expiresRaw != null
        ? _parseServerTime(expiresRaw) ??
              DateTime.now().add(const Duration(minutes: 5))
        : DateTime.now().add(const Duration(minutes: 5));
    final createdRaw = json['createdAt'] as String?;
    return DeliveryRequest(
      id: id,
      pickup: pickup,
      dropoff: dropoff,
      tier: tier,
      estimatedDistanceKm:
          (json['estimatedDistanceKm'] as num?)?.toDouble() ?? 0.0,
      potentialEarnings: earnings,
      currency: currency,
      expiresAt: expires,
      // Privacy: the feed strips `clientId`; `senderName` is only present on
      // the legacy shape.
      senderName: json['senderName'] as String? ?? json['clientId'] as String?,
      senderAvatarUrl: json['senderAvatarUrl'] as String?,
      // `description` is the deliverable summary the client authored for
      // jeebers (the card body line).
      itemsSummary:
          json['description'] as String? ??
          json['itemsSummary'] as String? ??
          json['title'] as String?,
      distanceFromYouKm: distanceMeters != null
          ? distanceMeters / 1000.0
          : (json['distanceFromYouKm'] as num?)?.toDouble(),
      receivedAt: createdRaw != null ? _parseServerTime(createdRaw) : null,
      feedStatus: feedStatus,
    );
  }

  /// Parses a gateway timestamp string. Server times are UTC; an ISO string
  /// WITHOUT an explicit zone marker (no trailing `Z`, no `±hh:mm` offset)
  /// would otherwise be interpreted by [DateTime.parse] as device-LOCAL,
  /// skewing every card's clock and expiry by the device's UTC offset
  /// (SW-03: feed cards read "12:31" under a 14:31 status bar). Zone-less
  /// strings are therefore re-interpreted as UTC; zoned strings parse as-is.
  /// Presentation converts with `toLocal()` at render time.
  static DateTime? _parseServerTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    if (parsed.isUtc) return parsed; // had `Z` or an explicit offset
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  /// Parses a Contract B `FeedLocation` (`{ address, location:{lat,lng} }`),
  /// tolerating the legacy flat `{ address|label, lat|latitude, lng|longitude }`
  /// shape. Returns `null` when no usable coordinates are present.
  RequestLocation? _parseFeedLocation(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final label =
        (raw['address'] as String?) ?? (raw['label'] as String?) ?? '';
    final loc = raw['location'];
    if (loc is Map) {
      final lat =
          (loc['lat'] as num?)?.toDouble() ??
          (loc['latitude'] as num?)?.toDouble();
      final lng =
          (loc['lng'] as num?)?.toDouble() ??
          (loc['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        return RequestLocation(label: label, latitude: lat, longitude: lng);
      }
    }
    // Legacy flat shape.
    final lat =
        (raw['lat'] as num?)?.toDouble() ??
        (raw['latitude'] as num?)?.toDouble();
    final lng =
        (raw['lng'] as num?)?.toDouble() ??
        (raw['longitude'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      return RequestLocation(label: label, latitude: lat, longitude: lng);
    }
    return null;
  }

  RequestLocation? _parseLiveLocation(Map<String, dynamic> json, String key) {
    final loc = json['${key}Location'];
    if (loc is! Map<String, dynamic>) return null;
    final label = json['${key}Address'] as String?;
    final lat =
        (loc['lat'] as num?)?.toDouble() ??
        (loc['latitude'] as num?)?.toDouble();
    final lng =
        (loc['lng'] as num?)?.toDouble() ??
        (loc['longitude'] as num?)?.toDouble();
    if (label == null || lat == null || lng == null) return null;
    return RequestLocation(label: label, latitude: lat, longitude: lng);
  }

  double? _amountValue(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is Map && raw['value'] is num) {
      return (raw['value'] as num).toDouble();
    }
    return null;
  }

  String? _amountCurrency(Object? raw) {
    if (raw is Map && raw['currency'] is String) {
      return raw['currency'] as String;
    }
    return null;
  }

  JeeberRequestTier _parseTier(String? raw) {
    switch (raw) {
      case 'flash':
        return JeeberRequestTier.flash;
      // Feed tiers: flash/express/standard/on_the_way/eco. Map express/standard
      // /on_the_way/eco onto the app's `standard` tier (the JeeberFeedTabView
      // tier filter treats `standard` as the "Express" chip).
      case 'standard':
      case 'express':
      case 'on_the_way':
      case 'eco':
        return JeeberRequestTier.standard;
      case 'bulk':
        return JeeberRequestTier.bulk;
      default:
        return JeeberRequestTier.light;
    }
  }
}
