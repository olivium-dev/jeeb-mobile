import 'package:dio/dio.dart';

import '../domain/entities/availability_status.dart';
import '../domain/services/availability_gateway.dart';

/// Dio-backed [AvailabilityGateway].
///
/// Endpoints (useMockPrefixes=false, Mockoon :3055):
///   GET  /jeebers/me/availability  → current [AvailabilityStatus]
///   PATCH /jeebers/me/availability → body: { "online": true|false }
///                                  → updated [AvailabilityStatus]
///
/// Mock contract verified against Mockoon :3055 — returns 200 with
/// `{ "online": true|false, "activeDeliveries": N }`.
class DioAvailabilityGateway implements AvailabilityGateway {
  const DioAvailabilityGateway(this._dio);

  final Dio _dio;

  static const String _statusPath = '/jeebers/me/availability';
  static const String _togglePath = '/jeebers/me/availability';

  @override
  Future<AvailabilityStatus> fetch() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>(_statusPath);
      return _parse(response.data ?? {});
    } on DioException catch (e) {
      throw AvailabilityGatewayException(e.message ?? 'fetch failed');
    }
  }

  @override
  Future<AvailabilityStatus> toggle({required bool goOnline}) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        _togglePath,
        data: {'online': goOnline},
      );
      return _parse(response.data ?? {});
    } on DioException catch (e) {
      throw AvailabilityGatewayException(e.message ?? 'toggle failed');
    }
  }

  AvailabilityStatus _parse(Map<String, dynamic> json) {
    final isOnline = json['online'] as bool?;
    final stateRaw = json['state'] as String?;
    final state = _parseState(isOnline, stateRaw);
    final count = (json['activeDeliveries'] as num?)?.toInt() ??
        (json['activeDeliveryCount'] as num?)?.toInt() ?? 0;
    final lastRaw = json['lastActivityAt'] as String?;
    final lastActivity =
        lastRaw != null ? DateTime.tryParse(lastRaw) : null;
    return AvailabilityStatus(
      state: state,
      activeDeliveryCount: count,
      lastActivityAt: lastActivity,
    );
  }

  AvailabilityState _parseState(bool? isOnline, String? raw) {
    if (isOnline != null) {
      return isOnline ? AvailabilityState.online : AvailabilityState.offline;
    }
    switch (raw) {
      case 'online': return AvailabilityState.online;
      case 'auto_offline': return AvailabilityState.autoOffline;
      default: return AvailabilityState.offline;
    }
  }
}
