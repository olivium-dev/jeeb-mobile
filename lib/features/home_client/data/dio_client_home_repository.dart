import 'package:dio/dio.dart';

import '../../../core/formatting/friendly_reference.dart';
import '../../../core/formatting/server_time.dart';
import '../../../core/network/app_failure.dart';
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
/// live offer count via `GET /v1/offers?requestId=<id>` and bucket on that. Until
/// a successful probe exists, a positive denormalised payload count remains a
/// best-effort fallback. Probes are concurrent + capped, and a failure never
/// breaks the home load.
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

  /// Last successful authoritative offer summary per request. The role=client
  /// endpoint does not carry offer lifecycle data, so a rotating bounded probe
  /// window fills and refreshes this cache across loads. Entries are pruned as
  /// soon as their request leaves the candidate set.
  final Map<String, _OfferProbe> _offerProbeCache = <String, _OfferProbe>{};

  /// Fair round-robin queue of active candidate ids. Keeping identity rather
  /// than a list index prevents request reordering from starving older rows.
  final List<String> _offerProbeQueue = <String>[];

  /// Snapshot-level single flight. Besides avoiding duplicate home reads, this
  /// serializes access to the rotating probe queue and makes the offer worker
  /// width a repository-wide concurrency bound even when callers overlap.
  Future<ClientHomeSnapshot>? _snapshotInFlight;

  // D5 contract: GET /deliveries?stage=<stage>&limit=<n>
  static const _activeDeliveriesPath = '/deliveries';
  static const _requestsPath = '/requests';

  /// Customer-readable offers-list route (BUG-3). The `requestId` query
  /// parameter is REQUIRED (the live gateway 400s without it, 404s for an
  /// unknown id) — `MockGatewayClient` rewrites the `/v1/offers` prefix to the
  /// offer-service. This is the same route `DioOffersRepository.fetchOffers`
  /// and `DioWaitingRepository.fetchOfferCount` use.
  static const _offersPath = '/v1/offers';

  /// Upper bound on per-request offer probes per home load. A fair rotating
  /// window and [_offerProbeCache] ensure rows beyond this bound are eventually
  /// covered without increasing the per-load network budget.
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
  Future<ClientHomeSnapshot> loadSnapshot() {
    final inFlight = _snapshotInFlight;
    if (inFlight != null) return inFlight;

    late final Future<ClientHomeSnapshot> next;
    next = _loadSnapshot().whenComplete(() {
      if (identical(_snapshotInFlight, next)) _snapshotInFlight = null;
    });
    _snapshotInFlight = next;
    return next;
  }

  Future<ClientHomeSnapshot> _loadSnapshot() async {
    // F3 (offers-polling storm): a 429 on ANY of the home reads must NOT fail
    // the load — each sub-fetch already degrades to empty/partial data. We only
    // RECORD that a throttle happened (and its Retry-After) so the cubit can
    // keep the cached data, back the poll off, and never show the full-screen
    // connection error. This tracker is shared across every read of this load.
    final rateLimit = _LoadHealthTracker();

    // F3 dedupe: the `role=client` list backs BOTH the auction buckets AND the
    // recent-deliveries strip. Fetch it ONCE and derive both from the same
    // payload instead of firing two near-identical `GET /requests?role=client`
    // reads per poll cycle.
    final results = await Future.wait([
      _fetchInProgress(rateLimit),
      _fetchRoleClientRows(rateLimit),
      _fetchActiveRequests(rateLimit),
    ]);

    final shipments = results[0] as List<ClientHomeRequest>;
    final roleClientRows = results[1];
    final activeRequests = results[2] as List<ClientHomeRequest>;

    // Partition the single role=client payload into buckets (the offer probes
    // run here, coalesced) and derive the recent-deliveries strip from the same
    // rows — no second network read.
    final buckets = await _partitionClientRequests(roleClientRows, rateLimit);
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
        (a) => !shipmentIds.contains(a.id) && !coveredRequestIds.contains(a.id),
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

    final offerStatusRequests = <String, ClientHomeRequest>{
      for (final request in buckets.offerStatusRequests) request.id: request,
      for (final request in inProgress)
        request.id: request.offerStatuses.isNotEmpty
            ? request
            : request.copyWith(
                offerStatuses: const {ClientOfferStatus.accepted},
              ),
    }.values.toList(growable: false);

    return ClientHomeSnapshot(
      inProgress: inProgress,
      pending: buckets.pending,
      replies: buckets.replies,
      recentDeliveries: recentDeliveries,
      offerStatusRequests: offerStatusRequests,
      // F3: surface (never throw) the throttle so the cubit degrades gracefully.
      rateLimited: rateLimit.rateLimited,
      // B1: an all-transport-failed load is NOT an empty home — say so.
      // Either active source can fill this tab; accepted role rows also survive.
      inProgressFailure: inProgress.isEmpty &&
              rateLimit.failures.containsKey(_Bucket.activeRequests)
          ? rateLimit.failures[_Bucket.inProgress]
          : null,
      requestsFailure: rateLimit.failures[_Bucket.requests],
      recentFailure: rateLimit.failures[_Bucket.recent],
      probeFailure: rateLimit.failures[_Bucket.probe],
      retryAfter: rateLimit.retryAfter,
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
  Future<List<ClientHomeRequest>> _fetchActiveRequests(
    _LoadHealthTracker rateLimit,
  ) async {
    try {
      final response = await _get(_requestsPath, const {
        'status': 'active',
        'role': 'client',
        'page': 1,
        'pageSize': 50,
      });
      rateLimit.recordSuccess();
      final rawItems = _items(response.data);
      final items = <ClientHomeRequest>[];
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          final request = _parseActiveRequest(raw);
          if (request != null) items.add(request);
        }
      }
      return items;
    } on DioException catch (e) {
      rateLimit.record(e, bucket: _Bucket.activeRequests);
      return const [];
    } on FormatException catch (e) {
      rateLimit.recordFailure(
        _Bucket.activeRequests,
        UnknownFailure(cause: e, parse: true),
      );
      return const [];
    } catch (e) {
      rateLimit.recordFailure(
        _Bucket.activeRequests,
        UnknownFailure(cause: e, parse: true),
      );
      return const [];
    }
  }

  Future<List<ClientHomeRequest>> _fetchInProgress(
    _LoadHealthTracker rateLimit,
  ) async {
    try {
      final response = await _get(_activeDeliveriesPath, const {
        'stage': 'active',
        'limit': 50,
      });
      rateLimit.recordSuccess();
      final rawItems = _items(response.data, fallbackKey: 'shipments');
      final items = <ClientHomeRequest>[];
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          final request = _parseActiveDelivery(raw);
          if (request != null) items.add(request);
        }
      }
      return items;
    } on DioException catch (e) {
      rateLimit.record(e, bucket: _Bucket.inProgress);
      return const [];
    } on FormatException catch (e) {
      rateLimit.recordFailure(
        _Bucket.inProgress,
        UnknownFailure(cause: e, parse: true),
      );
      return const [];
    } catch (e) {
      rateLimit.recordFailure(
        _Bucket.inProgress,
        UnknownFailure(cause: e, parse: true),
      );
      return const [];
    }
  }

  /// Single `GET /requests?role=client` read (F3), shared between the auction
  /// buckets and the recent-deliveries strip. Returns the raw row list (or an
  /// empty list on any transport/parse failure) so callers can derive their
  /// projections without re-fetching.
  Future<List<dynamic>> _fetchRoleClientRows(
    _LoadHealthTracker rateLimit,
  ) async {
    try {
      final response = await _get(_requestsPath, const {
        'role': 'client',
        'page': 1,
        'pageSize': 50,
      });
      rateLimit.recordSuccess();
      return _items(response.data);
    } on DioException catch (e) {
      rateLimit.record(e, bucket: _Bucket.requests);
      return const [];
    } on FormatException catch (e) {
      rateLimit.recordFailure(
        _Bucket.requests,
        UnknownFailure(cause: e, parse: true),
      );
      return const [];
    } catch (e) {
      rateLimit.recordFailure(
        _Bucket.requests,
        UnknownFailure(cause: e, parse: true),
      );
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
    _LoadHealthTracker rateLimit,
  ) async {
    try {
      final accepted = <ClientHomeRequest>[];
      final offerStatusRequests = <ClientHomeRequest>[];
      final candidates = <Map<String, dynamic>>[];
      for (final raw in rawItems) {
        if (raw is! Map<String, dynamic>) continue;
        final rawStatus = raw['status'];
        final normalized = _normalizeStatus(rawStatus);
        // Terminal (cancelled/expired/delivered/done/rated) → history. Drop it
        // from the auction buckets entirely so a dead request never re-surfaces
        // as Pending/Replies.
        if (_terminalRequestStatuses.contains(normalized)) {
          final inferred = _inferredOfferStatus(normalized);
          if (inferred != null) {
            final request = _parseRequest(
              raw,
              status: ClientRequestStatus.cancelled,
              offerStatuses: {inferred},
            );
            if (request != null) offerStatusRequests.add(request);
          }
          continue;
        }
        // Accepted (offer accepted, no shipment yet) OR already in-flight →
        // In Progress. Accepted keeps its chat-re-entry semantics; an in-flight
        // row carries its mapped delivery stage (atPickup / enRoute).
        if (DioAcceptedConversationsRepository.isAcceptedStatus(rawStatus)) {
          final request = _parseRequest(
            raw,
            status: ClientRequestStatus.accepted,
            offerStatuses: const {ClientOfferStatus.accepted},
          );
          if (request != null) {
            accepted.add(request);
            offerStatusRequests.add(request);
          }
        } else if (_inFlightRequestStatuses.contains(normalized)) {
          final request = _parseRequest(
            raw,
            status: _mapDeliveryStatus(rawStatus as String?),
            offerStatuses: const {ClientOfferStatus.accepted},
          );
          if (request != null) {
            accepted.add(request);
            offerStatusRequests.add(request);
          }
        } else {
          candidates.add(raw);
        }
      }

      // Resolve the live offer count for each non-accepted request so an
      // offer-bearing request surfaces in Replies deterministically — not only
      // when an FCM push happened to update a denormalised count.
      final offerProbes = await _resolveOfferCounts(candidates, rateLimit);

      final pending = <ClientHomeRequest>[];
      final replies = <ClientHomeRequest>[];
      for (var i = 0; i < candidates.length; i++) {
        final raw = candidates[i];
        final payloadCount = (raw['offersCount'] as num?)?.toInt() ?? 0;
        final probe = offerProbes[i];
        final offerCount = probe != null && probe.count > payloadCount
            ? probe.count
            : payloadCount;

        // A zero/absent denormalised count is not proof that a request has no
        // offers. Until this row's rotating probe succeeds (or a previous
        // successful result exists in the cache), its auction bucket is
        // unresolved. Omitting it is preferable to the old false Pending claim;
        // the fair window will cover it on a later load.
        if (probe == null && offerCount == 0) continue;

        final isReply = offerCount > 0;
        final request = _parseRequest(
          raw,
          status: isReply
              ? ClientRequestStatus.offersReceived
              : ClientRequestStatus.searching,
          offerCountOverride: offerCount,
          lowestOfferFee: probe?.minFee,
          offerCurrency: probe?.currency,
          offerStatuses: probe?.statuses ?? const <ClientOfferStatus>{},
          offerAvatarUrlsOverride: probe?.avatarUrls,
        );
        if (request == null) continue;
        (isReply ? replies : pending).add(request);
        if (request.offerStatuses.isNotEmpty) {
          offerStatusRequests.add(request);
        }
      }
      return _ClientRequestBuckets(
        accepted: accepted,
        pending: pending,
        replies: replies,
        offerStatusRequests: offerStatusRequests,
      );
    } on DioException catch (e) {
      rateLimit.record(e, primary: false, bucket: _Bucket.requests);
      return const _ClientRequestBuckets.empty();
    } on FormatException catch (e) {
      rateLimit.recordFailure(
        _Bucket.requests,
        UnknownFailure(cause: e, parse: true),
      );
      return const _ClientRequestBuckets.empty();
    } catch (e) {
      rateLimit.recordFailure(
        _Bucket.requests,
        UnknownFailure(cause: e, parse: true),
      );
      return const _ClientRequestBuckets.empty();
    }
  }

  /// Live offer summary per candidate request, aligned by index. Each load
  /// probes a fair rotating window of at most [_maxOfferProbes] distinct request
  /// ids through a worker pool of width [_probeConcurrency]. Successful results
  /// are cached, so non-selected rows retain their last authoritative lifecycle
  /// while the window advances. With the role list capped at 50 rows, every
  /// candidate is covered within at most five loads without increasing the
  /// existing ten-call/two-concurrent per-load bound.
  Future<List<_OfferProbe?>> _resolveOfferCounts(
    List<Map<String, dynamic>> candidates,
    _LoadHealthTracker rateLimit,
  ) async {
    final candidateIds = <String>[];
    final indicesById = <String, List<int>>{};
    for (var i = 0; i < candidates.length; i++) {
      final id = candidates[i]['id'] as String?;
      if (id == null || id.isEmpty) continue;
      final indices = indicesById.putIfAbsent(id, () {
        candidateIds.add(id);
        return <int>[];
      });
      indices.add(i);
    }

    final activeIds = candidateIds.toSet();
    _offerProbeCache.removeWhere((id, _) => !activeIds.contains(id));
    _offerProbeQueue.removeWhere((id) => !activeIds.contains(id));
    final queuedIds = _offerProbeQueue.toSet();
    for (final id in candidateIds) {
      if (queuedIds.add(id)) _offerProbeQueue.add(id);
    }

    final counts = List<_OfferProbe?>.generate(candidates.length, (i) {
      final id = candidates[i]['id'] as String?;
      return id == null ? null : _offerProbeCache[id];
    }, growable: false);

    if (candidateIds.isEmpty) {
      _offerProbeQueue.clear();
      return counts;
    }

    final jobCount = _offerProbeQueue.length < _maxOfferProbes
        ? _offerProbeQueue.length
        : _maxOfferProbes;
    final jobs = _offerProbeQueue.take(jobCount).toList(growable: false);
    _offerProbeQueue
      ..removeRange(0, jobCount)
      ..addAll(jobs);

    var next = 0;

    Future<void> drain() async {
      while (true) {
        if (next >= jobs.length) return;
        final id = jobs[next++];
        final live = await _fetchLiveOfferCount(id, rateLimit);

        // A failed refresh keeps the last successful result. A successful empty
        // result is authoritative and is cached just like a non-empty result.
        if (live != null) {
          _offerProbeCache[id] = live;
          for (final index in indicesById[id]!) {
            counts[index] = live;
          }
        }
      }
    }

    final workers = jobs.length < _probeConcurrency
        ? jobs.length
        : _probeConcurrency;
    await Future.wait([for (var w = 0; w < workers; w++) drain()]);
    return counts;
  }

  /// Count the live (acceptable) offers for [requestId] via
  /// `GET /v1/offers?requestId`, and take the lowest quoted fee over the SAME
  /// parsed items (the Replies card's "from $8" floor — no second request).
  /// Returns `null` (NOT a zero record) on any failure so the caller keeps the
  /// last successful cache entry, or falls back to a positive payload count when
  /// no authoritative result exists yet. The broad catch is intentional: this
  /// is a best-effort signal on the home critical path and must not surface as
  /// an error or crash the load.
  Future<_OfferProbe?> _fetchLiveOfferCount(
    String requestId,
    _LoadHealthTracker rateLimit,
  ) async {
    try {
      final response = await _get(_offersPath, {'requestId': requestId});
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
      final offers = items.whereType<Map<String, dynamic>>().toList(
        growable: false,
      );
      final statuses = <ClientOfferStatus>{};
      final live = offers
          .where((o) {
            final rawStatus = o['status'];
            final status = ClientOfferStatus.parse(rawStatus);
            if (status != null) statuses.add(status);
            final normalized = rawStatus is String
                ? rawStatus.trim().toLowerCase()
                : null;
            if (normalized == null || normalized.isEmpty) {
              statuses.add(ClientOfferStatus.pending);
              return true;
            }
            return _liveOfferStatuses.contains(normalized);
          })
          .toList(growable: false);
      // Offer floor over the same rows. Only the plain `fee` number is read —
      // `client_offers`' richer amount/price money-map parsing is deliberately
      // NOT replicated here; a fee-less offer simply does not participate, so
      // the worst case is a null floor, never a wrong one.
      double? minFee;
      String? currency;
      for (final offer in live) {
        final fee = (offer['fee'] as num?)?.toDouble();
        if (fee == null) continue;
        if (minFee == null || fee < minFee) {
          minFee = fee;
          currency = offer['currency'] as String?;
        }
      }
      // Offerer photos over the SAME rows, with the key precedence the
      // offer-review list already uses (`avatarUrl` ?? `jeeberAvatarUrl`).
      final avatarUrls = <String>[];
      for (final offer in live) {
        final url =
            offer['avatarUrl'] as String? ?? offer['jeeberAvatarUrl'] as String?;
        if (url != null && url.trim().isNotEmpty && avatarUrls.length < 3) {
          avatarUrls.add(url);
        }
      }
      return (
        count: live.length,
        minFee: minFee,
        currency: currency,
        statuses: Set<ClientOfferStatus>.unmodifiable(statuses),
        avatarUrls: List<String>.unmodifiable(avatarUrls),
      );
    } on DioException catch (e) {
      // A throttled probe degrades to the payload count (null) — but RECORD the
      // 429 so the home load reports `rateLimited` and the cubit backs off
      // instead of hammering the throttled offers endpoint every poll tick.
      rateLimit.record(e, primary: false, bucket: _Bucket.probe);
      return null;
    } catch (e) {
      rateLimit.recordFailure(_Bucket.probe, AppFailure.of(e));
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
    double? lowestOfferFee,
    String? offerCurrency,
    Set<ClientOfferStatus> offerStatuses = const <ClientOfferStatus>{},
    List<String>? offerAvatarUrlsOverride,
  }) {
    final id = json['id'] as String?;
    if (id == null) return null;
    final dropoff = json['dropoff'];
    final destination = dropoff is Map<String, dynamic>
        ? (dropoff['address'] as String? ?? '')
        : (json['dropoffAddress'] as String? ?? '');
    final offerAvatars = json['offerAvatars'];
    final payloadAvatarUrls = offerAvatars is List
        ? offerAvatars.whereType<String>().toList(growable: false)
        : const <String>[];
    // The live `role=client` row carries no `offerAvatars`, so the probe's
    // photos win whenever it found any; the payload key stays as the fallback.
    final offerAvatarUrls =
        (offerAvatarUrlsOverride != null && offerAvatarUrlsOverride.isNotEmpty)
        ? offerAvatarUrlsOverride
        : payloadAvatarUrls;
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
      // Real server creation instant when present (the captured `/v1/requests`
      // row carries `createdAt`). Best-effort + nullable via ServerTime: a
      // missing/unparseable value stays null so the card shows NO age line
      // rather than a fabricated one. This is a past "created N ago", never a
      // countdown — the removed manufactured-deadline lie is not reintroduced.
      createdAt: ServerTime.parse(
        json['createdAt'] as String? ?? json['created_at'] as String?,
      ),
      hasNewOffers:
          (json['hasNewOffers'] as bool?) ??
          (json['has_new_offers'] as bool?) ??
          false,
      lowestOfferFee: lowestOfferFee,
      offerCurrency: offerCurrency,
      offerStatuses: offerStatuses,
    );
  }

  static ClientOfferStatus? _inferredOfferStatus(String requestStatus) {
    return switch (requestStatus) {
      'expired' => ClientOfferStatus.expired,
      'delivered' || 'done' || 'rated' => ClientOfferStatus.accepted,
      _ => null,
    };
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

/// What one `/v1/offers?requestId` probe yields: how many live offers the
/// request has, and the lowest fee among them (with its currency) for the
/// Replies card's "from $X" floor. Both money fields are null when no offer
/// carried a `fee` — the floor is optional by design, never fabricated.
/// [avatarUrls] carries the offerers' photos the `role=client` row omits.
typedef _OfferProbe = ({
  int count,
  double? minFee,
  String? currency,
  Set<ClientOfferStatus> statuses,
  List<String> avatarUrls,
});

/// The three client-request buckets partitioned from a single
/// `GET /requests?role=client` call (S007-P1B).
class _ClientRequestBuckets {
  const _ClientRequestBuckets({
    required this.accepted,
    required this.pending,
    required this.replies,
    required this.offerStatusRequests,
  });

  const _ClientRequestBuckets.empty()
    : accepted = const [],
      pending = const [],
      replies = const [],
      offerStatusRequests = const [];

  final List<ClientHomeRequest> accepted;
  final List<ClientHomeRequest> pending;
  final List<ClientHomeRequest> replies;
  final List<ClientHomeRequest> offerStatusRequests;
}

/// Independent home sources; active requests never poison the role-only read.
enum _Bucket { requests, activeRequests, inProgress, recent, probe }

/// Accumulates whether ANY read in a single [DioClientHomeRepository.loadSnapshot]
/// was throttled with HTTP 429, and the longest advertised `Retry-After`.
///
/// F3 (offers-polling storm): the home reads are best-effort — a 429 degrades
/// each one to empty/partial data rather than failing the load. This tracker is
/// how that otherwise-swallowed 429 is surfaced (never thrown) so the cubit can
/// keep the cached data, honor `Retry-After`, and NEVER show the full-screen
/// connection error on a throttle.
///
/// B1: it ALSO counts primary-read transport failures vs successes, because the
/// same swallow-into-empty degradation turned a fully offline cold start into a
/// healthy-looking empty home. 429s are deliberately excluded from
/// [transportFailures] so the throttle contract above is unchanged.
class _LoadHealthTracker {
  bool rateLimited = false;

  /// Per-bucket classified failures, so one dead read no longer erases the
  /// buckets that loaded.
  final Map<_Bucket, AppFailure> failures = <_Bucket, AppFailure>{};

  void recordFailure(_Bucket bucket, AppFailure failure) =>
      failures.putIfAbsent(bucket, () => failure);

  /// Primary reads that failed on transport with a non-429 [DioException].
  int transportFailures = 0;

  /// Primary reads that completed (any parseable HTTP response).
  int successes = 0;

  /// True iff every primary read failed on transport and none succeeded.
  bool get loadFailed => successes == 0 && transportFailures > 0;

  void recordSuccess() => successes++;

  /// Longest `Retry-After` seen this load (a 429 from a slower-recovering
  /// endpoint should win so we back off for the full window).
  Duration? retryAfter;

  /// Folds a [DioException] into the tracker. Non-429 errors only feed the
  /// transport-failure count — they must not flip the 429-specific rate-limit
  /// signal, which each read's own catch already degrades around. Secondary
  /// reads (offer probes) pass `primary: false`: they never mean "home failed".
  void record(DioException error, {bool primary = true, _Bucket? bucket}) {
    if (error.response?.statusCode != 429) {
      if (primary) transportFailures++;
      // A 429 is a THROTTLE, not a dead bucket: the pinned contract is that a
      // rate-limited load still lands on READY.
      if (bucket != null) recordFailure(bucket, AppFailure.of(error));
      return;
    }
    rateLimited = true;
    final advertised = _parseRetryAfter(
      error.response?.headers.value('retry-after'),
    );
    if (advertised == null) return;
    final current = retryAfter;
    if (current == null || advertised > current) retryAfter = advertised;
  }

  /// Parses an HTTP `Retry-After` value. Supports the common delta-seconds form
  /// (`Retry-After: 30`); an HTTP-date form or an unparseable value yields
  /// `null`, so the cubit falls back to its own poll-cadence backoff. Negative
  /// values are clamped away (treated as absent).
  static Duration? _parseRetryAfter(String? raw) {
    if (raw == null) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds == null || seconds < 0) return null;
    return Duration(seconds: seconds);
  }
}
