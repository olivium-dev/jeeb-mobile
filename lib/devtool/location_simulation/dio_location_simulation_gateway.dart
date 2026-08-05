import 'package:dio/dio.dart';

import '../gateway/dev_gateway_client.dart';
import 'location_simulation_gateway.dart';
import 'location_simulation_models.dart';

class DioLocationSimulationGateway implements LocationSimulationGateway {
  const DioLocationSimulationGateway({
    required Dio dio,
    required DevGatewayClient devGatewayClient,
  }) : _dio = dio,
       _devGatewayClient = devGatewayClient;

  final Dio _dio;
  final DevGatewayClient _devGatewayClient;

  @override
  Future<LocationSimulationSession> openSession({
    required String jeeberUserId,
    required List<String> roles,
  }) async {
    final normalizedUserId = jeeberUserId.trim();
    if (normalizedUserId.isEmpty) {
      throw const LocationSimulationFailure(
        kind: LocationSimulationFailureKind.validation,
        operation: 'open simulation session',
        message: 'A Jeeber user id is required.',
      );
    }
    final normalizedRoles = roles
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .toList(growable: false);
    final canDrive = normalizedRoles.any((role) {
      final normalized = role.toLowerCase();
      return normalized == 'driver' || normalized == 'jeeber';
    });
    if (!canDrive) {
      throw const LocationSimulationFailure(
        kind: LocationSimulationFailureKind.validation,
        operation: 'open simulation session',
        message: 'The selected roster user has no `driver` role in `roles[]`.',
      );
    }
    try {
      final token = await _devGatewayClient.mintTokenForUser(
        normalizedUserId,
        roles: normalizedRoles,
      );
      return _DioLocationSimulationSession(
        dio: _dio,
        devGatewayClient: _devGatewayClient,
        jeeberUserId: normalizedUserId,
        bearerToken: token,
      );
    } on DevGatewayException catch (error) {
      throw LocationSimulationFailure(
        kind: _kindForStatus(error.statusCode),
        operation: 'mint Jeeber act-as token',
        message: error.message,
        statusCode: error.statusCode,
      );
    }
  }
}

class _DioLocationSimulationSession implements LocationSimulationSession {
  _DioLocationSimulationSession({
    required Dio dio,
    required DevGatewayClient devGatewayClient,
    required String jeeberUserId,
    required String bearerToken,
  }) : _dio = dio,
       _devGatewayClient = devGatewayClient,
       _jeeberUserId = jeeberUserId,
       _bearerToken = bearerToken;

  final Dio _dio;
  final DevGatewayClient _devGatewayClient;
  final String _jeeberUserId;
  final String _bearerToken;
  final Map<String, LocationSimulationDeliverySummary> _summaries =
      <String, LocationSimulationDeliverySummary>{};
  final Map<String, String> _clientTokens = <String, String>{};

