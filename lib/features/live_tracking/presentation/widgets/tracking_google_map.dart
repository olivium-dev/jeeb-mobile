import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/delivery_tracking_info.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import 'package:omds/omds.dart';

class TrackingGoogleMap extends StatefulWidget {
  const TrackingGoogleMap({super.key, required this.info});

  final DeliveryTrackingInfo info;

  static const String jeeberMarkerId = 'jeeber';
  static const String routePolylineId = 'route';

  @override
  State<TrackingGoogleMap> createState() => _TrackingGoogleMapState();
}

class _TrackingGoogleMapState extends State<TrackingGoogleMap> {
  GoogleMapController? _map;

  @override
  void didUpdateWidget(TrackingGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pos = widget.info.jeeberPosition;
    if (pos != null && pos != oldWidget.info.jeeberPosition) {
      _map?.animateCamera(CameraUpdate.newLatLng(LatLng(pos.lat, pos.lng)));
    }
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: trackingCamera(widget.info),
      onMapCreated: (controller) => _map = controller,
      markers: trackingMarkers(widget.info),
      polylines: trackingPolylines(widget.info),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      liteModeEnabled: false,
    );
  }
}

CameraPosition trackingCamera(DeliveryTrackingInfo info) {
  final point = info.jeeberPosition ??
      (info.polyline.isNotEmpty ? info.polyline.first : null);
  final target = point != null
      ? LatLng(point.lat, point.lng)
      : const LatLng(33.8938, 35.5018);
  return CameraPosition(target: target, zoom: 14);
}

Set<Marker> trackingMarkers(DeliveryTrackingInfo info) {
  final pos = info.jeeberPosition;
  if (pos == null || !info.markerIsLive) return const <Marker>{};
  return {
    Marker(
      markerId: const MarkerId(TrackingGoogleMap.jeeberMarkerId),
      position: LatLng(pos.lat, pos.lng),
      flat: true,
      anchor: const Offset(0.5, 0.5),
    ),
  };
}

Set<Polyline> trackingPolylines(DeliveryTrackingInfo info) {
  if (info.polyline.length < 2) return const <Polyline>{};
  return {
    Polyline(
      polylineId: const PolylineId(TrackingGoogleMap.routePolylineId),
      points: [
        for (final p in info.polyline) LatLng(p.lat, p.lng),
      ],
      width: 5,
      geodesic: false,
    ),
  };
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width, and enough height for a map band plus the two caption lines.
const Size _trackingGoogleMapBox = Size(390, 380);

/// The canonical pickup point of the pilot route (`tracking_google_map_test`
/// "straight line pickup→dropoff"). Note it is ALSO the literal Beirut-downtown
const GpsPoint _trackingGoogleMapPickup = GpsPoint(lat: 33.8938, lng: 35.5018);

/// The drop-off point of the same pilot route.
const GpsPoint _trackingGoogleMapDropoff = GpsPoint(lat: 33.8869, lng: 35.5131);

/// The courier's reported fix (`trackingMarkers` / `trackingCamera` tests).
const GpsPoint _trackingGoogleMapCourier = GpsPoint(lat: 33.89, lng: 35.50);

/// The full two-point pilot route. Q-061: the pilot draws pickup→dropoff as one
/// STRAIGHT segment, so two points is the production shape, not a shortcut.
const List<GpsPoint> _trackingGoogleMapRoute = <GpsPoint>[_trackingGoogleMapPickup, _trackingGoogleMapDropoff];

DeliveryTrackingInfo _trackingGoogleMapInfo({
  GpsPoint? position,
  List<GpsPoint> polyline = const <GpsPoint>[],
  bool stale = false,
  double? ageSeconds,
  PositionFreshness? status,
}) {
  return DeliveryTrackingInfo(
    deliveryId: 'd-1',
    currentStage: TrackingStage.inTransit,
    stageTimestamps: const <TrackingStage, DateTime>{},
    jeeberPosition: position,
    polyline: polyline,
    positionStale: stale,
    positionAgeSeconds: ageSeconds,
    positionStatus: status,
  );
}

/// What the map was actually told to draw, read back out of the widget's own
/// pure builders — see the library doc for why this stands in for a raster.
String _trackingGoogleMapReadout(DeliveryTrackingInfo info) {
  final Set<Polyline> lines = trackingPolylines(info);
  final int points = lines.isEmpty ? 0 : lines.single.points.length;
  final CameraPosition camera = trackingCamera(info);
  return '${info.positionStatus?.wire ?? 'unset'} · '
      'markers ${trackingMarkers(info).length} · '
      'route $points pts · '
      'camera ${camera.target.latitude.toStringAsFixed(4)},'
      '${camera.target.longitude.toStringAsFixed(4)}';
}

/// Mounts the real [TrackingGoogleMap] in a framed band, captioned with the
/// state name and the derived readout.
Widget _trackingGoogleMapHosted(String label, DeliveryTrackingInfo info) => Builder(
      builder: (BuildContext context) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: TrackingGoogleMap(info: info),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: Spacing.xSmall,
                left: Spacing.small,
                right: Spacing.small,
              ),
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.small),
              child: Text(
                _trackingGoogleMapReadout(info),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        );
      },
    );

