import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import 'widgets/capture_location_pin.dart';
import 'widgets/capture_map_viewport.dart';

/// "Capture Location" screen (Figma 56546:2303) — a full-screen map picker.
///
/// The map pans under a fixed centre pin; the user positions the desired
/// point under the pin tip and confirms with the bottom "Pin Location" CTA,
/// which returns the coordinates to the delivery-create flow.
///
/// Live map tiles are provided by the `ofl_geo_capture` wrap (reuse-table
/// "Delivery create → wrap" verdict). That package is not yet resolvable in
/// this worktree, so [mapBuilder] is injected: production passes the
/// geo-capture map widget; the dev seam / tests pass a neutral placeholder.
/// The Figma map raster is a mock and is never bundled.
class CaptureLocationScreen extends StatelessWidget {
  const CaptureLocationScreen({
    super.key,
    this.onPinned,
    this.mapBuilder,
    this.isConfirming = false,
  });

  /// Invoked when the user confirms the pinned point. Defaults to a back-pop.
  final VoidCallback? onPinned;

  /// Builds the map viewport. When null a neutral [CaptureMapViewport]
  /// placeholder is rendered (dev seam / offline).
  final WidgetBuilder? mapBuilder;

  /// When true the CTA shows a busy state (reverse-geocode / save in flight).
  final bool isConfirming;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: OMDSAppBar(
        title: l10n.captureLocationTitle,
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: _Body(
          mapBuilder: mapBuilder,
          onPinned: onPinned,
          isConfirming: isConfirming,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.mapBuilder,
    required this.onPinned,
    required this.isConfirming,
  });

  final WidgetBuilder? mapBuilder;
  final VoidCallback? onPinned;
  final bool isConfirming;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _MapStack(mapBuilder: mapBuilder)),
        _PinCta(onPinned: onPinned, isConfirming: isConfirming),
      ],
    );
  }
}

/// Bottom "Pin Location" confirm CTA. `OmdsPrimaryButton` owns the ≥48dp tap
/// height; the Semantics id lets Maestro target it.
class _PinCta extends StatelessWidget {
  const _PinCta({required this.onPinned, required this.isConfirming});

  final VoidCallback? onPinned;
  final bool isConfirming;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.large,
        Spacing.medium,
        Spacing.large,
        Spacing.medium,
      ),
      child: Semantics(
        identifier: 'capture_location_pin_cta',
        button: true,
        child: OmdsPrimaryButton(
          text: l10n.captureLocationPinCta,
          isEnabled: !isConfirming,
          onTap: () => _onPin(context),
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
