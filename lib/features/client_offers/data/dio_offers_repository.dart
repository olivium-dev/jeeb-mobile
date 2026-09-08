import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/gateway_problem.dart';
import '../../../core/network/single_flight_get.dart';
import '../../../core/requests/server_request_status.dart';
import '../../otp_handover/domain/handover_code_store.dart';
import '../domain/jeeber_vehicle.dart';
import '../domain/offer.dart';
import '../domain/offers_repository.dart';

class DioOffersRepository implements OffersRepository {
  DioOffersRepository(
    Dio dio, {
    HandoverCodeStore? handoverCodeStore,
    SingleFlightGet? coalescer,
  })  : _dio = dio,
        _handoverCodeStore = handoverCodeStore,
        _coalescer = coalescer ?? SingleFlightGet(dio);

  final Dio _dio;
  final SingleFlightGet _coalescer;

  final HandoverCodeStore? _handoverCodeStore;

  static const Set<String> _liveStatuses = {'pending', 'submitted', 'edited'};

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    try {
      final offersResponse = await _coalescer.get(
        '/v1/offers',
        queryParameters: <String, dynamic>{'requestId': requestId},
      );
      final requestResponse = await _dio.get<dynamic>(
        '/v1/requests/${Uri.encodeComponent(requestId)}',
      );
      return _parseSnapshot(offersResponse.data, requestResponse.data);
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    try {
      // Retry and the error snack both re-POST; RetryInterceptor only replays
      // mutations that carry the key.
      final response = await _dio.post<dynamic>(
        '/v1/offers/$offerId/accept',
        options: Options(headers: {'Idempotency-Key': 'accept-$offerId'}),
      );
      return _parseAcceptResult(response.data);
    } on DioException catch (e) {
      _rethrowAccept(e);
    }
  }

  OfferAcceptResult _parseAcceptResult(dynamic data) {
    if (data is! Map) return OfferAcceptResult.empty;
    final deliveryId = acceptResponseDeliveryId(data);
    final conversationId =
        _cleanString(data['conversationId'] ?? data['conversation_id']);
    final handoverCode =
        _cleanString(data['handoverCode'] ?? data['handover_code']);
    _persistHandoverCode(deliveryId: deliveryId, code: handoverCode);
    return OfferAcceptResult(
      deliveryId: deliveryId,
      conversationId: conversationId,
      handoverCode: handoverCode,
    );
  }

  String? _cleanString(Object? raw) =>
      raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

  void _persistHandoverCode({String? deliveryId, String? code}) {
    final store = _handoverCodeStore;
    if (store == null || deliveryId == null || code == null) return;
    unawaited(
      store.save(deliveryId: deliveryId, code: code).catchError((Object e) {
        Diag.event('handover_code_save_failed', <String, Object?>{
          'deliveryId': deliveryId,
          'kind': AppFailure.of(e).kind.name,
        });
      }),
    );
  }

  OffersSnapshot _parseSnapshot(dynamic data, dynamic requestData) {
    final List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic>) {
      items = (data['items'] as List?) ??
          (data['offers'] as List?) ??
          const <dynamic>[];
    } else {
      throw const OffersRepositoryException(
        OffersFailure.unknown,
        'unparseable offers payload',
      );
    }
    final rows = items.whereType<Map<String, dynamic>>().toList(growable: false);

    final hasAccepted =
        rows.any((r) => (r['status'] as String?) == 'accepted');

    final offers = rows
        .where((r) {
          final status = r['status'] as String?;
          return status == null || _liveStatuses.contains(status);
        })
        .map(_parseOffer)
        .whereType<Offer>()
        .toList(growable: false);

