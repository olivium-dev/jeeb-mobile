import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/delivery_tracking_info.dart';

/// T-MOB-017: live `GoogleMap` for the order-tracking screen (Figma 56560:1772).
///
/// Renders the route polyline and the Jeeber heading marker straight off the
/// [DeliveryTrackingInfo] the [LiveTrackingCubit] already parses from
/// `GET /deliveries/{id}/tracking` (polyline + position). The camera follows
/// the latest courier fix; when there is no fix yet it frames the polyline's
/// first point so the route is visible immediately.
///
/// This is the only live-tracking widget that touches `google_maps_flutter`
/// types; everything upstream stays on the domain [GpsPoint], so the cubit and
/// its tests never import the plugin. [TrackingMapSurface] decides between this
/// and the deterministic placeholder (dev seam / widget tests).
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

/// Initial camera: the courier fix when known, else the polyline's first point,
/// else Beirut downtown. Pure so it is unit-testable without a platform view.
CameraPosition trackingCamera(DeliveryTrackingInfo info) {
  final point = info.jeeberPosition ??
      (info.polyline.isNotEmpty ? info.polyline.first : null);
  final target = point != null
      ? LatLng(point.lat, point.lng)
      : const LatLng(33.8938, 35.5018);
  return CameraPosition(target: target, zoom: 14);
}

/// The Jeeber heading marker, rotated to its compass bearing. Pure so the marker
/// set is unit-testable.
///
/// EMPTY in two distinct cases, and the second one is the negative control of
/// the courier-marker P0:
///  * there is no GPS fix at all yet, and
///  * there IS a fix but the gateway flagged it `stale` — older than
///    `Tracking:StaleThreshold` (2 min). A pin left where the jeeber was ten
///    minutes ago reads as live and is worse than an honest blank: the customer
///    walks to a corner the courier already left. `markerIsLive` folds both
///    cases into one predicate so no future caller can render a marker while
///    skipping the freshness half.
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

/// The route polyline. Empty when fewer than two points are known. Pure so the
/// polyline set is unit-testable without a platform view.
///
/// Q-061 (pilot fidelity): the pilot renders a STRAIGHT-LINE route, not a
/// road-snapped or great-circle path — `geodesic: false` draws the polyline as
/// straight screen segments between the pickup and drop-off points the gateway
/// supplies (road-network routing is deferred post-pilot).
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
