import 'package:equatable/equatable.dart';

enum LocationSimulationDeliveryStatus {
  ordered('Ordered'),
  picked('Picked'),
  inTransit('InTransit'),
  atDoor('AtDoor'),
  done('Done'),
  cancelled('Cancelled'),
  expired('Expired'),
  disputed('FailedNeedsEscalation'),
  unknown('Unknown');

  const LocationSimulationDeliveryStatus(this.apiValue);

  factory LocationSimulationDeliveryStatus.fromApi(Object? value) {
    if (value is! String) return LocationSimulationDeliveryStatus.unknown;
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]'),
      '',
    );
    return switch (normalized) {
      'ordered' || 'accepted' => LocationSimulationDeliveryStatus.ordered,
      'picked' || 'pickedup' => LocationSimulationDeliveryStatus.picked,
      'intransit' || 'headingoff' => LocationSimulationDeliveryStatus.inTransit,
      'atdoor' => LocationSimulationDeliveryStatus.atDoor,
      'done' ||
      'delivered' ||
      'completed' ||
      'rated' => LocationSimulationDeliveryStatus.done,
      'cancelled' || 'canceled' => LocationSimulationDeliveryStatus.cancelled,
      'expired' => LocationSimulationDeliveryStatus.expired,
      'disputed' ||
      'failedneedsescalation' => LocationSimulationDeliveryStatus.disputed,
      _ => LocationSimulationDeliveryStatus.unknown,
    };
  }

  final String apiValue;

  bool get isTerminal =>
      this == done || this == cancelled || this == expired || this == disputed;
}

class LocationCoordinate extends Equatable {
  factory LocationCoordinate({
    required double latitude,
    required double longitude,
  }) {
    if (!isValidLatitude(latitude)) {
      throw ArgumentError.value(latitude, 'latitude', 'Must be within -90..90');
    }
    if (!isValidLongitude(longitude)) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'Must be within -180..180',
      );
    }
    return LocationCoordinate._(latitude: latitude, longitude: longitude);
  }

  const LocationCoordinate._({required this.latitude, required this.longitude});

  factory LocationCoordinate.fromJson(Object? value, {required String field}) {
    if (value is! Map) {
      throw FormatException('`$field` must be an object.');
    }
    final latitude = value['lat'] ?? value['latitude'];
    final longitude = value['lng'] ?? value['longitude'];
    if (latitude is! num || longitude is! num) {
      throw FormatException('`$field` must contain numeric lat/lng values.');
    }
    final lat = latitude.toDouble();
    final lng = longitude.toDouble();
    if (!isValidLatitude(lat) || !isValidLongitude(lng)) {
      throw FormatException(
        '`$field` contains coordinates outside valid bounds.',
      );
    }
    return LocationCoordinate(latitude: lat, longitude: lng);
  }

  final double latitude;
  final double longitude;

  static bool isValidLatitude(double value) =>
      value.isFinite && value >= -90 && value <= 90;

  static bool isValidLongitude(double value) =>
      value.isFinite && value >= -180 && value <= 180;

  @override
  List<Object?> get props => <Object?>[latitude, longitude];
}

class LocationSimulationDeliverySummary extends Equatable {
  const LocationSimulationDeliverySummary({
    required this.id,
    required this.status,
    this.requestId,
    this.jeeberUserId,
    this.pickupLocation,
    this.dropoffLocation,
  });

  factory LocationSimulationDeliverySummary.fromJson(
    Map<String, dynamic> json,
  ) {
    final id = _requiredIdentifier(json, 'delivery');
    return LocationSimulationDeliverySummary(
      id: id,
      status: LocationSimulationDeliveryStatus.fromApi(json['status']),
      requestId: _optionalString(json['requestId'] ?? json['request_id']),
      jeeberUserId: _optionalString(json['jeeberId'] ?? json['jeeber_id']),
      pickupLocation: _optionalCoordinate(
        json['pickupLocation'] ?? json['pickup_location'] ?? json['pickup'],
      ),
      dropoffLocation: _optionalCoordinate(
        json['dropoffLocation'] ??
            json['dropoff_location'] ??
            json['dropoff'] ??
            json['dropOff'],
      ),
    );
  }

  final String id;
  final LocationSimulationDeliveryStatus status;
  final String? requestId;
  final String? jeeberUserId;
  final LocationCoordinate? pickupLocation;
  final LocationCoordinate? dropoffLocation;

  @override
  List<Object?> get props => <Object?>[
    id,
    status,
    requestId,
    jeeberUserId,
    pickupLocation,
    dropoffLocation,
  ];
}

class LocationSimulationDelivery extends Equatable {
  const LocationSimulationDelivery({
    required this.id,
    required this.status,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.requestId,
    this.clientUserId,
    this.jeeberUserId,
  });

