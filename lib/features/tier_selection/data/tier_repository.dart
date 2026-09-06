import 'package:dio/dio.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../domain/tier.dart';

enum TierLoadFailure { network, server }

class TierLoadException implements Exception {
  const TierLoadException(this.failure);
  final TierLoadFailure failure;
}

abstract class TierRepository {
  Future<List<Tier>> fetchTiers();
}

class DioTierRepository implements TierRepository {
  const DioTierRepository(this._dio);

  final Dio _dio;

  static const String _path = '/tiers';
  static final RegExp _labelSeparators = RegExp(r'[-_\s]+');

  @override
  Future<List<Tier>> fetchTiers() async {
    try {
      final response = await _dio.get<dynamic>(_path);
      return _parseResponse(response.data);
    } on DioException catch (e) {
      throw AppFailure.of(e);
    }
  }

  List<Tier> _parseResponse(dynamic data) {
    final List<dynamic> items;
    if (data is Map<String, dynamic> && data['items'] is List) {
      items = data['items'] as List<dynamic>;
    } else if (data is List) {
      items = data;
    } else {
      throw const UnknownFailure(parse: true);
    }
    final tiers = items
        .whereType<Map<String, dynamic>>()
        .map(_parseTier)
        .whereType<Tier>()
        .toList(growable: false);
    Diag.event('tier_catalog_parsed', <String, Object?>{
      'items': items.length,
      'parsed': tiers.length,
    });
    // A catalogue we cannot read is not an empty catalogue.
    if (tiers.isEmpty && items.isNotEmpty) {
      throw const UnknownFailure(parse: true);
    }
    return tiers;
  }

  Tier? _parseTier(Map<String, dynamic> json) {
    final id = _resolveTierId(json);
    if (id == null) return null;
    final slaHours = (json['slaHours'] as num?)?.toInt();
    final slaMinutes = slaHours != null ? slaHours * 60 : null;
    final priceHint = json['priceHint'] as String? ?? '';
    final prices = _pricesForHint(priceHint);
    return Tier(
      id: id,
      serverId: json['id'] as String?,
      priceLow: prices.$1,
      priceHigh: prices.$2,
      currency: 'USD',
      vehicleClass: _vehicleForTier(id),
      slaMinutes: slaMinutes,
      // R9 badges Standard, not the most expensive tier (doc-13 P0-4).
      recommended: id == TierId.standard,
    );
  }

  TierId? _resolveTierId(Map<String, dynamic> json) {
    return _tierIdFromLabel(json['name'] as Object?) ??
        _tierIdFromLabel(json['id'] as Object?);
  }

  TierId? _tierIdFromLabel(Object? raw) {
    if (raw is! String) return null;
    final normalized = raw.trim().toLowerCase().replaceAll(
      _labelSeparators,
      '_',
    );
    switch (normalized) {
      case 'flash':
      case 'urgent':
        return TierId.flash;
      case 'express':
      case 'same_day':
      case 'sameday':
        return TierId.express;
      case 'standard':
      case 'scheduled':
        return TierId.standard;
      case 'on_the_way':
      case 'ontheway':
        return TierId.onTheWay;
      case 'eco':
        return TierId.eco;
    }
    Diag.event('tier_name_unresolved', <String, Object?>{'raw': raw});
    return null;
  }

  TierVehicleClass _vehicleForTier(TierId id) {
    switch (id) {
      case TierId.flash:
        return TierVehicleClass.scooterOrCar;
      case TierId.express:
        return TierVehicleClass.scooterOrCar;
      case TierId.standard:
        return TierVehicleClass.bikeOrScooter;
      case TierId.onTheWay:
        return TierVehicleClass.any;
      case TierId.eco:
        return TierVehicleClass.any;
    }
  }

  (int, int) _pricesForHint(String hint) {
    switch (hint) {
      case '\$\$\$':
        return (120000, 160000);
      case '\$\$':
        return (80000, 120000);
      case '\$':
        return (45000, 70000);
    }
    return (30000, 55000);
  }
}

class FakeTierRepository implements TierRepository {
  const FakeTierRepository({this.failWith});

  final TierLoadFailure? failWith;

  static const List<Tier> defaultCatalog = [
    Tier(
      id: TierId.flash,
      priceLow: 120000,
      priceHigh: 160000,
      currency: 'LBP',
      vehicleClass: TierVehicleClass.scooterOrCar,
      slaMinutes: 60,
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
      // R9 badges Standard, not the most expensive tier (doc-13 P0-4).
      recommended: true,
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
