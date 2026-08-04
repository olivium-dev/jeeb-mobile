import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/map/jeeb_map_style.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../domain/delivery_tracking_info.dart';

/// T-MOB-017: live `GoogleMap` for the order-tracking screen.
///
/// Renders the route polyline and the Jeeber marker straight off the
/// [DeliveryTrackingInfo] the [LiveTrackingCubit] already parses from
/// `GET /deliveries/{id}/tracking` (polyline + position). The camera follows
/// the latest courier fix; when there is no fix yet it frames the polyline's
/// first point so the route is visible immediately.
///
/// This is the only live-tracking widget that touches `google_maps_flutter`
/// types; everything upstream stays on the domain [GpsPoint], so the cubit and
/// its tests never import the plugin. [TrackingMapSurface] decides between this
/// and the deterministic placeholder (dev seam / widget tests).
///
/// redesign-2026-08 §C task 11: the route is a dotted navy trail and the courier
/// is an orange scooter disc (`12-live-tracking.html` tpl 756-760). Both are
/// painted from THEME values passed into the otherwise-pure builders — no colour
/// literal lives in this file.
/// The L10 cover that holds until the dark style lands on the first mount.
const Key trackingMapStyleCoverKey = Key('tracking-map-style-cover');

class TrackingGoogleMap extends StatefulWidget {
  const TrackingGoogleMap({super.key, required this.info});

  final DeliveryTrackingInfo info;

  static const String jeeberMarkerId = 'jeeber';
  static const String destinationMarkerId = 'destination';
  static const String routePolylineId = 'route';

  @override
  State<TrackingGoogleMap> createState() => _TrackingGoogleMapState();
}

class _TrackingGoogleMapState extends State<TrackingGoogleMap> {
  /// Board disc diameter (`tpl 758`), in logical px.
  static const double _courierDiscSize = 34;

  /// Glyph size inside the disc (`tpl 759`).
  static const double _courierGlyphSize = 19;

  GoogleMapController? _map;

  /// Rasterised once per [State], then reused on every rebuild — the map
  /// rebuilds on every position tick and re-encoding a PNG each time would be
  /// pure waste. Null means "not ready / generation failed", and the marker
  /// falls back to the platform default rather than disappearing.
  BitmapDescriptor? _courierIcon;

  /// Latched so a failed generation is not retried on every frame.
  bool _courierIconRequested = false;

  /// MIDNIGHT M0-6 — the dark map style JSON (null until the bundle read
  /// lands, and null forever if it fails; `GoogleMap.style` accepts null).
  /// Seeded from the process cache so a second mount never flashes the light
  /// default map.
  String? _mapStyle = JeebMapStyle.cached;

  /// L10 — the cache only covers the SECOND mount. On the first one the style
  /// is still on the wire, so a Midnight cover holds until the read settles.
  bool _styleSettled = JeebMapStyle.cached != null;

