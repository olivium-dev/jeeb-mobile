import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../../../core/network/mock_gateway_client.dart';
import '../../background_gps/domain/gps_sample.dart';
import '../domain/entities/availability_status.dart';
import '../domain/services/availability_gateway.dart';

class DioAvailabilityGateway implements AvailabilityGateway {
  const DioAvailabilityGateway(
    this._dio, {
    this.jeeberId,
    this.tokenStore,
    this.locationFix,
  });

  final Dio _dio;
  final AuthTokenStore? tokenStore;

  final Future<GpsSample> Function()? locationFix;

  final String? jeeberId;

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
    final isOnline = (json['available'] as bool?) ?? (json['online'] as bool?);
    final stateRaw = json['state'] as String?;
    final state = _parseState(isOnline, stateRaw);
    final count =
        (json['activeDeliveries'] as num?)?.toInt() ??
        (json['activeDeliveryCount'] as num?)?.toInt() ??
        0;
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
