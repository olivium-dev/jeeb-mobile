// Shared dev-only fixtures for `DeliveryRegisterPromptScreen`.
//
// The Screen Catalog entry for this screen (`batch_07_entries.dart`, feature
// `offer_kyc_gate`) used to build the screen bare — `(_) => const
// DeliveryRegisterPromptScreen()` — with the comment "fully static (no
// cubit/repository at all) so it needs no fake". That is true of its DATA and
// false of its ENVIRONMENT, which is what this file supplies. The entry and the
// preview section at the bottom of
// `lib/features/offer_kyc_gate/presentation/delivery_register_prompt_screen.dart`
// now both host the screen through [DeliveryRegisterPromptScreenPreviewHost], so
// the designer-facing catalog and the engineer-facing canvas cannot drift into
// two different "designed states".
//
// ## Why these fixtures are WINDOWS and a ROUTER, not a fake repository
//
// Most fixture sets in this directory are canned repositories, because most
// screens have a data axis to seed. `DeliveryRegisterPromptScreen` has none: it
// takes nothing but a `key`, resolves nothing out of GetIt, builds no cubit and
// renders four fixed ARB strings under a fixed icon. There is no empty /
// loading / error underneath it and nothing for a fake to stand in for.
//
// Two things DO vary, and they are the states:
//
//  1. **The window.** How wide, how tall, how much of the display the system
//     chrome has claimed, and how large the user has set their text. The body is
//     a `ListView`, so the window decides not whether the copy FITS but whether
//     the two actions at the bottom of it are on screen at all.
//  2. **The navigation stack underneath it.** Every one of the screen's three
//     exits calls into go_router — `context.canPop()`, `context.pop()`,
//     `context.go('/')`, `context.goNamed('jeeber-onboarding')` — which throws
//     when no `GoRouter` is in scope. The screen BUILDS fine without one (none
//     of those calls happen during `build`), so a naive host looks correct right
//     up until someone taps it.
//
// The router is seeded to model production. Both shipped callers reach this
// route with a stack-REPLACING `goNamed('delivery-register-prompt')` —
// `offer_kyc_gate_screen.dart:159` (`gate_register_link`) and
// `customer_profile_screen.dart:159` (`onRegisterDelivery`) — and
// `app_router.dart` mounts it as a bare top-level `GoRoute` with
// `backFallbacks['delivery-register-prompt'] = '/'`. So `canPop()` is false in
// the shipped app and BOTH back exits take the `context.go('/')` fallback onto
// the shell. `poppable: true` models the stack no shipped caller produces; it
// exists so the contrast is reviewable rather than assumed.
//
// Note the nesting: `Router.withConfig` is exactly what `MaterialApp.router`
// does internally, so this adds a Router and nothing else — ambient theme,
// locale and text scale still come from above. Inside the running app (the
// catalog) that means a second `RootBackButtonDispatcher`; the app's own is
// registered first and still wins the system BACK gesture, so the catalog's own
// back behaviour is unchanged. What changes is that a designer tapping "Start
// verification" now lands on a stand-in page here instead of silently steering
// the REAL app router into the onboarding wizard.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Where `context.go('/')` lands inside the fixture router — the app shell.
///
/// Public so the render test can tell "the exit reached a page" apart from "the
/// exit emptied the Navigator", which is the black contentless surface
/// `OMDSAppBar._buildBackButton` documents at length. It is also the string that
/// shows the back CTA's promise ("Back to requests") is not what the tap does.
const String deliveryRegisterPromptScreenShellStandInLabel =
    'app shell (preview stand-in)';

/// Where `context.goNamed('jeeber-onboarding')` lands — the JM-039 wizard.
///
/// Public so the render test can follow the CTA and then inspect the stack it
/// left behind.
const String deliveryRegisterPromptScreenOnboardingStandInLabel =
    'jeeber onboarding wizard (preview stand-in)';

/// The offer-KYC gate, the screen `gate_register_link` comes FROM.
///
/// Only reachable in the `poppable: true` state — in production the gate is
/// replaced, not stacked. Public so the render test can prove that.
const String deliveryRegisterPromptScreenGateStandInLabel =
    'offer-KYC gate (preview stand-in)';

/// One simulated device window to render [DeliveryRegisterPromptScreen] in.
///
/// The frame has to be pinned by the fixture rather than left to the canvas
/// `size:`, because the render tests in `test/previews/` pump onto a fixed
/// 800 x 600 surface: a state that merely ASKED for a 320 x 568 canvas would be
/// measured at 800 x 600 under test and every state would silently collapse into
/// the same widget.
@immutable
class DeliveryRegisterPromptScreenWindow {
  const DeliveryRegisterPromptScreenWindow({
    required this.label,
    required this.size,
    this.insets = EdgeInsets.zero,
    this.textScale,
  });

  /// Caption painted above the frame, and the string each preview is pinned by.
  ///
  /// This screen renders the same four strings in every state, so without a
  /// caption a render test cannot tell a preview wired to the wrong window from
  /// a correct one — and two of the states below are pixel-identical by design.
  final String label;

  /// Logical size of the simulated display.
  final Size size;

