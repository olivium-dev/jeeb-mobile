import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../obs_overlay_controller.dart';

/// Collapsed state of the devtool overlay: a small floating circular toggle
/// docked to the bottom-right corner. Tapping it expands `ObsOverlayPanel`.
///
/// There is no dedicated OMDS "floating toggle bubble" component to reuse
/// (the closest primitives are `Material` + `InkWell`, which OMDS itself
/// builds its own chips/buttons from) — this widget is the small, novel
/// affordance a live devtool overlay needs on top of those primitives.
class ObsOverlayBubble extends StatelessWidget {
  const ObsOverlayBubble({super.key, required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: Spacing.medium,
      bottom: Spacing.xLarge,
      child: Semantics(
        identifier: 'obs_overlay_bubble',
        button: true,
        label: 'Session trace overlay',
        child: _BubbleButton(controller: controller),
      ),
    );
  }
}

class _BubbleButton extends StatelessWidget {
  const _BubbleButton({required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('obs-overlay-bubble'),
      color: colorScheme.primaryContainer,
      shape: const CircleBorder(),
      elevation: UIConstants.elevationMedium,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: controller.toggleExpanded,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.small),
          child: _BubbleIcon(controller: controller),
        ),
      ),
    );
  }
}

class _BubbleIcon extends StatelessWidget {
  const _BubbleIcon({required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: Sizes.xLarge,
      height: Sizes.xLarge,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.data_object, color: colorScheme.onPrimaryContainer),
          if (controller.recording)
            Positioned(
              right: -Spacing.twoXSmall,
              top: -Spacing.twoXSmall,
              child: _RecordingDot(color: colorScheme.error),
            ),
        ],
      ),
    );
  }
}

class _RecordingDot extends StatelessWidget {
  const _RecordingDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Sizes.xSmall,
      height: Sizes.xSmall,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
