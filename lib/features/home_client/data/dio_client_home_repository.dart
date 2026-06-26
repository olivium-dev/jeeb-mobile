import 'package:dio/dio.dart';

import '../domain/client_home_repository.dart';
import '../domain/client_home_request.dart';
import '../domain/recent_delivery_summary.dart';

/// Dio-backed [ClientHomeRepository] hitting the mock (jeeb-gateway in prod).
///
/// Parallel calls, one per home-tab list the Figma renders:
///   - `GET /v1/deliveries?stage=active`     → In Progress  (delivery rows)
///   - `GET /v1/requests?role=client`        → Pending Requests + Replies
///   - `GET /v1/requests?role=client`        → in-flight requests merged into
///       In Progress so a freshly-accepted order surfaces even when the
///       deliveries-only source omits it (S10 Defect A — see [_mergeInProgress])
///
/// BLOCKER-1 fix (2026-06-13): corrected path from the non-existent
/// `/v1/delivery/active` to the gateway list contract.
///
/// LIVE-ROUTE fix (iter6, 2026-06-22): the path was still the mock-era
/// `/deliveries` (no `/v1`), which the LIVE gateway answers with the empty
/// legacy `ShipmentsListDto` `{"shipments":[],"count":0}` — so the "In Progress"
/// tab never populated. Repointed to the live
/// `JeebOrdersListController.ListDeliveries` route `GET /v1/deliveries?stage=active`
/// → `{ items: [ OrderListItem ], page, pageSize, totalCount, totalPages }`
/// (verified live on :10090 against an accepted delivery). Items are keyed on
/// `status` (the parser still tolerates the legacy `currentStage`).
///
/// BLOCKER-2 note: the real gateway `GET /requests` filters by `role`, not
/// `status`. Until the gateway exposes a `status` filter the client-side
/// parser distinguishes pending vs offers-received by the `offersCount` field:
/// items with offersCount > 0 are treated as replies.
///
/// The [MockGatewayClient] interceptor rewrites these to their
/// service-prefixed mock counterparts automatically.
class DioClientHomeRepository implements ClientHomeRepository {
  DioClientHomeRepository(this._dio);

  final Dio _dio;

  // Live gateway list contract: GET /v1/deliveries?stage=<stage>&limit=<n>
  // (the bare `/deliveries` path is the mock-era route the LIVE gateway answers
  // with an empty `{"shipments":[],"count":0}` — see the class doc).
  static const _activeDeliveriesPath = '/v1/deliveries';
  static const _requestsPath = '/v1/requests';

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    final results = await Future.wait([
      _fetchInProgress(),
      _fetchByStatus('pending'),
      _fetchByStatus('offers-received'),
      _fetchRecentDeliveries(),
      _fetchActiveRequests(),
    ]);

    final deliveries = results[0] as _InProgressDeliveries;
    final activeRequests = results[4] as List<ClientHomeRequest>;

