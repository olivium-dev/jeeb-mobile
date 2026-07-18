import 'package:flutter/material.dart';

import '../observability_config.dart';
import 'obs_overlay_controller.dart';
import 'widgets/obs_overlay_bubble.dart';
import 'widgets/obs_overlay_panel.dart';

/// Devtool-only in-app overlay for the Jeeb session-trace tool: a floating
/// bubble that expands into a live event panel (filter by the four signal
/// types), a session start/stop/clear control, and an export/share action
/// for the current session's JSONL file.
///
/// ## Mounting this overlay (integration step, NOT done by this file)
///
/// Wrap the app's routed content — the same `child` that
/// `PushBannerHost`/`jeebA11yBuilder` already wrap in `lib/app/app.dart`'s
/// `builder:` (or the equivalent spot in `DevToolApp`/`main_devtool.dart`)
/// — additively, gated on the SAME compile flag every other wiring point in
/// this tool uses, so a production build tree-shakes this class out
/// entirely:
///
/// ```dart
/// builder: (context, child) {
///   final routed = /* ...existing PushBannerHost/jeebA11yBuilder wrapping... */;
///   return kObsCompiledIn ? ObsOverlayHost(child: routed) : routed;
/// },
/// ```
///
/// This file does not perform that wiring itself (additive-only scope — see
/// the architecture contract §6): it only defines the widget to be mounted.
class ObsOverlayHost extends StatefulWidget {
  const ObsOverlayHost({super.key, required this.child});

  /// The app's existing routed content — rendered untouched, underneath
  /// this overlay's bubble/panel layer.
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
    // Belt-and-braces (mirrors `ObsFileWriter.installAsGlobal`'s own
    // internal check): if a future refactor ever constructs this widget
    // without gating the call site on `kObsCompiledIn`, render `child`
    // UNCHANGED rather than throwing — the hard guarantee for this tool is
    // "the app behaves exactly as before when disabled", which a thrown
    // error here would violate.
    if (!kObsCompiledIn) return widget.child;
    return Stack(
      children: [
        widget.child,
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _controller.expanded
              ? ObsOverlayPanel(controller: _controller)
              : ObsOverlayBubble(controller: _controller),
        ),
      ],
    );
  }
}
