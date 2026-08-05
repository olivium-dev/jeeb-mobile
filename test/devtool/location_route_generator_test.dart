import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/location_simulation/location_route_generator.dart';
import 'package:jeeb_mobile/devtool/location_simulation/location_simulation_models.dart';

void main() {
  const generator = LocationRouteGenerator();

  group('LocationRouteGenerator', () {
    test(
      'includes exact endpoints with deterministic monotonic UTC points',
      () {
        final start = LocationCoordinate(latitude: 33.8886, longitude: 35.4955);
        final end = LocationCoordinate(latitude: 33.9001, longitude: 35.5034);
        final startsAt = DateTime.parse('2026-08-05T14:00:00+02:00');

        final first = generator.generate(
          start: start,
          end: end,
          stepCount: 5,
          startsAt: startsAt,
          interval: const Duration(seconds: 10),
          accuracyMeters: 4,
        );
        final second = generator.generate(
          start: start,
          end: end,
          stepCount: 5,
          startsAt: startsAt,
          interval: const Duration(seconds: 10),
          accuracyMeters: 4,
        );

        expect(first, second);
        expect(first.points, hasLength(5));
        expect(first.points.first.coordinate, same(start));
        expect(first.points.last.coordinate, same(end));
        expect(first.points.first.capturedAt, DateTime.utc(2026, 8, 5, 12));
        expect(first.points.every((point) => point.capturedAt.isUtc), isTrue);
        for (var index = 1; index < first.points.length; index++) {
          expect(
            first.points[index].capturedAt.isAfter(
              first.points[index - 1].capturedAt,
            ),
            isTrue,
          );
          expect(
            first.points[index].distanceFromStartMeters,
            greaterThan(first.points[index - 1].distanceFromStartMeters),
          );
        }
        expect(first.points.first.speedMetersPerSecond, 0);
        expect(
          first.points.skip(1).every((point) => point.speedMetersPerSecond > 0),
          isTrue,
        );
      },
    );

    test('uses haversine distance and a normalized compass bearing', () {
      final west = LocationCoordinate(latitude: 0, longitude: 0);
      final east = LocationCoordinate(latitude: 0, longitude: 1);

      final route = generator.generate(
        start: west,
        end: east,
        stepCount: 3,
        startsAt: DateTime.utc(2026),
        interval: const Duration(seconds: 10),
      );

      expect(route.totalDistanceMeters, closeTo(111195, 100));
      expect(route.initialBearingDegrees, closeTo(90, 0.0001));
      expect(
        LocationRouteGenerator.haversineDistanceMeters(west, east),
        closeTo(route.totalDistanceMeters, 0.0001),
      );
      expect(
        route.points.every(
          (point) => point.bearingDegrees >= 0 && point.bearingDegrees < 360,
        ),
        isTrue,
      );
      expect(
        route.points.last.distanceFromStartMeters,
        closeTo(route.totalDistanceMeters, 0.0001),
      );
    });

    test('same pickup and drop-off produce an explicit moving loop', () {
      final endpoint = LocationCoordinate(
        latitude: 52.3994952,
        longitude: 5.2751205,
      );

      final route = generator.generate(
        start: endpoint,
        end: endpoint,
        stepCount: 9,
        startsAt: DateTime.utc(2026, 8, 5, 14),
        interval: const Duration(seconds: 2),
      );

      expect(route.points.first.coordinate, endpoint);
      expect(route.points.last.coordinate, endpoint);
      expect(
        route.points
            .skip(1)
            .take(route.points.length - 2)
            .any((point) => point.coordinate != endpoint),
        isTrue,
      );
      expect(route.totalDistanceMeters, greaterThan(200));
      expect(
        route.points.last.distanceFromStartMeters,
        route.totalDistanceMeters,
      );
    });

    test('rejects invalid coordinates', () {
      expect(
        () => LocationCoordinate(latitude: 91, longitude: 35),
        throwsArgumentError,
      );
      expect(
        () => LocationCoordinate(latitude: 33, longitude: -181),
        throwsArgumentError,
      );
      expect(
        () => LocationCoordinate(latitude: double.nan, longitude: 35),
        throwsArgumentError,
      );
      expect(
        () => LocationCoordinate(latitude: 33, longitude: double.infinity),
        throwsArgumentError,
      );
    });

    test('rejects invalid step counts, intervals, and accuracy', () {
      final start = LocationCoordinate(latitude: 33, longitude: 35);
      final end = LocationCoordinate(latitude: 34, longitude: 36);

      LocationSimulationRoute generate({
        int stepCount = 2,
        Duration interval = const Duration(seconds: 1),
        double accuracyMeters = 5,
      }) {
        return generator.generate(
          start: start,
          end: end,
          stepCount: stepCount,
          startsAt: DateTime.utc(2026),
          interval: interval,
          accuracyMeters: accuracyMeters,
        );
      }

      expect(() => generate(stepCount: 1), throwsArgumentError);
      expect(() => generate(stepCount: 0), throwsArgumentError);
      expect(() => generate(interval: Duration.zero), throwsArgumentError);
      expect(() => generate(accuracyMeters: 0), throwsArgumentError);
      expect(() => generate(accuracyMeters: double.nan), throwsArgumentError);
    });
  });
}
