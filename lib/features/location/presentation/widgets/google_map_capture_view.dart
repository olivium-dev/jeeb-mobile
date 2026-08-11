import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:omds/omds.dart';

import '../../../../core/map/jeeb_map_style.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../background_gps/data/geolocator_geocapture_gateway.dart';
import '../../data/location_repository.dart';
import 'map_capture_controller.dart';

/// Live `GoogleMap` viewport for the drop-off capture screen (T-MOB-012,
/// Figma 56546:2303). The map pans under the screen's fixed centre pin; this
/// widget reports the centre to [controller] on every camera-idle so the
/// "Pin Location" CTA can return the chosen coordinate. A "centre on my
/// location" affordance asks `geolocator` for a one-shot fix and animates the
/// camera there.
///
/// This is the only place that touches `google_maps_flutter` types — the
/// screen, launcher, cubit, and tests stay on the domain [LocationPoint], which
/// keeps `MapPickerLauncher` plugin-free and the Fakes the unit-test seam.
/// Marks the L10 cover so a test can assert the map is never shown unstyled.
const Key mapStyleCoverKey = Key('capture-map-style-cover');

class GoogleMapCaptureView extends StatefulWidget {
  const GoogleMapCaptureView({
    super.key,
    required this.controller,
    this.gateway,
    this.onCameraSettled,
    this.initialZoom = 16,
    this.bottomInset = Spacing.large,
    this.centreOnDeviceLocation = false,
    this.showZoomControls = false,
  });

  /// Two-way seam for the centre coordinate. The launcher owns it.
  final MapCaptureController controller;

  /// GPS source for the "centre on me" button. Injected so widget tests can
  /// pass a stub; production resolves the geolocator-backed gateway from DI.
  final GeolocatorGeocaptureGateway? gateway;

  /// Fires on every `onCameraIdle` — the ONLY proof the platform view really
  /// rendered a camera. Callers gate "return this coordinate" on it, so a map
  /// that never initialised (no SDK key, no view) cannot hand back the seed as
  /// if the customer had chosen it (JEBV4-176).
  final VoidCallback? onCameraSettled;

  final double initialZoom;

  /// How far above the bottom edge the floating "centre on me" control sits.
  /// The redesign docks a sheet over the bottom of this map, so the control
  /// has to clear it; the default keeps the pre-redesign placement for any
  /// caller that renders the map full-height.
  final double bottomInset;

  /// Centre the camera on the DEVICE once the map is created: the OS
  /// last-known fix first (instant), then the live one-shot fix. Callers that
  /// seed an explicit coordinate (editing a saved pin) leave it false — the
  /// saved point is the answer, not the phone's current whereabouts.
  final bool centreOnDeviceLocation;

  /// Native +/- buttons. Off by default (the redesign board draws none).
  final bool showZoomControls;

  @override
  State<GoogleMapCaptureView> createState() => _GoogleMapCaptureViewState();
}

class _GoogleMapCaptureViewState extends State<GoogleMapCaptureView> {
  GoogleMapController? _map;

  /// MIDNIGHT M0-6 — the dark map style JSON (null until the bundle read
  /// lands, and null forever if it fails; `GoogleMap.style` accepts null).
  /// Seeded from the process cache so a second mount never flashes the light
  /// default map.
  String? _mapStyle = JeebMapStyle.cached;

  /// L10 — the cache only covers the SECOND mount. On the first one the style
  /// is still on the wire, so a Midnight cover holds until the read settles.
  bool _styleSettled = JeebMapStyle.cached != null;

  LocationPoint get _initial => widget.controller.center;

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
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  void _onCameraMove(CameraPosition position) {
    widget.controller.updateCenter(
      LocationPoint(
        latitude: position.target.latitude,
        longitude: position.target.longitude,
      ),
    );
  }

  Future<void> _centreOnMe() async {
    final gateway = widget.gateway;
    if (gateway == null || _map == null) return;
    final fix = await gateway.currentFix();
    await _map?.animateCamera(
      CameraUpdate.newLatLng(LatLng(fix.latitude, fix.longitude)),
    );
  }

  Future<void> _zoomBy(double delta) async {
    await _map?.animateCamera(CameraUpdate.zoomBy(delta));
  }

  void _onMapCreated(GoogleMapController controller) {
    _map = controller;
    if (widget.centreOnDeviceLocation) unawaited(_centreOnDeviceLocation());
  }

