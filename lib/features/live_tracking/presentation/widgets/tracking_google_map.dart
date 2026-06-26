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

/// The Jeeber heading marker, rotated to its compass bearing. Empty when there
/// is no GPS fix yet. Pure so the marker set is unit-testable.
Set<Marker> trackingMarkers(DeliveryTrackingInfo info) {
  final pos = info.jeeberPosition;
  if (pos == null) return const <Marker>{};
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
Set<Polyline> trackingPolylines(DeliveryTrackingInfo info) {
  if (info.polyline.length < 2) return const <Polyline>{};
  return {
    Polyline(
      polylineId: const PolylineId(TrackingGoogleMap.routePolylineId),
      points: [
        for (final p in info.polyline) LatLng(p.lat, p.lng),
      ],
      width: 5,
      geodesic: true,
    ),
  };
}
