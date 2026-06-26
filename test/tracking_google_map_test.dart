import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_google_map.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_map_surface.dart';

import 'support/sync_app_localizations.dart';

DeliveryTrackingInfo _info({
  GpsPoint? position,
  List<GpsPoint> polyline = const [],
}) {
  return DeliveryTrackingInfo(
    deliveryId: 'd-1',
    currentStage: TrackingStage.inTransit,
    stageTimestamps: const {},
    jeeberPosition: position,
    polyline: polyline,
  );
}

void main() {
  // T-MOB-017: the marker + polyline + camera are built from the SAME
  // DeliveryTrackingInfo the cubit parses from GET /deliveries/{id}/tracking.
  // These pure builders are the live GoogleMap's data layer and are unit-green
  // without a platform view.
  group('trackingMarkers', () {
    test('renders one Jeeber marker at the courier position', () {
      final markers = trackingMarkers(
        _info(position: const GpsPoint(lat: 33.89, lng: 35.50)),
      );
      expect(markers, hasLength(1));
      final marker = markers.single;
      expect(marker.markerId, const MarkerId(TrackingGoogleMap.jeeberMarkerId));
      expect(marker.position, const LatLng(33.89, 35.50));
    });

    test('is empty when there is no GPS fix yet', () {
      expect(trackingMarkers(_info()), isEmpty);
    });
  });

  group('trackingPolylines', () {
    test('renders the route polyline from the parsed points', () {
      final polylines = trackingPolylines(
        _info(polyline: const [
          GpsPoint(lat: 33.89, lng: 35.50),
          GpsPoint(lat: 33.88, lng: 35.49),
          GpsPoint(lat: 33.87, lng: 35.48),
        ]),
      );
      expect(polylines, hasLength(1));
      final line = polylines.single;
      expect(line.polylineId,
          const PolylineId(TrackingGoogleMap.routePolylineId));
      expect(line.points, const [
        LatLng(33.89, 35.50),
        LatLng(33.88, 35.49),
        LatLng(33.87, 35.48),
      ]);
    });

    test('is empty when fewer than two points are known', () {
      expect(trackingPolylines(_info()), isEmpty);
      expect(
        trackingPolylines(_info(polyline: const [GpsPoint(lat: 1, lng: 2)])),
        isEmpty,
      );
    });
  });

  group('trackingCamera', () {
    test('frames the courier fix when known', () {
      final cam = trackingCamera(
        _info(position: const GpsPoint(lat: 33.89, lng: 35.50)),
      );
      expect(cam.target, const LatLng(33.89, 35.50));
    });

    test('falls back to the polyline first point when no fix', () {
      final cam = trackingCamera(
        _info(polyline: const [
          GpsPoint(lat: 33.70, lng: 35.40),
          GpsPoint(lat: 33.71, lng: 35.41),
        ]),
      );
      expect(cam.target, const LatLng(33.70, 35.40));
    });

    test('falls back to Beirut downtown when nothing is known', () {
      final cam = trackingCamera(_info());
      expect(cam.target.latitude, closeTo(33.8938, 1e-6));
      expect(cam.target.longitude, closeTo(35.5018, 1e-6));
    });
  });

  group('TrackingMapSurface', () {
    testWidgets('renders the placeholder (not a live map) when useLiveMap is '
        'false even with tracking info', (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          TrackingMapSurface(
            info: _info(position: const GpsPoint(lat: 33.89, lng: 35.50)),
            useLiveMap: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(TrackingMapSurface.rootKey), findsOneWidget);
      expect(find.byType(TrackingGoogleMap), findsNothing);
      expect(find.byIcon(Icons.navigation_outlined), findsOneWidget);
    });

    testWidgets('renders the placeholder when there is no tracking info yet',
        (tester) async {
      await tester.pumpWidget(wrapForTest(const TrackingMapSurface()));
      await tester.pump();

      expect(find.byKey(TrackingMapSurface.rootKey), findsOneWidget);
      expect(find.byType(TrackingGoogleMap), findsNothing);
    });

    testWidgets('keeps its accessibility identifier in both modes',
        (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          TrackingMapSurface(info: _info(), useLiveMap: false),
        ),
      );
      await tester.pump();

      final semantics = tester.getSemantics(
        find.byKey(TrackingMapSurface.rootKey),
      );
      expect(semantics.identifier, 'tracking_map');
    });
  });
}
