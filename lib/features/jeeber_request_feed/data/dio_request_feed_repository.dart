import 'dart:async';

import 'package:dio/dio.dart';

import 'request_feed_models.dart';
import 'request_feed_repository.dart';

/// Dio-backed [RequestFeedRepository].
///
/// Uses REST polling (no WebSocket in this implementation) against Mockoon
/// :3055 at `GET /v1/jeeber/feed`. Emits [FeedTransport.polling].
///
/// Mock endpoint (useMockPrefixes=false, verified against :3055):
///   GET /v1/jeeber/feed  → { "items": [...DeliveryRequest], "count": N }
///   POST /v1/delivery/requests/{id}/accept
///   POST /v1/delivery/requests/{id}/decline
class DioRequestFeedRepository implements RequestFeedRepository {
  DioRequestFeedRepository({
    required Dio dio,
    Duration pollInterval = const Duration(seconds: 10),
  })  : _dio = dio,
        _pollInterval = pollInterval;

  final Dio _dio;
  final Duration _pollInterval;

  final StreamController<DeliveryRequest> _requestsCtrl =
      StreamController<DeliveryRequest>.broadcast();
  final StreamController<String> _cancellationsCtrl =
      StreamController<String>.broadcast();
  final StreamController<FeedTransportUpdate> _transportCtrl =
      StreamController<FeedTransportUpdate>.broadcast(
    onListen: () {},
  );

  Timer? _pollTimer;
  bool _disposed = false;

  @override
  Stream<DeliveryRequest> get requests => _requestsCtrl.stream;

  @override
  Stream<String> get cancellations => _cancellationsCtrl.stream;

  @override
  Stream<FeedTransportUpdate> get transport => _transportCtrl.stream;

  @override
  Future<List<DeliveryRequest>> refresh() async {
    _ensurePolling();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/jeeber/feed',
      );
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
    await _cancellationsCtrl.close();
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
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/jeeber/feed',
      );
      final requests = _parseRequests(response.data ?? {});
      for (final r in requests) {
        _requestsCtrl.add(r);
      }
    } on DioException {
      // Swallow poll errors — UI shows stale feed rather than error banner.
    }
  }

  List<DeliveryRequest> _parseRequests(Map<String, dynamic> data) {
    final items = data['items'] as List? ?? const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(_parseRequest)
        .whereType<DeliveryRequest>()
        .toList(growable: false);
  }

  DeliveryRequest? _parseRequest(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return null;
    final pickup = _parseLocation(json['pickup'] as Map<String, dynamic>?);
    final dropoff = _parseLocation(json['dropoff'] as Map<String, dynamic>?);
    if (pickup == null || dropoff == null) return null;
    final tier = _parseTier(json['tier'] as String?);
    final earnings = (json['potentialEarnings'] as num?)?.toDouble() ?? 0.0;
    final distance = (json['estimatedDistanceKm'] as num?)?.toDouble() ?? 0.0;
    final currency = json['currency'] as String? ?? 'USD';
    final expiresRaw = json['expiresAt'] as String?;
    final expires = expiresRaw != null
        ? DateTime.tryParse(expiresRaw) ??
            DateTime.now().add(const Duration(minutes: 5))
        : DateTime.now().add(const Duration(minutes: 5));
    return DeliveryRequest(
      id: id,
      pickup: pickup,
      dropoff: dropoff,
      tier: tier,
      estimatedDistanceKm: distance,
      potentialEarnings: earnings,
      currency: currency,
      expiresAt: expires,
      senderName: json['senderName'] as String?,
      senderAvatarUrl: json['senderAvatarUrl'] as String?,
      itemsSummary: json['itemsSummary'] as String?,
    );
  }

  RequestLocation? _parseLocation(Map<String, dynamic>? json) {
    if (json == null) return null;
    final label = json['label'] as String?;
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    if (label == null || lat == null || lng == null) return null;
    return RequestLocation(label: label, latitude: lat, longitude: lng);
  }

  JeeberRequestTier _parseTier(String? raw) {
    switch (raw) {
      case 'flash': return JeeberRequestTier.flash;
      case 'standard': return JeeberRequestTier.standard;
      case 'bulk': return JeeberRequestTier.bulk;
      default: return JeeberRequestTier.light;
    }
  }
}
