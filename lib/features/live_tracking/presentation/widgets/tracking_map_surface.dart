import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_tracking_info.dart';

/// Full-bleed live map for the order-tracking screen (Figma 56560:1772).
///
/// Renders the real Google Map raster with the courier heading puck
/// ([jeeberPosition]) and the route polyline ([routePoints]) the gateway
/// tracking feed streams (`DeliveryTrackingInfo.jeeberPosition` / `.polyline`,
/// T-MOB-017). Coordinates arrive as domain [GpsPoint]s so the screen + cubit
/// never import `google_maps_flutter`; the conversion to map-SDK `LatLng`
/// happens here at the platform seam.
///
/// Null/empty position is handled gracefully: the camera falls back to the
/// last known route point, else the Riyadh city centre, so the surface is
/// always deterministic before the first GPS fix.
class TrackingMapSurface extends StatefulWidget {
  const TrackingMapSurface({
    super.key,
    this.jeeberPosition,
    this.routePoints = const <GpsPoint>[],
  });

  /// Latest courier GPS fix. Null until the tracking feed delivers one.
  final GpsPoint? jeeberPosition;

  /// Route polyline coordinates (pickup → drop-off). May be empty.
  final List<GpsPoint> routePoints;

  static const Key rootKey = Key('tracking_map');

  /// Riyadh city centre — the deterministic camera fallback before any fix.
  static const LatLng _riyadhFallback = LatLng(24.7136, 46.6753);

  @override
  State<TrackingMapSurface> createState() => _TrackingMapSurfaceState();
}

class _TrackingMapSurfaceState extends State<TrackingMapSurface> {
  GoogleMapController? _controller;

  static const Key _courierMarkerId = Key('tracking_map_courier');

  LatLng get _cameraTarget {
    final pos = widget.jeeberPosition;
    if (pos != null) return LatLng(pos.lat, pos.lng);
    if (widget.routePoints.isNotEmpty) {
      final last = widget.routePoints.last;
      return LatLng(last.lat, last.lng);
    }
    return TrackingMapSurface._riyadhFallback;
  }

  Set<Marker> get _markers {
    final pos = widget.jeeberPosition;
    if (pos == null) return const <Marker>{};
    return {
      Marker(
        markerId: MarkerId(_courierMarkerId.toString()),
        position: LatLng(pos.lat, pos.lng),
        rotation: 0,
        anchor: const Offset(0.5, 0.5),
      ),
    };
  }

  Set<Polyline> get _polylines {
    if (widget.routePoints.length < 2) return const <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('tracking_route'),
        points: [
          for (final p in widget.routePoints) LatLng(p.lat, p.lng),
        ],
        width: 4,
        color: Theme.of(context).colorScheme.primary,
      ),
    };
  }

  @override
  void didUpdateWidget(covariant TrackingMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jeeberPosition != widget.jeeberPosition) {
      _controller?.animateCamera(CameraUpdate.newLatLng(_cameraTarget));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tracking_map',
      image: true,
      label: l10n.trackingMapSemanticLabel,
      child: Container(
        key: TrackingMapSurface.rootKey,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: GoogleMap(
          mapType: MapType.normal,
          initialCameraPosition: CameraPosition(target: _cameraTarget, zoom: 14),
          markers: _markers,
          polylines: _polylines,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (c) => _controller = c,
        ),
      ),
    );
  }
}
