import 'package:dio/dio.dart';

import '../domain/entities/availability_status.dart';
import '../domain/online_location_fix.dart';
import '../domain/services/availability_gateway.dart';

/// Dio-backed [AvailabilityGateway].
///
/// FROZEN (S0-SEAM-02 / OAD-01, grounded in
/// `jeeb-gateway/src/JeebGateway/Controllers/AvailabilityController.cs`):
/// the canonical gateway route is `[Route("jeebers/me/availability")]`,
/// capability-gated (`AvailabilityToggle`, jeeber-typed) and resolving the
/// caller identity SERVER-SIDE from the bearer (`UserIdentity.TryGetUserId`).
/// The path is `me` — there is NO `userId` in the path, so the old
/// `user-jeeber-002` fallback disappears entirely; identity comes from the
/// live session bearer the shared Dio attaches. Edge serves it under `/v1`,
/// so the app path is `/v1/jeebers/me/availability` (exactly one `/v1`).
///
///   GET   /v1/jeebers/me/availability  → `AvailabilityResponse` (200). A
///         never-online jeeber yields an offline default (200, never 404/500).
///   PATCH /v1/jeebers/me/availability  → GO ONLINE body
///         `{ online:true, vehicleType, zone, latitude, longitude }`
///         (vehicleType + non-empty zone REQUIRED when online:true, else 400);
///         GO OFFLINE body `{ online:false }`.
///
/// RESPONSE (`AvailabilityResponse`, 200, both verbs): the canonical state key
/// is `online` (NOT the mock's legacy `available`). We read `online` first and
/// tolerate `available` so the mock lane keeps parsing.
class DioAvailabilityGateway implements AvailabilityGateway {
  const DioAvailabilityGateway(
    this._dio, {
    this.vehicleType = _defaultVehicleType,
    this.zone = _defaultZone,
    this.latitude,
    this.longitude,
    OnlineLocationFix? locationFix,
  }) : _locationFix = locationFix;

  final Dio _dio;

  /// Resolves a real device GPS fix to attach to the GO ONLINE body so the
  /// jeeber row keeps a non-null `last_lat/last_lng` and survives delivery's
  /// `ListOnline` filter (SPRINT-003). Null in tests / mock lanes that pass an
  /// explicit [latitude]/[longitude] (or none); a fix that resolves to null
  /// falls back to the injected [latitude]/[longitude].
  final OnlineLocationFix? _locationFix;

  /// Vehicle type sent on GO ONLINE. Required by the gateway when `online:true`
  /// (one of car|motorbike|bicycle|scooter|walk). Injectable so a future
  /// vehicle picker can supply the jeeber's real selection; defaults to `car`.
  final String vehicleType;

  /// Operating zone sent on GO ONLINE. Required-non-empty by the gateway when
  /// `online:true` (else 400). Injectable so the zone selector can supply a
  /// real zone; defaults to a non-empty placeholder so the toggle never 400s.
  final String zone;

  /// Optional last-known coordinates sent on GO ONLINE. The contract allows
  /// `null`, so both default to null until the location layer wires them in.
  final double? latitude;
  final double? longitude;

  static const String _defaultVehicleType = 'car';
  static const String _defaultZone = 'default';

  /// The me-scoped availability route. NO `userId` in the path — the gateway
  /// resolves identity from the bearer. Exactly one `/v1` (the base is
  /// origin-only per ARCH-01/INFRA-01).
  static const String _path = '/v1/jeebers/me/availability';

  @override
  Future<AvailabilityStatus> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_path);
      return _parse(response.data ?? {});
    } on DioException catch (e) {
      // A never-online jeeber yields an offline default (200) per the contract,
      // but tolerate a 404 too (older/mock backends) as a benign offline default
      // rather than the load-error retry screen.
      if (e.response?.statusCode == 404) {
        return AvailabilityStatus.initial;
      }
      throw AvailabilityGatewayException(e.message ?? 'fetch failed');
    }
  }

  @override
  Future<AvailabilityStatus> toggle({required bool goOnline}) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        _path,
        data: goOnline ? await _goOnlineBody() : const {'online': false},
      );
      return _parse(response.data ?? {});
    } on DioException catch (e) {
      throw AvailabilityGatewayException(e.message ?? 'toggle failed');
    }
  }

  /// GO ONLINE body. `online` + `vehicleType` are required and `zone` must be
  /// non-empty (gateway 400s otherwise). We acquire a REAL device GPS fix first
  /// so `latitude`/`longitude` are populated — delivery's `ListOnline` drops
  /// rows with null coordinates, so going online without them makes the jeeber
  /// invisible to matching (SPRINT-003). A failed/absent fix degrades to the
  /// injected [latitude]/[longitude] (which may be null) rather than blocking
  /// the toggle.
  Future<Map<String, dynamic>> _goOnlineBody() async {
    final fix = await _resolveFix();
    return {
      'online': true,
      'vehicleType': vehicleType,
      'zone': zone,
      'latitude': fix?.latitude ?? latitude,
      'longitude': fix?.longitude ?? longitude,
    };
  }

  /// Resolves a one-shot device fix, swallowing any failure (the toggle must
  /// never fail because location could not be read).
  Future<OnlineCoordinates?> _resolveFix() async {
    final provider = _locationFix;
    if (provider == null) return null;
    try {
      return await provider.resolve();
    } catch (_) {
      return null;
    }
  }

  AvailabilityStatus _parse(Map<String, dynamic> json) {
    // Canonical `AvailabilityResponse` uses `online` (bool); tolerate the mock's
    // legacy `available` key so the mock lane keeps parsing.
    final isOnline = (json['online'] as bool?) ?? (json['available'] as bool?);
    final stateRaw = json['state'] as String?;
    final state = _parseState(isOnline, stateRaw);
    final count = (json['activeDeliveries'] as num?)?.toInt() ??
        (json['activeDeliveryCount'] as num?)?.toInt() ??
        0;
    // Intentionally do NOT carry the server's `lastSeenAt`/`lastPingAt` into
    // `lastActivityAt`: a stale ping would make the cubit's idle ticker compute
    // elapsed > 8h on the first tick and flip the jeeber to auto-offline (hiding
    // the feed). A null `lastActivityAt` makes the idle tick a no-op until a
    // real in-app activity; the 8h auto-offline rule then runs off genuine
    // app-session activity, which is the intended UX.
    return AvailabilityStatus(
      state: state,
      activeDeliveryCount: count,
    );
  }

  AvailabilityState _parseState(bool? isOnline, String? raw) {
    if (isOnline != null) {
      return isOnline ? AvailabilityState.online : AvailabilityState.offline;
    }
    switch (raw) {
      case 'online':
        return AvailabilityState.online;
      case 'auto_offline':
        return AvailabilityState.autoOffline;
      default:
        return AvailabilityState.offline;
    }
  }
}
