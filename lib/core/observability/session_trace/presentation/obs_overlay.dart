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
        _ObsOverlayLayer(controller: _controller),
      ],
    );
  }
}

/// Gives the bubble/panel their OWN [Overlay] ancestor.
///
/// `ObsOverlayHost` is mounted from `MaterialApp.router`'s `builder:`
/// (`lib/app/app.dart`), where the incoming `child` is the ALREADY-BUILT
/// `Router`/`Navigator` — the app's real [Overlay] lives INSIDE that
/// subtree, not around it. Placing the bubble/panel as a `Stack` SIBLING of
/// that `child` (the previous shape of this file) put every `Tooltip`-
/// bearing descendant (e.g. `ObsOverlayPanelHeader`'s close button, which
/// sets `tooltip: 'Close'`) outside any `Overlay` ancestor. `Tooltip`
/// resolves its `Overlay` during `build()` — not only on hover/long-press —
/// so this threw "No Overlay widget found" the instant the panel first
/// expanded; the substituted `ErrorWidget`'s large intrinsic diagnostic-text
/// size (not an unbounded layout in `ObsOverlayPanel` itself, which was
/// already `_kHeightFraction`-bounded with an `Expanded` event list) is what
/// produced the companion "BOTTOM OVERFLOWED BY 99778 PIXELS" — one root
/// cause, two visible symptoms.
///
/// A private, dedicated `Overlay` — entirely separate from the app's real
/// one, and never the nearest ancestor for anything inside the routed
/// `child` — is the standard Flutter shape for floating chrome mounted
/// outside the routed tree (the same shape `Navigator` itself uses
/// internally).
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

/// The actual floating content hosted by [_ObsOverlayLayer]'s `Overlay`: a
/// full-screen [Stack] (the theatre the `Overlay` sizes to) whose single
/// reactive child is the collapsed bubble or the expanded panel. The [Stack]
/// is REQUIRED, not decorative: both [ObsOverlayBubble] and [ObsOverlayPanel]
/// return a [Positioned] to anchor themselves bottom-right, and `Positioned`
/// is a `ParentDataWidget` that must resolve against a `Stack` — without one
/// it is ignored and the child inherits the overlay's tight full-screen
/// constraints and balloons to fill the screen. Ink/selection `Material`
/// ancestors are supplied locally by the bubble (`_BubbleButton`) and the
/// panel (`_PanelShell`), so none is needed at this level.
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
