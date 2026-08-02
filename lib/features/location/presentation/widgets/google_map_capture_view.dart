import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../background_gps/data/geolocator_geocapture_gateway.dart';
import '../../data/location_repository.dart';
import 'map_capture_controller.dart';

class GoogleMapCaptureView extends StatefulWidget {
  const GoogleMapCaptureView({
    super.key,
    required this.controller,
    this.gateway,
    this.initialZoom = 16,
  });

  final MapCaptureController controller;

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
