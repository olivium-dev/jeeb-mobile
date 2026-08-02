import 'package:flutter/material.dart';

import '../obs_overlay_controller.dart';

class ObsOverlayPanelHeader extends StatelessWidget {
  const ObsOverlayPanelHeader({super.key, required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Session Trace',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          key: const Key('obs-overlay-close'),
          tooltip: 'Close',
          icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
          onPressed: controller.toggleExpanded,
        ),
      ],
    );
  }
}
