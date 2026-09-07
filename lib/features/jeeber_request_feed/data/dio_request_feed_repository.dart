import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/diagnostics/diag.dart';
import '../../../core/formatting/server_time.dart';
import '../../../core/idempotency/operation_id.dart';
import '../../../core/lifecycle/polling_source.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/requests/server_request_status.dart';
import 'request_feed_models.dart';
import 'request_feed_repository.dart';

class DioRequestFeedRepository implements RequestFeedRepository, PollingSource {
  DioRequestFeedRepository({
    required Dio dio,
    DateTime Function()? now,
    OperationIdFactory? newKey,
  }) : _dio = dio,
       _now = now ?? DateTime.now,
       _newKey = newKey ?? newOperationId;

  final Dio _dio;

  final DateTime Function() _now;

  final OperationIdFactory _newKey;

  /// One key per in-flight act, so a user-driven Retry of accept/decline
  /// replays the SAME mutation instead of double-firing it.
  final Map<String, String> _actionKeys = <String, String>{};

  static const String _feedPath = '/v1/jeebers/me/feed?status=pending';

  final StreamController<DeliveryRequest> _requestsCtrl =
      StreamController<DeliveryRequest>.broadcast();
  final StreamController<FeedTransportUpdate> _transportCtrl =
      StreamController<FeedTransportUpdate>.broadcast(onListen: () {});

  final Set<Object> _interest = HashSet<Object>.identity();
  bool _disposed = false;

  @override
  Stream<DeliveryRequest> get requests => _requestsCtrl.stream;

  @override
  Stream<FeedTransportUpdate> get transport => _transportCtrl.stream;

  @override
  Future<List<DeliveryRequest>> refresh() async {
    // Disposed: the cubit is gone, not a failure.
    if (_disposed) return const <DeliveryRequest>[];
    try {
      final response = await _dio.get<dynamic>(_feedPath);
      return _parseRequests(response.data ?? {});
    } on DioException catch (e) {
      throw AppFailure.of(e);
    }
  }

