import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/delivery_register_prompt_screen_fixtures.dart';

class DeliveryRegisterPromptScreen extends StatelessWidget {
  const DeliveryRegisterPromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'delivery_register_prompt',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.offerKycGateTitle,
          showBackButton: true,
          onBackPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        body: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.large,
            Spacing.medium,
            Spacing.xLarge,
          ),
          children: [
            Icon(
              Icons.delivery_dining_outlined,
              size: Sizes.sixXLarge,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: Spacing.large),
            Text(
              l10n.offerKycGateHeadline,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Spacing.small),
            Text(
              l10n.offerKycGateBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Spacing.xLarge),
            Semantics(
              identifier: 'delivery_register_prompt_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.gateStartKycCta,
                onTap: () => context.goNamed('jeeber-onboarding'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'delivery_register_prompt_back',
              button: true,
              container: true,
              child: TextButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                child: Text(l10n.gateBackCta),
              ),
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
// Render tests: test/previews/offer_kyc_gate/delivery_register_prompt_screen_preview_test.dart
// ===========================================================================
//
// [DeliveryRegisterPromptScreen] has NO data axis. It takes nothing but a `key`,
// resolves nothing out of GetIt, builds no cubit and renders four fixed ARB
// strings under a fixed icon — the Screen Catalog entry's own comment called it
// "fully static (no cubit/repository at all)". So the usual preview question
// ("empty, loading, error?") has no answer here and has to be asked differently.
// The only inputs this screen has are the WINDOW it is given and the NAVIGATION
// STACK underneath it, and those are the seven states below.
//
// That also makes it network-free by construction rather than by the guard in
// [jeebPreviewHost]: there is no seam here through which a Dio-backed repository
// could be reached even by accident.
//
// The hosting is delegated to
// `lib/devtool/catalog/fixtures/delivery_register_prompt_screen_fixtures.dart`,
// which the Screen Catalog entry (`batch_07_entries.dart`) now uses as well, so
// the state a designer signs off against and the cards an engineer edits against
// are ONE set of fixtures. Three things about it are worth knowing before
// editing:
//
// 1. The frame is pinned INSIDE the fixture — a `MediaQuery` override plus a
//    `SizedBox` — rather than left to the canvas [Size]. The canvas honours
//    `size`, but the render tests pump onto a fixed 800 x 600 surface, so a
//    state that merely ASKED for a 320 x 568 canvas would be measured at
//    800 x 600 and all seven states would silently become the same widget.
//    Windows that exist FOR a text scale set one; the rest inherit, so
//    `matrix: true` can still render its own 200% card.
// 2. The fixture mounts a local [GoRouter]. All three exits on this screen —
//    the app-bar arrow, `delivery_register_prompt_cta` and
//    `delivery_register_prompt_back` — call `context.canPop()` /
//    `context.goNamed()`, which throw when no router is in scope. The screen
//    BUILDS fine without one, so a naive host looks correct right up until
//    someone taps it.
// 3. This screen owns its own `Scaffold` and [jeebPreviewHost] wraps every child
//    in one as well, so the canvas shows two nested Scaffolds. The inner one is
//    the real surface; the outer contributes a background and a `SafeArea` —
//    which is exactly why each window has to RESTORE `MediaQuery.padding`, or
//    the notched states would mean nothing.
//
// What these previews surfaced in the screen — details on the states below:
//
//  * **This is the offer-KYC gate's copy on a screen that is not the gate.** All
//    four strings are `offerKycGate*` / `gate*` keys: the title is "Verification
//    required", the headline is "Get approved to start sending offers", the body
//    asks the user to "finish your identity verification", and the CTA reads
//    "Start verification". The screen is the REGISTER-AS-A-JEEBER prompt — its
//    own dartdoc calls the CTA "Register now", the route is
//    `delivery-register-prompt`, and `customer_profile_screen.dart:159` sends a
//    plain customer here from "register as a delivery person". Nothing on it
//    mentions registering or delivering, and the button that says "Start
//    verification" opens the onboarding WIZARD (photo → address → service area),
//    not KYC. Visible in every state below; `matrix: true` on the reference
//    reading shows it in both locales at once (AR is the same mismatch:
//    "التوثيق مطلوب" / "بدء التوثيق").
//  * **"Back to requests" does not go to requests.** `gateBackCta` is the gate's
//    string, where it means the jeeber request feed. Here both back exits are
//    `canPop() ? pop() : go('/')`, and since both shipped callers arrive by
//    stack-REPLACING `goNamed`, `canPop()` is false and the tap lands on the
//    shell root — for a customer coming from the profile row, a tab they have
//    never seen a request in. `Phone 390 × 844` (the production stack) and
//    `Pushed from the gate` are the same pixels with opposite outcomes, which is
//    why both are here.
//  * **The CTA `go`es where the wizard expects to have been `push`ed.**
//    `dm_onboarding_screen.dart:216` documents step-1 Back as returning "to the
//    `delivery-register-prompt` the wizard was pushed from" and implements it as
//    `canPop() ? pop() : go('/')`. This screen uses `goNamed`, which REPLACES —
//    so after the CTA the stack holds one page, `canPop()` is false, and the
//    wizard's Back drops the user on the shell instead of back here. The render
//    test taps the CTA and pins the empty stack it leaves behind.
//  * **The body has no bottom `SafeArea`, and the `ListView`'s 24 pt bottom
//    padding is smaller than a home indicator.** `app_router.dart` mounts this
//    screen as a bare top-level `GoRoute` — no `ShellRoute`, no `SafeArea` — so
//    the viewport runs to the physical bottom edge. Scrolled to the end, the
//    "Back to requests" text button rests `Spacing.xLarge` = 24 pt off that
//    edge, inside a 34 pt home indicator. Arithmetic, not a font artifact:
//    24 < 34. `Notched · 200% text` is the state that shows it.
//  * **Both actions live inside the scroll body rather than pinned**, and at
//    200% text they go below the fold on an ORDINARY phone — not just on the
//    small one. Measured on 390 x 844: 180 pt of scroll in EN, 220 pt in AR
//    behind a 788 pt viewport, and neither `delivery_register_prompt_cta` nor
//    `delivery_register_prompt_back` is in the widget tree or the semantics tree
//    on arrival — the two ids this screen's own dartdoc publishes as its QA
//    targets. The ROOT id survives, which is the trap: JM-044 AC3 and the
//    Maestro flows that touch this screen assert `delivery_register_prompt` and
//    nothing else, so they stay green while both of the screen's actions are off
//    the display. `Phone · 200% text` is where it starts; `Compact · 200% text`
//    is 2.5 screenfuls (1303 pt EN / 1159 pt AR behind a 512 pt viewport).
//  * The good news, recorded because it is cheap to lose: NOTHING overflows, in
//    any of the seven windows, in either locale. The `ListView` is what saves
//    it — the failure mode at the accessibility ceiling here is reachability, not
//    clipping — and the JEBV4-13 P1-6 `onBackPressed` fix holds: the app-bar
//    arrow is a working exit in both navigation states, not the dead arrow it
//    would be on `maybePop()`.

/// The canvas box for a whole screen: a real device plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _deliveryRegisterPromptScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on.
const Size _deliveryRegisterPromptScreenCompactCanvas = Size(332, 612);

/// A notched phone (iPhone 15 Pro class) in portrait.
const Size _deliveryRegisterPromptScreenNotchedCanvas = Size(405, 896);

/// Every state is the same screen in a different window, on one of two stacks —
/// see the fixture.
///
/// The `const DeliveryRegisterPromptScreen()` is constructed HERE rather than
/// inside the fixture host on purpose: `tool/preview_coverage.dart` credits a
/// section only when it literally builds the widget its previews are named
/// after, and it keeps the fixture library free of a circular import back into
/// this one.
Widget _deliveryRegisterPromptScreenHosted(
  DeliveryRegisterPromptScreenWindow window, {
  bool poppable = false,
}) =>
    DeliveryRegisterPromptScreenPreviewHost(
      window: window,
      poppable: poppable,
      screen: const DeliveryRegisterPromptScreen(),
    );

/// The reference reading, and the production stack: an ordinary phone, no
/// system chrome, default text, nothing underneath to pop.
///
/// Everything fits without scrolling, both actions are on screen, and the
/// app-bar arrow works — this screen is as simple as it looks in the one window
/// everybody reviews. What it is NOT is on-topic: read the four strings against
/// the route name in the AppBar-to-CTA order and this is the offer-KYC gate,
/// verbatim, on the screen a customer reaches from "register as a delivery
/// person".
///
/// Matrixed because the copy mismatch is the finding and it has to be checked in
/// both locales (AR carries the same gate wording), and because the 200% card of
/// this matrix is exactly the `Phone · 200% text` window below — the cheapest
/// way to see the reference reading and the state where its two actions leave
/// the screen, side by side.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Phone 390 × 844',
  size: _deliveryRegisterPromptScreenPhoneCanvas,
  matrix: true,
)
Widget deliveryRegisterPromptScreenPhone() =>
    _deliveryRegisterPromptScreenHosted(
      DeliveryRegisterPromptScreenWindows.phone,
    );

/// The smallest display the app supports, at default text size.
///
/// Still fits — the icon, headline and one-sentence body leave room for both
/// actions above the fold. Recorded because it is the reason the state below
/// went unnoticed: the small-phone axis alone does not break this screen, and
/// the small-phone axis is the one people check.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Compact 320 × 568',
  size: _deliveryRegisterPromptScreenCompactCanvas,
)
Widget deliveryRegisterPromptScreenCompact() =>
    _deliveryRegisterPromptScreenHosted(
      DeliveryRegisterPromptScreenWindows.compact,
    );

