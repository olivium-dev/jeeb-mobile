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
class GoogleMapCaptureView extends StatefulWidget {
  const GoogleMapCaptureView({
    super.key,
    required this.controller,
    this.gateway,
    this.onCameraSettled,
    this.initialZoom = 16,
    this.bottomInset = Spacing.large,
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

  LocationPoint get _initial => widget.controller.center;

  @override
  void initState() {
    super.initState();
    if (_mapStyle == null) {
      JeebMapStyle.load().then((String? style) {
        if (!mounted || style == null) return;
        setState(() => _mapStyle = style);
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
          onMapCreated: (controller) => _map = controller,
          onCameraMove: _onCameraMove,
          onCameraIdle: widget.onCameraSettled,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
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