  @override
  Future<RequestActionOutcome> accept(String id) async {
    final String slot = 'accept:$id';
    try {
      await _dio.post<void>(
        '/v1/delivery/requests/$id/accept',
        options: _idempotent(slot),
      );
      _actionKeys.remove(slot);
      return RequestActionOutcome.accepted;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 409 || status == 410) {
        _actionKeys.remove(slot);
        return status == 409
            ? RequestActionOutcome.alreadyTaken
            : RequestActionOutcome.expired;
      }
      // The key survives: the next Retry must be the same mutation.
      throw AppFailure.of(e);
    }
  }

  @override
  Future<RequestActionOutcome> decline(String id) async {
    final String slot = 'decline:$id';
    try {
      await _dio.post<void>(
        '/v1/delivery/requests/$id/decline',
        options: _idempotent(slot),
      );
      _actionKeys.remove(slot);
      return RequestActionOutcome.declined;
    } on DioException catch (e) {
      throw AppFailure.of(e);
    }
  }

  Options _idempotent(String slot) => Options(
    headers: <String, dynamic>{
      'Idempotency-Key': _actionKeys.putIfAbsent(slot, _newKey),
    },
  );

  @override
  void addPollInterest(Object owner) {
    if (_disposed || !_interest.add(owner)) return;
    if (_interest.length != 1) return;
    _transportCtrl.add(const FeedTransportUpdate(FeedTransport.polling));
  }

  @override
  void removePollInterest(Object owner) {
    _interest.remove(owner);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _interest.clear();
    _actionKeys.clear();
    await _requestsCtrl.close();
    await _transportCtrl.close();
  }

  @visibleForTesting
  bool get debugIsDisposed => _disposed;

  List<DeliveryRequest> _parseRequests(Object? data) {
    final items = data is List
        ? data
        : data is Map<String, dynamic> && data['items'] is List
        ? data['items'] as List
        : const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(_parseRequest)
        .whereType<DeliveryRequest>()
        .toList(growable: false);
  }

  DeliveryRequest? _parseRequest(Map<String, dynamic> json) {

    final id = (json['requestId'] as String?) ?? (json['id'] as String?);
    if (id == null) return null;

    // UX-21: nothing reads a row's coordinates (only `.label`) and the frozen
    // envelope makes both nullable — degrade and record, never hide the row.
    final pickup =
        _parseFeedLocation(json['pickup']) ?? _parseLiveLocation(json, 'pickup');
    final dropoff =
        _parseFeedLocation(json['dropoff']) ??
        _parseLiveLocation(json, 'dropoff');
    if (pickup == null || dropoff == null) {
      Diag.event('feed.row_location_missing', <String, Object?>{
        'pickup': pickup != null,
        'dropoff': dropoff != null,
      });
    }
    // `tier` is the slug; `tierId` is a UUID that never parses. Slug must win.
    final tier = _parseTier(
      json['tier'] as String? ?? json['tierId'] as String?,
    );

    final myOffer = json['myOffer'];
    final hasOffer = myOffer is Map<String, dynamic>;
    final feedStatus = hasOffer
        ? JeeberFeedItemStatus.pendingResponse
        : JeeberFeedItemStatus.incoming;

    final amount = json['amount'];
    final offerFee = hasOffer ? (myOffer['feeCents'] as num?)?.toDouble() : null;
    final parsedEarnings =
        (json['potentialEarnings'] as num?)?.toDouble() ??
        _amountValue(amount) ??
        (offerFee == null ? null : offerFee / 100.0);
    final earnings = parsedEarnings ?? 0.0;
    final parsedCurrency =
        (json['currency'] as String?) ?? _amountCurrency(amount);
    if (parsedCurrency == null && parsedEarnings != null) {
      Diag.event('feed.row_currency_missing', const <String, Object?>{});
    }

    final distanceMeters = (json['distanceMeters'] as num?)?.toDouble();

    final rawRemaining = json['offerDeadlineInSeconds'];
    final DateTime? expires;
    if (rawRemaining is num) {
      expires = _now().add(
        Duration(seconds: rawRemaining.toInt().clamp(0, 1 << 31)),
      );
    } else {
      expires = null; 
    }
    final createdRaw = json['createdAt'] as String?;
    final requestStatus = ServerRequestStatus.normalize(json['status']);
    return DeliveryRequest(
      id: id,
      pickup: pickup ?? _unknownLocation,
      dropoff: dropoff ?? _unknownLocation,
      tier: tier,
      estimatedDistanceKm:
          (json['estimatedDistanceKm'] as num?)?.toDouble() ?? 0.0,
      potentialEarnings: earnings,
      earningsKnown: parsedEarnings != null,
      currency: parsedCurrency ?? 'USD',
      currencyKnown: parsedCurrency != null,
      expiresAt: expires,

      senderName: json['senderName'] as String?,
      senderAvatarUrl: json['senderAvatarUrl'] as String?,

      itemsSummary:
          json['description'] as String? ??
          json['itemsSummary'] as String? ??
          json['title'] as String?,
      distanceFromYouKm: distanceMeters != null
          ? distanceMeters / 1000.0
          : (json['distanceFromYouKm'] as num?)?.toDouble(),
      receivedAt: createdRaw != null ? _parseServerTime(createdRaw) : null,
      feedStatus: feedStatus,

      requestIsOpen: requestStatus.isEmpty ||
          ServerRequestStatus.isOpen(requestStatus),
    );
  }

  /// Label-only placeholder: no consumer reads these coordinates, and the row
  /// must still reach the jeeber.
  static const RequestLocation _unknownLocation =
      RequestLocation(label: '', latitude: 0, longitude: 0);

  static DateTime? _parseServerTime(String raw) => ServerTime.parse(raw);

  RequestLocation? _parseFeedLocation(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final label =
        (raw['address'] as String?) ?? (raw['label'] as String?) ?? '';
    final loc = raw['location'];
    if (loc is Map) {
      final lat =
          (loc['lat'] as num?)?.toDouble() ??
          (loc['latitude'] as num?)?.toDouble();
      final lng =
          (loc['lng'] as num?)?.toDouble() ??
          (loc['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        return RequestLocation(label: label, latitude: lat, longitude: lng);
      }
    }

    final lat =
        (raw['lat'] as num?)?.toDouble() ??
        (raw['latitude'] as num?)?.toDouble();
    final lng =
        (raw['lng'] as num?)?.toDouble() ??
        (raw['longitude'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      return RequestLocation(label: label, latitude: lat, longitude: lng);
    }
    return null;
  }

  RequestLocation? _parseLiveLocation(Map<String, dynamic> json, String key) {
    final loc = json['${key}Location'];
    if (loc is! Map<String, dynamic>) return null;
    final label = json['${key}Address'] as String?;
    final lat =
        (loc['lat'] as num?)?.toDouble() ??
        (loc['latitude'] as num?)?.toDouble();
    final lng =
        (loc['lng'] as num?)?.toDouble() ??
        (loc['longitude'] as num?)?.toDouble();
    if (label == null || lat == null || lng == null) return null;
    return RequestLocation(label: label, latitude: lat, longitude: lng);
  }

  double? _amountValue(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is Map && raw['value'] is num) {
      return (raw['value'] as num).toDouble();
    }
    return null;
  }

  String? _amountCurrency(Object? raw) {
    if (raw is Map && raw['currency'] is String) {
      return raw['currency'] as String;
    }
    return null;
  }

  JeeberRequestTier? _parseTier(String? raw) {
    switch (raw) {
      case 'flash':
        return JeeberRequestTier.flash;

      case 'standard':
      case 'express':
      case 'on_the_way':
      case 'eco':
        return JeeberRequestTier.standard;
      case 'bulk':
        return JeeberRequestTier.bulk;
      default:
        return null;
    }
  }
}