    return ClientHomeSnapshot(
      inProgress: _mergeInProgress(deliveries, activeRequests),
      pending: results[1] as List<ClientHomeRequest>,
      replies: results[2] as List<ClientHomeRequest>,
      recentDeliveries: results[3] as List<RecentDeliverySummary>,
    );
  }

  /// S10 Defect A — surface a freshly-accepted order in the In-Progress tab.
  ///
  /// The deliveries-only source (`GET /v1/deliveries?stage=active`) reliably
  /// returns SEEDED active delivery rows and, on the Express mock, the
  /// accept-minted `delivery-<offerId>` too. But the field-observed two-party
  /// run hit a backend where that source omits the freshly-accepted order
  /// (e.g. Mockoon :3055 has no `/v1/deliveries` route at all → 404 → empty;
  /// a gateway can flip the parent REQUEST to `matched` without surfacing a
  /// delivery row yet). The client-scoped requests source
  /// (`GET /v1/requests?role=client`) DOES carry that `matched`/in-flight
  /// request, so we MERGE it in — purely additively (we never drop a delivery
  /// row, so seeded rows always render) and deduped by the delivery rows'
  /// `requestId` so an order already shown as a delivery row is never doubled.
  /// Delivery rows are kept FIRST because they carry the real
  /// `delivery-<offerId>` id the "Track my order" CTA needs (a request id 404s
  /// `GET /v1/delivery/<id>`); merged request rows fall back to their request
  /// id only when no delivery row covers them.
  List<ClientHomeRequest> _mergeInProgress(
    _InProgressDeliveries deliveries,
    List<ClientHomeRequest> activeRequests,
  ) {
    final merged = <ClientHomeRequest>[...deliveries.rows];
    final seenIds = deliveries.rows.map((r) => r.id).toSet();
    for (final request in activeRequests) {
      // Skip a request already represented by a delivery row (same order) or a
      // duplicate id — keep the delivery-backed row (it has the tracking id).
      if (deliveries.coveredRequestIds.contains(request.id)) continue;
      if (!seenIds.add(request.id)) continue;
      merged.add(request);
    }
    return merged;
  }

  Future<_InProgressDeliveries> _fetchInProgress() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _activeDeliveriesPath,
        queryParameters: {'stage': 'active', 'limit': 50},
      );
      final data = response.data;
      if (data == null) return _InProgressDeliveries.empty;
      final rawItems = data['items'];
      if (rawItems is! List) return _InProgressDeliveries.empty;
      final items = <ClientHomeRequest>[];
      final coveredRequestIds = <String>{};
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          final request = _parseActiveDelivery(raw);
          if (request != null) {
            items.add(request);
            // Remember the parent request id this delivery row covers so the
            // active-requests merge does not double-render the same order.
            final requestId =
                (raw['requestId'] ?? raw['request_id']) as String?;
            if (requestId != null && requestId.isNotEmpty) {
              coveredRequestIds.add(requestId);
            }
          }
        }
      }
      return _InProgressDeliveries(items, coveredRequestIds);
    } on DioException {
      return _InProgressDeliveries.empty;
    } on FormatException {
      return _InProgressDeliveries.empty;
    }
  }

  /// Fetches the client's own in-flight requests (`matched`/active SM-1 family)
  /// from the client-scoped `GET /v1/requests?role=client`. These are the
  /// freshly-accepted orders the deliveries-only source can omit (S10 Defect A).
  /// Terminal (`delivered`/`cancelled`) and pre-acceptance (`pending`/
  /// `offers-received`) requests are filtered out so they never leak into the
  /// In-Progress tab — only orders genuinely on the road appear.
  Future<List<ClientHomeRequest>> _fetchActiveRequests() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _requestsPath,
        queryParameters: {'role': 'client', 'page': 1, 'pageSize': 50},
      );
      final data = response.data;
      if (data == null) return const [];
      final rawItems = data['items'];
      if (rawItems is! List) return const [];
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

  /// Fetches client requests filtered by [bucket].
  ///
  /// BLOCKER-2 (2026-06-13): the real gateway GET /requests only supports a
  /// `role` filter, not a `status` filter. We pass `role=client` for both tabs
  /// and disambiguate locally: items with offersCount > 0 are classified as
  /// replies (offers-received), items with offersCount == 0 are classified as
  /// pending. The [bucket] parameter drives which subset is returned.
  Future<List<ClientHomeRequest>> _fetchByStatus(String bucket) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _requestsPath,
        // Use role=client (documented D3 filter). Do NOT pass status= — the
        // gateway ignores it and both tabs would show identical data.
        queryParameters: {'role': 'client', 'page': 1, 'pageSize': 50},
      );
      final data = response.data;
      if (data == null) return const [];
      final rawItems = data['items'];
      if (rawItems is! List) return const [];
      final items = <ClientHomeRequest>[];
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          final request = _parseRequest(raw, status: bucket);
          if (request != null) {
            // Client-side bucket assignment: offers-received ↔ offersCount > 0
            final isReply =
                ((raw['offersCount'] as num?)?.toInt() ?? 0) > 0;
            final wantReply = bucket == 'offers-received';
            if (isReply == wantReply) items.add(request);
          }
        }
      }
      return items;
    } on DioException {
      return const [];
    } on FormatException {
      return const [];
    }
  }

  Future<List<RecentDeliverySummary>> _fetchRecentDeliveries() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _requestsPath,
        queryParameters: {'role': 'client', 'page': 1, 'pageSize': 10},
      );
      final data = response.data;
      if (data == null) return const [];
      final rawItems = data['items'];
      if (rawItems is! List) return const [];
      final items = <RecentDeliverySummary>[];
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          final summary = _parseRecentDelivery(raw);
          if (summary != null) items.add(summary);
        }
      }
      return items;
    } on DioException {
      return const [];
    } on FormatException {
      return const [];
    }
  }

  static ClientHomeRequest? _parseActiveDelivery(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return null;
    final dropoff = json['dropoff'];
    final destination = dropoff is Map<String, dynamic>
        ? (dropoff['address'] as String? ?? '')
        : '';
    // D5 ShipmentsListDto uses 'currentStage', not 'status'.
    final stage =
        json['currentStage'] as String? ?? json['status'] as String?;
    // S9 live-tracking fix: the live-tracking surface reads
    // `GET /v1/delivery/<deliveryId>`. The In-Progress list item's `id` may be
    // the parent REQUEST/order id (the live gateway models orders by request),
    // which 404s that lookup. Prefer an explicit delivery-id field when the
    // gateway surfaces one (`deliveryId`/`delivery_id`); leave null otherwise
    // so [ClientHomeRequest.trackingId] falls back to `id` (correct when the
    // list endpoint already keys items on the delivery id).
    final deliveryId =
        (json['deliveryId'] ?? json['delivery_id']) as String?;
    return ClientHomeRequest(
      id: id,
      deliveryId: (deliveryId != null && deliveryId.isNotEmpty)
          ? deliveryId
          : null,
      displayId: json['displayId'] as String?,
      title: json['title'] as String? ?? 'Delivery $id',
      status: _mapDeliveryStatus(stage),
      destinationLabel: destination,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      jeeberName: json['jeeberName'] as String?,
      tier: ClientRequestTier.parse(json['tier'] as String?),
      progressStep: (json['progressStep'] as num?)?.toInt() ?? 0,
      conversationId: json['conversationId'] as String?,
    );
  }

  static ClientHomeRequest? _parseRequest(
    Map<String, dynamic> json, {
    required String status,
  }) {
    final id = json['id'] as String?;
    if (id == null) return null;
    final dropoff = json['dropoff'];
    final destination = dropoff is Map<String, dynamic>
        ? (dropoff['address'] as String? ?? '')
        : '';
    final offerAvatars = json['offerAvatars'];
    final offerAvatarUrls = offerAvatars is List
        ? offerAvatars.whereType<String>().toList(growable: false)
        : const <String>[];
    return ClientHomeRequest(
      id: id,
      displayId: json['displayId'] as String?,
      title: json['title'] as String? ?? 'Request $id',
      status: status == 'offers-received'
          ? ClientRequestStatus.offersReceived
          : ClientRequestStatus.searching,
      destinationLabel: destination,
      tier: ClientRequestTier.parse(json['tier'] as String?),
      offerCount: (json['offersCount'] as num?)?.toInt() ?? 0,
      offerAvatarUrls: offerAvatarUrls,
      conversationId: json['conversationId'] as String?,
      ttlSeconds: (json['ttlSeconds'] as num?)?.toInt(),
    );
  }

  /// Parses an in-flight client request (S10 Defect A) into an In-Progress
  /// card. Returns null for requests that are NOT on the road — pending,
  /// offers-received, delivered, cancelled — so only genuinely active orders
  /// merge into the In-Progress tab. Carries the minted delivery id when the
  /// request surfaces one (`deliveryId`/`delivery_id`) so the "Track my order"
  /// CTA resolves; otherwise [ClientHomeRequest.trackingId] falls back to the
  /// request id (best-effort, mirrors the delivery-row fallback).
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
        : '';
    final deliveryId = (json['deliveryId'] ?? json['delivery_id']) as String?;
    return ClientHomeRequest(
      id: id,
      deliveryId: (deliveryId != null && deliveryId.isNotEmpty)
          ? deliveryId
          : null,
      displayId: json['displayId'] as String?,
      title: json['title'] as String? ?? 'Request $id',
      status: status,
      destinationLabel: destination,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      jeeberName: json['jeeberName'] as String?,
      tier: ClientRequestTier.parse(json['tier'] as String?),
      progressStep: (json['progressStep'] as num?)?.toInt() ?? 0,
      conversationId: json['conversationId'] as String?,
    );
  }

  /// Maps a REQUEST status onto a coarse In-Progress [ClientRequestStatus],
  /// returning null when the request is not on the road. Tolerates the mock's
  /// snake_case request statuses (`matched`, `picked_up`, `en_route`) and the
  /// live gateway's PascalCase SM-1 stage values (`Picked`, `InTransit`,
  /// `AtDoor`, `Ordered`).
  static ClientRequestStatus? _mapRequestStatus(String? status) {
    switch (status) {
      case 'matched':
      case 'active':
      case 'accepted':
      case 'assigned':
      case 'Ordered':
      case 'Matched':
        return ClientRequestStatus.accepted;
      case 'picked_up':
      case 'pickedup':
      case 'at_pickup':
      case 'Picked':
        return ClientRequestStatus.atPickup;
      case 'en_route':
      case 'enroute':
      case 'at_door':
      case 'atdoor':
      case 'InTransit':
      case 'AtDoor':
        return ClientRequestStatus.enRoute;
      default:
        // pending / offers-received / delivered / cancelled / unknown — not an
        // in-flight order, so it must not appear in the In-Progress tab.
        return null;
    }
  }

  static RecentDeliverySummary? _parseRecentDelivery(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return null;
    final dropoff = json['dropoff'];
    final destination = dropoff is Map<String, dynamic>
        ? (dropoff['address'] as String? ?? '')
        : '';
    return RecentDeliverySummary(
      id: id,
      title: json['title'] as String? ?? 'Delivery $id',
      destinationLabel: destination,
      completedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static ClientRequestStatus _mapDeliveryStatus(String? status) {
    switch (status) {
      case 'Ordered':
        return ClientRequestStatus.searching;
      case 'Picked':
        return ClientRequestStatus.atPickup;
      case 'InTransit':
        return ClientRequestStatus.enRoute;
      case 'AtDoor':
        return ClientRequestStatus.enRoute;
      case 'Done':
        return ClientRequestStatus.accepted;
      case 'FailedNeedsEscalation':
        return ClientRequestStatus.accepted;
      case 'Cancelled':
        return ClientRequestStatus.searching;
      default:
        return ClientRequestStatus.searching;
    }
  }
}

/// Result of the In-Progress deliveries fetch: the parsed delivery rows plus
/// the set of parent request ids they cover, so [_mergeInProgress] can dedupe
/// the active-requests merge (S10 Defect A) without double-rendering an order.
class _InProgressDeliveries {
  const _InProgressDeliveries(this.rows, this.coveredRequestIds);

  static const _InProgressDeliveries empty =
      _InProgressDeliveries(<ClientHomeRequest>[], <String>{});

  final List<ClientHomeRequest> rows;
  final Set<String> coveredRequestIds;
}
