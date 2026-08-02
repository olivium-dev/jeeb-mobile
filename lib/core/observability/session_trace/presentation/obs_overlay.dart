import 'package:flutter/material.dart';

import '../observability_config.dart';
import 'obs_overlay_controller.dart';
import 'widgets/obs_overlay_bubble.dart';
import 'widgets/obs_overlay_panel.dart';

class ObsOverlayHost extends StatefulWidget {
  const ObsOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  State<ObsOverlayHost> createState() => _ObsOverlayHostState();
}

class _ObsOverlayHostState extends State<ObsOverlayHost> {
  final ObsOverlayController _controller = ObsOverlayController();

  @override
  void initState() {
    super.initState();
    _controller.attach();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kObsCompiledIn) return widget.child;
    return Stack(
      children: [
        widget.child,
        _ObsOverlayLayer(controller: _controller),
      ],
    );
  }
}

class _ObsOverlayLayer extends StatelessWidget {
  const _ObsOverlayLayer({required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (_) => _ObsOverlayContent(controller: controller),
        ),
      ],
    );
  }
}

class _ObsOverlayContent extends StatelessWidget {
  const _ObsOverlayContent({required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.expanded
              ? ObsOverlayPanel(controller: controller)
              : ObsOverlayBubble(controller: controller),
        ),
      ],
    );
  }
}
