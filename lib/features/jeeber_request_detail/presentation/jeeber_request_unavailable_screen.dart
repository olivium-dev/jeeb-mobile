import 'package:flutter/material.dart';
import 'package:omds/omds.dart';
import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/jeeber_request_unavailable_screen_fixtures.dart';

class JeeberRequestUnavailableScreen extends StatelessWidget {
  const JeeberRequestUnavailableScreen({
    super.key,
    required this.requestId,
    required this.onBack,
  });

  final String requestId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.requestUnavailableTitle),
      body: SafeArea(
        child: Semantics(
          identifier: 'jeeber_request_unavailable',
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.large),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OmdsEmptyState(
                    key: const Key('jeeber-request-unavailable-state'),
                    icon: Icons.inbox_outlined,
                    title: l10n.requestUnavailableTitle,
                    subtitle: l10n.requestNoLongerAvailable(requestId),
                  ),
                  const SizedBox(height: Spacing.large),
                  OmdsPrimaryButton(
                    key: const Key('jeeber-request-unavailable-back-cta'),
                    text: l10n.requestUnavailableBrowseCta,
                    onTap: onBack,
                  ),
                ],
              ),
            ),
          ),
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
// test/previews/jeeber_request_detail/jeeber_request_unavailable_screen_preview_test.dart
// ===========================================================================
//
// This screen has no data axis. It takes a `String requestId` and a
// `VoidCallback onBack`, resolves nothing out of GetIt, builds no cubit, and
// renders three ARB strings under a fixed icon. It IS the terminal state — the
// graceful dead end [JeeberRequestDetailLoader] routes to when a request is
// cancelled, expired, or matched to another jeeber — so the usual preview
// question ("empty, loading, error?") has no answer here and has to be asked
// differently. Its three real inputs are the ID it is handed, the WINDOW it is
// given, and the NAVIGATION STACK underneath it, and those are the six states
// below.
//
// That also makes these previews network-free by construction rather than by
// the guard in [jeebPreviewHost]: there is no seam here through which a
// Dio-backed repository could be reached even by accident.
//
// The ids and the hosting are delegated to
// `lib/devtool/catalog/fixtures/jeeber_request_unavailable_screen_fixtures.dart`,
// EXTRACTED from the Screen Catalog entry that used to build this screen inline
// with a literal `requestId: 'req-404'` (`batch_05_entries.dart`). Both surfaces
// now read that file, so the state a designer signs off against and the state an
// engineer reviews cannot drift. Two things about the fixture are worth knowing
// before editing:
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
// * **At 200% text the CTA is laid out below the display, and nothing
//   scrolls.** `Scaffold > SafeArea > Center > Column` with no scroll view
//   anywhere in the chain. Measured: on the REFERENCE phone (390 x 844, EN) the
//   column overflows by 96 px and "Browse other requests" lands at y 904–952
//   against an edge at y 876; on 320 x 568 it overflows by 684 px (EN) / 412 px
//   (AR) and the CTA lands at y 1216 / y 944 against an edge at y 600. There is
//   no gesture that brings it back. The sibling screen this same loader routes
//   to survives the same box because its summary scrolls and its action bar is
//   pinned.
// * **A cold push tap has no back arrow to fall back on.** [OMDSAppBar] is
//   constructed with no `showBackButton` — which DEFAULTS TO FALSE — and passes
//   `automaticallyImplyLeading: true` through to Material's `AppBar`, so the
//   arrow exists only when the enclosing route can be popped. A feed-row tap
//   leaves a page underneath; `context.go`-style arrival on `/jeeber/requests/:id`
//   from a notification does not. Put `Cold push tap` next to `Phone · short id`:
//   identical pixels, one of them with an arrow. Combine it with the state above
//   and `Compact · 200% text` is a screen with ZERO reachable affordances.
// * **The CTA label is clipped inside its own pill at 200%.** Independent of the
//   overflow, and it bites even where the CTA is on screen: [OmdsPrimaryButton]
//   hard-pins its height to `Sizes.fourXLarge` (48) and centres an
//   unconstrained `Text`, so the label does not grow with the text scale.
//   Measured: "Browse other requests" needs 120 pt at 200% and is laid out into
//   48.
// * **The router's `?? ''` fallback renders a malformed sentence.**
//   `app_router.dart:1284` is `state.pathParameters['id'] ?? ''` and the id is
//   interpolated with no guard, so a blank id does not shorten the sentence —
//   it produces "Request  is no longer available." with a double space.
//   `Blank id` is that state.
// * **The raw UUID is printed in full**, corroborating what the loader's own
//   previews record: the resolved detail screen shortens the id to `#775EAE`
//   (sprint-009 audit §T5, `friendlyReference`), this one hands the raw route id
//   straight to the ARB. In AR that is a 36-character LTR run inside an RTL
//   sentence, which is why `Cold push tap` carries the matrix.
// * And one that is a contract rather than a defect, recorded for its cost: the
//   title is rendered TWICE, by [OMDSAppBar] and again as [OmdsEmptyState.title]
//   (`jeeber_request_unavailable_screen_test.dart` pins the pair). At 200% on a
//   phone the restatement alone measures 320 pt of the 788 pt body — 41% of the
//   space, in the window that has run out.
//
// The absolute pixel counts are inflated by the test font (`flutter_test` draws
// every glyph as a square of the font size, so English measures roughly twice as
// wide as Inter renders it), and AR at 390 x 844 does still fit — that state is
// previewed too, so the finding is not overstated. The STRUCTURE is not a font
// artifact: a centred, non-scrolling column has no fallback at any text scale,
// and this is the screen a jeeber reaches when something has already gone wrong.

