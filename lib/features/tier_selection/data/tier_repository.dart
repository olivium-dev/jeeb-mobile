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

/// Dio-backed implementation. Talks to `GET /tiers` on jeeb-gateway (resolved
/// against the configured base URL — `.../v1` in prod, so the effective live
/// route is `GET /v1/tiers`) and decodes the JSON envelope.
///
/// LIVE contract (iter6, verified `curl http://localhost:10090/v1/tiers`
/// through the tunnel) — the production gateway mints **UUID** ids and labels
/// each tier with a `name` field; there is NO slug `id`, and `priceHint` is
/// human copy ("Within 30 minutes"), not the `$$$` bands the mock used:
/// ```json
/// { "items": [ { "id": "0be308ce-01b5-5cb9-a3e8-9adb60668d9c",
///   "name": "Flash", "slaHours": 1, "radiusKm": 3, "commissionRate": 0.25,
///   "priceHint": "Within 30 minutes" } ] }
/// ```
/// Legacy Mockoon :3055 contract (scenario `s05-order-prohibited-items`) used
/// SLUG ids instead:
/// ```json
/// { "items": [ { "id": "flash", "name": "Flash", "slaHours": 1,
///   "radiusKm": 3.0, "commissionRate": 0.15, "priceHint": "$$$" } ] }
/// ```
/// We classify each row to a [TierId] by **`name` first** (live shape), then
/// fall back to the slug `id` (mock shape), so both contracts parse to a
/// non-empty catalog. Before iter6 the parser keyed off the slug `id` ONLY,
/// so every UUID row dropped → empty catalog → compose "Continue" stayed
/// disabled (iter6 B1). The raw server `id` is preserved on `Tier.wireId` so
/// request-create can echo it verbatim (the UUID live) without fabricating a
/// slug — see B2 note on [Tier.wireId].
class DioTierRepository implements TierRepository {
  const DioTierRepository(this._dio);

  final Dio _dio;

  /// `GET /tiers` — resolves to `GET /v1/tiers` once joined to the prod base
  /// URL (`https://api.jeeb.app/v1`). Acceptance note (T-MOB-010 AC): returns
  /// 200 with an `items` array.
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
    final rawId = json['id'];
    final rawName = json['name'];
    // Classify to a TierId by `name` first (LIVE gateway shape: UUID id +
    // human name), then fall back to the slug `id` (legacy Mockoon shape).
    final id = _parseId(rawName) ?? _parseId(rawId);
    if (id == null) return null;
    final slaHours = (json['slaHours'] as num?)?.toInt();
    final slaMinutes = slaHours != null ? slaHours * 60 : null;
    final priceHint = json['priceHint'] as String? ?? '';
    final vehicle = _vehicleForTier(id);
    final prices = _pricesForHint(priceHint);
    // Preserve the EXACT server id (UUID live / slug on the mock) so
    // request-create echoes it verbatim — see [Tier.wireId] / iter6 B2.
    final wireId = rawId is String && rawId.isNotEmpty ? rawId : null;
    return Tier(
      id: id,
      wireId: wireId,
      priceLow: prices.$1,
      priceHigh: prices.$2,
      currency: 'USD',
      vehicleClass: vehicle,
      slaMinutes: slaMinutes,
      recommended: id == TierId.flash,
    );
  }

  /// Resolves a [TierId] from either the gateway's `name` label
  /// (`"Flash"`/`"On-the-way"` — live) or a slug `id` (`flash`/`on_the_way` —
  /// mock). Matching is case-insensitive and tolerant of `-`/`_`/space so the
  /// same routine handles both the live `name` and the legacy slug.
  TierId? _parseId(Object? raw) {
    if (raw is! String) return null;
    final key = raw.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    switch (key) {
      case 'flash':
        return TierId.flash;
      case 'express':
        return TierId.express;
      case 'standard':
        return TierId.standard;
      case 'ontheway':
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
