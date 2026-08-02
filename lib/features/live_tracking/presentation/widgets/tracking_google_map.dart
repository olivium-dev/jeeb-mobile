import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/delivery_tracking_info.dart';

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
