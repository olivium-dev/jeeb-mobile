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

/// Dio-backed implementation. Talks to `GET /tiers` on jeeb-gateway and decodes
/// the JSON envelope.
///
/// Two server shapes are supported, identity resolved by display `name`
/// (case-insensitive) and falling back to the `id` slug:
///
/// LIVE gateway (192.168.2.39:10090, authoritative) — `id` is a UUID, the
/// human label lives in `name`, and `priceHint` is a free-text band:
/// ```json
/// { "items": [ { "id": "0be308ce-…", "name": "Flash", "slaHours": 1,
///   "radiusKm": 3, "commissionRate": 0.25, "priceHint": "Within 30 minutes" } ] }
/// ```
///
/// Mockoon mock (:3055, legacy) — `id` is a slug and `priceHint` is a `$` band:
/// ```json
/// { "items": [ { "id": "flash", "name": "Flash", "slaHours": 1,
///   "radiusKm": 3.0, "commissionRate": 0.15, "priceHint": "$$$" } ] }
/// ```
///
/// Resolving by `name` (with a slug fallback) keeps BOTH shapes parsing: the
/// previous slug-only `switch` dropped every live row (UUID id ∉ slug set),
/// producing an empty tier list and a dead "Choose your request" screen.
/// The gateway UUID is preserved on [Tier.serverId] for the create RPC.
class DioTierRepository implements TierRepository {
  const DioTierRepository(this._dio);

  final Dio _dio;

  /// Endpoint verified against Mockoon :3055 — `GET /tiers` (no v1 prefix).
  /// Acceptance-test note (T-MOB-010 AC): mock returns 200 with items array.
  static const String _path = '/tiers';

  @override
  Future<List<Tier>> fetchTiers() async {
    try {
      final response = await _dio.get<dynamic>(_path);
      return _parseResponse(response.data);
    } on DioException {
      throw const TierLoadException(TierLoadFailure.network);
    }
  }

  List<Tier> _parseResponse(dynamic data) {
    final List<dynamic> items;
    if (data is Map<String, dynamic> && data['items'] is List) {
      items = data['items'] as List<dynamic>;
    } else if (data is List) {
      items = data;
    } else {
      throw const TierLoadException(TierLoadFailure.server);
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(_parseTier)
        .whereType<Tier>()
        .toList(growable: false);
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
      recommended: id == TierId.flash,
    );
  }

  /// Resolves the stable [TierId] from a gateway item. Tries the display
  /// `name` first (live shape: `name: "Flash"`, `id: <uuid>`), then falls back
  /// to the `id` slug (mock shape: `id: "flash"`). Returns null only when
  /// neither maps to a known tier, so unrecognised rows are skipped rather than
  /// poisoning the list.
  TierId? _resolveTierId(Map<String, dynamic> json) {
    return _tierIdFromLabel(json['name'] as Object?) ??
        _tierIdFromLabel(json['id'] as Object?);
  }

  /// Case-insensitive label → [TierId]. Accepts both the human label ("Flash",
  /// "On-the-way") and the slug ("flash", "on_the_way").
  TierId? _tierIdFromLabel(Object? raw) {
    if (raw is! String) return null;
    switch (raw.trim().toLowerCase()) {
      case 'flash':
        return TierId.flash;
      case 'express':
        return TierId.express;
      case 'standard':
        return TierId.standard;
      case 'on_the_way':
      case 'ontheway':
      case 'on-the-way':
      case 'on the way':
        return TierId.onTheWay;
      case 'eco':
        return TierId.eco;
    }
    return null;
  }

  /// Maps tier id to the vehicle class shown on the card.
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

  /// Derives indicative price band from the gateway's priceHint string.
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
