import 'package:dio/dio.dart';

import '../domain/tier.dart';

/// Failure surfaced when [TierRepository.fetchTiers] cannot return a list.
///
/// Kept narrow on purpose — the cubit only needs to distinguish "we couldn't
/// reach jeeb-gateway" from "we got a response but it was unusable". The view
/// renders a single retry banner for both.
enum TierLoadFailure { network, server }

class TierLoadException implements Exception {
  const TierLoadException(this.failure);
  final TierLoadFailure failure;
}

/// Side-channel between the cubit and jeeb-gateway's tier catalog. The MVP
/// cubit ships with [FakeTierRepository] so the screen renders end-to-end
/// without a backend; real wiring lands when the Dio client is generated from
/// the jeeb-gateway NSwag spec.
abstract class TierRepository {
  /// Returns the active tier catalog. Implementations must return tiers in
  /// the back-office's recommended display order.
  Future<List<Tier>> fetchTiers();
}

/// Dio-backed implementation. Talks to `GET /api/tiers` on jeeb-gateway and
/// decodes the JSON envelope. The endpoint is unauthenticated for catalog
/// reads — auth headers are layered in by the Dio interceptor.
class DioTierRepository implements TierRepository {
  const DioTierRepository(this._dio);

  final Dio _dio;

  static const String _path = '/api/tiers';

  @override
  Future<List<Tier>> fetchTiers() async {
    try {
      final response = await _dio.get<dynamic>(_path);
      final data = response.data;
      if (data is! List) {
        throw const TierLoadException(TierLoadFailure.server);
      }
      return data
          .whereType<Map<String, dynamic>>()
          .map(_parseTier)
          .whereType<Tier>()
          .toList(growable: false);
    } on DioException {
      throw const TierLoadException(TierLoadFailure.network);
    }
  }

  Tier? _parseTier(Map<String, dynamic> json) {
    final id = _parseId(json['id'] as Object?);
    if (id == null) return null;
    final vehicle = _parseVehicleClass(json['vehicleClass'] as Object?);
    final low = (json['priceLow'] as num?)?.toInt();
    final high = (json['priceHigh'] as num?)?.toInt();
    final currency = json['currency'] as String?;
    if (low == null || high == null || currency == null || vehicle == null) {
      return null;
    }
    return Tier(
      id: id,
      priceLow: low,
      priceHigh: high,
      currency: currency,
      vehicleClass: vehicle,
      slaMinutes: (json['slaMinutes'] as num?)?.toInt(),
      recommended: json['recommended'] == true,
    );
  }

  TierId? _parseId(Object? raw) {
    switch (raw) {
      case 'flash':
        return TierId.flash;
      case 'express':
        return TierId.express;
      case 'standard':
        return TierId.standard;
      case 'on_the_way':
      case 'onTheWay':
        return TierId.onTheWay;
      case 'eco':
        return TierId.eco;
    }
    return null;
  }

  TierVehicleClass? _parseVehicleClass(Object? raw) {
    switch (raw) {
      case 'bike_or_scooter':
        return TierVehicleClass.bikeOrScooter;
      case 'scooter_or_car':
        return TierVehicleClass.scooterOrCar;
      case 'car_or_van':
        return TierVehicleClass.carOrVan;
      case 'any':
        return TierVehicleClass.any;
    }
    return null;
  }
}

/// In-memory catalog used during the UI-only milestone and in widget tests.
///
/// The shape mirrors what jeeb-gateway returns: Express is the recommended
/// premium tier (1–2hr), Standard is the cheapest tier with a hard SLA
/// (2–4hr), and On-the-way is the opportunistic tier with no SLA.
class FakeTierRepository implements TierRepository {
  const FakeTierRepository({this.failWith});

  /// When non-null, [fetchTiers] throws the corresponding exception. Lets the
  /// cubit tests exercise the error branch without a Dio mock.
  final TierLoadFailure? failWith;

  static const List<Tier> defaultCatalog = [
    // Figma 56535:2392 display order: Flash → Express → Standard →
    // On-the-way → Eco. Flash is flagged recommended so it is the default
    // selected card (matching the Figma "Flash selected" frame).
    Tier(
      id: TierId.flash,
      priceLow: 120000,
      priceHigh: 160000,
      currency: 'LBP',
      vehicleClass: TierVehicleClass.scooterOrCar,
      slaMinutes: 60,
      recommended: true,
    ),
    Tier(
      id: TierId.express,
      priceLow: 80000,
      priceHigh: 120000,
      currency: 'LBP',
      vehicleClass: TierVehicleClass.scooterOrCar,
      slaMinutes: 180,
    ),
    Tier(
      id: TierId.standard,
      priceLow: 45000,
      priceHigh: 70000,
      currency: 'LBP',
      vehicleClass: TierVehicleClass.bikeOrScooter,
      slaMinutes: 240,
    ),
    Tier(
      id: TierId.onTheWay,
      priceLow: 30000,
      priceHigh: 55000,
      currency: 'LBP',
      vehicleClass: TierVehicleClass.any,
      slaMinutes: null,
    ),
    Tier(
      id: TierId.eco,
      priceLow: 20000,
      priceHigh: 40000,
      currency: 'LBP',
      vehicleClass: TierVehicleClass.any,
      slaMinutes: 2880,
    ),
  ];

  @override
  Future<List<Tier>> fetchTiers() async {
    final failure = failWith;
    if (failure != null) {
      throw TierLoadException(failure);
    }
    return defaultCatalog;
  }
}
