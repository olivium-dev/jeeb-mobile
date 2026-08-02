import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/request_summary_unavailable_screen_fixtures.dart';

/// Graceful fallback rendered when `/request-summary` is reached without a
/// `RequestDraft` (e.g. a cold deep-link). Replaces a raw scaffold that carried
/// hardcoded English copy, so the AR build no longer leaks English here.
class RequestSummaryUnavailableScreen extends StatelessWidget {
  const RequestSummaryUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.requestSummaryUnavailableTitle,
        showBackButton: true,
      ),
      body: Center(
        child: OmdsErrorState(
          key: const Key('request-summary-unavailable-state'),
          message: l10n.requestSummaryUnavailableBody,
          icon: Icons.inbox_outlined,
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
// Render tests: test/previews/request_summary/request_summary_unavailable_screen_preview_test.dart
// ===========================================================================
//
// [RequestSummaryUnavailableScreen] has NO data axis. It takes nothing but a
// `key`, resolves nothing out of GetIt, builds no cubit, and renders one ARB
// title plus one ARB sentence under a fixed icon. It IS the empty state — the
// fallback `app_router.dart:1329` substitutes for `/request-summary` when
// `state.extra` is not a `RequestDraft` — so the usual preview question
// ("empty, loading, error?") has no answer here and has to be asked
// differently. The only inputs this screen has are the WINDOW it is given and
// the NAVIGATION STACK underneath it, and those are the states below.
//
// That also makes it network-free by construction rather than by the guard in
// [jeebPreviewHost]: there is no seam through which a Dio-backed repository
// could be reached even by accident.
//
// The hosting is delegated to
// `lib/devtool/catalog/fixtures/request_summary_unavailable_screen_fixtures.dart`,
// which the Screen Catalog entry for this screen (`batch_10_entries.dart`,
// feature `request_summary`, state "Unavailable") now reads as well — one
// designed state, two dev surfaces, no drift. Three things about the fixture
// are worth knowing before editing:
//
// 1. The frame is pinned INSIDE the fixture — a `MediaQuery` override plus a
//    `SizedBox` — rather than left to the canvas [Size]. The canvas honours
//    `size`, but the render tests pump onto a fixed 800 x 600 surface, so a
//    state that merely ASKED for a 320 x 568 canvas would be measured at
//    800 x 600 and every state would silently become the same widget. Windows
//    that exist FOR a text scale set one; the rest inherit, so `matrix: true`
//    can still render its own 200% card.
// 2. The fixture mounts a LOCAL [Navigator] (except in the catalog form, which
//    inherits the ambient one). The screen's only affordance is
//    `OMDSAppBar(showBackButton: true)`, whose default action is
//    `Navigator.of(context).maybePop()`, so how many pages sit under it decides
//    whether that arrow is an exit or a no-op.
// 3. This screen owns its own `Scaffold` and [jeebPreviewHost] wraps every
//    child in one as well, so the canvas shows two nested Scaffolds. The inner
//    one is the real surface; the outer contributes a background and a
//    `SafeArea` — which is exactly why each window has to RESTORE
//    `MediaQuery.padding`, or the notched state would mean nothing.
//
// What these previews surfaced in the screen — details on the states below:
//
//  * **In English the app bar is the SAME string as the screen this one
//    replaces.** `requestSummaryUnavailableTitle` (`app_en.arb:1912`) and
//    `requestSummaryTitle` (`:1784`) are both exactly "Review & submit", so the
//    fallback wears the populated screen's header: a user whose draft was lost
//    sees "Review & submit" over an empty box, with nothing in the header
//    saying anything went wrong. Arabic does NOT collide — "المراجعة والإرسال"
//    for this screen against "مراجعة وإرسال" for the populated one
//    (`app_ar.arb:660` / `:626`) — which is why the matrix on the reference
//    card is worth opening: the two locales disagree about whether these are
//    the same screen.
//  * **The body promises an action the screen cannot perform.** The copy is
//    "No request draft available. Start a new request to continue.", and there
//    is nothing here to start one with: [OmdsErrorState] renders a button only
//    when given `onRetry`, and this screen gives it none.
//  * **So the only control is a back arrow that is dead in the state the screen
//    exists for.** `OMDSAppBar._buildBackButton` defaults to
//    `Navigator.of(context).maybePop()`, which no-ops on a lone page, and this
//    screen passes no `onBackPressed`. `RootAwareBackScope` rescues the Android
//    system BACK gesture (`AppRouter.backFallbacks['request-summary'] = '/'`),
//    but nothing rescues the arrow, and on iOS there is no system gesture to
//    fall back on. This is the same defect JEBV4-13 P1-6 fixed on
//    `offer_kyc_gate_screen`, `delivery_register_prompt_screen` and
//    `kyc_rejected_screen` (`test/back_arrow_dead_at_root_test.dart`); this
//    screen was not in that sweep. `Cold deep link · nothing to pop` is that
//    state — read it next to `Phone 390 × 844`, which is the same pixels with a
//    page underneath, and note that the two are indistinguishable.
//  * **At the accessibility ceiling on the smallest phone it fits by 16 pt.**
//    Nothing overflows in any of these windows, in either locale — but that is
//    a margin, not a property. `Compact · 200% text` measures 480 pt of content
//    in the 512 pt the app bar leaves, i.e. 94% of the body box, ending 16 pt
//    above the display edge. There is no `SingleChildScrollView` anywhere in
//    the chain, so those 16 pt are the ONLY thing between this screen and
//    clipping: the sibling `ProfileUnavailableScreen` is the same `Center` +
//    non-scrolling `Column` shape with one more line of text, and it overflows
//    the identical window by 164 px. A heading, a second sentence, the CTA the
//    copy promises, or a longer translation each spend more than 16 pt. (The
//    absolute figure is inflated by the test font — `flutter_test` draws every
//    glyph as a square of the font size, so English measures roughly twice as
//    wide as Inter renders it, and AR measures 360 pt in the same window. The
//    STRUCTURE is not a font artifact.)

/// The canvas box for a whole screen: a real device plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _requestSummaryUnavailableScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on.
const Size _requestSummaryUnavailableScreenCompactCanvas = Size(332, 612);

/// A notched phone (iPhone 15 Pro class) in portrait.
const Size _requestSummaryUnavailableScreenNotchedCanvas = Size(405, 896);

/// Every state is the same screen in a different window — see the fixture.
///
/// The `const RequestSummaryUnavailableScreen()` is constructed HERE rather
/// than inside the fixture host on purpose: `tool/preview_coverage.dart`
/// credits a section only when it literally builds the widget its previews are
/// named after, and it keeps the fixture library free of a circular import back
/// into this one.
Widget _requestSummaryUnavailableScreenHosted(
  RequestSummaryUnavailableScreenWindow? window, {
  bool? parentOnStack = true,
}) =>
    RequestSummaryUnavailableScreenPreviewHost(
      window: window,
      parentOnStack: parentOnStack,
      screen: const RequestSummaryUnavailableScreen(),
    );

/// The reference reading: an ordinary phone, no system chrome, default text,
/// and a page underneath so the back arrow is a real exit.
///
/// This is the `context.push('/request-summary', extra: draft)` case where the
/// draft did not survive — go_router's `extra` is not serializable, so an
/// Android process-death restore rebuilds the route with `extra == null` and
/// the builder falls through to this screen with the pushing page still below.
///
/// Matrixed because the whole screen is a title and a sentence, and their
/// length is what swings by locale — and because the AR RTL rendering is the
/// only place the centred icon-above-text stack and the mirrored app bar can be
/// checked in one glance.
@JeebPreview(
  group: 'request_summary',
  name: 'Phone 390 × 844',
  size: _requestSummaryUnavailableScreenPhoneCanvas,
  matrix: true,
)
Widget requestSummaryUnavailableScreenPhone() =>
    _requestSummaryUnavailableScreenHosted(
      RequestSummaryUnavailableScreenWindows.phone,
    );

/// The smallest display the app supports, at default text size.
///
/// Comfortable — 200 pt of content in the 512 pt the app bar leaves, 312 pt of
/// slack — and worth having as the control. It is also the reason the state two
/// cards below reads as a surprise: the small-phone axis alone does not stress
/// this screen at all, and the small-phone axis is the one people check.
@JeebPreview(
  group: 'request_summary',
  name: 'Compact 320 × 568',
  size: _requestSummaryUnavailableScreenCompactCanvas,
)
Widget requestSummaryUnavailableScreenCompact() =>
    _requestSummaryUnavailableScreenHosted(
      RequestSummaryUnavailableScreenWindows.compact,
    );

/// A notched phone: 59 pt status bar, 34 pt home indicator.
///
/// `/request-summary` is a bare top-level `GoRoute` — no `ShellRoute`, no
/// `SafeArea` in `app_router.dart` at all — so the insets are the screen's own
/// problem. It handles them: the app bar grows to 115 pt (56 + the 59 pt status
/// bar), and because the body is a `Center` rather than a bottom-anchored
/// composition the content ends 278 pt clear of the frame bottom, well past the
/// 34 pt home indicator. Included as the control for the window axis, not
/// because it breaks.
@JeebPreview(
  group: 'request_summary',
  name: 'Notched 393 × 852 · inset 59/34',
  size: _requestSummaryUnavailableScreenNotchedCanvas,
)
Widget requestSummaryUnavailableScreenNotched() =>
    _requestSummaryUnavailableScreenHosted(
      RequestSummaryUnavailableScreenWindows.notched,
    );

/// The accessibility ceiling on an ordinary phone: 200% text on 390 x 844.
///
/// Holds together with room to spare — 360 pt of content inside the 788 pt the
/// app bar leaves, ending 214 pt clear of the display edge. The 390 pt of width
/// is what buys that: the one sentence wraps onto fewer lines than it does at
/// 320. Read it as the boundary case for the text-scale axis on its own, and
/// then read the card below, where that axis is combined with the width axis.
@JeebPreview(
  group: 'request_summary',
  name: 'Phone · 200% text',
  size: _requestSummaryUnavailableScreenPhoneCanvas,
)
Widget requestSummaryUnavailableScreenLargeText() =>
    _requestSummaryUnavailableScreenHosted(
      RequestSummaryUnavailableScreenWindows.phoneLargeText,
    );

/// The worst case the app supports: the smallest display AND the largest text.
///
/// **It fits by 16 pt, and that is a measurement rather than a property.**
/// 480 pt of content in the 512 pt the app bar leaves — 94% of the body box —
/// ending at y 584 against a display edge at 600. [OmdsErrorState] is a
/// `Column(mainAxisSize: min)` inside a `Center` with no `SingleChildScrollView`
/// above it anywhere in the chain, so anything that stops fitting is CLIPPED
/// rather than scrolled, and clipped off the BOTTOM — where the sentence is.
/// The sibling `ProfileUnavailableScreen` has exactly this shape plus a title
/// line, and it overflows this same window by 164 px.
///
/// What saves this screen is only that its body is one sentence and no heading.
/// Adding a heading, a second sentence, or the CTA the copy already promises
/// each cost more than the 16 pt that are left, and this is the card that would
/// break first. The render test pins the fit in both locales, so spending the
/// margin fails CI instead of shipping.
///
/// The absolute figures are inflated by the test font (`flutter_test` draws
/// every glyph as a square of the font size, so English measures roughly twice
/// as wide as Inter renders it; AR measures 360 pt in this same window). The
/// structure — a centred, non-scrolling column with no fallback at any text
/// scale — is not a font artifact.
@JeebPreview(
  group: 'request_summary',
  name: 'Compact · 200% text',
  size: _requestSummaryUnavailableScreenCompactCanvas,
)
Widget requestSummaryUnavailableScreenCompactLargeText() =>
    _requestSummaryUnavailableScreenHosted(
      RequestSummaryUnavailableScreenWindows.compactLargeText,
    );

/// The same phone as the reference reading, with nothing underneath it.
///
/// This is the arrival this screen was WRITTEN for: a cold deep link straight
/// to `/request-summary` with no `extra`, the case
/// `test/core/router/request_summary_route_test.dart` Test 2 pins. `maybePop()`
/// then finds nothing to pop, so the back arrow — the only control on the
/// screen, since no `onBackPressed` is passed and [OmdsErrorState] gets no
/// `onRetry` — silently does nothing, while the body tells the user to "Start a
/// new request to continue".
///
/// Compare it with `Phone 390 × 844`: identical pixels, opposite behaviour, no
/// visual difference whatsoever. That is the point of previewing it.
@JeebPreview(
  group: 'request_summary',
  name: 'Cold deep link · nothing to pop',
  size: _requestSummaryUnavailableScreenPhoneCanvas,
)
Widget requestSummaryUnavailableScreenDeepLink() =>
    _requestSummaryUnavailableScreenHosted(
      RequestSummaryUnavailableScreenWindows.phoneDeepLink,
      parentOnStack: false,
    );

/// The Screen Catalog's own state, rendered in the canvas.
///
/// No frame, no caption, no local Navigator — the form
/// `batch_10_entries.dart` mounts, where the device IS the window and the
/// catalog's own route sits underneath. It is here so the state a designer signs
/// off against is reviewable next to the engineering windows, and so the render
/// test can pin that the extraction did not change what the catalog shows.
@JeebPreview(
  group: 'request_summary',
  name: 'Catalog state · Unavailable',
  size: _requestSummaryUnavailableScreenPhoneCanvas,
)
Widget requestSummaryUnavailableScreenCatalogState() =>
    _requestSummaryUnavailableScreenHosted(null, parentOnStack: null);
