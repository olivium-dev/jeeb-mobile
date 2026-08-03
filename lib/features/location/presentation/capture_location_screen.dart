import 'package:flutter/material.dart';

import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import 'widgets/capture_location_pin.dart';
import 'widgets/capture_map_viewport.dart';
import 'widgets/capture_picker_sheet.dart';
import 'widgets/map_capture_controller.dart';

/// "Capture Location" — the map-first pin picker (redesign-2026-08 screen 09).
///
/// The map runs full-bleed to every edge; the chrome floats on top of it: a
/// circular back button under the status bar, and a docked sheet carrying the
/// pinned point and the "Pin Location" CTA. The map pans under a fixed centre
/// pin, so the point the user is choosing is always the viewport centre.
///
/// Live map tiles are provided by the `google_maps_flutter` view, injected as
/// [mapBuilder]: production passes it (via `GoogleMapPickerLauncher`), the dev
/// seam / tests pass nothing and get a neutral placeholder. The board's map
/// raster is a mock and is never bundled.
class CaptureLocationScreen extends StatelessWidget {
  const CaptureLocationScreen({
    super.key,
    this.onPinned,
    this.mapBuilder,
    this.isConfirming = false,
    this.controller,
  });

  /// Invoked when the user confirms the pinned point. Defaults to a back-pop.
  final VoidCallback? onPinned;

  /// Builds the map viewport. When null a neutral [CaptureMapViewport]
  /// placeholder is rendered (dev seam / offline).
  final WidgetBuilder? mapBuilder;

  /// When true the CTA shows a busy state (reverse-geocode / save in flight).
  final bool isConfirming;

  /// The live map centre, when one exists. Supplied together with [mapBuilder]
  /// by `GoogleMapPickerLauncher`; the router's placeholder path passes none,
  /// so the sheet renders without a coordinate card rather than invent one.
  final MapCaptureController? controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // No SafeArea around the map — it runs to the top edge, and the floating
    // chrome carries the inset itself.
    final topPad = MediaQuery.viewPaddingOf(context).top;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Semantics(
        identifier: 'capture_location_root',
        container: true,
        explicitChildNodes: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _MapStack(mapBuilder: mapBuilder),
            PositionedDirectional(
              start: 0,
              end: 0,
              top: topPad,
              child: JeebTopBar.back(
                leadingTreatment: JeebTopBarLeadingTreatment.floating,
                identifier: 'capture_location_back',
                onLeadingPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: CapturePickerSheet(
                onPin: () => _onPin(context),
                isConfirming: isConfirming,
                controller: controller,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPin(BuildContext context) {
    final handler = onPinned;
    if (handler != null) {
      handler();
    } else {
      Navigator.of(context).maybePop();
    }
  }
}

/// The map viewport with the fixed centre pin layered on top. The pin never
/// moves — the map pans underneath — so it sits in an [IgnorePointer] overlay.
class _MapStack extends StatelessWidget {
  const _MapStack({required this.mapBuilder});

  final WidgetBuilder? mapBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          identifier: 'capture_location_map',
          label: l10n.captureLocationMapSemantic,
          child: mapBuilder?.call(context) ?? const CaptureMapViewport(),
        ),
        const Center(child: CaptureLocationPin()),
      ],
    );
  }
}
