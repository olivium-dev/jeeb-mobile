import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../devtool/catalog/fixtures/profile_unavailable_screen_fixtures.dart';
import '../previews/jeeb_preview.dart';

class ProfileUnavailableScreen extends StatelessWidget {
  const ProfileUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.profileUnavailableTitle,
        showBackButton: true,
      ),
      body: Center(
        child: OmdsErrorState(
          key: const Key('profile_unavailable_state'),
          title: l10n.profileUnavailableTitle,
          message: l10n.profileUnavailableBody,
          icon: Icons.person_off_outlined,
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
// Render tests: test/previews/core/profile_unavailable_screen_preview_test.dart
// ===========================================================================
//
// [ProfileUnavailableScreen] has NO data axis. It takes nothing but a `key`,
// resolves nothing out of GetIt, builds no cubit, and renders two fixed ARB
// strings under a fixed icon. It IS the error state — the release-safe fallback
// `app_router.dart` substitutes for `/profile/customer` and
// `/profile/delivery-man` when the typed `extra` is missing — so the usual
// preview question ("empty, loading, error?") has no answer here and has to be
// asked differently. The only inputs this screen has are the WINDOW it is given
// and the NAVIGATION STACK underneath it, and those are the six states below.
//
// That also makes it network-free by construction rather than by the guard in
// [jeebPreviewHost]: there is no seam through which a Dio-backed repository
// could be reached even by accident.
//
// The hosting is delegated to
// `lib/devtool/catalog/fixtures/profile_unavailable_screen_fixtures.dart` so a
// future Screen Catalog entry seeds from the same windows instead of inventing a
// second set (there is no catalog entry for this screen today). Three things
// about it are worth knowing before editing:
//
// 1. The frame is pinned INSIDE the fixture — a `MediaQuery` override plus a
//    `SizedBox` — rather than left to the canvas [Size]. The canvas honours
//    `size`, but the render tests pump onto a fixed 800 x 600 surface, so a
//    state that merely ASKED for a 320 x 568 canvas would be measured at
//    800 x 600 and all six states would silently become the same widget.
//    Windows that exist FOR a text scale set one; the rest inherit, so
//    `matrix: true` can still render its own 200% card.
// 2. The fixture mounts a LOCAL [Navigator]. The screen's only affordance is
//    `OMDSAppBar(showBackButton: true)`, whose default action is
//    `Navigator.of(context).maybePop()`, so how many pages sit under it decides
//    whether that arrow is an exit or a no-op. Inheriting the canvas's Navigator
//    would have modelled the one-page case by accident in every state.
// 3. This screen owns its own `Scaffold` and [jeebPreviewHost] wraps every child
//    in one as well, so the canvas shows two nested Scaffolds. The inner one is
//    the real surface; the outer contributes a background and a `SafeArea` —
//    which is exactly why each window has to RESTORE `MediaQuery.padding`, or
//    the notched state would mean nothing.
//
// What these previews surfaced in the screen — details on the states below:
//
//  * **The body does not scroll, so at 200% text on a small phone the copy is
//    clipped.** `Center` + `OmdsErrorState`'s `Column(mainAxisSize: min)` with
//    no `SingleChildScrollView` anywhere: on 320 x 568 at the accessibility
//    ceiling the column overflows its 512 pt box by 164 px in EN (124 px in AR)
//    and the overflow is at the BOTTOM — so the sentence that tells the user
//    what to do is the half that goes. Measured: the message occupies
//    y 424 → 744 against a display edge at 600, i.e. 144 of its 320 pt sit off
//    the screen. `Compact · 200% text` renders the stripes.
//  * **The only affordance is an arrow that does nothing when this screen is the
//    stack root.** `OMDSAppBar._buildBackButton` defaults to
//    `Navigator.of(context).maybePop()`, which no-ops on a lone page, and this
//    screen passes no `onBackPressed` and gives [OmdsErrorState] no `onRetry`.
//    The route is reached by stack-REPLACING navigation in shipped code
//    (`password_security_screen.dart:132` → `context.goNamed('customer-profile')`),
//    and in release that lands on THIS screen whenever the typed `extra` is
//    absent. `RootAwareBackScope` rescues the Android system BACK gesture
//    (`backFallbacks['customer-profile'] = '/'`), but nothing rescues the arrow,
//    and on iOS there is no system gesture to fall back on. `Dead end · nothing
//    to pop` is that state; read it next to `Phone 390 × 844`, which is the same
//    pixels with a page underneath, and note that the two are indistinguishable.
//  * **The title is rendered twice**, once by [OMDSAppBar] and once as
//    [OmdsErrorState.title], so every window shows "Profile unavailable"
//    stacked directly under "Profile unavailable". Harmless at 100% on a phone;
//    at 200% on the compact window the duplicate alone is 224 pt of the 512 pt
//    the body has — it is 44% of the space, spent restating the app bar, in the
//    one window that has run out.
//  * The good news, recorded because it is cheap to lose: nothing overflows in
//    the other five windows, in either locale, and the notched insets are
//    handled — the app bar grows to 115 pt to swallow the 59 pt status bar, and
//    the centred body ends 210 pt clear of the 34 pt home indicator.

/// The canvas box for a whole screen: a real device plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _profileUnavailableScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on.
const Size _profileUnavailableScreenCompactCanvas = Size(332, 612);

/// A notched phone (iPhone 15 Pro class) in portrait.
const Size _profileUnavailableScreenNotchedCanvas = Size(405, 896);

/// Every state is the same screen in a different window — see the fixture.
///
/// The `const ProfileUnavailableScreen()` is constructed HERE rather than inside
/// the fixture host on purpose: `tool/preview_coverage.dart` credits a section
/// only when it literally builds the widget its previews are named after, and it
/// keeps the fixture library free of a circular import back into this one.
Widget _profileUnavailableScreenHosted(
  ProfileUnavailableScreenWindow window, {
  bool parentOnStack = true,
}) =>
    ProfileUnavailableScreenPreviewHost(
      window: window,
      parentOnStack: parentOnStack,
      screen: const ProfileUnavailableScreen(),
    );

/// The reference reading: an ordinary phone, no system chrome, default text,
/// and a page underneath so the back arrow is a real exit.
///
/// Matrixed because the whole screen is two sentences and their length is what
/// swings by locale — and because the AR RTL rendering is the only place the
/// duplicated title and the icon-above-text stack can be checked for mirroring
/// in one glance. The 200% card of this matrix is the same window as
/// `Phone · 200% text` below; on a 390 pt phone it still fits.
@JeebPreview(
  group: 'core',
  name: 'Phone 390 × 844',
  size: _profileUnavailableScreenPhoneCanvas,
  matrix: true,
)
Widget profileUnavailableScreenPhone() => _profileUnavailableScreenHosted(
      ProfileUnavailableScreenWindows.phone,
    );

/// The smallest display the app supports, at default text size.
///
/// Comfortable: the whole composition measures 268 pt inside the 512 pt the app
/// bar leaves, so there is 244 pt of slack. Recorded because it is the reason
/// the state below went unnoticed — the small-phone axis alone does not break
/// this screen, and the small-phone axis is the one people check.
@JeebPreview(
  group: 'core',
  name: 'Compact 320 × 568',
  size: _profileUnavailableScreenCompactCanvas,
)
Widget profileUnavailableScreenCompact() => _profileUnavailableScreenHosted(
      ProfileUnavailableScreenWindows.compact,
    );

/// A notched phone: 59 pt status bar, 34 pt home indicator.
///
/// The profile routes are bare top-level `GoRoute`s — no `ShellRoute`, no
/// `SafeArea` — so the insets are the screen's own problem. It handles them:
/// the app bar grows to 115 pt (56 + the 59 pt status bar), and because the body
/// is a `Center` rather than a bottom-anchored composition, the content ends
/// 210 pt clear of the home indicator. Included as the control for the window
/// axis, not because it breaks.
@JeebPreview(
  group: 'core',
  name: 'Notched 393 × 852 · inset 59/34',
  size: _profileUnavailableScreenNotchedCanvas,
)
Widget profileUnavailableScreenNotched() => _profileUnavailableScreenHosted(
      ProfileUnavailableScreenWindows.notched,
    );

/// The accessibility ceiling on an ordinary phone: 200% text on 390 x 844.
///
/// Holds together — 540 pt of content inside the 788 pt the app bar leaves. The
/// 390 pt of width is what saves it: the same strings wrap onto fewer lines than
/// they do at 320. Read it as the boundary case, since the only two axes this
/// screen has are width and text scale and this state maxes out one of them.
@JeebPreview(
  group: 'core',
  name: 'Phone · 200% text',
  size: _profileUnavailableScreenPhoneCanvas,
)
Widget profileUnavailableScreenLargeText() => _profileUnavailableScreenHosted(
      ProfileUnavailableScreenWindows.phoneLargeText,
    );

/// The worst case the app supports: the smallest display AND the largest text.
///
/// **This card overflows, and the stripes you see are real.** `OmdsErrorState`
/// is a `Column(mainAxisSize: min)` inside a `Center`, with no
/// `SingleChildScrollView` above it anywhere in the chain — so when the icon,
/// the (duplicated) title and the message outgrow the box, the surplus is
/// clipped rather than scrolled, and it is clipped off the BOTTOM. Measured:
/// 164 px of overflow in EN, 124 px in AR, with the message running from
/// y 424 to y 744 against a display edge at 600. What is cut is the only
/// instruction the screen offers — "We couldn't load this profile. Please go
/// back and try again." — and the duplicated title above it has already spent
/// 224 pt of the 512 pt available.
///
/// The absolute pixel count is inflated by the test font (`flutter_test` draws
/// every glyph as a square of the font size, so English measures roughly twice
/// as wide as Inter renders it), and at 100% this window has 244 pt to spare.
/// The STRUCTURE is not a font artifact: a centred, non-scrolling column has no
/// fallback at any text scale, and this is the screen a user reaches when
/// something already went wrong.
///
/// The fix is not in this preview — it is a `SingleChildScrollView` around the
/// body, which is what every other error surface in the app already does.
@JeebPreview(
  group: 'core',
  name: 'Compact · 200% text',
  size: _profileUnavailableScreenCompactCanvas,
)
Widget profileUnavailableScreenCompactLargeText() =>
    _profileUnavailableScreenHosted(
      ProfileUnavailableScreenWindows.compactLargeText,
    );

/// The same phone as the reference reading, with nothing underneath it.
///
/// This is how the route is actually reached in the shipped app:
/// `password_security_screen.dart:132` calls `context.goNamed('customer-profile')`,
/// a stack-REPLACING navigation that leaves one page in the Navigator, and in a
/// release build the builder falls through to this screen whenever the typed
/// `extra` is absent. `maybePop()` then finds nothing to pop, so the back arrow
/// — the ONLY affordance on the screen, since no `onBackPressed` is passed and
/// [OmdsErrorState] gets no `onRetry` — silently does nothing.
///
/// Compare it with `Phone 390 × 844`: identical pixels, opposite behaviour, no
/// visual difference whatsoever. That is the point of previewing it.
@JeebPreview(
  group: 'core',
  name: 'Dead end · nothing to pop',
  size: _profileUnavailableScreenPhoneCanvas,
)
Widget profileUnavailableScreenStackRoot() => _profileUnavailableScreenHosted(
      ProfileUnavailableScreenWindows.phoneStackRoot,
      parentOnStack: false,
    );