/// The happy path: a fresh courier fix on a known route.
/// One marker, the two-point straight-line route, and the camera framing the
@JeebPreview(group: 'live_tracking', name: 'Live fix on route', size: _trackingGoogleMapBox)
Widget trackingGoogleMapLiveFix() => _trackingGoogleMapHosted(
      'Live fix on route',
      _trackingGoogleMapInfo(
        position: _trackingGoogleMapCourier,
        polyline: _trackingGoogleMapRoute,
        status: PositionFreshness.live,
      ),
    );

/// Cold start: the route is known, the courier has never reported.
/// The state every tracking session opens in. No marker (there is nothing to
@JeebPreview(group: 'live_tracking', name: 'Awaiting first fix', size: _trackingGoogleMapBox)
Widget trackingGoogleMapAwaitingFirstFix() => _trackingGoogleMapHosted(
      'Awaiting first fix',
      _trackingGoogleMapInfo(
        polyline: _trackingGoogleMapRoute,
        status: PositionFreshness.awaitingFirstFix,
      ),
    );

/// **The negative control of the courier-marker P0.**
/// There IS a fix and the gateway still publishes its coordinates — a
@JeebPreview(group: 'live_tracking', name: 'Stale fix — no marker', size: _trackingGoogleMapBox)
Widget trackingGoogleMapStaleFix() => _trackingGoogleMapHosted(
      'Stale fix — no marker',
      _trackingGoogleMapInfo(
        position: _trackingGoogleMapCourier,
        polyline: _trackingGoogleMapRoute,
        stale: true,
        ageSeconds: 187,
        status: PositionFreshness.stale,
      ),
    );

/// The other half of the phantom pin: the gateway had this courier and lost
/// them.
@JeebPreview(group: 'live_tracking', name: 'Position lost', size: _trackingGoogleMapBox)
Widget trackingGoogleMapPositionLost() => _trackingGoogleMapHosted(
      'Position lost',
      _trackingGoogleMapInfo(
        polyline: _trackingGoogleMapRoute,
        stale: true,
        ageSeconds: 312.5,
        status: PositionFreshness.lost,
      ),
    );

/// One waypoint known: below the two-point floor, so NO route is drawn.
/// [trackingPolylines] returns an empty set under two points — a one-point
@JeebPreview(group: 'live_tracking', name: 'Single waypoint — no route', size: _trackingGoogleMapBox)
Widget trackingGoogleMapSingleWaypoint() => _trackingGoogleMapHosted(
      'Single waypoint — no route',
      _trackingGoogleMapInfo(
        polyline: const <GpsPoint>[_trackingGoogleMapDropoff],
        status: PositionFreshness.awaitingFirstFix,
      ),
    );

/// Nothing known at all — the true empty state.
/// No fix, no route, and no freshness verdict (a hand-built snapshot from a
@JeebPreview(group: 'live_tracking', name: 'Nothing known', size: _trackingGoogleMapBox)
Widget trackingGoogleMapNothingKnown() => _trackingGoogleMapHosted('Nothing known', _trackingGoogleMapInfo());
