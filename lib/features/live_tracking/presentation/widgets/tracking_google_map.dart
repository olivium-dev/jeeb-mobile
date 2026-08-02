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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/live_tracking/tracking_google_map_preview_test.dart
// ===========================================================================
// Widget previews for [TrackingGoogleMap] — run with
// `flutter widget-preview start`.
//
// ## What you can and cannot see here
//
// [TrackingGoogleMap] draws NOTHING on the Flutter side. Its whole build is a
// `GoogleMap` — a platform view whose pixels belong to the native (or, on web,
// JS) Maps SDK, reached through an `AndroidView` / `UiKitView` /
// `HtmlElementView`. Under `flutter test` that view is never initialised, so
// the map band measures and lays out but paints nothing; and the preview
// canvas is a generated Flutter **web** app whose `index.html` does not load
// the Google Maps JS API (this repo ships no `web/` target to add the script
// to), so the band is blank there too. Expect no map tile, no route line and
// no courier pin in the canvas, whatever these previews pass in.
//
// That does not make the widget unreviewable — it moves what is worth
// reviewing. Everything [TrackingGoogleMap] decides, it decides in the three
// pure builders it hands the platform view: [trackingCamera],
// [trackingMarkers] and [trackingPolylines]. That is also where the P0 of this
// feature lives — a courier pin left at a corner the jeeber abandoned ten
// minutes ago reads as live and walks the customer to the wrong place — and it
// is invisible in a map raster anyway, because a stale pin and a live pin are
// the same pin.
//
// So every preview below mounts the REAL [TrackingGoogleMap] (its `build`,
// `didUpdateWidget` and `dispose` all run) inside a frame that reports what
// the map was handed — the freshness verdict, the marker count, the route
// point count and the camera target, as one line of text such as
// `stale · markers 0 · route 2 pts · camera 33.8900,35.5000`.
//
// The readout is derived from the widget's own builders, so if the
// staleness half of [DeliveryTrackingInfo.markerIsLive] is ever dropped, the
// stale preview flips from `markers 0` to `markers 1` in the canvas and in
// `test/previews/live_tracking/tracking_google_map_preview_test.dart`.
//
// Fixture coordinates are the ones already pinned in
// `test/tracking_google_map_test.dart` and
// `test/features/live_tracking/tracking_position_status_test.dart`, so the
// previews and the unit tests describe the same delivery.
//
// Network-free by construction: [DeliveryTrackingInfo] is a plain value object
// built inline. There is no cubit and no repository in this file.

/// Phone width, and enough height for a map band plus the two caption lines.
const Size _trackingGoogleMapBox = Size(390, 380);

/// The canonical pickup point of the pilot route (`tracking_google_map_test`
/// "straight line pickup→dropoff"). Note it is ALSO the literal Beirut-downtown
/// constant [trackingCamera] falls back to when nothing at all is known — a
/// coincidence in the fixture, not in the code, and one worth knowing about
/// before reading two previews as identical.
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
///
/// The band is `Expanded` rather than a fixed [SizedBox] so the captions keep
/// their room at the 200%-text rendering instead of being pushed off the
/// canvas — the map is the part that can afford to shrink here, being blank in
/// the canvas regardless.
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
///
/// One marker, the two-point straight-line route, and the camera framing the
/// courier rather than the route — [trackingCamera] prefers the fix, because a
/// customer watching this screen is watching the jeeber, not the geometry.
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
///
/// The state every tracking session opens in. No marker (there is nothing to
/// mark), and the camera falls back to the polyline's FIRST point so the route
/// is on screen immediately instead of the map opening on a default city
/// centre. If this preview's camera ever reads `33.8938,35.5018` for the wrong
/// reason — the Beirut constant rather than the pickup — the two are
/// numerically identical here; the `route 2 pts` half of the readout is what
/// tells them apart.
@JeebPreview(group: 'live_tracking', name: 'Awaiting first fix', size: _trackingGoogleMapBox)
Widget trackingGoogleMapAwaitingFirstFix() => _trackingGoogleMapHosted(
      'Awaiting first fix',
      _trackingGoogleMapInfo(
        polyline: _trackingGoogleMapRoute,
        status: PositionFreshness.awaitingFirstFix,
      ),
    );

/// **The negative control of the courier-marker P0.**
///
/// There IS a fix and the gateway still publishes its coordinates — a
/// stationary courier legitimately uploads nothing for minutes, the uploader
/// runs on a 10 m `distanceFilter` — but the fix is older than
/// `Tracking:StaleThreshold` (2 min), so [DeliveryTrackingInfo.markerIsLive] is
/// false and the map must draw NO marker. A pin where the jeeber was three
/// minutes ago reads as live and sends the customer to a corner the courier
/// already left.
///
/// The camera still frames the last known coordinates, which is correct: the
/// area is still the right area, only the pin's precision is not vouched for.
///
/// This is the preview to look at first after any change to the marker
/// pipeline. `markers 1` here is the regression.
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
///
/// Past `Tracking:PositionTtl` the gateway publishes an AGE with no
/// coordinates, and that pairing is the entire signal separating this from
/// "awaiting first fix". The map drops the marker and keeps the route, so the
/// customer still sees where the delivery is going.
///
/// Note what this preview cannot show, and what it therefore proves about the
/// widget rather than about the preview: [TrackingGoogleMap] renders no
/// explanation. The "we lost them, it has been 5 min" copy lives one layer up,
/// in `CourierPositionNotice`, which `TrackingMapSurface` stacks over this
/// widget — so on its own this map is indistinguishable from a cold start.
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
///
/// [trackingPolylines] returns an empty set under two points — a one-point
/// `Polyline` is not a line — while [trackingCamera] happily frames that single
/// point. The result is a map centred on a spot with nothing on it, which is
/// the honest rendering and worth having seen once: the camera and the route
/// disagree about whether the polyline is usable, by design.
@JeebPreview(group: 'live_tracking', name: 'Single waypoint — no route', size: _trackingGoogleMapBox)
Widget trackingGoogleMapSingleWaypoint() => _trackingGoogleMapHosted(
      'Single waypoint — no route',
      _trackingGoogleMapInfo(
        polyline: const <GpsPoint>[_trackingGoogleMapDropoff],
        status: PositionFreshness.awaitingFirstFix,
      ),
    );

/// Nothing known at all — the true empty state.
///
/// No fix, no route, and no freshness verdict (a hand-built snapshot from a
/// devtool seam or an old gateway leaves `positionStatus` null, which means
/// "nobody told us", not "everything is fine"). The camera falls back to the
/// hardcoded Beirut-downtown constant `33.8938, 35.5018`.
///
/// Worth its own preview because it is the one state where the widget shows a
/// confidently-framed city centre that has no relationship to this delivery,
/// and nothing on the map says so.
@JeebPreview(group: 'live_tracking', name: 'Nothing known', size: _trackingGoogleMapBox)
Widget trackingGoogleMapNothingKnown() => _trackingGoogleMapHosted('Nothing known', _trackingGoogleMapInfo());