/// A notched phone: 59 pt status bar, 34 pt home indicator.
///
/// The app bar handles the top inset correctly — the viewport starts 59 + 56 pt
/// down. The bottom is the interesting half: the scroll viewport ends at the
/// physical bottom edge, because `Scaffold` does not `SafeArea` its body and
/// nothing above this screen does either. At 100% the content is short enough
/// that the back link lands clear of the indicator and the omission costs
/// nothing. `Notched · 200% text` is the same window with the content long
/// enough to reach the bottom.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Notched 393 × 852 · inset 59/34',
  size: _deliveryRegisterPromptScreenNotchedCanvas,
)
Widget deliveryRegisterPromptScreenNotched() =>
    _deliveryRegisterPromptScreenHosted(
      DeliveryRegisterPromptScreenWindows.notched,
    );

/// The accessibility ceiling on an ORDINARY phone — the same window the matrix
/// above renders as its third card, pinned here so the render suite asserts it.
///
/// This is where the screen stops fitting, and it is not an edge case: 390 x 844
/// is a current mainstream phone and 200% is a setting, not a stunt. 180 pt of
/// scroll in EN and 220 pt in AR behind a 788 pt viewport — and with it, both
/// `delivery_register_prompt_cta` and `delivery_register_prompt_back` drop out
/// of the widget tree AND the semantics tree until the user scrolls, while the
/// root `delivery_register_prompt` the QA flows assert stays exactly where it
/// was.
///
/// Note the locale ordering: Arabic is the LONGER rendering here (220 vs 180),
/// so anyone checking only the English card is reading the better case.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Phone · 200% text',
  size: _deliveryRegisterPromptScreenPhoneCanvas,
)
Widget deliveryRegisterPromptScreenLargeText() =>
    _deliveryRegisterPromptScreenHosted(
      DeliveryRegisterPromptScreenWindows.phoneLargeText,
    );

