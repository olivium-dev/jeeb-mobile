import 'package:dio/dio.dart';

import '../domain/order_broadcast_service.dart';

class DioOrderBroadcastService implements OrderBroadcastService {
  const DioOrderBroadcastService(this._dio);

  final Dio _dio;

  @override
  Future<OrderBroadcastResult> broadcast({required String requestId}) async {
    if (requestId.trim().isEmpty) {
      throw const OrderBroadcastException(OrderBroadcastFailure.badRequest);
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/matching/run',
        data: <String, Object?>{'requestId': requestId},
      );
      return _MatchingRunResponse.fromJson(
        response.data,
        expectedRequestId: requestId,
      ).toDomain();
    } on DioException catch (e) {
      throw OrderBroadcastException(_map(e));
    } catch (_) {
      throw const OrderBroadcastException(OrderBroadcastFailure.unknown);
    }
  }

  OrderBroadcastFailure _map(DioException e) {
    final code = e.response?.statusCode ?? 0;
    if (code == 400) return OrderBroadcastFailure.badRequest;
    return (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout)
        ? OrderBroadcastFailure.network
        : OrderBroadcastFailure.unknown;
  }
}

final class _MatchingRunResponse {
  const _MatchingRunResponse({
    required this.requestId,
    required this.tierId,
    required this.radiusKm,
    required this.notifiedCount,
    required this.candidateCount,
    required this.candidates,
    required this.elapsedMs,
  });

  factory _MatchingRunResponse.fromJson(
    Map<String, dynamic>? json, {
    required String expectedRequestId,
  }) {
    if (json == null) throw const FormatException('missing matching response');
    final requestId = _requiredString(json, 'requestId');
    if (requestId != expectedRequestId) {
      throw const FormatException('matching response requestId mismatch');
    }
    return _MatchingRunResponse(
      requestId: requestId,
      tierId: _requiredString(json, 'tierId'),
      radiusKm: _requiredDouble(json, 'radiusKm', minimum: 0),
      notifiedCount: _requiredInt(json, 'notifiedCount'),
      candidateCount: _requiredInt(json, 'candidateCount'),
      candidates: _candidatesFrom(json['candidates']),
      elapsedMs: _requiredInt(json, 'elapsedMs'),
    );
  }

  final String requestId;
  final String tierId;
  final double radiusKm;
  final int notifiedCount;
  final int candidateCount;
  final List<OrderMatchingCandidate> candidates;
  final int elapsedMs;

  OrderBroadcastResult toDomain() => OrderBroadcastResult(
    requestId: requestId,
    tierId: tierId,
    radiusKm: radiusKm,
    notifiedCount: notifiedCount,
    candidateCount: candidateCount,
    candidates: candidates,
    elapsedMs: elapsedMs,
  );
}

List<OrderMatchingCandidate> _candidatesFrom(Object? value) {
  if (value is! List<dynamic>) {
    throw const FormatException('candidates must be a list');
  }
  return List.unmodifiable(value.map(_candidateFrom));
}

OrderMatchingCandidate _candidateFrom(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('candidate must be an object');
  }
  return OrderMatchingCandidate(
    userId: _requiredString(value, 'userId'),
    vehicleType: _requiredString(value, 'vehicleType'),
    distanceKm: _requiredDouble(value, 'distanceKm', minimum: 0),
    rating: _requiredDouble(value, 'rating', minimum: 0, maximum: 5),
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$key must be a non-empty string');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int && value >= 0) return value;
  throw FormatException('$key must be a non-negative integer');
}

double _requiredDouble(
  Map<String, dynamic> json,
  String key, {
  double? minimum,
  double? maximum,
}) {
  final value = json[key];
  if (value is! num || !value.isFinite) {
    throw FormatException('$key must be a finite number');
  }
  final parsed = value.toDouble();
  if (minimum != null && parsed < minimum) {
    throw FormatException('$key must be at least $minimum');
  }
  if (maximum != null && parsed > maximum) {
    throw FormatException('$key must be at most $maximum');
  }
  return parsed;
}
