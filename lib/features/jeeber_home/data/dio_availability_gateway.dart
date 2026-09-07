import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
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
    this.lastKnownFix,
  });

  final Dio _dio;
  final AuthTokenStore? tokenStore;

  final Future<GpsSample> Function()? locationFix;

  final Future<GpsSample?> Function()? lastKnownFix;

  final String? jeeberId;

  static const Duration _retryBackoff = Duration(milliseconds: 500);

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
      // JHOME-05: 404 means un-onboarded, NOT offline.
      if (e.response?.statusCode == 404) {
        throw const AvailabilityGatewayException.notRegistered();
      }
      throw AvailabilityGatewayException.from(AppFailure.of(e));
    }
  }

  @override
  Future<AvailabilityToggleResult> toggle({required bool goOnline}) async {
    try {
      if (MockGatewayClient.useMockPrefixes) {
        final response = await _dio.post<Map<String, dynamic>>(
          _mockBasePath,
          data: {'userId': await _requiredId(), 'available': goOnline},
        );
        return AvailabilityToggleResult(status: _parse(response.data ?? {}));
      }
      if (!goOnline) {
        final response = await _dio.patch<Map<String, dynamic>>(
          _livePath,
          data: {'online': false},
        );
        return AvailabilityToggleResult(status: _parse(response.data ?? {}));
      }
      final (fix, outcome) = await _captureFix();
      final response = await _dio.patch<Map<String, dynamic>>(
        _livePath,
        data: _onlinePayload(fix),
      );
      return AvailabilityToggleResult(
        status: _parse(response.data ?? {}),
        location: outcome,
      );
    } on DioException catch (e) {
      throw AvailabilityGatewayException.from(AppFailure.of(e));
    }
  }

  @override
  Future<GoOnlineLocationOutcome> refreshLocation() async {
    if (MockGatewayClient.useMockPrefixes) {
      return GoOnlineLocationOutcome.notApplicable;
    }
    final (fix, outcome) = await _captureFix(attempts: 1);
    if (fix == null) return outcome;
    try {
      await _dio.patch<Map<String, dynamic>>(
        _livePath,
        data: _onlinePayload(fix),
      );
      return GoOnlineLocationOutcome.attached;
    } on DioException catch (e) {
      throw AvailabilityGatewayException.from(AppFailure.of(e));
    }
  }

  Map<String, dynamic> _onlinePayload(GpsSample? fix) {
    final payload = <String, dynamic>{
      'online': true,
      'vehicleType': 'car',
      'zone': 'default',
    };
    if (fix != null) {
      payload['latitude'] = fix.latitude;
      payload['longitude'] = fix.longitude;
    }
    return payload;
  }

  /// Retries a transient fix failure, then falls back to the cached OS fix;
  /// a denied permission short-circuits because retrying cannot help.
  Future<(GpsSample?, GoOnlineLocationOutcome)> _captureFix({
    int attempts = 2,
  }) async {
    final capture = locationFix;
    if (capture == null) return (null, GoOnlineLocationOutcome.notApplicable);
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        return (await capture(), GoOnlineLocationOutcome.attached);
      } on LocationCaptureDeniedException {
        return (null, GoOnlineLocationOutcome.permissionDenied);
      } catch (_) {
        // Typed outcome, not a swallow: the loop falls through to fixFailed.
        if (attempt < attempts - 1) await Future<void>.delayed(_retryBackoff);
      }
    }
    final cached = lastKnownFix;
    if (cached != null) {
      try {
        final sample = await cached();
        if (sample != null) {
          return (sample, GoOnlineLocationOutcome.attached);
        }
      } catch (_) {
        // Typed outcome, not a swallow: falls through to fixFailed.
      }
    }
    return (null, GoOnlineLocationOutcome.fixFailed);
  }

  Future<String> _fetchPath() async {
    if (!MockGatewayClient.useMockPrefixes) return _livePath;
    return '$_mockBasePath/${await _requiredId()}';
  }

  Future<String> _requiredId() async {
    final id = await _id();
    if (id == null || id.isEmpty) {
      throw const AvailabilityGatewayException.from(UnauthorizedFailure());
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