  @override
  Future<List<LocationSimulationDeliverySummary>> listDeliveries() async {
    const operation = 'list Jeeber deliveries';
    const pageSize = 100;
    final assigned = <LocationSimulationDeliverySummary>[];
    try {
      for (var page = 1; page <= 20; page++) {
        final response = await _dio.get<Map<String, dynamic>>(
          '/v1/deliveries',
          queryParameters: <String, dynamic>{
            'role': 'jeeber',
            'page': page,
            'pageSize': pageSize,
          },
          options: _bearer(),
        );
        final data = response.data;
        final rawItems = data?['items'];
        if (data == null || rawItems is! List) {
          throw _invalidResponse(
            operation,
            response.statusCode,
            data,
            'The response must contain an `items` list.',
          );
        }
        try {
          for (final item in rawItems) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException(
                'Every delivery item must be an object.',
              );
            }
            final summary = LocationSimulationDeliverySummary.fromJson(item);
            if (summary.jeeberUserId != _jeeberUserId ||
                summary.status.isTerminal ||
                summary.status == LocationSimulationDeliveryStatus.unknown) {
              continue;
            }
            _summaries[summary.id] = summary;
            assigned.add(summary);
          }
        } on FormatException catch (error) {
          throw _invalidResponse(
            operation,
            response.statusCode,
            data,
            error.message,
          );
        }
        final totalPages = data['totalPages'];
        if (totalPages is num && page >= totalPages.toInt()) break;
        if (rawItems.length < pageSize) break;
      }
      return List<LocationSimulationDeliverySummary>.unmodifiable(assigned);
    } on DioException catch (error) {
      throw _fromDio(error, operation);
    }
  }

  @override
  Future<LocationSimulationDelivery> getDelivery(String deliveryId) async {
    const operation = 'get delivery details';
    final id = _requiredValue(deliveryId, 'deliveryId', operation);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/deliveries/$id',
        options: _bearer(),
      );
      final data = response.data;
      if (data == null) {
        throw _invalidResponse(
          operation,
          response.statusCode,
          null,
          'The gateway returned an empty delivery body.',
        );
      }
      final assignedJeeberId = _optionalText(
        data['jeeberId'] ?? data['jeeber_id'],
      );
      if (assignedJeeberId != _jeeberUserId) {
        throw LocationSimulationFailure(
          kind: LocationSimulationFailureKind.authorization,
          operation: operation,
          statusCode: response.statusCode,
          responseBody: data,
          message:
              'Delivery $id is not assigned to the selected Jeeber. '
              'Refresh the assigned-delivery list.',
        );
      }

      final summary = _summaries[id];
      final requestId =
          _optionalText(data['requestId'] ?? data['request_id']) ??
          summary?.requestId;
      Map<String, dynamic>? ownerRequest;
      Object? coordinateReadFailure;
      if (!_hasCoordinates(data)) {
        final clientUserId = _optionalText(
          data['clientId'] ?? data['client_id'],
        );
        if (clientUserId != null && requestId != null) {
          try {
            final clientToken = await _clientToken(clientUserId);
            final ownerResponse = await _dio.get<Map<String, dynamic>>(
              '/v1/requests/$requestId',
              options: _bearer(clientToken),
            );
            ownerRequest = ownerResponse.data;
          } on DevGatewayException catch (error) {
            coordinateReadFailure = error.message;
          } on DioException catch (error) {
            coordinateReadFailure =
                'owner request returned HTTP ${error.response?.statusCode ?? 'unreachable'}';
          }
        } else if (requestId == null) {
          coordinateReadFailure = 'delivery has no requestId';
        }
      }

      final merged = <String, dynamic>{
        ...data,
        if (data['pickupLocation'] == null)
          'pickupLocation':
              ownerRequest?['pickupLocation'] ??
              ownerRequest?['pickup_location'] ??
              _coordinateJson(summary?.pickupLocation),
        if (data['dropoffLocation'] == null)
          'dropoffLocation':
              ownerRequest?['dropoffLocation'] ??
              ownerRequest?['dropoff_location'] ??
              _coordinateJson(summary?.dropoffLocation),
      };
      try {
        return LocationSimulationDelivery.fromJson(merged);
      } on FormatException catch (error) {
        throw _invalidResponse(
          operation,
          response.statusCode,
          data,
          'MSI supplied no usable pickup/drop-off coordinates for delivery '
          '$id. Select another assigned delivery, or create a disposable dev '
          'request with both locations${coordinateReadFailure == null ? '' : ' '
                    '($coordinateReadFailure)'}. ${error.message}',
        );
      }
    } on DioException catch (error) {
      throw _fromDio(error, operation);
    }
  }

  @override
  Future<void> transitionDelivery({
    required String deliveryId,
    required LocationSimulationDeliveryStatus to,
  }) async {
    const operation = 'transition delivery status';
    final id = _requiredValue(deliveryId, 'deliveryId', operation);
    if (to == LocationSimulationDeliveryStatus.unknown) {
      throw const LocationSimulationFailure(
        kind: LocationSimulationFailureKind.validation,
        operation: operation,
        message: 'An unknown delivery status cannot be sent to the gateway.',
      );
    }
    try {
      await _dio.patch<void>(
        '/v1/deliveries/$id/status',
        data: <String, dynamic>{'to': to.apiValue, 'evidenceUrl': null},
        options: _bearer(),
      );
    } on DioException catch (error) {
      throw _fromDio(error, operation);
    }
  }

  @override
  Future<LocationSimulationUpdateResult> postLocation({
    required String deliveryId,
    required LocationRoutePoint point,
  }) async {
    const operation = 'post simulated location';
    final id = _requiredValue(deliveryId, 'deliveryId', operation);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/location/update',
        data: <String, dynamic>{
          'deliveryId': id,
          'points': <Map<String, dynamic>>[point.toLocationUpdateJson()],
        },
        options: _bearer(),
      );
      final data = response.data;
      final accepted = data?['accepted'];
      final rejected = data?['rejected'];
      if (accepted is! num || rejected is! num) {
        throw _invalidResponse(
          operation,
          response.statusCode,
          data,
          'The response must contain numeric accepted/rejected counts.',
        );
      }
      return LocationSimulationUpdateResult(
        accepted: accepted.toInt(),
        rejected: rejected.toInt(),
      );
    } on DioException catch (error) {
      throw _fromDio(error, operation);
    }
  }

  @override
  Future<void> verifyOtp({
    required String deliveryId,
    required String code,
  }) async {
    const operation = 'verify delivery OTP';
    final id = _requiredValue(deliveryId, 'deliveryId', operation);
    final normalizedCode = _requiredValue(code, 'code', operation);
    try {
      await _dio.post<void>(
        '/v1/deliveries/$id/otp/verify',
        data: <String, dynamic>{'code': normalizedCode},
        options: _bearer(),
      );
    } on DioException catch (error) {
      throw _fromDio(error, operation);
    }
  }

  Future<String> _clientToken(String clientUserId) async {
    final cached = _clientTokens[clientUserId];
    if (cached != null) return cached;
    final token = await _devGatewayClient.mintTokenForUser(
      clientUserId,
      roles: const <String>['customer'],
    );
    _clientTokens[clientUserId] = token;
    return token;
  }

  Options _bearer([String? token]) => Options(
    headers: <String, dynamic>{
      'Authorization': 'Bearer ${token ?? _bearerToken}',
    },
  );
}

