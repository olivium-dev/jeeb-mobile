import 'package:dio/dio.dart';

import '../../../core/dev_seam/session_seam_bootstrap.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/network/mock_gateway_client.dart';
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
  const DioAvailabilityGateway(this._dio, {this.jeeberId, this.tokenStore});

  final Dio _dio;
  final AuthTokenStore? tokenStore;

  /// The jeeber whose availability this gateway reads. Defaults to the seeded
  /// W2 jeeber session (`user-jeeber-002`) since the mock filters by id, not
  /// the bearer (the global authStub otherwise pins to a client).
  final String? jeeberId;

  Future<String?> _id() async {
    final explicit = jeeberId;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final sessionUserId = await tokenStore?.userId;
    if (sessionUserId != null && sessionUserId.isNotEmpty) {
      return sessionUserId;
    }
    return MockGatewayClient.useMockPrefixes
        ? SessionSeamBootstrap.jeeberUserId
        : null;
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
              data: goOnline
                  ? {
                      'online': true,
                      'vehicleType': 'car',
                      'zone': 'default',
                      'latitude': 33.5138,
                      'longitude': 36.2765,
                    }
                  : {'online': false},
            );
      return _parse(response.data ?? {});
    } on DioException catch (e) {
      throw AvailabilityGatewayException(e.message ?? 'toggle failed');
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