/// The worst case the app supports: the smallest display AND the largest text.
///
/// It holds together — no overflow, nothing clipped, in either locale; the
/// composition simply becomes a long scroll: 1303 pt in EN and 1159 pt in AR
/// behind a 512 pt viewport, two and a half screenfuls. Everything said about
/// `Phone · 200% text` applies here with more room to spare, which is the point
/// — by the time the window is this small the actions are not merely below the
/// fold, they are two swipes away with no affordance suggesting they exist.
///
/// Treat the absolute scroll extent with care — `flutter_test` draws every glyph
/// as a square of the font size, so English measures roughly twice as wide as
/// Inter renders it. The STRUCTURE is not a font artifact: the only two actions
/// on the screen are the last two items of a scroll view.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Compact · 200% text',
  size: _deliveryRegisterPromptScreenCompactCanvas,
)
Widget deliveryRegisterPromptScreenCompactLargeText() =>
    _deliveryRegisterPromptScreenHosted(
      DeliveryRegisterPromptScreenWindows.compactLargeText,
    );

/// The one combination where the missing bottom inset is visible rather than
/// latent: a device with a home indicator, and content long enough to scroll.
///
/// Scroll to the end — 231 pt in EN, 271 pt in AR. The "Back to requests" button
/// comes to rest 24 pt off the display edge, the `ListView`'s `Spacing.xLarge`
/// bottom padding, while the home indicator claims 34. The last 10 pt of the
/// app's own back affordance sits under the system gesture bar, where a swipe
/// goes to the OS rather than to the app.
///
/// The fix is not in this preview: either `SafeArea(bottom: true)` around the
/// body, or `MediaQuery.paddingOf(context).bottom` added to the `ListView`'s
/// bottom padding.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Notched · 200% text',
  size: _deliveryRegisterPromptScreenNotchedCanvas,
)
Widget deliveryRegisterPromptScreenNotchedLargeText() =>
    _deliveryRegisterPromptScreenHosted(
      DeliveryRegisterPromptScreenWindows.notchedLargeText,
    );

/// The same phone as the reference reading, with the offer-KYC gate underneath
/// it — the stack no shipped caller actually produces.
///
/// `offer_kyc_gate_screen.dart:159` and `customer_profile_screen.dart:159` both
/// arrive by stack-REPLACING `goNamed('delivery-register-prompt')`, and
/// `app_router.dart` backs that up with `backFallbacks['delivery-register-prompt']
/// = '/'`. So in the shipped app `canPop()` is false and both back exits land on
/// the shell; only here do they pop to the gate the user came from.
///
/// Compare it with `Phone 390 × 844`: identical pixels, different destination,
/// no visual difference whatsoever. That is the point of previewing it — the
/// label under which a user reads "Back to requests" is decided entirely by how
/// they got here.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Pushed from the gate',
  size: _deliveryRegisterPromptScreenPhoneCanvas,
)
Widget deliveryRegisterPromptScreenPushed() =>
    _deliveryRegisterPromptScreenHosted(
      DeliveryRegisterPromptScreenWindows.phonePushed,
      poppable: true,
    );
