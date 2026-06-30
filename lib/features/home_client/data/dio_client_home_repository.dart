import 'package:dio/dio.dart';

import '../domain/client_home_repository.dart';
import '../domain/client_home_request.dart';
import '../domain/recent_delivery_summary.dart';

/// Dio-backed [ClientHomeRepository] hitting the mock (jeeb-gateway in prod).
///
/// Three calls in parallel, one per home-tab list the Figma renders:
///   - `GET /deliveries?stage=active`        → In Progress  (D5 contract)
///   - `GET /v1/requests?role=client`        → Pending Requests + Replies
///   - `GET /v1/requests?role=client`        → Replies (+6 stack)
///
/// BLOCKER-1 fix (2026-06-13): corrected path from the non-existent
/// `/v1/delivery/active` to the real gateway contract
/// `GET /deliveries?stage=active&limit=50` (ShipmentsListDto).
/// Response items are keyed on `currentStage`, not `status`.
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

  // D5 contract: GET /deliveries?stage=<stage>&limit=<n>
  static const _activeDeliveriesPath = '/deliveries';
  static const _requestsPath = '/requests';

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

  /// Fetches client requests filtered by [bucket].
  ///
  /// BLOCKER-2 (2026-06-13): the real gateway GET /requests only supports a
  /// `role` filter, not a `status` filter. We pass `role=client` for both tabs
  /// and disambiguate locally: items with offersCount > 0 are classified as
  /// replies (offers-received), items with offersCount == 0 are classified as
  /// pending. The [bucket] parameter drives which subset is returned.
  Future<List<ClientHomeRequest>> _fetchByStatus(String bucket) async {
    try {
      final response = await _dio.get<dynamic>(
        _requestsPath,
        // Use role=client (documented D3 filter). Do NOT pass status= — the
        // gateway ignores it and both tabs would show identical data.
        queryParameters: {'role': 'client', 'page': 1, 'pageSize': 50},
      );
      final rawItems = _items(response.data);
      final items = <ClientHomeRequest>[];
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          final request = _parseRequest(raw, status: bucket);
          if (request != null) {
            // Client-side bucket assignment: offers-received ↔ offersCount > 0
            final isReply = ((raw['offersCount'] as num?)?.toInt() ?? 0) > 0;
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
      status: status == 'offers-received'
          ? ClientRequestStatus.offersReceived
          : ClientRequestStatus.searching,
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
