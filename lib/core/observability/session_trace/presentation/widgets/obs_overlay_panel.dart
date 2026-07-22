import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../obs_overlay_controller.dart';
import 'obs_overlay_control_bar.dart';
import 'obs_overlay_event_list.dart';
import 'obs_overlay_export_button.dart';
import 'obs_overlay_filter_bar.dart';
import 'obs_overlay_panel_header.dart';

/// Expanded state of the devtool overlay: a frosted floating card with the
/// live event list, the type filter, the session controls, and the
/// export/share action. OMDS has no token for "how much of the screen a
/// floating devtool panel should occupy" (a layout decision, not a spacing
/// /color/radius/duration design value), so [_kMaxWidth]/[_kHeightFraction]
/// are this panel's own named, commented constants rather than bare
/// literals sprinkled through `build()`.
class ObsOverlayPanel extends StatelessWidget {
  const ObsOverlayPanel({super.key, required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: Spacing.medium,
      bottom: Spacing.xLarge,
      child: _PanelShell(controller: controller),
    );
  }
}

const double _kMaxWidth = 340;
const double _kHeightFraction = 0.62;

class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    return OMDSGlassCard(
      width: _widthFor(size.width),
      height: size.height * _kHeightFraction,
      backgroundColor: colorScheme.surface.withValues(
        alpha: UIConstants.opacityHigh,
      ),
      borderRadius: OMDSBorderRadius.lg,
      padding: const EdgeInsets.all(Spacing.medium),
      // `ListTile`-based OMDS rows (used by the event list) expect a
      // `Material` ancestor for ink/selection; `OMDSGlassCard` is a
      // blur+container, not a `Material`, so this provides one invisibly.
      child: Material(
        type: MaterialType.transparency,
        child: _PanelBody(controller: controller),
      ),
    );
  }

  double _widthFor(double screenWidth) {
    final maxAvailable = screenWidth - Spacing.xLarge;
    return _kMaxWidth < maxAvailable ? _kMaxWidth : maxAvailable;
  }
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ObsOverlayPanelHeader(controller: controller),
        const SizedBox(height: Spacing.xSmall),
        ObsOverlayFilterBar(controller: controller),
        const SizedBox(height: Spacing.xSmall),
        Expanded(child: ObsOverlayEventList(controller: controller)),
        const SizedBox(height: Spacing.xSmall),
        ObsOverlayControlBar(controller: controller),
        const SizedBox(height: Spacing.xSmall),
        ObsOverlayExportButton(controller: controller),
      ],
    );
  }
}