  /// The picker used to open on the Beirut seed whatever the phone knew. Move
  /// to the cached OS fix at once, then to the live one when it lands; every
  /// failure leaves the seed on screen, which is the previous behaviour.
  Future<void> _centreOnDeviceLocation() async {
    final gateway = widget.gateway;
    if (gateway == null) return;
    try {
      final cached = await gateway.lastKnownFix();
      if (cached != null && mounted) {
        await _map?.moveCamera(
          CameraUpdate.newLatLng(LatLng(cached.latitude, cached.longitude)),
        );
      }
    } catch (_) {
      // No cached fix is not a failure state — the live read below still runs.
    }
    try {
      if (!mounted) return;
      await _centreOnMe();
    } catch (_) {
      // Permission denied / services off: the seed stays, and the user can
      // still pan. The recovery surfaces own the permission conversation.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(_initial.latitude, _initial.longitude),
            zoom: widget.initialZoom,
          ),
          style: _mapStyle,
          onMapCreated: _onMapCreated,
          onCameraMove: _onCameraMove,
          onCameraIdle: widget.onCameraSettled,
          myLocationButtonEnabled: false,
          // NEVER the native controls: they sit under the docked sheet, and
          // the `padding` that would lift them also moves the camera TARGET
          // away from the widget centre the fixed pin is drawn at.
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        if (!_styleSettled)
          Positioned.fill(
            key: mapStyleCoverKey,
            child: IgnorePointer(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
              ),
            ),
          ),
        if (widget.showZoomControls)
          _ZoomControls(
            onZoomIn: () => _zoomBy(1),
            onZoomOut: () => _zoomBy(-1),
            bottomInset: widget.bottomInset + _zoomControlsLift,
          ),
        if (widget.gateway != null)
          _CentreOnMeButton(
            onPressed: _centreOnMe,
            bottomInset: widget.bottomInset,
          ),
      ],
    );
  }
}

/// How far above the "centre on me" disc the zoom stack sits: the disc's own
/// diameter plus one gap.
const double _zoomControlsLift = Sizes.fourXLarge + Spacing.small;

/// Manual zoom, drawn as the same glass discs as the recentre control so it
/// clears the docked sheet — the native `zoomControlsEnabled` buttons cannot
/// (see the GoogleMap note above).
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.bottomInset,
  });

  final Future<void> Function() onZoomIn;
  final Future<void> Function() onZoomOut;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      bottom: bottomInset + MediaQuery.viewPaddingOf(context).bottom,
      end: Spacing.large,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GlassMapDisc(
            identifier: 'capture_location_zoom_in',
            icon: Icons.add,
            onPressed: onZoomIn,
          ),
          const SizedBox(height: Spacing.small),
          _GlassMapDisc(
            identifier: 'capture_location_zoom_out',
            icon: Icons.remove,
            onPressed: onZoomOut,
          ),
        ],
      ),
    );
  }
}

/// The Ø48 glass disc the map's floating controls are all drawn as.
class _GlassMapDisc extends StatelessWidget {
  const _GlassMapDisc({
    required this.identifier,
    required this.icon,
    required this.onPressed,
  });

  static const double _glyphSize = 22;

  final String identifier;
  final IconData icon;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glass = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Semantics(
      identifier: identifier,
      button: true,
      child: Container(
        width: Sizes.fourXLarge,
        height: Sizes.fourXLarge,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: glass.glassFillEmphasis,
          border: Border.all(color: glass.glassBorderVivid),
          boxShadow: JeebShadows.overlay,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Center(
              child: Icon(icon, size: _glyphSize, color: scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Centre on my current location" affordance. Carries a Semantics identifier
/// so uiautomator/Maestro can target it; sits in the bottom-end corner clear of
/// the centre pin.
///
/// MIDNIGHT R11: a Ø48 GLASS disc floating on the night map — `glassFill`
/// (measured white 12%) + a 1px vivid glass stroke + `JeebShadows.overlay`,
/// white glyph. Not a Material FAB: the board has no FAB shape anywhere.
class _CentreOnMeButton extends StatelessWidget {
  const _CentreOnMeButton({
    required this.onPressed,
    required this.bottomInset,
  });

  /// R11 — 22px sits between `Sizes.large` (20) and `Sizes.xLarge` (24).
  static const double _glyphSize = 22;

  final Future<void> Function() onPressed;

  /// Clearance for whatever is docked over the bottom of the map.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glass = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return PositionedDirectional(
      // The docked sheet ends at the safe-area edge, so the inset the caller
      // quotes is measured from there, not from the raw screen bottom.
      bottom: bottomInset + MediaQuery.viewPaddingOf(context).bottom,
      end: Spacing.large,
      child: Semantics(
        identifier: 'capture_location_my_location',
        button: true,
        label: l10n.captureLocationMyLocation,
        child: Container(
          width: Sizes.fourXLarge,
          height: Sizes.fourXLarge,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: glass.glassFillEmphasis,
            border: Border.all(color: glass.glassBorderVivid),
            boxShadow: JeebShadows.overlay,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Center(
                child: Icon(
                  Icons.my_location,
                  size: _glyphSize,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
