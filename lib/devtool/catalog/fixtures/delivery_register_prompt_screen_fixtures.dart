// Shared dev-only fixtures for `DeliveryRegisterPromptScreen`.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Where `context.go('/')` lands inside the fixture router — the app shell.
/// Public so the render test can tell "the exit reached a page" apart from "the
const String deliveryRegisterPromptScreenShellStandInLabel =
    'app shell (preview stand-in)';

/// Where `context.goNamed('jeeber-onboarding')` lands — the JM-039 wizard.
/// Public so the render test can follow the CTA and then inspect the stack it
const String deliveryRegisterPromptScreenOnboardingStandInLabel =
    'jeeber onboarding wizard (preview stand-in)';

/// The offer-KYC gate, the screen `gate_register_link` comes FROM.
/// Only reachable in the `poppable: true` state — in production the gate is
const String deliveryRegisterPromptScreenGateStandInLabel =
    'offer-KYC gate (preview stand-in)';

/// One simulated device window to render [DeliveryRegisterPromptScreen] in.
/// The frame has to be pinned by the fixture rather than left to the canvas
@immutable
class DeliveryRegisterPromptScreenWindow {
  const DeliveryRegisterPromptScreenWindow({
    required this.label,
    required this.size,
    this.insets = EdgeInsets.zero,
    this.textScale,
  });

  /// Caption painted above the frame, and the string each preview is pinned by.
  /// This screen renders the same four strings in every state, so without a
  final String label;

  /// Logical size of the simulated display.
  final Size size;

  /// System-chrome insets (`MediaQuery.padding`) — status bar, home indicator.
  final EdgeInsets insets;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  final double? textScale;
}

/// The named windows this screen is reviewed in.
final class DeliveryRegisterPromptScreenWindows {
  DeliveryRegisterPromptScreenWindows._();

  /// The reference reading: an ordinary modern phone, no system chrome claimed,
  /// and the production stack (nothing to pop).
  static const DeliveryRegisterPromptScreenWindow phone =
      DeliveryRegisterPromptScreenWindow(
    label: 'Phone · 390 × 844 · 100% text · stack root',
    size: Size(390, 844),
  );

  /// The smallest display the app still has to look right on (iPhone SE 1st gen
  /// class). The body is a `ListView` with an icon, a headline, a paragraph and
  static const DeliveryRegisterPromptScreenWindow compact =
      DeliveryRegisterPromptScreenWindow(
    label: 'Compact · 320 × 568 · 100% text',
    size: Size(320, 568),
  );

  /// A notched phone in portrait: 59 pt status bar, 34 pt home indicator.
  /// `app_router.dart` mounts this screen as a bare top-level `GoRoute` — no
  static const DeliveryRegisterPromptScreenWindow notched =
      DeliveryRegisterPromptScreenWindow(
    label: 'Notched · 393 × 852 · inset 59/34',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
  );

  /// The accessibility ceiling on an ORDINARY phone — not an edge case, and the
  /// window in which this screen first stops fitting: 180 pt of scroll in EN,
  static const DeliveryRegisterPromptScreenWindow phoneLargeText =
      DeliveryRegisterPromptScreenWindow(
    label: 'Phone · 390 × 844 · 200% text',
    size: Size(390, 844),
    textScale: 2,
  );

  /// The worst case the app supports: the smallest display AND the largest
  /// text. This is the window that decides whether either action on the screen
  static const DeliveryRegisterPromptScreenWindow compactLargeText =
      DeliveryRegisterPromptScreenWindow(
    label: 'Compact · 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );

  /// The notched phone at the accessibility ceiling — the one combination in
  /// which the body actually SCROLLS on a device that has a home indicator, and
  static const DeliveryRegisterPromptScreenWindow notchedLargeText =
      DeliveryRegisterPromptScreenWindow(
    label: 'Notched · 393 × 852 · inset 59/34 · 200% text',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
    textScale: 2,
  );

  /// The ordinary phone again, reviewed for its NAVIGATION state rather than
  /// its geometry: the screen with the gate still underneath it.
  static const DeliveryRegisterPromptScreenWindow phonePushed =
      DeliveryRegisterPromptScreenWindow(
    label: 'Phone · 390 × 844 · pushed from the gate',
    size: Size(390, 844),
  );
}

/// Hosts `DeliveryRegisterPromptScreen` in one
/// [DeliveryRegisterPromptScreenWindow], with a real `Router` above it so all
/// three of its exits work.
class DeliveryRegisterPromptScreenPreviewHost extends StatefulWidget {
  const DeliveryRegisterPromptScreenPreviewHost({
    required this.screen,
    super.key,
    this.window,
    this.poppable = false,
  });