bool _hasCoordinates(Map<String, dynamic> data) =>
    _isCoordinate(
      data['pickupLocation'] ?? data['pickup_location'] ?? data['pickup'],
    ) &&
    _isCoordinate(
      data['dropoffLocation'] ??
          data['dropoff_location'] ??
          data['dropoff'] ??
          data['dropOff'],
    );

bool _isCoordinate(Object? value) {
  if (value is! Map) return false;
  return (value['lat'] ?? value['latitude']) is num &&
      (value['lng'] ?? value['longitude']) is num;
}

Map<String, dynamic>? _coordinateJson(LocationCoordinate? coordinate) {
  if (coordinate == null) return null;
  return <String, dynamic>{
    'lat': coordinate.latitude,
    'lng': coordinate.longitude,
  };
}

String? _optionalText(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

String _requiredValue(String value, String field, String operation) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw LocationSimulationFailure(
      kind: LocationSimulationFailureKind.validation,
      operation: operation,
      message: '`$field` is required.',
    );
  }
  return normalized;
}

LocationSimulationFailure _invalidResponse(
  String operation,
  int? statusCode,
  Object? responseBody,
  String message,
) {
  return LocationSimulationFailure(
    kind: LocationSimulationFailureKind.invalidResponse,
    operation: operation,
    message: message,
    statusCode: statusCode,
    responseBody: responseBody,
  );
}

LocationSimulationFailure _fromDio(DioException error, String operation) {
  final statusCode = error.response?.statusCode;
  final responseBody = error.response?.data;
  final detail = _responseDetail(responseBody);
  final message = statusCode == null
      ? 'Could not $operation: ${error.type.name}.'
      : 'Could not $operation: HTTP $statusCode${detail == null ? '' : ' ($detail)'}.';
  return LocationSimulationFailure(
    kind: _kindForStatus(statusCode, dioType: error.type),
    operation: operation,
    message: message,
    statusCode: statusCode,
    responseBody: responseBody,
  );
}

LocationSimulationFailureKind _kindForStatus(
  int? statusCode, {
  DioExceptionType? dioType,
}) {
  if (statusCode == 401) return LocationSimulationFailureKind.authentication;
  if (statusCode == 403) return LocationSimulationFailureKind.authorization;
  if (statusCode == 404) return LocationSimulationFailureKind.notFound;
  if (statusCode == 409) return LocationSimulationFailureKind.conflict;
  if (statusCode != null && statusCode >= 500) {
    return LocationSimulationFailureKind.server;
  }
  if (statusCode != null) return LocationSimulationFailureKind.unexpected;
  if (dioType == DioExceptionType.connectionError ||
      dioType == DioExceptionType.connectionTimeout ||
      dioType == DioExceptionType.sendTimeout ||
      dioType == DioExceptionType.receiveTimeout) {
    return LocationSimulationFailureKind.network;
  }
  return LocationSimulationFailureKind.unexpected;
}

String? _responseDetail(Object? responseBody) {
  if (responseBody is! Map) return null;
  for (final key in const <String>[
    'detail',
    'message',
    'error',
    'reason',
    'code',
  ]) {
    final value = responseBody[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}
