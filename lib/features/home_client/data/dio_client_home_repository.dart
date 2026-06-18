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
            final isReply = _offerCount(raw) > 0;
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
    final id = _stringOf(json, const ['id', 'deliveryId']);
    if (id == null) return null;
    final destination = _destinationLabel(json);
    // D5 ShipmentsListDto uses 'currentStage', not 'status'.
    final stage = _stringOf(json, const ['currentStage', 'stage', 'status']);
    return ClientHomeRequest(
      id: id,
      displayId: _stringOf(json, const ['displayId', 'orderNumber']),
      title: _stringOf(json, const ['title', 'description']) ?? 'Delivery $id',
      status: _mapDeliveryStatus(stage),
      destinationLabel: destination,
      etaMinutes: _intOf(json, const ['etaMinutes', 'eta_minutes']),
      jeeberName: _stringOf(json, const ['jeeberName', 'driverName']),
      tier: ClientRequestTier.parse(_stringOf(json, const ['tier', 'tierId'])),
      progressStep: _intOf(json, const ['progressStep']) ?? 0,
      conversationId: _stringOf(json, const [
        'conversationId',
        'conversation_id',
        'chatId',
      ]),
    );
  }

  static ClientHomeRequest? _parseRequest(
    Map<String, dynamic> json, {
    required String status,
  }) {
    final id = _stringOf(json, const ['id', 'requestId']);
    if (id == null) return null;
    final destination = _destinationLabel(json);
    return ClientHomeRequest(
      id: id,
      displayId: _stringOf(json, const ['displayId', 'orderNumber']),
      title: _stringOf(json, const ['title', 'description']) ?? 'Request $id',
      status: status == 'offers-received'
          ? ClientRequestStatus.offersReceived
          : ClientRequestStatus.searching,
      destinationLabel: destination,
      tier: ClientRequestTier.parse(_stringOf(json, const ['tier', 'tierId'])),
      offerCount: _offerCount(json),
      offerAvatarUrls: _offerAvatarUrls(json),
      conversationId: _stringOf(json, const [
        'conversationId',
        'conversation_id',
        'chatId',
      ]),
      ttlSeconds: _intOf(json, const ['ttlSeconds', 'ttl_seconds']),
    );
  }

  static RecentDeliverySummary? _parseRecentDelivery(
    Map<String, dynamic> json,
  ) {
    final id = _stringOf(json, const ['id', 'requestId', 'deliveryId']);
    if (id == null) return null;
    final destination = _destinationLabel(json);
    return RecentDeliverySummary(
      id: id,
      title: _stringOf(json, const ['title', 'description']) ?? 'Delivery $id',
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

  static String _destinationLabel(Map<String, dynamic> json) {
    final direct = _stringOf(json, const [
      'destinationLabel',
      'dropoffAddress',
    ]);
    if (direct != null) return direct;
    final dropoff = json['dropoff'];
    if (dropoff is Map<String, dynamic>) {
      return _stringOf(dropoff, const ['address', 'label']) ?? '';
    }
    return '';
  }

  static int _offerCount(Map<String, dynamic> json) {
    final count = _intOf(json, const [
      'offersCount',
      'offerCount',
      'offers_count',
    ]);
    if (count != null) return count;
    final offers = json['offers'];
    return offers is List ? offers.length : 0;
  }

  static List<String> _offerAvatarUrls(Map<String, dynamic> json) {
    final direct = json['offerAvatars'] ?? json['offerAvatarUrls'];
    if (direct is List) {
      return direct.whereType<String>().toList(growable: false);
    }
    final offers = json['offers'];
    if (offers is! List) return const <String>[];
    return offers
        .whereType<Map<String, dynamic>>()
        .map((o) => _stringOf(o, const ['avatarUrl', 'jeeberAvatarUrl']))
        .whereType<String>()
        .toList(growable: false);
  }

  static int? _intOf(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final raw = json[key];
      if (raw is num) return raw.toInt();
      if (raw is String) {
        final parsed = int.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static String? _stringOf(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw;
    }
    return null;
  }
}