  /// The screen under review — `const DeliveryRegisterPromptScreen()`.
  final Widget screen;

  /// The simulated display, or `null` to use the real one.
  final DeliveryRegisterPromptScreenWindow? window;

  /// Whether the offer-KYC gate sits underneath on the fixture's stack.
  final bool poppable;

  @override
  State<DeliveryRegisterPromptScreenPreviewHost> createState() =>
      _DeliveryRegisterPromptScreenPreviewHostState();
}

class _DeliveryRegisterPromptScreenPreviewHostState
    extends State<DeliveryRegisterPromptScreenPreviewHost> {
  late final GoRouter _router = _buildRouter();

  GoRouter _buildRouter() {
    // Declaring the prompt as a CHILD of the gate is what makes the two stacks
    final GoRoute prompt = GoRoute(
      path: widget.poppable ? 'register-prompt' : '/jeeber/register-prompt',
      name: 'delivery-register-prompt',
      builder: (_, _) => widget.screen,
    );
    return GoRouter(
      initialLocation: widget.poppable
          ? '/jeeber/offer-gate/register-prompt'
          : '/jeeber/register-prompt',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const _DeliveryRegisterPromptScreenStandIn(
            label: deliveryRegisterPromptScreenShellStandInLabel,
          ),
        ),
        // The name the CTA reaches for. Registered so the tap resolves inside
        GoRoute(
          path: '/jeeber/onboarding',
          name: 'jeeber-onboarding',
          builder: (_, _) => const _DeliveryRegisterPromptScreenStandIn(
            label: deliveryRegisterPromptScreenOnboardingStandInLabel,
          ),
        ),
        GoRoute(
          path: '/jeeber/offer-gate',
          name: 'offer-kyc-gate',
          builder: (_, _) => const _DeliveryRegisterPromptScreenStandIn(
            label: deliveryRegisterPromptScreenGateStandInLabel,
          ),
          routes: <RouteBase>[if (widget.poppable) prompt],
        ),
        if (!widget.poppable) prompt,
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget routed = Router.withConfig(config: _router);
    final DeliveryRegisterPromptScreenWindow? window = widget.window;
    if (window == null) return routed;

    final ThemeData theme = Theme.of(context);
    final Widget framed = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            window.label,
            // Forced LTR: a diagnostic caption, not shipped copy.
            textDirection: TextDirection.ltr,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: MediaQuery(
            // `jeebPreviewHost` wraps every preview in a `SafeArea`, which
            data: MediaQuery.of(context).copyWith(
              size: window.size,
              padding: window.insets,
              viewPadding: window.insets,
              viewInsets: EdgeInsets.zero,
              // Null leaves the ambient scaler alone — see the field's dartdoc.
              textScaler: window.textScale == null
                  ? null
                  : TextScaler.linear(window.textScale!),
            ),
            child: SizedBox.fromSize(size: window.size, child: routed),
          ),
        ),
      ],
    );

    // Unbind both axes. The render tests pump onto 800 x 600 and every frame
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}

/// A page the fixture router can land on — the shell, the gate, or the
/// onboarding wizard.
/// It only has to exist and to be identifiable, so a tap on one of the screen's
class _DeliveryRegisterPromptScreenStandIn extends StatelessWidget {
  const _DeliveryRegisterPromptScreenStandIn({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text(
            // Forced LTR: a diagnostic string, not shipped copy.
            label,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
