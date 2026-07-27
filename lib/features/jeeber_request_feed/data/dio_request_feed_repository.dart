import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/formatting/server_time.dart';
import '../../../core/lifecycle/polling_source.dart';
import '../../../core/requests/server_request_status.dart';
import 'request_feed_models.dart';
import 'request_feed_repository.dart';

/// Dio-backed [RequestFeedRepository].
///
/// ## NO PERIODIC POLL LIVES HERE ANY MORE (b02, POLLING-ELIMINATION-PLAN A.1)
///
/// This class used to own a 60 s `LifecyclePoller` ("safety net") that re-GET
/// the feed on a wall clock. It is **deleted**, not shortened, not gated: under
/// the owner's rule a repeated call at *any* interval is banned, and a
/// "bounded safety net" is still a repeated call.
///
/// What drives the feed now — all three are one-shot, none is periodic:
///   1. **screen open** — `RequestFeedCubit.start()` awaits one [refresh].
///   2. **foreground resume / shell-tab refocus** — `FeedResumeRefetcher`
///      (`presentation/feed_resume_refetcher.dart`) calls
///      `RequestFeedCubit.refresh()` once per transition.
///   3. **`new_request` push** — `PushRefreshSignals` → `RequestFeedCubit`'s
///      `refreshSignals` subscription → one [refresh] (JEBV4-342, merged as
///      jeeb-mobile #178; arrival witnessed on physical hardware).
///
/// Deleting the interval was deliberately sequenced AFTER (3) was proven to
/// drive the UI on a device. Do not delete a poll before its push is proven:
/// the failure mode is stale data with no error anywhere — silent on the
/// device, silent in the gateway journal, invisible to a screenshot.
///
/// The `--dart-define JEEB_FEED_POLL_SECONDS` knob added alongside #178 (to
/// push the poll past the observation window during that PR's negative test)
/// is gone with the poll it parameterised. There is no cadence left to move.
///
/// Consequence worth stating plainly: the poll tick was the ONLY producer on
/// [requests] for this implementation, so that stream is now silent here and
/// every row reaches the cubit through the snapshot-authoritative [refresh]
/// reconcile instead. That reconcile is a strict superset of what the stream
/// fan-in did (it also RETIRES rows the gateway has dropped, which the stream
/// never could), so no feed row is lost. `RequestFeedCubit`'s optional
/// `onNewRequestSound` hook fired off the stream — it has zero production
/// construction sites (only `test/request_feed_cubit_test.dart:75`), so no
/// shipped behaviour depends on it. Other `RequestFeedRepository`
/// implementations (the fakes, the seeded catalog doubles) still emit.
///
/// ⚠️ If you are about to re-add a timer here, you are re-opening JEBV4-342.
///
/// Uses REST (no WebSocket in this implementation) against the W2
/// delivery-service contract.
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
class DioRequestFeedRepository implements RequestFeedRepository, PollingSource {
  DioRequestFeedRepository({required Dio dio, DateTime Function()? now})
    : _dio = dio,
      _now = now ?? DateTime.now;

  final Dio _dio;

  /// Device clock, injected for tests. It anchors the DERIVED card deadline
  /// (see the `offerDeadlineInSeconds` parse below) — the feed never parses a
  /// server absolute.
  final DateTime Function() _now;

  /// The jeeb-gateway request-centric discovery feed (Contract B). Online-gated
  /// pending requests the jeeber may bid on. Was `/requests?status=pending`
  /// (returned the caller's own requests → always 0 for a jeeber).
  static const String _feedPath = '/v1/jeebers/me/feed?status=pending';

  final StreamController<DeliveryRequest> _requestsCtrl =
      StreamController<DeliveryRequest>.broadcast();
  final StreamController<FeedTransportUpdate> _transportCtrl =
      StreamController<FeedTransportUpdate>.broadcast(onListen: () {});

  /// Interest lease held by the visible consumers ([PollingSource]). It no
  /// longer arms anything — see the class doc: there is no timer left. It is
  /// retained for exactly one reason: it is the edge on which the one-shot
  /// [FeedTransport] announcement fires (first interest only), and the shell's
  /// visibility plumbing already speaks it. It must never be used to (re)arm a
  /// cadence.
  final Set<Object> _interest = HashSet<Object>.identity();
  bool _disposed = false;

  @override
  Stream<DeliveryRequest> get requests => _requestsCtrl.stream;

  @override
  Stream<FeedTransportUpdate> get transport => _transportCtrl.stream;

  @override
  Future<List<DeliveryRequest>> refresh() async {
    if (_disposed) return const <DeliveryRequest>[];
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

  /// Declares interest. **Arms nothing.** The first interest announces the
  /// transport once so the screen layer knows this feed has no WebSocket; every
  /// subsequent call, and every removal, is pure bookkeeping.
  @override
  void addPollInterest(Object owner) {
    if (_disposed || !_interest.add(owner)) return;
    if (_interest.length != 1) return;
    _transportCtrl.add(const FeedTransportUpdate(FeedTransport.polling));
  }

  @override
  void removePollInterest(Object owner) {
    _interest.remove(owner);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _interest.clear();
    await _requestsCtrl.close();
    await _transportCtrl.close();
  }

  @visibleForTesting
  bool get debugIsDisposed => _disposed;

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
    // P7 — derive the deadline in the DEVICE clock domain from the server's
    // relative seconds. Never parse a server absolute here: the feed card diffs
    // this against the device clock (request_feed_screen.dart), so a skewed
    // handset would corrupt an absolute but cannot corrupt an anchored
    // relative. The legacy dual-read of two server absolutes is gone — the
    // first of the two keys it tried was never on the wire at all.
    final rawRemaining = json['offerDeadlineInSeconds'];
    final DateTime? expires;
    if (rawRemaining is num) {
      expires = _now().add(
        Duration(seconds: rawRemaining.toInt().clamp(0, 1 << 31)),
      );
    } else {
      expires = null; // no countdown applies to this row
    }
    final createdRaw = json['createdAt'] as String?;
    final requestStatus = ServerRequestStatus.normalize(json['status']);
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
      // the legacy shape. Never substitute an opaque id as a person's name —
      // the card owns a localized, intentional identity fallback.
      senderName: json['senderName'] as String?,
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
      // Contract B requires `status`; tolerate legacy rows that omit it, but
      // fail closed for every present unknown/terminal value. This is the same
      // server-owned status policy used by the customer offer-review path.
      requestIsOpen: requestStatus.isEmpty ||
          ServerRequestStatus.isOpen(requestStatus),
    );
  }

  /// Parses a gateway timestamp string to a UTC instant — the zone-less→UTC
  /// normalization now lives in the shared [ServerTime.parse] (cycle-5 T11
  /// centralization: feed, order history, wallet and tracking all normalize
  /// through one rule). Kept as a thin alias so the created-at / expiry parsing
  /// below reads locally.
  static DateTime? _parseServerTime(String raw) => ServerTime.parse(raw);

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

  JeeberRequestTier? _parseTier(String? raw) {
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
        return null;
    }
  }
}
