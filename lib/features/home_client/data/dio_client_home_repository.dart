import 'package:dio/dio.dart';

import '../../../core/formatting/friendly_reference.dart';
import '../../../core/formatting/server_time.dart';
import '../../../core/network/single_flight_get.dart';
import '../../chat/data/dio_accepted_conversations_repository.dart';
import '../domain/client_home_repository.dart';
import '../domain/client_home_request.dart';
import '../domain/recent_delivery_summary.dart';

class DioClientHomeRepository implements ClientHomeRepository {
  DioClientHomeRepository(Dio dio, {SingleFlightGet? coalescer})
      : _coalescer = coalescer ?? SingleFlightGet(dio);

  final SingleFlightGet _coalescer;

  static const _activeDeliveriesPath = '/deliveries';
  static const _requestsPath = '/requests';

  /// requestId parameter is REQUIRED.
  static const _offersPath = '/v1/offers';

  static const int _maxOfferProbes = 10;

  /// Limits concurrency to prevent 429.
  static const int _probeConcurrency = 2;

  static const Set<String> _liveOfferStatuses = {
    'pending',
    'submitted',
    'edited',
  };

  static const Set<String> _terminalRequestStatuses = {
    'cancelled',
    'canceled',
    'expired',
    'delivered',
    'done',
    'rated',
  };

  static const Set<String> _inFlightRequestStatuses = {
    'picked',
    'pickedup',
    'intransit',
    'atdoor',
    'headingoff',
    'matched',
  };

  /// Tolerates snake_case (mock) and PascalCase (gateway).
  static String _normalizeStatus(Object? status) =>
      (status is String ? status : '').toLowerCase().replaceAll('_', '');

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    final rateLimit = _RateLimitTracker();

    final results = await Future.wait([
      _fetchInProgress(rateLimit),
      _fetchRoleClientRows(rateLimit),
      _fetchActiveRequests(rateLimit),
    ]);

    final shipments = results[0] as List<ClientHomeRequest>;
    final roleClientRows = results[1];
    final activeRequests = results[2] as List<ClientHomeRequest>;

    final buckets = await _partitionClientRequests(roleClientRows, rateLimit);
    final recentDeliveries = _recentDeliveries(roleClientRows);

    final activeShipments = shipments
        .where(
          (r) =>
              r.status != ClientRequestStatus.delivered &&
              r.status != ClientRequestStatus.cancelled,
        )
        .toList(growable: false);
    final shipmentIds = activeShipments.map((r) => r.id).toSet();
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
      rateLimited: rateLimit.rateLimited,
      retryAfter: rateLimit.retryAfter,
    );
  }

  Future<List<ClientHomeRequest>> _fetchActiveRequests(
    _RateLimitTracker rateLimit,
  ) async {
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
    } on DioException catch (e) {
      rateLimit.record(e);
      return const [];
    } on FormatException {
      return const [];
    }
  }

  Future<List<ClientHomeRequest>> _fetchInProgress(
    _RateLimitTracker rateLimit,
  ) async {
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
    } on DioException catch (e) {
      rateLimit.record(e);
      return const [];
    } on FormatException {
      return const [];
    }
  }

  Future<List<dynamic>> _fetchRoleClientRows(
    _RateLimitTracker rateLimit,
  ) async {
    try {
      final response = await _get(
        _requestsPath,
        const {'role': 'client', 'page': 1, 'pageSize': 50},
      );
      return _items(response.data);
    } on DioException catch (e) {
      rateLimit.record(e);
      return const [];
    } on FormatException {
      return const [];
    }
  }

  Future<_ClientRequestBuckets> _partitionClientRequests(
    List<dynamic> rawItems,
    _RateLimitTracker rateLimit,
  ) async {
    try {
      final accepted = <ClientHomeRequest>[];
      final candidates = <Map<String, dynamic>>[];
      for (final raw in rawItems) {
        if (raw is! Map<String, dynamic>) continue;
        final rawStatus = raw['status'];
        final normalized = _normalizeStatus(rawStatus);
        if (_terminalRequestStatuses.contains(normalized)) {
          continue;
        }
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

      final offerCounts = await _resolveOfferCounts(candidates, rateLimit);

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

  /// Deduped via memo.
  Future<List<int>> _resolveOfferCounts(
    List<Map<String, dynamic>> candidates,
    _RateLimitTracker rateLimit,
  ) async {
    final counts = List<int>.generate(
      candidates.length,
      (i) => (candidates[i]['offersCount'] as num?)?.toInt() ?? 0,
      growable: false,
    );

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
          live = await _fetchLiveOfferCount(id, rateLimit);
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

  /// Returns null (not 0) on failure so caller keeps payload count.
  Future<int?> _fetchLiveOfferCount(
    String requestId,
    _RateLimitTracker rateLimit,
  ) async {
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
    } on DioException catch (e) {
      rateLimit.record(e);
      return null;
    } catch (_) {
      return null;
    }
  }

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
      itemsSummary: json['description'] as String?,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      jeeberName: json['jeeberName'] as String?,
      tier: ClientRequestTier.parse(
        json['tier'] as String? ?? json['tierId'] as String?,
      ),
      progressStep: (json['progressStep'] as num?)?.toInt() ?? 0,
      conversationId: json['conversationId'] as String?,
      /// Delivery id for tracking, request id for chat correlation.
      deliveryId:
          json['deliveryId'] as String? ?? json['delivery_id'] as String?,
      chatCorrelationId:
          json['requestId'] as String? ?? json['request_id'] as String?,
    );
  }

  static ClientHomeRequest? _parseActiveRequest(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return null;
    final rawStatus =
        (json['status'] ?? json['deliveryStatus'] ?? json['currentStage'])
            as String?;
    final status = _mapRequestStatus(rawStatus);
    if (status == null) return null;
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
      itemsSummary: json['description'] as String?,
      tier: ClientRequestTier.parse(
        json['tier'] as String? ?? json['tierId'] as String?,
      ),
      offerCount:
          offerCountOverride ?? (json['offersCount'] as num?)?.toInt() ?? 0,
      offerAvatarUrls: offerAvatarUrls,
      conversationId: json['conversationId'] as String?,
      ttlSeconds: (json['ttlSeconds'] as num?)?.toInt(),
      createdAt: ServerTime.parse(
        json['createdAt'] as String? ?? json['created_at'] as String?,
      ),
      hasNewOffers: (json['hasNewOffers'] as bool?) ??
          (json['has_new_offers'] as bool?) ??
          false,
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

  static ClientRequestStatus _mapDeliveryStatus(String? status) {
    switch (_normalizeStatus(status)) {
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
      case 'done':
      case 'delivered':
      case 'completed':
      case 'rated':
        return ClientRequestStatus.delivered;
      case 'failedneedsescalation':
        return ClientRequestStatus.accepted;
      case 'cancelled':
      case 'canceled':
      case 'expired':
        return ClientRequestStatus.cancelled;
      default:
        return ClientRequestStatus.searching;
    }
  }

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

class _RateLimitTracker {
  bool rateLimited = false;

  Duration? retryAfter;

  void record(DioException error) {
    if (error.response?.statusCode != 429) return;
    rateLimited = true;
    final advertised = _parseRetryAfter(
      error.response?.headers.value('retry-after'),
    );
    if (advertised == null) return;
    final current = retryAfter;
    if (current == null || advertised > current) retryAfter = advertised;
  }

  /// Parses `Retry-After: <seconds>` delta form.
  static Duration? _parseRetryAfter(String? raw) {
    if (raw == null) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds == null || seconds < 0) return null;
    return Duration(seconds: seconds);
  }
}