  /// System-chrome insets (`MediaQuery.padding`) — status bar, home indicator.
  final EdgeInsets insets;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  ///
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  /// third card at `textScaleFactor: 2.0`, and a window that pinned 1.0 would
  /// silently overwrite it and show a 100% rendering under a "200% text" label.
  /// Only the windows that exist FOR a text scale set one.
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
  /// two stacked actions, so this is the width at which the actions start
  /// moving below the fold.
  static const DeliveryRegisterPromptScreenWindow compact =
      DeliveryRegisterPromptScreenWindow(
    label: 'Compact · 320 × 568 · 100% text',
    size: Size(320, 568),
  );

  /// A notched phone in portrait: 59 pt status bar, 34 pt home indicator.
  ///
  /// `app_router.dart` mounts this screen as a bare top-level `GoRoute` — no
  /// `ShellRoute`, no `SafeArea` — so whether the composition clears the system
  /// chrome is the screen's own problem.
  static const DeliveryRegisterPromptScreenWindow notched =
      DeliveryRegisterPromptScreenWindow(
    label: 'Notched · 393 × 852 · inset 59/34',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
  );

  /// The accessibility ceiling on an ORDINARY phone — not an edge case, and the
  /// window in which this screen first stops fitting: 180 pt of scroll in EN,
  /// 220 pt in AR, behind a 788 pt viewport.
  static const DeliveryRegisterPromptScreenWindow phoneLargeText =
      DeliveryRegisterPromptScreenWindow(
    label: 'Phone · 390 × 844 · 200% text',
    size: Size(390, 844),
    textScale: 2,
  );

  /// The worst case the app supports: the smallest display AND the largest
  /// text. This is the window that decides whether either action on the screen
  /// is reachable on arrival.
  static const DeliveryRegisterPromptScreenWindow compactLargeText =
      DeliveryRegisterPromptScreenWindow(
    label: 'Compact · 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );

  /// The notched phone at the accessibility ceiling — the one combination in
  /// which the body actually SCROLLS on a device that has a home indicator, and
  /// therefore the only window in which the missing bottom inset is visible
  /// rather than merely latent.
  static const DeliveryRegisterPromptScreenWindow notchedLargeText =
      DeliveryRegisterPromptScreenWindow(
    label: 'Notched · 393 × 852 · inset 59/34 · 200% text',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
    textScale: 2,
  );

  /// The ordinary phone again, reviewed for its NAVIGATION state rather than
  /// its geometry: the screen with the gate still underneath it.
  ///
  /// Same pixels as [phone] — a distinct label so the two cannot be confused in
  /// the canvas or in the render test, where the caption is what each preview is
  /// pinned by.
  static const DeliveryRegisterPromptScreenWindow phonePushed =
      DeliveryRegisterPromptScreenWindow(
    label: 'Phone · 390 × 844 · pushed from the gate',
    size: Size(390, 844),
  );
}

/// Hosts `DeliveryRegisterPromptScreen` in one
/// [DeliveryRegisterPromptScreenWindow], with a real `Router` above it so all
/// three of its exits work.
///
/// The screen is passed IN rather than constructed here, for two reasons. It
/// keeps this file free of a circular import back into the feature library, and
/// — the load-bearing one — `tool/preview_coverage.dart` only credits a preview
/// section that literally CONSTRUCTS the widget it is named after, so the
/// `const DeliveryRegisterPromptScreen()` has to appear below the banner in the
/// screen's own file rather than in here.
///
/// Pass `window: null` to render at the ambient window with no caption and no
/// outline — that is the form the Screen Catalog entry uses, where the device IS
/// the frame.
///
/// [poppable] models how the route was reached:
///
///  * `false` — PRODUCTION, and the default. Both shipped callers use a
///    stack-REPLACING `goNamed('delivery-register-prompt')`, so the screen is
///    the only page on the stack, `canPop()` is false, and both back exits take
///    the `context.go('/')` fallback onto the shell stand-in.
///  * `true` — the prompt declared as a CHILD of `/jeeber/offer-gate`, which is
///    how go_router materializes a page for the gate underneath it. `canPop()`
///    is true and both back exits `pop()` to the gate stand-in. No shipped
///    caller produces this stack; it is here so the difference is reviewable.
///
/// Stateful, and the [GoRouter] is built once and disposed with the host: a
/// router rebuilt on every frame would drop the navigation state `canPop()`
/// reads.
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
    // differ: go_router materializes a page for every matched ancestor that has
    // a builder, so as a child `canPop()` is true. As a top-level route — how
    // `app_router.dart` actually declares it — it is the lone page.
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
        // the fixture instead of throwing — and so the stack it leaves behind
        // can be inspected.
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
            // ZEROES `padding` for everything below it. Restoring it here is
            // what makes the notched windows mean anything at all.
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
    // here is taller than that; an `Align` + `SizedBox` would pass the host's
    // constraints down and the frame would be silently clamped to 600 pt — the
    // exact measurement the "is the CTA below the fold" assertions depend on not
    // being faked.
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
///
/// It only has to exist and to be identifiable, so a tap on one of the screen's
/// exits demonstrably reaches a page rather than emptying the Navigator.
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
