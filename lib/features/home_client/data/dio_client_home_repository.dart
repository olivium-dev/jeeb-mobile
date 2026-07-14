import 'package:dio/dio.dart';

import '../../../core/formatting/friendly_reference.dart';
import '../../../core/network/single_flight_get.dart';
import '../../chat/data/dio_accepted_conversations_repository.dart';
import '../domain/client_home_repository.dart';
import '../domain/client_home_request.dart';
import '../domain/recent_delivery_summary.dart';

/// Dio-backed [ClientHomeRepository] hitting the jeeb-gateway.
///
/// Two endpoints back the three home-tab lists the Figma renders:
///   - `GET /deliveries?stage=active`  → In Progress (active shipments, D5).
///   - `GET /requests?role=client`     → partitioned client-side into:
///       * In Progress — rows with `status == accepted` (an offer was accepted
///         but no active shipment exists yet). These carry the `conversationId`
///         used for chat re-entry.
///       * Replies      — non-accepted rows that HAVE ≥1 live offer.
///       * Pending      — non-accepted rows with no live offer yet.
///
/// BUG-3 (deterministic offer discovery): the LIVE `GET /requests?role=client`
/// payload carries NO offer indicator — `offersCount`/`offerCount`/`jeeberId`
/// come back `null` even when a jeeber has already offered (confirmed by a
/// read-only probe against `:10090` as the seed customer). The old logic keyed
/// replies-vs-pending purely on the row's denormalised `offersCount`, so EVERY
/// offer-bearing request fell into Pending and the Replies tab read "No replies
/// yet" — the customer could never reach/accept the offer, and the local
/// search-window timer eventually expired the (still-pending-server-side)
/// request. Discovery was effectively PUSH-ONLY: if the FCM offer push didn't
/// land in-window, the offer stayed invisible. We now make discovery
/// DETERMINISTIC: for each non-accepted request we authoritatively resolve the
/// live offer count via `GET /v1/offers?requestId=<id>` and bucket on that
/// (taking `max(payloadCount, liveCount)` so a denormalised count still counts).
/// The probe is best-effort + concurrent + capped: any failure degrades to the
/// payload count and never breaks the home load.
///
/// S007-P1B: before this fix the accepted order fell through every bucket — it
/// is absent from `/deliveries?stage=active` (no shipment yet) and, with
/// `offersCount == 0`, the old logic dropped it into Pending where its TTL
/// expired into a dead "Expired" card; In Progress and Replies stayed empty.
/// It is now surfaced in In Progress with an "Open chat" CTA, so the accepted
/// conversation is reachable in-app without a push notification. Verified
/// against the dev gateway: `GET /requests?role=client` returns the accepted
/// order as `{ status: "accepted", conversationId, title, displayId }` while
/// `GET /deliveries?stage=active` returns no shipment for it.
///
/// The [MockGatewayClient] interceptor rewrites these paths to their
/// service-prefixed counterparts automatically.
class DioClientHomeRepository implements ClientHomeRepository {
  DioClientHomeRepository(Dio dio, {SingleFlightGet? coalescer})
      : _coalescer = coalescer ?? SingleFlightGet(dio);

  /// In-flight GET dedupe (F3), promoted to the shared network layer (FIX-A):
  /// collapses accidental duplicate same-cycle reads (same path + query) onto a
  /// single network call. DI injects ONE instance across the home / waiting /
  /// offers-review repos, so this repo's `GET /v1/offers?requestId` probes now
  /// coalesce against the offers-review and waiting pollers too — not just its
  /// own. Entries self-evict on completion, so it is a single-flight coalescer,
  /// never a stale cache.
  final SingleFlightGet _coalescer;

  // D5 contract: GET /deliveries?stage=<stage>&limit=<n>
  static const _activeDeliveriesPath = '/deliveries';
  static const _requestsPath = '/requests';

  /// Customer-readable offers-list route (BUG-3). The `requestId` query
  /// parameter is REQUIRED (the live gateway 400s without it, 404s for an
  /// unknown id) — `MockGatewayClient` rewrites the `/v1/offers` prefix to the
  /// offer-service. This is the same route `DioOffersRepository.fetchOffers`
  /// and `DioWaitingRepository.fetchOfferCount` use.
  static const _offersPath = '/v1/offers';

