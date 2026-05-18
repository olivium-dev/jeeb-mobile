import 'package:dio/dio.dart';

import '../domain/client_home_repository.dart';
import '../domain/client_home_request.dart';
import '../domain/recent_delivery_summary.dart';

/// Dio-backed [ClientHomeRepository] hitting the mock (jeeb-gateway in prod).
///
/// Three calls in parallel, one per home-tab list the Figma renders:
///   - `GET /v1/delivery/active`             → In Progress
///   - `GET /v1/requests?status=pending`     → Pending Requests
///   - `GET /v1/requests?status=offers-received` → Replies (+6 stack)
///
/// The [MockGatewayClient] interceptor rewrites these to their
/// service-prefixed mock counterparts automatically.
class DioClientHomeRepository implements ClientHomeRepository {
  DioClientHomeRepository(this._dio);

  final Dio _dio;

  static const _activeDeliveriesPath = '/v1/delivery/active';
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

  Future<List<ClientHomeRequest>> _fetchByStatus(String status) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _requestsPath,
        queryParameters: {'status': status, 'page': 1, 'pageSize': 50},
      );
      final data = response.data;
      if (data == null) return const [];
      final rawItems = data['items'];
      if (rawItems is! List) return const [];
      final items = <ClientHomeRequest>[];
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          final request = _parseRequest(raw, status: status);
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

  Future<List<RecentDeliverySummary>> _fetchRecentDeliveries() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _requestsPath,
        queryParameters: {'status': 'delivered', 'page': 1, 'pageSize': 10},
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
    return ClientHomeRequest(
      id: id,
      displayId: json['displayId'] as String?,
      title: json['title'] as String? ?? 'Delivery $id',
      status: _mapDeliveryStatus(json['status'] as String?),
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