  factory LocationSimulationDelivery.fromJson(
    Map<String, dynamic> json, {
    LocationCoordinate? pickupLocationFallback,
    LocationCoordinate? dropoffLocationFallback,
  }) {
    final pickup =
        json['pickupLocation'] ?? json['pickup_location'] ?? json['pickup'];
    final dropoff =
        json['dropoffLocation'] ??
        json['dropoff_location'] ??
        json['dropoff'] ??
        json['dropOff'];
    return LocationSimulationDelivery(
      id: _requiredIdentifier(json, 'delivery'),
      status: LocationSimulationDeliveryStatus.fromApi(json['status']),
      requestId: _optionalString(json['requestId'] ?? json['request_id']),
      clientUserId: _optionalString(json['clientId'] ?? json['client_id']),
      jeeberUserId: _optionalString(json['jeeberId'] ?? json['jeeber_id']),
      pickupLocation: _coordinateOrFallback(
        pickup,
        pickupLocationFallback,
        field: 'pickupLocation',
      ),
      dropoffLocation: _coordinateOrFallback(
        dropoff,
        dropoffLocationFallback,
        field: 'dropoffLocation',
      ),
    );
  }

  final String id;
  final LocationSimulationDeliveryStatus status;
  final String? requestId;
  final String? clientUserId;
  final String? jeeberUserId;
  final LocationCoordinate pickupLocation;
  final LocationCoordinate dropoffLocation;

  @override
  List<Object?> get props => <Object?>[
    id,
    status,
    requestId,
    clientUserId,
    jeeberUserId,
    pickupLocation,
    dropoffLocation,
  ];
}

class LocationRoutePoint extends Equatable {
  const LocationRoutePoint({
    required this.coordinate,
    required this.accuracyMeters,
    required this.capturedAt,
    required this.distanceFromStartMeters,
    required this.speedMetersPerSecond,
    required this.bearingDegrees,
  });

  final LocationCoordinate coordinate;
  final double accuracyMeters;
  final DateTime capturedAt;
  final double distanceFromStartMeters;
  final double speedMetersPerSecond;
  final double bearingDegrees;

  Map<String, dynamic> toLocationUpdateJson() => <String, dynamic>{
    'lat': coordinate.latitude,
    'lng': coordinate.longitude,
    'accuracy': accuracyMeters,
    'timestamp': capturedAt.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props => <Object?>[
    coordinate,
    accuracyMeters,
    capturedAt,
    distanceFromStartMeters,
    speedMetersPerSecond,
    bearingDegrees,
  ];
}

class LocationSimulationRoute extends Equatable {
  const LocationSimulationRoute({
    required this.points,
    required this.totalDistanceMeters,
    required this.initialBearingDegrees,
  });

  final List<LocationRoutePoint> points;
  final double totalDistanceMeters;
  final double initialBearingDegrees;

  @override
  List<Object?> get props => <Object?>[
    points,
    totalDistanceMeters,
    initialBearingDegrees,
  ];
}

class LocationSimulationUpdateResult extends Equatable {
  const LocationSimulationUpdateResult({
    required this.accepted,
    required this.rejected,
  });

  final int accepted;
  final int rejected;

  @override
  List<Object?> get props => <Object?>[accepted, rejected];
}

enum LocationSimulationFailureKind {
  validation,
  authentication,
  authorization,
  notFound,
  conflict,
  network,
  server,
  invalidResponse,
  unexpected,
}

class LocationSimulationFailure implements Exception {
  const LocationSimulationFailure({
    required this.kind,
    required this.operation,
    required this.message,
    this.statusCode,
    this.responseBody,
  });

  final LocationSimulationFailureKind kind;
  final String operation;
  final String message;
  final int? statusCode;
  final Object? responseBody;

  @override
  String toString() =>
      'LocationSimulationFailure('
      'kind: $kind, operation: $operation, statusCode: $statusCode, '
      'message: $message)';
}

String _requiredIdentifier(Map<String, dynamic> json, String resource) {
  final raw = json['id'] ?? json['deliveryId'] ?? json['delivery_id'];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('The $resource response contains no valid id.');
  }
  return raw.trim();
}

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

LocationCoordinate _coordinateOrFallback(
  Object? value,
  LocationCoordinate? fallback, {
  required String field,
}) {
  if (value != null) return LocationCoordinate.fromJson(value, field: field);
  if (fallback != null) return fallback;
  throw FormatException('`$field` is missing from the response.');
}

LocationCoordinate? _optionalCoordinate(Object? value) {
  if (value is Map) {
    final latitude = value['lat'] ?? value['latitude'];
    final longitude = value['lng'] ?? value['longitude'];
    if (latitude is num && longitude is num) {
      final lat = latitude.toDouble();
      final lng = longitude.toDouble();
      if (LocationCoordinate.isValidLatitude(lat) &&
          LocationCoordinate.isValidLongitude(lng)) {
        return LocationCoordinate(latitude: lat, longitude: lng);
      }
    }
    for (final key in const <String>['address', 'label']) {
      final parsed = _coordinateFromText(value[key]);
      if (parsed != null) return parsed;
    }
  }
  return _coordinateFromText(value);
}

LocationCoordinate? _coordinateFromText(Object? value) {
  if (value is! String) return null;
  final match = RegExp(
    r'\((-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\)',
  ).firstMatch(value);
  if (match == null) return null;
  final latitude = double.tryParse(match.group(1)!);
  final longitude = double.tryParse(match.group(2)!);
  if (latitude == null || longitude == null) return null;
  if (!LocationCoordinate.isValidLatitude(latitude) ||
      !LocationCoordinate.isValidLongitude(longitude)) {
    return null;
  }
  return LocationCoordinate(latitude: latitude, longitude: longitude);
}
