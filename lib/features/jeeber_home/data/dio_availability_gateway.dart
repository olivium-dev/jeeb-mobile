import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../../../core/network/mock_gateway_client.dart';
import '../../background_gps/domain/gps_sample.dart';
import '../domain/entities/availability_status.dart';
import '../domain/services/availability_gateway.dart';

/// Dio-backed [AvailabilityGateway].
///
/// Endpoints (W2 geolocation-service contract; gateway path → `MockGatewayClient`
/// rewrite `/v1/availability` → `/geolocation-service/v1/availability` → :4010):
///   GET  /v1/availability/{jeeberId}  → `{ userId, available, geo, lastPingAt }`
///                                       (404 when the jeeber was never seeded —
///                                       treated as "offline", not an error)
///   POST /v1/availability             → body `{ userId, available }` →
///                                       updated `{ userId, available, ... }`
///
/// The mock seeds `user-jeeber-002` with `available: true` (seed.ts
/// `seedAvailability`), so a freshly-launched jeeber session lands ONLINE and
/// the feed renders State 3 (JM-048). `available` maps to
/// [AvailabilityState.online]/[AvailabilityState.offline].
class DioAvailabilityGateway implements AvailabilityGateway {
  const DioAvailabilityGateway(
    this._dio, {
    this.jeeberId,
    this.tokenStore,
    this.locationFix,
  });

  final Dio _dio;
  final AuthTokenStore? tokenStore;

  /// One-shot device GPS fix used to stamp the jeeber's REAL coordinates onto
  /// the go-online toggle (E16 — replaces the hardcoded Damascus
  /// 33.5138/36.2765 fallback). Injected as a function seam so this data layer
  /// never imports `geolocator` directly (JEEB-BOUNDARIES §F9) and tests can
  /// script a fix. When null, or when the fix throws (permission denied /
  /// location services off), the jeeber still goes online but WITHOUT
  /// coordinates — never a fabricated fix.
  final Future<GpsSample> Function()? locationFix;

  /// The jeeber whose availability this gateway reads. Explicit override for
  /// tests / seams; when absent the REAL authenticated session id is resolved
  /// from [tokenStore] (see [_id]) — never a hardcoded fixture id.
  final String? jeeberId;

  /// Resolves the jeeber id: explicit override (tests / seams) → the REAL
  /// authenticated session id from [AuthTokenStore] — never a hardcoded
  /// fixture id (S0-OAD-03). In the mock lane the session seam / login flow
  /// seeds the store's userId, so the same lookup serves both lanes. FAIL
  /// CLOSED: with no session id, [_requiredId] throws
  /// [AvailabilityGatewayException] ('missing session user id') instead of
  /// silently reading/toggling another user's availability. The live lane
  /// (`/jeebers/me/availability`) never needs the id — the gateway scopes by
  /// the bearer.
  Future<String?> _id() async {
    final explicit = jeeberId;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final sessionUserId = await tokenStore?.userId;
    if (sessionUserId != null && sessionUserId.isNotEmpty) {
      return sessionUserId;
    }
    return null;
  }

  static const String _mockBasePath = '/v1/availability';
  static const String _livePath = '/jeebers/me/availability';

  @override
  Future<AvailabilityStatus> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(await _fetchPath());
      return _parse(response.data ?? {});
    } on DioException catch (e) {
      // 404 = no availability row yet (never toggled). Surface a benign
      // offline default rather than the load-error retry screen.
      if (e.response?.statusCode == 404) {
        return AvailabilityStatus.initial;
      }
      throw AvailabilityGatewayException(e.message ?? 'fetch failed');
    }
  }

  @override
  Future<AvailabilityStatus> toggle({required bool goOnline}) async {
    try {
      final response = MockGatewayClient.useMockPrefixes
          ? await _dio.post<Map<String, dynamic>>(
              _mockBasePath,
              data: {'userId': await _requiredId(), 'available': goOnline},
            )
          : await _dio.patch<Map<String, dynamic>>(
              _livePath,
              data: goOnline ? await _onlinePayload() : {'online': false},
            );
      return _parse(response.data ?? {});
    } on DioException catch (e) {
      throw AvailabilityGatewayException(e.message ?? 'toggle failed');
    }
  }

  /// Live-lane go-online body. Stamps the jeeber's REAL device coordinates
  /// when a fix is available; on any failure the jeeber still goes online but
  /// without coordinates (E16 removes the old hardcoded Damascus fallback
  /// rather than swapping in another fake fix).
  Future<Map<String, dynamic>> _onlinePayload() async {
    final payload = <String, dynamic>{
      'online': true,
      'vehicleType': 'car',
      'zone': 'default',
    };
    final fix = await _tryLocationFix();
    if (fix != null) {
      payload['latitude'] = fix.latitude;
      payload['longitude'] = fix.longitude;
    }
    return payload;
  }

  Future<GpsSample?> _tryLocationFix() async {
    final capture = locationFix;
    if (capture == null) return null;
    try {
      return await capture();
    } catch (_) {
      // Permission denied / location services off / plugin error: go online
      // without coordinates instead of substituting a fake city-centre fix.
      return null;
    }
  }

  Future<String> _fetchPath() async {
    if (!MockGatewayClient.useMockPrefixes) return _livePath;
    return '$_mockBasePath/${await _requiredId()}';
  }

  Future<String> _requiredId() async {
    final id = await _id();
    if (id == null || id.isEmpty) {
      throw const AvailabilityGatewayException('missing session user id');
    }
    return id;
  }

  AvailabilityStatus _parse(Map<String, dynamic> json) {
    // W2 shape uses `available` (bool); tolerate the legacy `online` key too.
    final isOnline = (json['available'] as bool?) ?? (json['online'] as bool?);
    final stateRaw = json['state'] as String?;
    final state = _parseState(isOnline, stateRaw);
    final count =
        (json['activeDeliveries'] as num?)?.toInt() ??
        (json['activeDeliveryCount'] as num?)?.toInt() ??
        0;
    // Intentionally do NOT carry the server's `lastPingAt` into
    // `lastActivityAt`: the seeded ping is months old, and the cubit's idle
    // ticker would compute elapsed > 8h on the first tick and flip the jeeber
    // to auto-offline (hiding the feed). A null `lastActivityAt` makes the
    // idle tick a no-op until a real in-app activity; the 8h auto-offline rule
    // then runs off genuine app-session activity, which is the intended UX.
    return AvailabilityStatus(state: state, activeDeliveryCount: count);
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
