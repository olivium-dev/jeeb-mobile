import 'package:dio/dio.dart';

import '../../../core/dev_seam/session_seam_bootstrap.dart';
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
  const DioAvailabilityGateway(this._dio, {this.jeeberId});

  final Dio _dio;

  /// The jeeber whose availability this gateway reads. Defaults to the seeded
  /// W2 jeeber session (`user-jeeber-002`) since the mock filters by id, not
  /// the bearer (the global authStub otherwise pins to a client).
  final String? jeeberId;

  String get _id => jeeberId ?? SessionSeamBootstrap.jeeberUserId;

  static const String _basePath = '/v1/availability';

  @override
  Future<AvailabilityStatus> fetch() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('$_basePath/$_id');
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
      final response = await _dio.post<Map<String, dynamic>>(
        _basePath,
        data: {'userId': _id, 'available': goOnline},
      );
      return _parse(response.data ?? {});
    } on DioException catch (e) {
      throw AvailabilityGatewayException(e.message ?? 'toggle failed');
    }
  }

  AvailabilityStatus _parse(Map<String, dynamic> json) {
    // W2 shape uses `available` (bool); tolerate the legacy `online` key too.
    final isOnline = (json['available'] as bool?) ?? (json['online'] as bool?);
    final stateRaw = json['state'] as String?;
    final state = _parseState(isOnline, stateRaw);
    final count = (json['activeDeliveries'] as num?)?.toInt() ??
        (json['activeDeliveryCount'] as num?)?.toInt() ??
        0;
    // Intentionally do NOT carry the server's `lastPingAt` into
    // `lastActivityAt`: the seeded ping is months old, and the cubit's idle
    // ticker would compute elapsed > 8h on the first tick and flip the jeeber
    // to auto-offline (hiding the feed). A null `lastActivityAt` makes the
    // idle tick a no-op until a real in-app activity; the 8h auto-offline rule
    // then runs off genuine app-session activity, which is the intended UX.
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