    final requestStatus = ServerRequestStatus.normalize(
      requestData is Map ? requestData['status'] : null,
    );
    final deadline = _serverDeadline(requestData) ?? _serverDeadline(data);
    final explicitlyOpen = _explicitOpen(requestData) ?? _explicitOpen(data);
    final statusIsOpen = ServerRequestStatus.isOpen(requestStatus);
    final open = !hasAccepted &&
        (requestStatus.isNotEmpty ? statusIsOpen : explicitlyOpen ?? false);
    return OffersSnapshot(
      offers: offers,
      windowExpiresAt: deadline,
      requestIsOpen: open,
      requestIsExpired: ServerRequestStatus.isExpired(requestStatus),
      requestTitle: _requestTitle(requestData),
    );
  }

  /// The request's item title off the already-fetched `/v1/requests/:id` row.
  /// No extra call — `fetchOffers` reads that row anyway. Blank/absent → null so
  /// the offer-review top bar renders one line instead of an empty subtitle.
  String? _requestTitle(dynamic requestData) {
    if (requestData is! Map) return null;
    final raw = requestData['title'];
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool? _explicitOpen(dynamic data) {
    if (data is! Map) return null;
    final raw = data['requestIsOpen'];
    return raw is bool ? raw : null;
  }

  DateTime? _serverDeadline(dynamic data) {
    if (data is! Map) return null;
    final raw = data['windowExpiresAt'] ??
        data['offerWindowExpiresAt'] ??
        data['broadcastExpiresAt'] ??
        data['expiresAt'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  Offer? _parseOffer(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final jeeberId = json['jeeberId'] as String?;
    if (id == null || jeeberId == null) return null;
    final fee = _parseFee(json);
    final eta = (json['etaMinutes'] as num?)?.toInt() ?? 0;
    final submitted = _parseDate(
      json['submittedAt'] as String? ?? json['createdAt'] as String?,
    );
    return Offer(
      id: id,
      jeeberId: jeeberId,
      jeeberName: json['jeeberName'] as String? ?? jeeberId,
      fee: fee,
      currency: _parseCurrency(json),
      etaMinutes: eta,
      vehicle: _parseVehicle(
        json['vehicleType'] as String? ?? json['vehicle'] as String?,
      ),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      submittedAt: submitted,
      avatarUrl: json['avatarUrl'] as String? ??
          json['jeeberAvatarUrl'] as String?,
      note: (json['note'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['note'] as String).trim(),
    );
  }

  double _parseFee(Map<String, dynamic> json) {
    final flat = json['fee'];
    if (flat is num) return flat.toDouble();
    final value = _moneyValue(json['amount']) ?? _moneyValue(json['price']);
    return value ?? 0.0;
  }

  String _parseCurrency(Map<String, dynamic> json) {
    final flat = json['currency'];
    if (flat is String && flat.isNotEmpty) return flat;
    final fromAmount = _moneyCurrency(json['amount']) ??
        _moneyCurrency(json['price']);
    return fromAmount ?? 'USD';
  }

  double? _moneyValue(dynamic money) {
    if (money is Map) {
      final v = money['value'];
      if (v is num) return v.toDouble();
    }
    return null;
  }

  String? _moneyCurrency(dynamic money) {
    if (money is Map) {
      final c = money['currency'];
      if (c is String && c.isNotEmpty) return c;
    }
    return null;
  }

  DateTime _parseDate(String? raw) {
    if (raw == null) return DateTime.now();
    return DateTime.tryParse(raw) ?? DateTime.now();
  }

  JeeberVehicle _parseVehicle(String? raw) {
    switch (raw) {
      case 'car':
        return JeeberVehicle.car;
      case 'motorcycle':
        return JeeberVehicle.motorcycle;
      case 'bicycle':
        return JeeberVehicle.bicycle;
      case 'scooter':
        return JeeberVehicle.scooter;
      case 'van':
        return JeeberVehicle.van;
      case 'walker':
        return JeeberVehicle.walker;
    }
    return JeeberVehicle.scooter;
  }

  static const Duration _rateLimitRetryFallback = Duration(seconds: 5);

  Never _rethrowDio(DioException e) {
    // `cancel` is our own local throttle, which AppFailure classifies as
    // unknown — keep it a rate limit.
    if (_isRateLimited(e)) {
      throw OffersRepositoryException(
        OffersFailure.rateLimited,
        'rate limited',
        _retryAfterOf(e),
        GatewayProblem.tryParse(e.response?.data),
      );
    }
    final AppFailure f = AppFailure.of(e);
    throw OffersRepositoryException(
      f is NetworkFailure || f is TimeoutFailure
          ? OffersFailure.network
          : OffersFailure.unknown,
      null,
      null,
      f.problem,
      null,
      f,
    );
  }

  static bool _isRateLimited(DioException e) =>
      e.response?.statusCode == 429 || e.type == DioExceptionType.cancel;

  Duration _retryAfterOf(DioException e) {
    final raw = e.response?.headers.value('retry-after')?.trim();
    final seconds = raw == null ? null : int.tryParse(raw);
    if (seconds != null && seconds > 0) return Duration(seconds: seconds);
    return _rateLimitRetryFallback;
  }

  Never _rethrowAccept(DioException e) {
    final int? status = e.response?.statusCode;
    final GatewayProblem? problem = GatewayProblem.tryParse(e.response?.data);
    if (status == 409) {
      final String? suffix = problem?.typeSuffix;
      throw OffersRepositoryException(
        _conflictFailure(suffix),
        null,
        null,
        problem,
        suffix,
      );
    }
    if (status == 410 || status == 404) {
      throw OffersRepositoryException(
        OffersFailure.requestNotOpen,
        null,
        null,
        problem,
        problem?.typeSuffix,
      );
    }
    _rethrowDio(e);
  }

  /// The gateway's own 409 `type` suffixes — never English prose, which used
  /// to send `request-expired` down the offerNotPending branch.
  static OffersFailure _conflictFailure(String? suffix) => switch (suffix) {
        'request-not-open' ||
        'request-not-acceptable' ||
        'already-accepted' =>
          OffersFailure.requestNotOpen,
        'request-expired' => OffersFailure.requestExpired,
        'too-many-active-deliveries' => OffersFailure.jeeberAtCapacity,
        'offer-jeeber-insufficient-balance' => OffersFailure.jeeberWalletShort,
        _ => OffersFailure.offerNotPending,
      };
}