/// The canvas box for a phone frame plus the fixture's outline and caption.
const Size _jeeberRequestUnavailableScreenPhoneCanvas = Size(402, 888);

/// The same, for the smallest supported display.
const Size _jeeberRequestUnavailableScreenCompactCanvas = Size(332, 612);

/// Taps on the "Browse other requests" CTA.
///
/// A dead end whose only forward affordance does nothing reviews nothing, and
/// `onBack` is injected — a preview that wired it to `() {}` would look
/// identical whether or not the CTA was connected. The render test taps it and
/// asserts this moves.
int jeeberRequestUnavailableScreenBrowseTaps = 0;

/// Resets [jeeberRequestUnavailableScreenBrowseTaps]; the counter is top-level,
/// so one test's taps would otherwise leak into the next.
void jeeberRequestUnavailableScreenResetTaps() =>
    jeeberRequestUnavailableScreenBrowseTaps = 0;

/// Builds the screen for [fixture] and hands it to the shared host.
///
/// The `JeeberRequestUnavailableScreen(...)` is constructed HERE rather than
/// inside the fixture host on purpose: `tool/preview_coverage.dart` credits a
/// section only when it literally builds the widget its previews are named
/// after, and it keeps the fixture library free of a circular import back into
/// this one.
Widget _jeeberRequestUnavailableScreenHosted(
  JeeberRequestUnavailableScreenFixture fixture,
) =>
    JeeberRequestUnavailableScreenPreviewHost(
      fixture: fixture,
      screen: JeeberRequestUnavailableScreen(
        requestId: fixture.requestId,
        onBack: () => jeeberRequestUnavailableScreenBrowseTaps++,
      ),
    );

/// The Screen Catalog's state, framed as a phone: the short, human-sized id,
/// default text, and a page underneath so the app bar has a back arrow.
///
/// The reference reading, and the control for everything else. Comfortable —
/// measured 204 pt of slack below the CTA — which is exactly why the states
/// further down went unnoticed: on the width axis alone this screen is as simple
/// as it looks. Nothing in the shipped app produces an id this shape; read it
/// next to `Cold push tap` for what the route really renders.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Phone · short id',
  size: _jeeberRequestUnavailableScreenPhoneCanvas,
)
Widget jeeberRequestUnavailableScreenPhoneShortId() =>
    _jeeberRequestUnavailableScreenHosted(
      JeeberRequestUnavailableScreenFixtures.phoneShortId,
    );

/// What a cold push tap on a dead request actually produces: the raw 36-character
/// route id in the sentence, and nothing underneath to pop back to.
///
/// Compare it with `Phone · short id` — same window, same copy, two differences
/// that both matter. The id is the one the resolved detail screen would have
/// shown as `#775EAE`, and the back arrow is GONE, because `OMDSAppBar` implies
/// its leading from whether the route can be popped and a `context.go`-style
/// arrival leaves one page in the Navigator. The CTA is then the entire exit.
///
/// Matrixed: the AR RTL card is where the UUID reads as an LTR run dropped into
/// an RTL sentence, and the 200% card is the accessibility ceiling on the
/// reference device (see `Phone · 200% text`, which is the same window pinned so
/// the render test can measure it).
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Cold push tap · raw UUID',
  size: _jeeberRequestUnavailableScreenPhoneCanvas,
  matrix: true,
)
Widget jeeberRequestUnavailableScreenPushDeadEnd() =>
    _jeeberRequestUnavailableScreenHosted(
      JeeberRequestUnavailableScreenFixtures.pushDeadEnd,
    );

