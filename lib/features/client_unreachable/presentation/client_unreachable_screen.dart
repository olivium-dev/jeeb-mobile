import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/client_unreachable_screen_fixtures.dart';

// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs; live flow is live_tracking + tracking_noshow_sheet — see docs/project-understanding/reconciliation/orphans.md
class ClientUnreachableScreen extends StatelessWidget {
  const ClientUnreachableScreen({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'client_unreachable_root',
      container: true,
      child: Scaffold(
        appBar: const OMDSAppBar(title: 'Client Unreachable'),
        body: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _UnreachableNoticeCard(),
              const SizedBox(height: Spacing.xLarge),
              Semantics(
                identifier: 'client_unreachable_call_again_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  text: 'Try Calling Again',
                  variant: OmdsButtonVariant.outlined,
                  icon: const Icon(Icons.phone),
                  onTap: () {},
                ),
              ),
              const SizedBox(height: Spacing.small),
              Semantics(
                identifier: 'client_unreachable_chat_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  text: 'Send Chat Message',
                  variant: OmdsButtonVariant.outlined,
                  icon: const Icon(Icons.chat),
                  onTap: () {},
                ),
              ),
              const Spacer(),
              Semantics(
                identifier: 'client_unreachable_flag_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  text: 'Flag as Unreachable',
                  backgroundColor: Theme.of(context).colorScheme.error,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreachableNoticeCard extends StatelessWidget {
  const _UnreachableNoticeCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          children: [
            Icon(
              Icons.phone_disabled,
              size: Sizes.fourXLarge,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: Spacing.small),
            Text(
              'Cannot reach the Client',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.xSmall),
            Text(
              'If the Client is not responding, you can flag them as '
              'unreachable. They will have 15 minutes to respond before the '
              'delivery is escalated.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests:
// test/previews/client_unreachable/client_unreachable_screen_preview_test.dart
// ===========================================================================
//
// This screen has no data axis at all. It builds no cubit, resolves nothing out
// of GetIt, takes no callbacks, and every string it draws is a hardcoded
// English literal a few lines above this banner. Its one constructor parameter
// is required and never read. So the usual preview question ("empty, loading,
// error?") has no answer here and has to be asked differently: what varies is
// the WINDOW (the body is a non-scrolling `Column` with a `Spacer`) and the
// NAVIGATION STACK underneath it, and those are the five states below.
//
// That also makes these previews network-free by construction rather than by
// the guard in [jeebPreviewHost]: there is no seam here through which a
// Dio-backed repository could be reached even by accident.
//
// The ids and the hosting are delegated to
// `lib/devtool/catalog/fixtures/client_unreachable_screen_fixtures.dart`,
// EXTRACTED from the Screen Catalog entry that used to build this screen inline
// with a literal `deliveryId: 'delivery-demo-1'` (`batch_02_entries.dart`). Both
// surfaces now read that file, so the state a designer signs off against and the
// state an engineer reviews cannot drift. Two things about the fixture are worth
// knowing before editing:
//
// 1. The frame is pinned INSIDE the fixture — a `MediaQuery` override plus a
//    `SizedBox` — rather than left to the canvas [Size]. The canvas honours
//    `size`, but the render tests pump onto a fixed 800 x 600 surface, so a
//    state that merely ASKED for a 320 x 568 canvas would be measured at
//    800 x 600 and the small-window states would silently become copies of the
//    large ones. Only the windows that exist FOR a text scale pin one; the rest
//    inherit, so `matrix: true` can still render its own 200% card.
// 2. This screen owns its own `Scaffold` and [jeebPreviewHost] wraps every child
//    in one as well, so the canvas shows two nested Scaffolds. The inner one is
//    the real surface; the outer contributes a background and a `SafeArea`.
//
// WHAT THESE PREVIEWS SURFACED IN THE SCREEN, all pinned as assertions in the
// render test:
//
// * **The screen is not localized — at all.** There is no `AppLocalizations`
//   lookup anywhere in the file; "Client Unreachable", "Try Calling Again",
//   "Send Chat Message", "Flag as Unreachable", "Cannot reach the Client" and
//   the 15-minute paragraph are English string literals. The AR RTL card of
//   `Phone` renders the identical English on a mirrored surface: the layout
//   flips, the words do not. The live flow this screen was meant to sit in is
//   fully localized — `live_tracking` carries its own `live_tracking_l10n.dart`
//   — and this file has zero ARB keys.
// * **`deliveryId` is required and dead.** Nothing in `build` reads it, so
//   `Cold arrival` — handed a real 36-character delivery id instead of the
//   catalog's `delivery-demo-1` — is pixel-identical to `Phone`. A jeeber who
//   flags the wrong delivery has nothing on screen to have checked it against,
//   and the flag CTA reports only `true`, never WHICH delivery.
// * **Two of the three buttons are dead in the shipped source.** "Try Calling
//   Again" and "Send Chat Message" are `onTap: () {}` literals ABOVE this
//   banner — not injected callbacks a preview could have left unwired. They
//   look, hover and press exactly like the working one. Only "Flag as
//   Unreachable" does anything, and what it does is `pop(true)`.
// * **Nothing scrolls, so the body has no fallback when it runs out of room.**
//   `Scaffold > Padding > Column` with a `Spacer`, and no scroll view anywhere
//   in the chain: once the fixed children exceed the height the `Spacer`
//   collapses to zero and the surplus is laid out off the display, unreachable
//   by any gesture. Measured, and what is cut is always the flag CTA — the only
//   button on this screen that does anything:
//   - 390 x 844 at 100% — fits, 16 pt of slack (`Phone`).
//   - 320 x 568 at 100% — body overflows 36 px, CTA straddles the edge at
//     y 572–620 against y 600 (`Compact 320 × 568`).
//   - 390 x 844 at 200% — body overflows 236 px, CTA at y 1048 against y 876
//     (`Phone · 200% text`).
//   - 320 x 568 at 200% — body overflows 800 px, CTA at y 1336 against y 600
//     (`Compact · 200% text`).
// * **A cold arrival has no back arrow either.** [OMDSAppBar] is constructed
//   with no `showBackButton` — which DEFAULTS TO FALSE — and passes
//   `automaticallyImplyLeading: true` through to Material's `AppBar`, so the
//   arrow exists only when the enclosing route can be popped. Put `Cold arrival`
//   next to `Phone`: identical pixels, one of them with an arrow. Combine it
//   with the state above and `Compact · 200% text` is a screen whose only
//   touchable controls are the two empty handlers.
// * **`pop(true)` on a stack-replacing arrival empties the navigator.** The one
//   live affordance assumes something is underneath it. When there is not, the
//   tap removes the only route and leaves a blank surface, and the `true` it
//   reports has no caller to receive it — the render test taps `Cold arrival`
//   and pins exactly that.
// * **The CTA labels are painted OUTSIDE their own pill rather than wrapped.**
//   [OmdsPrimaryButton] centres a `Row(mainAxisSize: min)` of icon +
//   UNCONSTRAINED `Text` inside a pill whose height is hard-pinned to
//   `Sizes.fourXLarge` (48), so a label wider than the button neither wraps nor
//   ellipsizes. Measured on the reference phone at 200%: the "Try Calling Again"
//   paragraph is 478 pt wide inside a 358 pt button, still on one line, and the
//   row reports 187 px of horizontal overflow. It bites on the two buttons that
//   survive the vertical cut.
//
// Two things keep this honest. The absolute pixel counts are inflated by the
// test font — `flutter_test` draws every glyph as a square of the font size, so
// English measures roughly twice as wide as Inter renders it and the wrapped
// paragraph in the notice card is correspondingly taller — which matters most
// for the 320 x 568 / 100% reading, where the margin is small enough that Inter
// may well recover it. Treat that window as the BOUNDARY, not as a guaranteed
// break. And the measurements are identical in AR, because the copy is the same
// English in both — there is no shorter translation to be saved by.
//
// The STRUCTURE is not a font artifact at any scale: a `Spacer` in a
// non-scrolling column has no fallback, and this is a screen a jeeber reaches
// when a delivery has already gone wrong.

/// The canvas box for a phone frame plus the fixture's outline and caption.
const Size _clientUnreachableScreenPhoneCanvas = Size(402, 888);

/// The same, for the smallest supported display.
const Size _clientUnreachableScreenCompactCanvas = Size(332, 612);

/// Builds the screen for [fixture] and hands it to the shared host.
///
/// The `ClientUnreachableScreen(...)` is constructed HERE rather than inside the
/// fixture host on purpose: `tool/preview_coverage.dart` credits a section only
/// when it literally builds the widget its previews are named after, and it
/// keeps the fixture library free of a circular import back into this one.
Widget _clientUnreachableScreenHosted(
  ClientUnreachableScreenFixture fixture,
) =>
    ClientUnreachableScreenPreviewHost(
      fixture: fixture,
      screen: ClientUnreachableScreen(deliveryId: fixture.deliveryId),
    );

/// The reference reading: an ordinary phone, default text, live tracking still
/// underneath so the app bar has a back arrow and `pop(true)` has a caller.
///
/// The control for everything else, and comfortable enough that the states
/// further down went unnoticed — on the width axis alone this screen is exactly
/// as simple as it looks.
///
/// Matrixed, because the AR RTL card is the finding: the layout mirrors and the
/// copy does not translate, since there is not one `AppLocalizations` lookup in
/// the file. Read the three cards together — the English is identical in all of
/// them, and the 200% card is the accessibility ceiling on this device (see
/// `Phone · 200% text`, the same window pinned so the render test can measure
/// it).
@JeebPreview(
  group: 'client_unreachable',
  name: 'Phone · from live tracking',
  size: _clientUnreachableScreenPhoneCanvas,
  matrix: true,
)
Widget clientUnreachableScreenPhone() => _clientUnreachableScreenHosted(
      ClientUnreachableScreenFixtures.phone,
    );

/// A stack-replacing arrival, carrying a REAL delivery id rather than the
/// catalog's demo one.
///
/// Read it next to `Phone`. Two things differ and neither is visible: the id is
/// a 36-character UUID instead of `delivery-demo-1` — and the frames are
/// identical, because `deliveryId` is required and never read — and there is
/// nothing underneath, so the back arrow is gone and the flag CTA's
/// `Navigator.of(context).pop(true)` has no caller to return `true` to.
@JeebPreview(
  group: 'client_unreachable',
  name: 'Cold arrival · nothing to pop',
  size: _clientUnreachableScreenPhoneCanvas,
)
Widget clientUnreachableScreenColdArrival() => _clientUnreachableScreenHosted(
      ClientUnreachableScreenFixtures.coldArrival,
    );

/// The smallest display the app supports, at DEFAULT text — no accessibility
/// setting involved.
///
/// **The `Spacer` has already collapsed to zero here and the body overflows.**
/// Measured 36 px, leaving the flag CTA straddling the bottom edge at y 572–620
/// against an edge at y 600: the lower half of the only working button is off
/// the display, and nothing scrolls it back. The notice paragraph wraps onto
/// more lines at this width and there is no slack left to pay for them — the
/// reference phone has only 16 pt, and this window is 276 pt shorter.
///
/// This is the one measurement the test font can plausibly account for (the
/// wrapped paragraph is roughly twice as tall as Inter renders it), so read
/// 320 pt as the BOUNDARY rather than as a guaranteed break on a device. The
/// canvas draws it in real Inter, which is the point of previewing it.
@JeebPreview(
  group: 'client_unreachable',
  name: 'Compact 320 × 568',
  size: _clientUnreachableScreenCompactCanvas,
)
Widget clientUnreachableScreenCompact() => _clientUnreachableScreenHosted(
      ClientUnreachableScreenFixtures.compact,
    );

/// The accessibility ceiling on an ORDINARY phone — 200% text on 390 x 844.
///
/// **This card overflows, and the stripes you see are real.** `Padding >
/// Column` with a `Spacer` and no `SingleChildScrollView` above it anywhere:
/// once the fixed children exceed the height the `Spacer` collapses to zero and
/// the surplus is laid out off the display, unreachable by any gesture.
/// Measured 236 px of overflow, with "Flag as Unreachable" at y 1048–1096
/// against an edge at y 876 — 172 pt past it, far more than any font metric
/// explains.
///
/// What is cut is the only button on this screen that does anything. The two
/// that survive the cut are the two wired to `onTap: () {}` — and their labels
/// are the ones now 187 px wider than the pills they sit in.
@JeebPreview(
  group: 'client_unreachable',
  name: 'Phone · 200% text',
  size: _clientUnreachableScreenPhoneCanvas,
)
Widget clientUnreachableScreenLargeText() => _clientUnreachableScreenHosted(
      ClientUnreachableScreenFixtures.phoneLargeText,
    );

/// The worst case the app supports: the smallest display, the largest text, and
/// a stack with nothing to pop.
///
/// **A screen with ZERO working affordances.** Measured 800 px of overflow,
/// putting the flag CTA at y 1336 against an edge at y 600 — and there is no
/// back arrow either, because nothing can be popped. What is left on the
/// surface is two buttons whose handlers are empty blocks.
///
/// Neither axis alone produces it: `Phone · 200% text` still has an arrow, and
/// `Compact 320 × 568` at least leaves the top half of the flag CTA on screen.
/// That is why it survived review.
///
/// Asserted in BOTH locales in the render test, because the copy is the same
/// English in both — unlike every other screen in this app, there is no shorter
/// translation that could rescue this window.
@JeebPreview(
  group: 'client_unreachable',
  name: 'Compact · 200% text',
  size: _clientUnreachableScreenCompactCanvas,
)
Widget clientUnreachableScreenCompactLargeText() =>
    _clientUnreachableScreenHosted(
      ClientUnreachableScreenFixtures.compactLargeText,
    );