  @override
  void initState() {
    super.initState();
    if (!_styleSettled) {
      JeebMapStyle.load().then((String? style) {
        if (!mounted) return;
        setState(() {
          if (style != null) _mapStyle = style;
          _styleSettled = true;
        });
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Theme read — hence here and not initState.
    if (!_courierIconRequested) {
      _courierIconRequested = true;
      _startCourierIconRasterisation();
    }
  }

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

  /// Fire-and-forget rasterisation of the courier disc.
  ///
  /// Deliberately total: ANY failure (a platform without an image codec, a
  /// disposed engine mid-test) leaves [_courierIcon] null and the marker falls
  /// back to the default pin. A courier that is genuinely there must never
  /// vanish because a decoration could not be drawn.
  void _startCourierIconRasterisation() {
    final MediaQueryData media = MediaQuery.of(context);
    final Color fill = context.jeebRoles.accent;
    final Color glyph = context.jeebRoles.onAccent;
    _rasterizeCourierDisc(
      fill: fill,
      glyph: glyph,
      pixelRatio: media.devicePixelRatio,
    ).then((BitmapDescriptor? icon) {
      if (!mounted || icon == null) return;
      setState(() => _courierIcon = icon);
    });
  }

  static Future<BitmapDescriptor?> _rasterizeCourierDisc({
    required Color fill,
    required Color glyph,
    required double pixelRatio,
  }) async {
    try {
      final double ratio = pixelRatio <= 0 ? 1.0 : pixelRatio;
      final double size = _courierDiscSize * ratio;
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        size / 2,
        Paint()..color = fill,
      );

      final TextPainter painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(Icons.two_wheeler.codePoint),
          style: TextStyle(
            fontSize: _courierGlyphSize * ratio,
            fontFamily: Icons.two_wheeler.fontFamily,
            package: Icons.two_wheeler.fontPackage,
            color: glyph,
          ),
        ),
      )..layout();
      painter.paint(
        canvas,
        Offset((size - painter.width) / 2, (size - painter.height) / 2),
      );

      final ui.Image image = await recorder
          .endRecording()
          .toImage(size.round(), size.round());
      final ByteData? bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return null;
      return BitmapDescriptor.bytes(
        bytes.buffer.asUint8List(),
        imagePixelRatio: ratio,
      );
    } catch (_) {
      // Total by contract — see the doc on [_startCourierIconRasterisation].
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GoogleMap(
          initialCameraPosition: trackingCamera(widget.info),
          style: _mapStyle,
          onMapCreated: (controller) => _map = controller,
          markers: {
            ...trackingMarkers(widget.info, courierIcon: _courierIcon),
            ...trackingDestinationMarkers(widget.info),
          },
          polylines: trackingPolylines(
            widget.info,
            routeColor: Theme.of(context).colorScheme.primary,
          ),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          liteModeEnabled: false,
        ),
        if (!_styleSettled)
          Positioned.fill(
            key: trackingMapStyleCoverKey,
            child: IgnorePointer(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
              ),
            ),
          ),
      ],
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

/// The COURIER marker, and only the courier marker. Pure so the marker set is
/// unit-testable.
///
/// EMPTY in two distinct cases, and the second one is the negative control of
/// the courier-marker P0:
///  * there is no GPS fix at all yet, and
///  * there IS a fix but the gateway flagged it `stale` — older than
///    `Tracking:StaleThreshold` (2 min). A pin left where the jeeber was ten
///    minutes ago reads as live and is worse than an honest blank: the customer
///    walks to a corner the courier already left. `markerIsLive` folds both
///    cases into one predicate so no future caller can render a marker while
///    skipping the freshness half — it stays the ONLY courier-marker predicate.
///
/// **The drop-off pin is deliberately NOT folded in here** (it lives in
/// [trackingDestinationMarkers]). `tracking_position_status_test.dart:250/324/
/// 361/388` and `tracking_live_position_overlay_test.dart:148` all assert
/// `trackingMarkers(...) isEmpty` on rows whose polyline is explicitly
/// non-empty — this function's emptiness IS the phantom-pin contract, and a
/// destination marker inside it would make "no pin for a courier we cannot
/// vouch for" unassertable. Two functions, two questions.
///
/// [courierIcon] is optional: null falls back to the platform default pin,
/// never to no marker.
Set<Marker> trackingMarkers(
  DeliveryTrackingInfo info, {
  BitmapDescriptor? courierIcon,
}) {
  final pos = info.jeeberPosition;
  if (pos == null || !info.markerIsLive) return const <Marker>{};
  return {
    Marker(
      markerId: const MarkerId(TrackingGoogleMap.jeeberMarkerId),
      position: LatLng(pos.lat, pos.lng),
      flat: true,
      anchor: const Offset(0.5, 0.5),
      icon: courierIcon ?? BitmapDescriptor.defaultMarker,
    ),
  };
}

/// The drop-off pin at the end of the route (`tpl 761-763` — the red teardrop).
///
/// Mounts only when a route is actually known (two points or more); a single
/// point is the courier's own position, not a destination.
///
/// RISK (open, §F-2): this assumes `polyline.last` IS the drop-off. That is
/// asserted by the gateway contract comment only — confirm against one real
/// gateway response before trusting the pin's position.
Set<Marker> trackingDestinationMarkers(
  DeliveryTrackingInfo info, {
  BitmapDescriptor? destinationIcon,
}) {
  if (info.polyline.length < 2) return const <Marker>{};
  final destination = info.polyline.last;
  return {
    Marker(
      markerId: const MarkerId(TrackingGoogleMap.destinationMarkerId),
      position: LatLng(destination.lat, destination.lng),
      icon: destinationIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
///
/// redesign-2026-08: dotted, round-capped (`tpl 757`), inked by the caller's
/// `colorScheme.primary` — under Midnight that is ORANGE, never the board navy.
Set<Polyline> trackingPolylines(
  DeliveryTrackingInfo info, {
  Color? routeColor,
}) {
  // `stroke-dasharray: 1 11` on the board (`tpl 757`) — a round dot every 11px.
  const double routeDotGap = 11;
  if (info.polyline.length < 2) return const <Polyline>{};
  final line = Polyline(
    polylineId: const PolylineId(TrackingGoogleMap.routePolylineId),
    points: [
      for (final p in info.polyline) LatLng(p.lat, p.lng),
    ],
    width: 5,
    geodesic: false,
    startCap: Cap.roundCap,
    endCap: Cap.roundCap,
    jointType: JointType.round,
    patterns: <PatternItem>[PatternItem.dot, PatternItem.gap(routeDotGap)],
  );
  return {routeColor == null ? line : line.copyWith(colorParam: routeColor)};
}
