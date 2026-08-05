import 'dart:math' as math;

import 'location_simulation_models.dart';

class LocationRouteGenerator {
  const LocationRouteGenerator();

  static const double _earthRadiusMeters = 6371008.8;

  LocationSimulationRoute generate({
    required LocationCoordinate start,
    required LocationCoordinate end,
    required int stepCount,
    required DateTime startsAt,
    required Duration interval,
    double accuracyMeters = 5,
  }) {
    if (stepCount < 2) {
      throw ArgumentError.value(
        stepCount,
        'stepCount',
        'Must include at least the start and end points.',
      );
    }
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'Must be positive.');
    }
    if (!accuracyMeters.isFinite || accuracyMeters <= 0) {
      throw ArgumentError.value(
        accuracyMeters,
        'accuracyMeters',
        'Must be a finite positive value.',
      );
    }

    final utcStart = startsAt.toUtc();
    final intervalSeconds =
        interval.inMicroseconds / Duration.microsecondsPerSecond;
    final sameEndpoints = start == end;
    final coordinates = List<LocationCoordinate>.generate(stepCount, (index) {
      if (index == 0) return start;
      if (index == stepCount - 1) return end;
      final fraction = index / (stepCount - 1);
      return sameEndpoints
          ? _loopCoordinate(start, fraction)
          : _interpolate(start, end, fraction);
    }, growable: false);
    final points = <LocationRoutePoint>[];
    var travelled = 0.0;

    for (var index = 0; index < stepCount; index++) {
      final coordinate = coordinates[index];
      final previous = points.isEmpty ? null : points.last.coordinate;
      final segmentDistance = previous == null
          ? 0.0
          : haversineDistanceMeters(previous, coordinate);
      travelled += segmentDistance;
      final nextCoordinate = index == stepCount - 1
          ? null
          : coordinates[index + 1];
      final initialBearing = coordinates.length < 2
          ? 0.0
          : bearingDegrees(coordinates.first, coordinates[1]);
      final pointBearing = nextCoordinate == null
          ? (points.isEmpty ? initialBearing : points.last.bearingDegrees)
          : bearingDegrees(coordinate, nextCoordinate);

      points.add(
        LocationRoutePoint(
          coordinate: coordinate,
          accuracyMeters: accuracyMeters,
          capturedAt: utcStart.add(interval * index),
          distanceFromStartMeters: travelled,
          speedMetersPerSecond: segmentDistance / intervalSeconds,
          bearingDegrees: pointBearing,
        ),
      );
    }

    return LocationSimulationRoute(
      points: List<LocationRoutePoint>.unmodifiable(points),
      totalDistanceMeters: travelled,
      initialBearingDegrees: bearingDegrees(coordinates.first, coordinates[1]),
    );
  }

  static double haversineDistanceMeters(
    LocationCoordinate start,
    LocationCoordinate end,
  ) {
    final lat1 = _toRadians(start.latitude);
    final lat2 = _toRadians(end.latitude);
    final deltaLat = lat2 - lat1;
    final deltaLng = _toRadians(end.longitude - start.longitude);
    final sinLat = math.sin(deltaLat / 2);
    final sinLng = math.sin(deltaLng / 2);
    final a =
        sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLng * sinLng;
    final centralAngle = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * centralAngle;
  }

  static double bearingDegrees(
    LocationCoordinate start,
    LocationCoordinate end,
  ) {
    if (start == end) return 0;
    final lat1 = _toRadians(start.latitude);
    final lat2 = _toRadians(end.latitude);
    final deltaLng = _toRadians(end.longitude - start.longitude);
    final y = math.sin(deltaLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng);
    return (_toDegrees(math.atan2(y, x)) + 360) % 360;
  }

  static LocationCoordinate _interpolate(
    LocationCoordinate start,
    LocationCoordinate end,
    double fraction,
  ) {
    return LocationCoordinate(
      latitude: start.latitude + (end.latitude - start.latitude) * fraction,
      longitude: start.longitude + (end.longitude - start.longitude) * fraction,
    );
  }

  static LocationCoordinate _loopCoordinate(
    LocationCoordinate origin,
    double fraction,
  ) {
    const radiusMeters = 40.0;
    final angle = -math.pi / 2 + 2 * math.pi * fraction;
    final northMeters = radiusMeters + radiusMeters * math.sin(angle);
    final eastMeters = radiusMeters * math.cos(angle);
    final latitude = origin.latitude + northMeters / 111320;
    final longitudeScale = 111320 * math.cos(_toRadians(origin.latitude));
    final longitude =
        origin.longitude +
        (longitudeScale.abs() < 0.001 ? 0 : eastMeters / longitudeScale);
    return LocationCoordinate(latitude: latitude, longitude: longitude);
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  static double _toDegrees(double radians) => radians * 180 / math.pi;
}
