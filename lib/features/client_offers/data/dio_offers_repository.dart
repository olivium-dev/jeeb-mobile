import 'package:dio/dio.dart';

import '../domain/jeeber_vehicle.dart';
import '../domain/offer.dart';
import '../domain/offers_repository.dart';

/// Dio-backed [OffersRepository].
///
/// Endpoints verified against Mockoon :3055 (T-MOB-015 AC):
///   GET  /v1/requests/:requestId/offers  → JSON array of offer objects
///   POST /v1/offers/:offerId/accept      → 200 on success, 409 race-conflict
///
/// Since `useMockPrefixes=false` the paths pass through unchanged to :3055.
/// The offer-window deadline is derived from the first offer's `createdAt`
/// + 5 min because the mock list endpoint omits `windowExpiresAt`.
class DioOffersRepository implements OffersRepository {
  const DioOffersRepository(this._dio);

  final Dio _dio;

  static const Duration _defaultWindow = Duration(minutes: 5);

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/v1/requests/$requestId/offers',
      );
      return _parseSnapshot(response.data);
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
      final response = await _dio.post<dynamic>('/v1/offers/$offerId/accept');
      return _parseAcceptResult(response.data);
    } on DioException catch (e) {
      _rethrowAccept(e);
    }
  }

  /// Pull the server-created delivery id out of the accept response.
  ///
  /// The offer-accept saga returns an `OfferAcceptResultDto`. The golden
  /// response surfaces the created delivery as `deliveryId`; we also accept
  /// the snake_case `delivery_id` so we stay compatible regardless of the
  /// gateway's serialization casing. Anything else (legacy body with no
  /// delivery field, non-map payload, empty string) maps to
  /// [OfferAcceptResult.empty] so the caller never crashes and the
  /// "Track order" CTA simply stays hidden.
  OfferAcceptResult _parseAcceptResult(dynamic data) {
    if (data is! Map) return OfferAcceptResult.empty;
    final raw = data['deliveryId'] ?? data['delivery_id'];
    final deliveryId = raw is String && raw.trim().isNotEmpty ? raw : null;
    return OfferAcceptResult(deliveryId: deliveryId);
  }

  OffersSnapshot _parseSnapshot(dynamic data) {
    final List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic>) {
      items =
          (data['offers'] as List?) ??
          (data['items'] as List?) ??
          const <dynamic>[];
    } else {
      throw const OffersRepositoryException(OffersFailure.unknown);
    }
    final offers = items
        .whereType<Map<String, dynamic>>()
        .map(_parseOffer)
        .whereType<Offer>()
        .toList(growable: false);
    final deadline = _deriveDeadline(data, offers);
    final open = data is Map<String, dynamic>
        ? (data['requestIsOpen'] as bool?) ?? true
        : true;
    return OffersSnapshot(
      offers: offers,
      windowExpiresAt: deadline,
      requestIsOpen: open,
    );
  }

  DateTime _deriveDeadline(dynamic data, List<Offer> offers) {
    if (data is Map<String, dynamic>) {
      final raw = data['windowExpiresAt'] as String?;
      if (raw != null) {
        return DateTime.tryParse(raw) ?? _fallbackDeadline(offers);
      }
    }
    return _fallbackDeadline(offers);
  }

  DateTime _fallbackDeadline(List<Offer> offers) {
    if (offers.isEmpty) return DateTime.now().add(_defaultWindow);
    return offers.first.submittedAt.add(_defaultWindow);
  }

  Offer? _parseOffer(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final jeeberId = json['jeeberId'] as String?;
    if (id == null || jeeberId == null) return null;
    final fee = (json['fee'] as num?)?.toDouble() ?? 0.0;
    final eta = (json['etaMinutes'] as num?)?.toInt() ?? 0;
    final submitted = _parseDate(
      json['createdAt'] as String? ?? json['submittedAt'] as String?,
    );
    return Offer(
      id: id,
      jeeberId: jeeberId,
      jeeberName: json['jeeberName'] as String? ?? jeeberId,
      fee: fee,
      currency: json['currency'] as String? ?? 'USD',
      etaMinutes: eta,
      vehicle: _parseVehicle(
        json['vehicleType'] as String? ?? json['vehicle'] as String?,
      ),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      submittedAt: submitted,
      avatarUrl: json['avatarUrl'] as String?,
    );
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

  Never _rethrowDio(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw const OffersRepositoryException(OffersFailure.network);
    }
    throw const OffersRepositoryException(OffersFailure.unknown);
  }

  Never _rethrowAccept(DioException e) {
    final status = e.response?.statusCode;
    if (status == 409) {
      throw const OffersRepositoryException(OffersFailure.offerNotPending);
    }
    if (status == 410) {
      throw const OffersRepositoryException(OffersFailure.requestNotOpen);
    }
    _rethrowDio(e);
  }
}
