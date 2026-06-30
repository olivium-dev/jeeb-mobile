import 'package:dio/dio.dart';

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
///       * Replies      — non-accepted rows with `offersCount > 0`.
///       * Pending      — non-accepted rows with `offersCount == 0`.
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
  DioClientHomeRepository(this._dio);

  final Dio _dio;

  // D5 contract: GET /deliveries?stage=<stage>&limit=<n>
  static const _activeDeliveriesPath = '/deliveries';
  static const _requestsPath = '/requests';

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    final results = await Future.wait([
      _fetchInProgress(),
      _fetchClientRequests(),
      _fetchRecentDeliveries(),
    ]);

    final shipments = results[0] as List<ClientHomeRequest>;
    final buckets = results[1] as _ClientRequestBuckets;
    final recentDeliveries = results[2] as List<RecentDeliverySummary>;

    // Merge accepted orders into In Progress, deduped against any live shipment
    // by id so the same order never renders twice.
    final shipmentIds = shipments.map((r) => r.id).toSet();
    final inProgress = <ClientHomeRequest>[
      ...shipments,
      ...buckets.accepted.where((a) => !shipmentIds.contains(a.id)),
    ];

    return ClientHomeSnapshot(
      inProgress: inProgress,
      pending: buckets.pending,
      replies: buckets.replies,
      recentDeliveries: recentDeliveries,
    );
  }

  Future<List<ClientHomeRequest>> _fetchInProgress() async {
    try {
      final response = await _dio.get<dynamic>(
        _activeDeliveriesPath,
        queryParameters: {'stage': 'active', 'limit': 50},
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

  /// Single `GET /requests?role=client` call, partitioned client-side into the
  /// accepted / replies / pending buckets (S007-P1B). The gateway only filters
  /// by `role`, so the status/offers split is done here:
  ///   * `status == accepted` → In Progress (chat re-entry).
  ///   * else `offersCount > 0` → Replies.
  ///   * else → Pending.
  Future<_ClientRequestBuckets> _fetchClientRequests() async {
    try {
      final response = await _dio.get<dynamic>(
        _requestsPath,
        queryParameters: {'role': 'client', 'page': 1, 'pageSize': 50},
      );
      final rawItems = _items(response.data);
      final accepted = <ClientHomeRequest>[];
      final pending = <ClientHomeRequest>[];
      final replies = <ClientHomeRequest>[];
      for (final raw in rawItems) {
        if (raw is! Map<String, dynamic>) continue;
        _classify(raw, accepted: accepted, pending: pending, replies: replies);
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

  void _classify(
    Map<String, dynamic> raw, {
    required List<ClientHomeRequest> accepted,
    required List<ClientHomeRequest> pending,
    required List<ClientHomeRequest> replies,
  }) {
    if (DioAcceptedConversationsRepository.isAcceptedStatus(raw['status'])) {
      final request = _parseRequest(raw, status: 'accepted');
      if (request != null) accepted.add(request);
      return;
    }
    final isReply = ((raw['offersCount'] as num?)?.toInt() ?? 0) > 0;
    final request =
        _parseRequest(raw, status: isReply ? 'offers-received' : 'pending');
    if (request == null) return;
    (isReply ? replies : pending).add(request);
  }

  Future<List<RecentDeliverySummary>> _fetchRecentDeliveries() async {
    try {
      final response = await _dio.get<dynamic>(
        _requestsPath,
        queryParameters: {'role': 'client', 'page': 1, 'pageSize': 10},
      );
      final rawItems = _items(response.data);
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
        : (json['dropoffAddress'] as String? ?? '');
    // D5 ShipmentsListDto uses 'currentStage', not 'status'.
    final stage = json['currentStage'] as String? ?? json['status'] as String?;
    return ClientHomeRequest(
      id: id,
      displayId: json['displayId'] as String?,
      title:
          json['title'] as String? ??
          json['description'] as String? ??
          'Delivery $id',
      status: _mapDeliveryStatus(stage),
      destinationLabel: destination,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      jeeberName: json['jeeberName'] as String?,
      tier: ClientRequestTier.parse(
        json['tier'] as String? ?? json['tierId'] as String?,
      ),
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
          'Request $id',
      status: _mapRequestStatus(status),
      destinationLabel: destination,
      tier: ClientRequestTier.parse(
        json['tier'] as String? ?? json['tierId'] as String?,
      ),
      offerCount: (json['offersCount'] as num?)?.toInt() ?? 0,
      offerAvatarUrls: offerAvatarUrls,
      conversationId: json['conversationId'] as String?,
      ttlSeconds: (json['ttlSeconds'] as num?)?.toInt(),
    );
  }

  static ClientRequestStatus _mapRequestStatus(String bucket) {
    switch (bucket) {
      case 'accepted':
        return ClientRequestStatus.accepted;
      case 'offers-received':
        return ClientRequestStatus.offersReceived;
      default:
        return ClientRequestStatus.searching;
    }
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
          'Delivery $id',
      destinationLabel: destination,
      completedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
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