  /// Upper bound on per-request offer probes per home load, to cap the fan-out
  /// (a customer realistically has a handful of open requests). Beyond this we
  /// fall back to the payload's denormalised `offersCount`.
  static const int _maxOfferProbes = 10;

  /// Max offer probes in flight at once (F3). The old code fired up to
  /// [_maxOfferProbes] concurrent `GET /v1/offers` per poll cycle — a fan-out
  /// that, ticking every few seconds, blew past the gateway's per-subscription
  /// rate budget and tripped 429s. We now drain the probes through a bounded
  /// worker pool of this width so at most a couple ever hit the wire together.
  static const int _probeConcurrency = 2;

  /// Offer statuses that still count as a live, acceptable bid (mirrors
  /// `DioOffersRepository._liveStatuses`). Withdrawn/expired/accepted/superseded
  /// offers must NOT flip a request into Replies.
  static const Set<String> _liveOfferStatuses = {
    'pending',
    'submitted',
    'edited',
  };

  /// Normalized (lowercase, underscores stripped) request statuses that are
  /// TERMINAL for the customer — the request left the active funnel. These are
  /// history (surfaced via recent deliveries), so they must NEVER be bucketed
  /// into Pending / Replies / In Progress. Pre-fix, a cancelled/expired request
  /// with no live offers fell through to Pending and re-armed a dead auction.
  static const Set<String> _terminalRequestStatuses = {
    'cancelled',
    'canceled',
    'expired',
    'delivered',
    'done',
    'rated',
  };

  /// Normalized request statuses that mean a shipment is already on the road —
  /// the row is In Progress with a mapped delivery stage, not a Pending/Replies
  /// auction. `matched` is the moment an offer was accepted (== accepted).
  static const Set<String> _inFlightRequestStatuses = {
    'picked',
    'pickedup',
    'intransit',
    'atdoor',
    'headingoff',
    'matched',
  };

  /// Lowercase a status and strip underscores so `In_Transit`, `IN_TRANSIT`,
  /// `InTransit` and `intransit` all compare equal (40_GUARDRAILS_ARCH §4).
  static String _normalizeStatus(Object? status) =>
      (status is String ? status : '').toLowerCase().replaceAll('_', '');

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    // F3 dedupe: the `role=client` list backs BOTH the auction buckets AND the
    // recent-deliveries strip. Fetch it ONCE and derive both from the same
    // payload instead of firing two near-identical `GET /requests?role=client`
    // reads per poll cycle.
    final results = await Future.wait([
      _fetchInProgress(),
      _fetchRoleClientRows(),
      _fetchActiveRequests(),
    ]);

    final shipments = results[0] as List<ClientHomeRequest>;
    final roleClientRows = results[1];
    final activeRequests = results[2] as List<ClientHomeRequest>;

    // Partition the single role=client payload into buckets (the offer probes
    // run here, coalesced) and derive the recent-deliveries strip from the same
    // rows — no second network read.
    final buckets = await _partitionClientRequests(roleClientRows);
    final recentDeliveries = _recentDeliveries(roleClientRows);