/// The smallest display the app supports, carrying the id the shipped route
/// hands over.
///
/// It fits, but only just: measured 36 pt between the CTA and the bottom edge,
/// against 204 pt on the 390 pt phone. Most of the difference is the UUID, which
/// costs an extra wrapped line at this width. Included as the boundary case —
/// it is the last window in which this composition has anywhere left to go.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Compact 320 × 568',
  size: _jeeberRequestUnavailableScreenCompactCanvas,
)
Widget jeeberRequestUnavailableScreenCompact() =>
    _jeeberRequestUnavailableScreenHosted(
      JeeberRequestUnavailableScreenFixtures.compact,
    );

/// The accessibility ceiling on an ORDINARY phone — 200% text on 390 x 844.
///
/// **This card overflows in English, and the stripes you see are real.** The
/// body is a `Center` around a `Column` with no `SingleChildScrollView` above it
/// anywhere, so the surplus is not reachable by any gesture — it is simply off
/// the display. Measured: 96 px of overflow, with "Browse other requests" laid
/// out at y 904–952 against an edge at y 876. What is cut is the only forward
/// path the screen offers, and the duplicated title above it has already spent
/// 320 pt of the 788 pt body.
///
/// Two things keep this honest. The Arabic copy is shorter and DOES fit in this
/// window (CTA at y 772–820), so the exact ceiling is locale-dependent; both
/// readings are asserted in the render test. And the absolute counts are
/// inflated by the test font. Neither changes the mechanism: there is no scroll
/// view to fall back on at any text scale.
///
/// This state also carries a defect the overflow hides — at 200% the CTA's own
/// label needs 120 pt and is laid out into the 48 pt [OmdsPrimaryButton] pins,
/// so even when the button is on screen its text is clipped.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Phone · 200% text',
  size: _jeeberRequestUnavailableScreenPhoneCanvas,
)
Widget jeeberRequestUnavailableScreenLargeText() =>
    _jeeberRequestUnavailableScreenHosted(
      JeeberRequestUnavailableScreenFixtures.phoneLargeText,
    );

/// The worst case the app supports, and one a cold push tap can really produce:
/// the smallest display, the largest text, and a stack with nothing to pop.
///
/// **A screen with ZERO reachable affordances.** Measured: 684 px of overflow in
/// EN and 412 px in AR, putting the CTA at y 1216 / y 944 against an edge at
/// y 600 — and because the route was reached by a stack-REPLACING navigation
/// there is no back arrow either, so there is nothing at all on this surface a
/// jeeber can touch. Unlike the profile fallback, `RootAwareBackScope` is not a
/// rescue to reason about here: on iOS there is no system gesture at all.
///
/// This is the state the other five exist to make legible. Neither axis alone
/// produces it — `Compact 320 × 568` fits, `Phone · 200% text` still has an
/// arrow — which is why it survived review.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Compact · 200% text',
  size: _jeeberRequestUnavailableScreenCompactCanvas,
)
Widget jeeberRequestUnavailableScreenCompactLargeText() =>
    _jeeberRequestUnavailableScreenHosted(
      JeeberRequestUnavailableScreenFixtures.compactLargeText,
    );

/// The router's `?? ''` fallback, rendered.
///
/// `app_router.dart:1284` is `state.pathParameters['id'] ?? ''`, and the id goes
/// into `requestNoLongerAvailable` with no guard — so an absent id does not
/// shorten the sentence, it MALFORMS it: "Request  is no longer available.",
/// with a double space where the reference should be.
///
/// go_router will not match an empty path segment, so this is a defensive branch
/// rather than a route a jeeber can walk into today. It is previewed because the
/// `?? ''` is in shipped code, the copy has no `{requestId}`-less variant to
/// fall back to, and the failure is invisible from the id side — every other
/// state renders the same layout perfectly.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Blank id',
  size: _jeeberRequestUnavailableScreenPhoneCanvas,
)
Widget jeeberRequestUnavailableScreenBlankId() =>
    _jeeberRequestUnavailableScreenHosted(
      JeeberRequestUnavailableScreenFixtures.blankId,
    );
