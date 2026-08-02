import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/biometric_lock_cubit.dart';
import '../application/biometric_lock_state.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/biometric_lock_screen_fixtures.dart';

/// `phase == locked`, see 40_GUARDRAILS_ARCH §5.5). They either:
class BiometricLockScreen extends StatelessWidget {
  const BiometricLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'biometric_unlock_prompt',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<BiometricLockCubit, BiometricLockState>(
            builder: (context, state) {
              return Center(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(Spacing.large),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fingerprint,
                        size: Sizes.fiveXLarge,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: Spacing.large),
                      Text(
                        l10n.biometricUnlockTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Spacing.small),
                      Text(
                        l10n.biometricLockBody,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (state.hasFailed) ...[
                        const SizedBox(height: Spacing.small),
                        Text(
                          l10n.biometricLockFailure,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.error,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: Spacing.xLarge),
                      Semantics(
                        identifier: 'biometric_unlock_authenticate_cta',
                        button: true,
                        enabled: !state.isPrompting,
                        child: OmdsPrimaryButton(
                          text: state.hasFailed
                              ? l10n.biometricLockRetry
                              : l10n.biometricUnlockAuthenticateCta,
                          isEnabled: !state.isPrompting,
                          onTap: () =>
                              context.read<BiometricLockCubit>().authenticate(),
                        ),
                      ),
                      const SizedBox(height: Spacing.small),
                      Semantics(
                        identifier: 'biometric_unlock_use_password_link',
                        button: true,
                        child: OmdsPrimaryButton(
                          text: l10n.biometricUnlockUsePasswordLink,
                          variant: OmdsButtonVariant.text,
                          onTap: () => _usePasswordFallback(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _usePasswordFallback(BuildContext context) {
    context.read<BiometricLockCubit>().usePasswordFallback();
    context.goNamed('register');
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/biometric_auth/biometric_lock_screen_preview_test.dart
// ===========================================================================
//
// [BiometricLockScreen] is a GATE, not a page: a returning enrolled user cannot
// reach anything in the app until they get past it. That changes which states
// are worth reviewing. There is no data axis at all — no list to be empty, no
// request to be in flight, no payload to be long — so "empty / loading / error"
// maps onto the cubit's three-value `prompt` sub-status and nothing else:
//
//   * `idle` — the arrival state, and the only one a designer has ever seen;
//   * `prompting` — the OS sheet is up. Unreachable without a real pending
//     platform future, so nobody had looked at it;
//   * `failed` — the check was declined. The state with the most copy on it.
//
// The other axis is the WINDOW, and on this screen it is the one that decides
// whether the user can get in: the body is a `Center` + `Column` with no scroll
// view anywhere in it, so at a large text scale the composition does not become
// a scroll, it overflows.
//
// All of it is hosted through
// `lib/devtool/catalog/fixtures/biometric_lock_screen_fixtures.dart`, which the
// Screen Catalog entry (`batch_01_entries.dart`) now uses as well, so the state
// a designer signs off against and the cards an engineer edits against are ONE
// set of fixtures. Three things about that host are worth knowing:
//
// 1. The frame is pinned INSIDE the fixture — a `MediaQuery` override plus a
//    `SizedBox` — rather than left to the canvas [Size]. The canvas honours
//    `size`, but the render tests pump onto a fixed 800 x 600 surface, so a
//    state that merely ASKED for a 320 x 568 canvas would be measured at
//    800 x 600 and every window would silently collapse into the same widget.
// 2. The fixture mounts a local [GoRouter] carrying the app's two biometric-gate
//    redirects. Both of this screen's outcomes are navigation the screen does
//    not perform: `usePasswordFallback` calls `goNamed('register')` (which
//    throws with no router in scope), and the SUCCESS path is nothing but the
//    central gate reacting to `phase == unlocked`. Without the gate in the
//    fixture, a successful unlock would look like a screen that does nothing.
// 3. This screen owns its own `Scaffold` and [jeebPreviewHost] wraps every child
//    in one as well, so the canvas shows two nested `Scaffold`s. The inner one
//    is the real surface; the outer contributes a background and a `SafeArea`,
//    which is why the fixture re-pins `MediaQuery.padding` to zero rather than
//    inheriting whatever the outer `SafeArea` left behind.
//
// What these previews surfaced in the screen — details on the states below:
//
//  * **At 200% text on a small phone the gate stops fitting, and there is no
//    scroll view to fall back on — so BOTH of its controls are off the display
//    on arrival.** `SafeArea` → `BlocBuilder` → `Center` → `Padding` → `Column`,
//    and nothing in that chain scrolls. Measured on 320 x 568 at 200%, EN, in
//    the IDLE arrival state: the `Column` overflows by 124 pt, which leaves 4 pt
//    of the 48 pt `biometric_unlock_authenticate_cta` above the bottom edge and
//    puts the whole of `biometric_unlock_use_password_link` 56 pt below it. In
//    the failed state the same window overflows by 328 pt (216 pt in AR) and the
//    two controls sit 200 pt and 260 pt off the display. There is no scroll to
//    reach them with and no other exit: this is a gate, so the failure mode is
//    not "ugly", it is "cannot enter the app". 390 x 844 at 200% is fine in both
//    locales, and AR at 320 x 568 is fine in the idle state, which is exactly
//    why this went unnoticed — it needs the small phone AND the large text AND
//    (for Arabic) a failure to show up.
//  * **The failure copy points at an affordance the screen does not have.**
//    `biometricLockFailure` reads "Biometric check failed. Try again or use your
//    PIN." — and there is no PIN entry anywhere on this screen, in this feature,
//    or on the route. `SharedPrefsPinRepository` exists and `evaluate()` counts
//    `hasPin()` as a reason to LOCK the user (`canChallenge = available ||
//    hasPin`), so a PIN-enrolled user on a device whose platform biometric is
//    unavailable is held here by their PIN and then offered no way to enter it.
//    On the shipped `UnavailableBiometricGateway` that user's CTA can never
//    succeed. `Failed attempt` is the card that says it out loud.
//  * **"Use password instead" does not lead to a password.** The link's own
//    handler routes to `/register`, the phone-OTP entry, because the
//    email/password funnel was deleted in JEBV4-199 — the ARB metadata for
//    `biometricUnlockUsePasswordLink` still documents it as "→ /login". The
//    fixture's router lands the tap on a labelled stand-in so the render test
//    can pin where it actually goes; the AR copy has the same problem
//    ("استخدم كلمة المرور بدلاً من ذلك"). The AC3 ordering itself is sound —
//    the release-then-`goNamed` emit beats the gate, and the render test proves
//    it against a fixture gate that WOULD bounce a `/lock` → elsewhere move.
//  * **The OS dialog's reason string is a hardcoded English literal.**
//    `BiometricLockCubit._osPromptReason` is "Confirm it's you to open Jeeb",
//    passed straight to the gateway. It is the one piece of user-visible copy on
//    this flow that never passes through a `Text`, so no rendering can show it —
//    the fixture's fake gateway records it instead, and the render test asserts
//    that an Arabic user gets the English string.
//  * The good news, recorded because it is cheap to lose: at 100% text the
//    composition holds in both locales down to 320 pt, the failure hint uses the
//    semantic error color rather than a hardcoded red, and the `prompting` state
//    genuinely disables the CTA rather than merely dimming it — the tap is dead,
//    not just discouraged.

/// The canvas box for a whole screen: a real device plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _biometricLockScreenPhoneCanvas = Size(402, 888);

/// The same, around the smallest display the app supports.
const Size _biometricLockScreenCompactCanvas = Size(332, 612);

/// Every state is one seeded [BiometricLockCubit] in one simulated window.
///
/// The `const BiometricLockScreen()` is constructed HERE rather than inside the
/// fixture host on purpose: `tool/preview_coverage.dart` credits a section only
/// when it literally builds the widget its previews are named after, and it
/// keeps the fixture library free of a circular import back into this one.
///
/// The [ValueKey] is not decoration. Several of these states are the same widget
/// at a different size, and a render test that pumps two of them in a row would
/// otherwise hand Flutter two hosts of the same type with no key — an update,
/// not a remount — and the second card would go on showing the first card's
/// cubit.
Widget _biometricLockScreenHosted(
  BiometricLockCubit Function() create, {
  required BiometricLockScreenWindow window,
  required String caption,
}) =>
    BiometricLockScreenPreviewHost(
      key: ValueKey<String>(caption),
      create: create,
      window: window,
      caption: caption,
      screen: const BiometricLockScreen(),
    );

/// The reference reading: a returning enrolled user on an ordinary phone, held
/// on `/lock`, nothing attempted yet.
///
/// Matrixed because this is the state everybody reviews and the three cards
/// disagree with each other. The AR card is where the copy stops being short —
/// and the 200% card is the same window as `Phone · 200% text` below, so the
/// reference reading and the first sign of the fit problem sit side by side.
@JeebPreview(
  group: 'biometric_auth',
  name: 'Awaiting authentication',
  size: _biometricLockScreenPhoneCanvas,
  matrix: true,
)
Widget biometricLockScreenAwaiting() => _biometricLockScreenHosted(
      biometricLockScreenLockedCubit,
      window: BiometricLockScreenWindows.phone,
      caption: 'Awaiting authentication · Phone 390 × 844',
    );

/// The platform sheet is in flight (`prompt == prompting`).
///
/// Unreachable in any environment without biometric hardware, which is why it
/// had never been looked at: `authenticate()` sets it and clears it the moment
/// the gateway answers. What it shows is the whole design of the state — the CTA
/// keeps its label and takes a disabled tint, and nothing else on the screen
/// changes. There is no spinner and no copy saying the OS is asking. On Android
/// the system sheet covers this; on a device where the sheet fails to appear,
/// this frame is all the user gets.
@JeebPreview(
  group: 'biometric_auth',
  name: 'Prompting',
  size: _biometricLockScreenPhoneCanvas,
)
Widget biometricLockScreenPrompting() => _biometricLockScreenHosted(
      biometricLockScreenPromptingCubit,
      window: BiometricLockScreenWindows.phone,
      caption: 'Prompting · Phone 390 × 844',
    );

/// The check was declined or failed. `phase` stays `locked`, so the gate still
/// holds `/lock`; the screen adds the failure hint and swaps the CTA to the
/// retry label.
///
/// Matrixed because this is the longest copy on the screen and the two locales
/// disagree about how much longer: "Try biometrics again" against "إعادة
/// المحاولة بالقياسات الحيوية", inside an `OmdsPrimaryButton` whose height is
/// pinned at 48 pt regardless of text scale.
///
/// Read the hint against the buttons under it. It says "use your PIN"; the only
/// two controls on the screen are "try the biometric again" and "leave for
/// phone-OTP registration".
@JeebPreview(
  group: 'biometric_auth',
  name: 'Failed attempt',
  size: _biometricLockScreenPhoneCanvas,
  matrix: true,
)
Widget biometricLockScreenFailed() => _biometricLockScreenHosted(
      biometricLockScreenFailedCubit,
      window: BiometricLockScreenWindows.phone,
      caption: 'Failed attempt · Phone 390 × 844',
    );

/// The smallest display the app supports, at default text size.
///
/// Holds together with room to spare — the icon, two lines of copy and two
/// stacked buttons are a short composition. Recorded because it is the reason
/// the state below went unnoticed: the small-phone axis alone does not break
/// this screen, and the small-phone axis is the one people check.
@JeebPreview(
  group: 'biometric_auth',
  name: 'Compact 320 × 568',
  size: _biometricLockScreenCompactCanvas,
)
Widget biometricLockScreenCompact() => _biometricLockScreenHosted(
      biometricLockScreenLockedCubit,
      window: BiometricLockScreenWindows.compact,
      caption: 'Awaiting authentication · Compact 320 × 568',
    );

/// The failure state on the smallest display, still at default text size.
///
/// The extra paragraph and the longer CTA label are the most this screen ever
/// has to lay out, and at 100% it still fits. This is the last window in which
/// it does.
@JeebPreview(
  group: 'biometric_auth',
  name: 'Failed · Compact 320 × 568',
  size: _biometricLockScreenCompactCanvas,
)
Widget biometricLockScreenFailedCompact() => _biometricLockScreenHosted(
      biometricLockScreenFailedCubit,
      window: BiometricLockScreenWindows.compact,
      caption: 'Failed attempt · Compact 320 × 568',
    );

/// The accessibility ceiling on an ORDINARY phone: 390 x 844 at 200% text.
///
/// Not an edge case — 390 x 844 is a current mainstream phone and 200% is a
/// setting, not a stunt. The idle state survives it, which is worth knowing
/// precisely because it makes the failure state below look like an outlier when
/// it is really the same composition with one more paragraph in it.
@JeebPreview(
  group: 'biometric_auth',
  name: 'Phone · 200% text',
  size: _biometricLockScreenPhoneCanvas,
)
Widget biometricLockScreenLargeText() => _biometricLockScreenHosted(
      biometricLockScreenLockedCubit,
      window: BiometricLockScreenWindows.phoneLargeText,
      caption: 'Awaiting authentication · Phone 390 × 844 · 200% text',
    );

/// The state a user with large text on a small phone actually ARRIVES in, and
/// the reason this screen is a defect rather than a rough edge.
///
/// Nothing has gone wrong here. This is the cold-start gate on a 320 x 568
/// display at 200% text, first frame, before any interaction — and the `Column`
/// already overflows by 124 pt. Four points of the `Authenticate` button are
/// above the bottom edge; the "Use password instead" link is 56 pt below it. The
/// chain the body hangs off (`SafeArea` → `BlocBuilder` → `Center` → `Padding`
/// → `Column`) contains no scroll view, so there is nothing for the user to
/// scroll and no other way off this route. The app is unreachable.
///
/// Contrast it with `Compact 320 × 568` — the identical composition, one text
/// scale down, with room to spare.
///
/// This preview is deliberately NOT in the shared render suite: it throws, and
/// the suite asserts that nothing does. Its test is a KNOWN DEFECT case in
/// `biometric_lock_screen_preview_test.dart` which pins the overflow and the
/// off-display geometry, so this note cannot quietly go stale. When the screen
/// grows a scroll view that test fails — delete it and this paragraph then.
@JeebPreview(
  group: 'biometric_auth',
  name: 'Compact · 200% text',
  size: _biometricLockScreenCompactCanvas,
)
Widget biometricLockScreenCompactLargeText() => _biometricLockScreenHosted(
      biometricLockScreenLockedCubit,
      window: BiometricLockScreenWindows.compactLargeText,
      caption: 'Awaiting authentication · Compact 320 × 568 · 200% text',
    );

/// The worst case the app supports, on the screen with the least slack: the
/// failure state, on the smallest display, at 200% text.
///
/// The same overflow as the card above, three times as far out — 328 pt in EN,
/// 216 pt in AR, with the CTA 200 pt and the fallback link 260 pt below the
/// display edge. The failure hint is what pushes it there, which is the part
/// worth sitting with: the state that tells the user "try again or use your PIN"
/// is the state in which neither of the two things they could actually tap is
/// on screen.
///
/// Also NOT in the shared render suite, for the same reason as the card above.
@JeebPreview(
  group: 'biometric_auth',
  name: 'Failed · Compact · 200% text',
  size: _biometricLockScreenCompactCanvas,
)
Widget biometricLockScreenFailedCompactLargeText() =>
    _biometricLockScreenHosted(
      biometricLockScreenFailedCubit,
      window: BiometricLockScreenWindows.compactLargeText,
      caption: 'Failed attempt · Compact 320 × 568 · 200% text',
    );