    // Merge accepted orders into In Progress, deduped against any live shipment
    // by id so the same order never renders twice. A delivery that already
    // reached a terminal state (V3 `Done` → delivered, or cancelled/expired) is
    // NOT in progress — drop it from the active list so a completed or dead
    // order never lingers as "active".
    final activeShipments = shipments
        .where(
          (r) =>
              r.status != ClientRequestStatus.delivered &&
              r.status != ClientRequestStatus.cancelled,
        )
        .toList(growable: false);
    final shipmentIds = activeShipments.map((r) => r.id).toSet();
    // S10 dedupe (re-applied — 274ecef's `_mergeInProgress` deduped the
    // role=client accepted rows by the delivery rows' parent `requestId`; a
    // later integration merge kept only the S11 activeRequests-path dedupe): a
    // request already represented by a delivery row must appear ONLY as that
    // delivery row (it carries the real `delivery-<offerId>` tracking id) —
    // never a second time under its request id.
    final coveredRequestIds = activeShipments
        .map((r) => r.chatCorrelationId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final inProgress = <ClientHomeRequest>[
      ...activeShipments,
      ...buckets.accepted.where(
        (a) =>
            !shipmentIds.contains(a.id) && !coveredRequestIds.contains(a.id),
      ),
    ];

    // S11 Defect-A: additively merge the `status=active` in-flight requests.
    // Deduped two ways so an order never renders twice: (a) a request already
    // represented by a delivery row is skipped via that row's parent
    // `requestId` (captured as [ClientHomeRequest.chatCorrelationId] by
    // `_parseActiveDelivery`) — the delivery-backed row wins because it carries
    // the real `delivery-<offerId>` tracking id; (b) plain id dedupe against
    // everything already merged. Purely additive: no existing row is dropped.
    final presentIds = inProgress.map((r) => r.id).toSet();
    for (final request in activeRequests) {
      if (coveredRequestIds.contains(request.id)) continue;
      if (!presentIds.add(request.id)) continue;
      inProgress.add(request);
    }

    return ClientHomeSnapshot(
      inProgress: inProgress,
      pending: buckets.pending,
      replies: buckets.replies,
      recentDeliveries: recentDeliveries,
    );
  }

