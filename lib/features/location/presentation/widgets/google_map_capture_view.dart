import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:omds/omds.dart';

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
    this.initialZoom = 16,
  });

  /// Two-way seam for the centre coordinate. The launcher owns it.
  final MapCaptureController controller;

  /// GPS source for the "centre on me" button. Injected so widget tests can
  /// pass a stub; production resolves the geolocator-backed gateway from DI.
  final GeolocatorGeocaptureGateway? gateway;

  final double initialZoom;

  @override
  State<GoogleMapCaptureView> createState() => _GoogleMapCaptureViewState();
}

class _GoogleMapCaptureViewState extends State<GoogleMapCaptureView> {
  GoogleMapController? _map;

  LocationPoint get _initial => widget.controller.center;

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
          onMapCreated: (controller) => _map = controller,
          onCameraMove: _onCameraMove,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        if (widget.gateway != null)
          _CentreOnMeButton(onPressed: _centreOnMe),
      ],
    );
  }
}

/// "Centre on my current location" affordance. Carries a Semantics identifier
/// so uiautomator/Maestro can target it; sits in the bottom-end corner clear of
/// the centre pin.
class _CentreOnMeButton extends StatelessWidget {
  const _CentreOnMeButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PositionedDirectional(
      bottom: Spacing.large,
      end: Spacing.large,
      child: Semantics(
        identifier: 'capture_location_my_location',
        button: true,
        label: l10n.captureLocationMyLocation,
        child: FloatingActionButton.small(
          heroTag: 'capture_location_my_location',
          onPressed: onPressed,
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }
}
