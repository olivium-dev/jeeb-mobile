import 'package:dio/dio.dart';

import '../domain/client_home_repository.dart';
import '../domain/client_home_request.dart';
import '../domain/recent_delivery_summary.dart';

/// Dio-backed [ClientHomeRepository] hitting the mock (jeeb-gateway in prod).
///
/// Three calls in parallel, one per home-tab list the Figma renders:
///   - `GET /v1/deliveries?stage=active`     → In Progress  (live gateway)
///   - `GET /v1/requests?role=client`        → Pending Requests + Replies
///   - `GET /v1/requests?role=client`        → Replies (+6 stack)
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
    ]);

    return ClientHomeSnapshot(
      inProgress: results[0] as List<ClientHomeRequest>,
      pending: results[1] as List<ClientHomeRequest>,
      replies: results[2] as List<ClientHomeRequest>,
      recentDeliveries: results[3] as List<RecentDeliverySummary>,
    );
  }

  Future<List<ClientHomeRequest>> _fetchInProgress() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _activeDeliveriesPath,
        queryParameters: {'stage': 'active', 'limit': 50},
      );
      final data = response.data;
      if (data == null) return const [];
      final rawItems = data['items'];
      if (rawItems is! List) return const [];
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