  /// S11 Defect-A LIVE fix (restored — the original fix, eba82e8, was lost when
  /// a later integration merge kept the mainline rewrite of this file while
  /// keeping its regression test): the freshly-matched in-flight request is
  /// surfaced by the gateway through the `status=active` filter — the same
  /// param the order-history Active tab uses — NOT through the `role=client`
  /// query [_fetchClientRequests] sends. So when the deliveries source lags
  /// (no `delivery-<offerId>` row minted yet) the role-only merge missed the
  /// brand-new order and the In-Progress tab dropped it. We query
  /// `status=active` (load-bearing — proven live to return the `matched` row)
  /// AND keep `role=client` (belt-and-braces for a backend that scopes by
  /// role). Only genuinely on-the-road rows are kept ([_mapRequestStatus]);
  /// pending / offers-received / terminal rows are dropped here so they can
  /// never leak into In Progress through this path.
  Future<List<ClientHomeRequest>> _fetchActiveRequests() async {
    try {
      final response = await _get(
        _requestsPath,
        const {
          'status': 'active',
          'role': 'client',
          'page': 1,
          'pageSize': 50,
        },
      );
      final rawItems = _items(response.data);
      final items = <ClientHomeRequest>[];
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          final request = _parseActiveRequest(raw);
          if (request != null) items.add(request);
        }
      }
      return items;
    } on DioException {
      return const [];
    } on FormatException {
      return const [];
    }
  }

  Future<List<ClientHomeRequest>> _fetchInProgress() async {
    try {
      final response = await _get(
        _activeDeliveriesPath,
        const {'stage': 'active', 'limit': 50},
      );
      final rawItems = _items(response.data, fallbackKey: 'shipments');
      final items = <ClientHomeRequest>[];
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          final request = _parseActiveDelivery(raw);
          if (request != null) items.add(request);
        }
      }
      return items;
    } on DioException {
      return const [];
    } on FormatException {
      return const [];
    }
  }

  /// Single `GET /requests?role=client` read (F3), shared between the auction
  /// buckets and the recent-deliveries strip. Returns the raw row list (or an
  /// empty list on any transport/parse failure) so callers can derive their
  /// projections without re-fetching.
  Future<List<dynamic>> _fetchRoleClientRows() async {
    try {
      final response = await _get(
        _requestsPath,
        const {'role': 'client', 'page': 1, 'pageSize': 50},
      );
      return _items(response.data);
    } on DioException {
      return const [];
    } on FormatException {
      return const [];
    }
  }

  /// Partitions the `role=client` rows client-side into the accepted / replies
  /// / pending buckets (S007-P1B, BUG-3). The gateway only filters by `role`:
  ///   * `status == accepted` → In Progress (chat re-entry).
  ///   * else live offer count > 0 → Replies.
  ///   * else → Pending.
  ///
  /// BUG-3: the live `role=client` payload omits any offer indicator, so the
  /// replies-vs-pending decision is driven by an authoritative per-request
  /// `GET /v1/offers?requestId` probe (best-effort, coalesced, capped — see
  /// [_resolveOfferCounts]) rather than the row's (absent) `offersCount`.
  Future<_ClientRequestBuckets> _partitionClientRequests(
    List<dynamic> rawItems,
  ) async {
    try {
      final accepted = <ClientHomeRequest>[];
      final candidates = <Map<String, dynamic>>[];
      for (final raw in rawItems) {
        if (raw is! Map<String, dynamic>) continue;
        final rawStatus = raw['status'];
        final normalized = _normalizeStatus(rawStatus);
        // Terminal (cancelled/expired/delivered/done/rated) → history. Drop it
        // from the auction buckets entirely so a dead request never re-surfaces
        // as Pending/Replies.
        if (_terminalRequestStatuses.contains(normalized)) {
          continue;
        }
        // Accepted (offer accepted, no shipment yet) OR already in-flight →
        // In Progress. Accepted keeps its chat-re-entry semantics; an in-flight
        // row carries its mapped delivery stage (atPickup / enRoute).
        if (DioAcceptedConversationsRepository.isAcceptedStatus(rawStatus)) {
          final request = _parseRequest(
            raw,
            status: ClientRequestStatus.accepted,
          );
          if (request != null) accepted.add(request);
        } else if (_inFlightRequestStatuses.contains(normalized)) {
          final request = _parseRequest(
            raw,
            status: _mapDeliveryStatus(rawStatus as String?),
          );
          if (request != null) accepted.add(request);
        } else {
          candidates.add(raw);
        }
      }

      // Resolve the live offer count for each non-accepted request so an
      // offer-bearing request surfaces in Replies deterministically — not only
      // when an FCM push happened to update a denormalised count.
      final offerCounts = await _resolveOfferCounts(candidates);

      final pending = <ClientHomeRequest>[];
      final replies = <ClientHomeRequest>[];
      for (var i = 0; i < candidates.length; i++) {
        final raw = candidates[i];
        final payloadCount = (raw['offersCount'] as num?)?.toInt() ?? 0;
        final liveCount = offerCounts[i];
        final offerCount = liveCount > payloadCount ? liveCount : payloadCount;
        final isReply = offerCount > 0;
        final request = _parseRequest(
          raw,
          status: isReply
              ? ClientRequestStatus.offersReceived
              : ClientRequestStatus.searching,
          offerCountOverride: offerCount,
        );
        if (request == null) continue;
        (isReply ? replies : pending).add(request);
      }
      return _ClientRequestBuckets(
        accepted: accepted,
        pending: pending,
        replies: replies,
      );
    } on DioException {
      return const _ClientRequestBuckets.empty();
    } on FormatException {
      return const _ClientRequestBuckets.empty();
    }
  }

  /// Live offer count per candidate request, aligned by index. Probes are
  /// COALESCED (F3): only rows whose bucket is still unknown are probed, at most
  /// [_maxOfferProbes] of them, drained through a bounded worker pool of width
  /// [_probeConcurrency] with a per-cycle memo so a duplicate request id shares
  /// one GET. Each probe is best-effort — a failure leaves the payload's
  /// denormalised count in place, so a degraded/erroring offers endpoint never
  /// breaks the home load.
  Future<List<int>> _resolveOfferCounts(
    List<Map<String, dynamic>> candidates,
  ) async {
    final counts = List<int>.generate(
      candidates.length,
      (i) => (candidates[i]['offersCount'] as num?)?.toInt() ?? 0,
      growable: false,
    );

    // Skip rows we already know are Replies: a payload count > 0 buckets the row
    // into Replies regardless of the probe (the probe can only raise the count),
    // so probing it is a wasted GET. Cap the remaining fan-out.
    final jobs = <int>[];
    for (var i = 0;
        i < candidates.length && jobs.length < _maxOfferProbes;
        i++) {
      final id = candidates[i]['id'] as String?;
      if (id == null || id.isEmpty) continue;
      if (counts[i] > 0) continue;
      jobs.add(i);
    }
    if (jobs.isEmpty) return counts;

    // Per-cycle memo: distinct request ids only ever hit `/v1/offers` once.
    final memo = <String, int?>{};
    var next = 0;

    Future<void> drain() async {
      while (true) {
        if (next >= jobs.length) return;
        final index = jobs[next++];
        final id = candidates[index]['id'] as String;
        final int? live;
        if (memo.containsKey(id)) {
          live = memo[id];
        } else {
          live = await _fetchLiveOfferCount(id);
          memo[id] = live;
        }
        if (live != null && live > counts[index]) counts[index] = live;
      }
    }

    final workers = jobs.length < _probeConcurrency
        ? jobs.length
        : _probeConcurrency;
    await Future.wait([for (var w = 0; w < workers; w++) drain()]);
    return counts;
  }

  /// Count the live (acceptable) offers for [requestId] via
  /// `GET /v1/offers?requestId`. Returns `null` (NOT 0) on any failure so the
  /// caller keeps the payload's count rather than wrongly zeroing it — the
  /// enrichment must never tear down an already-known reply. The broad catch is
  /// intentional: this is a best-effort signal on the home critical path and
  /// must not surface as an error or crash the load.
  Future<int?> _fetchLiveOfferCount(String requestId) async {
    try {
      final response = await _get(
        _offersPath,
        {'requestId': requestId},
      );
      final data = response.data;
      final List<dynamic> items;
      if (data is List) {
        items = data;
      } else if (data is Map<String, dynamic>) {
        items =
            (data['items'] as List?) ??
            (data['offers'] as List?) ??
            const <dynamic>[];
      } else {
        return null;
      }
      return items.whereType<Map<String, dynamic>>().where((o) {
        final status = o['status'] as String?;
        return status == null || _liveOfferStatuses.contains(status);
      }).length;
    } catch (_) {
      return null;
    }
  }

  /// Recent-deliveries strip, derived from the SAME `role=client` rows the
  /// buckets are built from (F3 — no separate `pageSize=10` read). The cubit
  /// caps this to a single entry, and the gateway returns the newest rows
  /// first, so the shared 50-row payload yields the identical head element the
  /// old dedicated 10-row read did.
  List<RecentDeliverySummary> _recentDeliveries(List<dynamic> rawItems) {
    final items = <RecentDeliverySummary>[];
    for (final raw in rawItems) {
      if (raw is Map<String, dynamic>) {
        final summary = _parseRecentDelivery(raw);
        if (summary != null) items.add(summary);
      }
    }
    return items;
  }

  static ClientHomeRequest? _parseActiveDelivery(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return null;
    final dropoff = json['dropoff'];
    final destination = dropoff is Map<String, dynamic>
        ? (dropoff['address'] as String? ?? '')
        : (json['dropoffAddress'] as String? ?? '');
    // D5 ShipmentsListDto uses 'currentStage', not 'status'.
    final stage = json['currentStage'] as String? ?? json['status'] as String?;
    return ClientHomeRequest(
      id: id,
      displayId: json['displayId'] as String?,
      title:
          json['title'] as String? ??
          json['description'] as String? ??
          'Delivery ${friendlyReference(id)}',
      status: _mapDeliveryStatus(stage),
      destinationLabel: destination,
      // G1: the request content (customer's "What do you need?" text) — the
      // card subtitle echoes what was asked for via [summaryLine].
      itemsSummary: json['description'] as String?,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      jeeberName: json['jeeberName'] as String?,
      tier: ClientRequestTier.parse(
        json['tier'] as String? ?? json['tierId'] as String?,
      ),
      progressStep: (json['progressStep'] as num?)?.toInt() ?? 0,
      conversationId: json['conversationId'] as String?,
      // The active-deliveries row's `id` can be the DELIVERY id, but the order
      // conversation is correlated on the parent REQUEST id and live tracking
      // reads the DELIVERY id. Capture both so the "Open chat" CTA routes by
      // the request/correlation id (BUG-17 / S13) and "Track order" keeps the
      // delivery id (S9) — falling back to `id` via the getters when absent.
      deliveryId:
          json['deliveryId'] as String? ?? json['delivery_id'] as String?,
      chatCorrelationId:
          json['requestId'] as String? ?? json['request_id'] as String?,
    );
  }

  /// Parses a `status=active` request row into an In-Progress card, or `null`
  /// when the row is not genuinely on the road (see [_mapRequestStatus]). The
  /// row's `id` is the REQUEST id; when the payload carries a real
  /// `deliveryId` it is kept so the Track CTA resolves, otherwise callers fall
  /// back to the request id (best-effort, mirrors the delivery-row fallback).
  static ClientHomeRequest? _parseActiveRequest(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return null;
    final rawStatus =
        (json['status'] ?? json['deliveryStatus'] ?? json['currentStage'])
            as String?;
    final status = _mapRequestStatus(rawStatus);
    if (status == null) return null; // not an in-flight (on-the-road) request
    final dropoff = json['dropoff'];
    final destination = dropoff is Map<String, dynamic>
        ? (dropoff['address'] as String? ?? '')
        : (json['dropoffAddress'] as String? ?? '');
    final deliveryId = (json['deliveryId'] ?? json['delivery_id']) as String?;
    return ClientHomeRequest(
      id: id,
      deliveryId: (deliveryId != null && deliveryId.isNotEmpty)
          ? deliveryId
          : null,
      displayId: json['displayId'] as String?,
      title:
          json['title'] as String? ??
          json['description'] as String? ??
          'Request ${friendlyReference(id)}',
      status: status,
      destinationLabel: destination,
      // G1: echo the request content on the card subtitle (see summaryLine).
      itemsSummary: json['description'] as String?,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      jeeberName: json['jeeberName'] as String?,
      tier: ClientRequestTier.parse(
        json['tier'] as String? ?? json['tierId'] as String?,
      ),
      progressStep: (json['progressStep'] as num?)?.toInt() ?? 0,
      conversationId: json['conversationId'] as String?,
    );
  }

  /// Maps a REQUEST status onto a coarse In-Progress [ClientRequestStatus],
  /// returning null when the request is not on the road. Tolerates the mock's
  /// snake_case request statuses (`matched`, `picked_up`, `en_route`) and the
  /// live gateway's PascalCase SM-1 stage values (`Picked`, `InTransit`,
  /// `AtDoor`, `Ordered`) via [_normalizeStatus].
  static ClientRequestStatus? _mapRequestStatus(String? status) {
    switch (_normalizeStatus(status)) {
      case 'matched':
      case 'active':
      case 'accepted':
      case 'assigned':
      case 'ordered':
        return ClientRequestStatus.accepted;
      case 'pickedup':
      case 'picked':
      case 'atpickup':
        return ClientRequestStatus.atPickup;
      case 'enroute':
      case 'atdoor':
      case 'intransit':
      case 'headingoff':
        return ClientRequestStatus.enRoute;
      default:
        // pending / offers-received / delivered / cancelled / unknown — not an
        // in-flight order, so it must not appear in the In-Progress tab.
        return null;
    }
  }

  static ClientHomeRequest? _parseRequest(
    Map<String, dynamic> json, {
    required ClientRequestStatus status,
    int? offerCountOverride,
  }) {
    final id = json['id'] as String?;
    if (id == null) return null;
    final dropoff = json['dropoff'];
    final destination = dropoff is Map<String, dynamic>
        ? (dropoff['address'] as String? ?? '')
        : (json['dropoffAddress'] as String? ?? '');
    final offerAvatars = json['offerAvatars'];
    final offerAvatarUrls = offerAvatars is List
        ? offerAvatars.whereType<String>().toList(growable: false)
        : const <String>[];
    return ClientHomeRequest(
      id: id,
      displayId: json['displayId'] as String?,
      title:
          json['title'] as String? ??
          json['description'] as String? ??
          'Request ${friendlyReference(id)}',
      status: status,
      destinationLabel: destination,
      // G1: echo the request content on the card subtitle (see summaryLine).
      itemsSummary: json['description'] as String?,
      tier: ClientRequestTier.parse(
        json['tier'] as String? ?? json['tierId'] as String?,
      ),
      offerCount:
          offerCountOverride ?? (json['offersCount'] as num?)?.toInt() ?? 0,
      offerAvatarUrls: offerAvatarUrls,
      conversationId: json['conversationId'] as String?,
      ttlSeconds: (json['ttlSeconds'] as num?)?.toInt(),
    );
  }

  static RecentDeliverySummary? _parseRecentDelivery(
    Map<String, dynamic> json,
  ) {
    final id = json['id'] as String?;
    if (id == null) return null;
    final dropoff = json['dropoff'];
    final destination = dropoff is Map<String, dynamic>
        ? (dropoff['address'] as String? ?? '')
        : (json['dropoffAddress'] as String? ?? '');
    return RecentDeliverySummary(
      id: id,
      title:
          json['title'] as String? ??
          json['description'] as String? ??
          'Delivery ${friendlyReference(id)}',
      destinationLabel: destination,
      completedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Map a gateway delivery stage → the customer-facing [ClientRequestStatus].
  /// Normalized (lowercase, no underscores) so CapitalCase (`InTransit`),
  /// snake (`in_transit`) and lowercase (`intransit`) all resolve.
  static ClientRequestStatus _mapDeliveryStatus(String? status) {
    switch (_normalizeStatus(status)) {
      // S12 fix (re-applied — the original mapping, ac51352, was lost when a
      // later integration merge kept the mainline rewrite of this switch): a
      // delivery row only exists once a Jeeber is assigned / the order is
      // placed, so `Ordered`/`matched` is the FIRST trackable stage —
      // `accepted`, never `searching`. Mapping it to `searching` rendered a
      // brand-new order as a non-trackable row with no "Track my order" /
      // "Open chat" CTA (ActiveOrderCard._canTrack rejects `searching`), so a
      // freshly-created request could not be tracked. The visual stage is read
      // independently from `progressStep` (parsed at _parseActiveDelivery), so
      // the stepper stays at step 0 "Ordered" — only the CTA gate opens.
      // `matched` gets the same treatment for parity with [_mapRequestStatus]
      // (matched == the offer was accepted == a Jeeber is assigned).
      case 'ordered':
      case 'matched':
        return ClientRequestStatus.accepted;
      case 'picked':
      case 'pickedup':
        return ClientRequestStatus.atPickup;
      case 'intransit':
      case 'atdoor':
      case 'headingoff':
        return ClientRequestStatus.enRoute;
      // V3 `Done` is the delivered/completed TERMINAL (Core Flow step 7). It
      // must NOT collapse back to `accepted` (which reads as in-progress and
      // never clears) — surface it as the delivered final state. Tolerate the
      // legacy lowercase `delivered`/`completed` aliases too.
      case 'done':
      case 'delivered':
      case 'completed':
      case 'rated':
        return ClientRequestStatus.delivered;
      case 'failedneedsescalation':
        return ClientRequestStatus.accepted;
      // Cancelled/expired are terminal — a REAL cancelled state, never
      // `searching` (which would falsely re-open a dead auction).
      case 'cancelled':
      case 'canceled':
      case 'expired':
        return ClientRequestStatus.cancelled;
      default:
        return ClientRequestStatus.searching;
    }
  }

  /// Single-flight GET (F3), delegated to the SHARED [SingleFlightGet] (FIX-A):
  /// an identical read (same path + query) already in flight — issued by THIS
  /// repo or by the offers-review / waiting pollers over the same Dio — returns
  /// that same future instead of a duplicate network call.
  Future<Response<dynamic>> _get(String path, Map<String, dynamic> query) =>
      _coalescer.get(path, queryParameters: query);

  static List<dynamic> _items(Object? data, {String fallbackKey = 'items'}) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      final raw = data['items'] ?? data[fallbackKey];
      if (raw is List) return raw;
    }
    return const <dynamic>[];
  }
}

/// The three client-request buckets partitioned from a single
/// `GET /requests?role=client` call (S007-P1B).
class _ClientRequestBuckets {
  const _ClientRequestBuckets({
    required this.accepted,
    required this.pending,
    required this.replies,
  });

  const _ClientRequestBuckets.empty()
    : accepted = const [],
      pending = const [],
      replies = const [];

  final List<ClientHomeRequest> accepted;
  final List<ClientHomeRequest> pending;
  final List<ClientHomeRequest> replies;
}
