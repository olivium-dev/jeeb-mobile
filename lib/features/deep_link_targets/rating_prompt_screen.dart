import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../devtool/catalog/fixtures/rating_prompt_screen_fixtures.dart';
import '../../core/previews/jeeb_preview.dart';

class RatingPromptScreen extends StatefulWidget {
  const RatingPromptScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  State<RatingPromptScreen> createState() => _RatingPromptScreenState();
}

class _RatingPromptScreenState extends State<RatingPromptScreen> {
  static const String _featureId = 'rating-prompt';

  @override
  void initState() {
    super.initState();
    debugPrint('[placeholder] $_featureId opened');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Rating Prompt coming soon. This screen is not yet available.',
      child: const OmdsEmptyStatePage(
        appBar: OMDSAppBar(title: 'Rate your Jeeber', showBackButton: true),
        icon: Icons.construction_outlined,
        title: 'Rating Prompt coming soon',
        subtitle: 'This screen is not yet available.',
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
// Render tests: test/previews/deep_link_targets/rating_prompt_screen_preview_test.dart
// ===========================================================================
//
// [RatingPromptScreen] has NO data axis. It is a frozen Type-A placeholder
// (`qa/t-mob-fix-001/placeholder-discipline.sh`): it resolves nothing out of
// GetIt, builds no cubit, holds no state, and renders an app bar plus one icon
// and two fixed English sentences. Its own dartdoc forbids adding behavior,
// action buttons, loading indicators or dialogs. There is no empty / loading /
// error to seed and no repository to fake, so the only inputs it has are the
// WINDOW it is painted into — how wide, how tall, how much of the display the
// system chrome has claimed, how large the user has set their text — and the
// deep-link `deliveryId` it is handed. Those are the six states below.
//
// The windows and the host live in
// `lib/devtool/catalog/fixtures/rating_prompt_screen_fixtures.dart` and are
// shared with the Screen Catalog entry for this screen
// (`lib/devtool/catalog/entries/batch_03_entries.dart`), so the designer's
// on-device browser and this canvas render the same designed states. The frame
// is pinned INSIDE the fixture — a `MediaQuery` override plus a `SizedBox` —
// rather than left to the canvas [Size], because the render tests pump onto a
// fixed 800 x 600 surface: a state that merely ASKED for a 320 x 568 canvas
// would be measured at 800 x 600 and all six states would silently become the
// same widget. Windows that exist FOR a text scale pin one; the rest inherit,
// so `matrix: true` can still render its own 200% card.
//
// Note that this screen owns its own `Scaffold` — the OMDS empty-state page
// returns one — and [jeebPreviewHost] wraps every child in one as well, so the
// canvas shows two nested Scaffolds. The inner one is the real surface; the
// outer contributes a background and a `SafeArea`, which is why each window has
// to RESTORE `MediaQuery.padding` or the notched state would mean nothing.
//
// What these previews surfaced in the screen — details on the states below:
//
//  * **The `deliveryId` is accepted and never rendered.** The route
//    (`/orders/:id/rate`) carries a delivery id and hands it to the constructor,
//    and nothing on the surface names a delivery, a jeeber or an order
//    reference — not the app bar, not the title, not the subtitle. The last
//    state below hands the screen a completely different id and renders
//    pixel-for-pixel the same thing, which is what makes the omission visible
//    instead of merely documented.
//  * **The copy is hardcoded English, not localized.** "Rate your Jeeber",
//    "Rating Prompt coming soon", "This screen is not yet available." and the
//    `Semantics` label are string literals rather than ARB lookups, so the AR
//    RTL card of `Phone 390 × 844` renders English inside a right-to-left
//    layout. (That is required here — UX rule #7 is explicitly out of scope for
//    the placeholder gate — but it is what a reviewer sees, so it is recorded.)
//  * **Nothing scrolls, and the composition is clipped at the accessibility
//    ceiling.** The empty-state page centres a `Column(mainAxisSize: min)` —
//    no `ListView`, no `SingleChildScrollView` anywhere in the subtree — and
//    the icon is a fixed 100 pt that does NOT shrink with the text scale. At
//    200% on a 320 x 568 display the column wants 732 pt and is given 464, so
//    the ends of it are cut off with no way to reach them. The app bar is worth
//    56 pt of that shortfall: it is taken off the body before the centred
//    column is measured, leaving 464 pt where the sibling `KycStatusScreen`
//    (same page, no app bar) has 520. Neither figure is enough — the app bar
//    deepens the clip, it does not cause it.
//  * **The app bar reads "Rate your Jeeber" while the body says the screen does
//    not exist.** The two halves of the surface disagree about what the user is
//    looking at, and a screen reader gets both — see the next point.
//  * **The `Semantics(container: true)` wrapper double-announces.** It sets a
//    label ("Rating Prompt coming soon. This screen is not yet available.")
//    over a subtree that already publishes both sentences as text, and does not
//    set `explicitChildNodes`, so a screen reader hears the sentence pair twice.
//  * The good news, recorded because it is cheap to lose: at 100% text nothing
//    clips in any window, in either locale; the app bar consumes the status-bar
//    inset (its sibling, which passes no app bar, does not); and the back
//    button is pop-guarded, so tapping it in the canvas is a no-op rather than
//    an empty-navigator crash.

/// The canvas box for a whole screen: a real device plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _ratingPromptScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on.
const Size _ratingPromptScreenCompactCanvas = Size(332, 612);

/// A notched phone (iPhone 15 Pro class) in portrait.
const Size _ratingPromptScreenNotchedCanvas = Size(405, 896);

/// Every state is the same screen in a different window — see the fixture.
///
/// The `RatingPromptScreen(...)` is constructed HERE rather than inside the
/// fixture host on purpose: `tool/preview_coverage.dart` credits a section only
/// when it literally builds the widget its previews are named after, and it
/// keeps the fixture library free of a circular import back into this one. The
/// id comes off the window so the catalog and this canvas hand the screen the
/// same one in the same state.
Widget _ratingPromptScreenHosted(RatingPromptScreenWindow window) =>
    RatingPromptScreenPreviewHost(
      window: window,
      screen: RatingPromptScreen(deliveryId: window.deliveryId),
    );

/// The reference reading: an ordinary phone, no system chrome, default text.
///
/// Everything fits with room to spare — a 56 pt app bar and a 252 pt centred
/// column in the 788 pt left under it. Read the five states below against this
/// one.
///
/// Matrixed because the AR card is the finding: all three strings and the
/// `Semantics` label are hardcoded English literals rather than ARB lookups, so
/// the right-to-left rendering shows English copy in a mirrored layout. If this
/// preview ever renders Arabic, someone localized the screen and this note is
/// stale.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Phone 390 × 844',
  size: _ratingPromptScreenPhoneCanvas,
  matrix: true,
)
Widget ratingPromptScreenPhone() =>
    _ratingPromptScreenHosted(RatingPromptScreenWindows.phone);

/// The smallest display the app supports, at default text size.
///
/// Still clean: the fixed 100 pt icon plus both sentences come to 284 pt of the
/// 464 pt the app bar and the page's own padding leave of 568. This is the last
/// window in which the missing scroll view costs nothing.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Compact 320 × 568',
  size: _ratingPromptScreenCompactCanvas,
)
Widget ratingPromptScreenCompact() =>
    _ratingPromptScreenHosted(RatingPromptScreenWindows.compact);

/// The accessibility ceiling on an ordinary phone: 200% text on 390 × 844.
///
/// Both sentences wrap several times around an icon that did not grow, so the
/// column roughly doubles — measured 524 pt of the 788 pt the app bar leaves.
/// It holds. Width is what saves it, not height: the same content in a 320
/// pt-wide window wraps to 732 pt and is the state below.
///
/// Worth noticing while you are here: the app bar title does NOT double. The
/// toolbar clamps its own text scaling, so "Rate your Jeeber" grows by about a
/// third while everything under it grows by a half again as much.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Phone · 200% text',
  size: _ratingPromptScreenPhoneCanvas,
)
Widget ratingPromptScreenPhoneLargeText() =>
    _ratingPromptScreenHosted(RatingPromptScreenWindows.phoneLargeText);

/// The worst case the app supports: the smallest display AND the largest text.
///
/// This is the state that breaks. The centred column is
/// `Column(mainAxisSize: min)` with nothing scrollable above or below it, and
/// the icon is a fixed 100 pt that ignores the text scale, so the column asks
/// for more height than the body has and the ends of it are simply cut off.
/// There is no scroll affordance and no way for the user to reach what was
/// clipped.
///
/// Measured under `flutter test`: 732 pt of content in the 464 pt the app bar
/// and the page's own padding leave of a 568 pt display — "RenderFlex
/// overflowed by 268 pixels on the bottom", in EN and AR alike. The app bar
/// owns 56 pt of that: strip it and the body is 520 pt, which the same content
/// still overruns, so the toolbar deepens the clip rather than causing it.
///
/// Treat 268 with care, since the test font is wider than Inter and wraps
/// English more often than a device would. What is NOT a font artifact is that
/// nothing in this screen can absorb a shortfall of any size, which is what the
/// render test pins.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Compact · 200% text',
  size: _ratingPromptScreenCompactCanvas,
)
Widget ratingPromptScreenCompactLargeText() =>
    _ratingPromptScreenHosted(RatingPromptScreenWindows.compactLargeText);

/// A notched phone at the accessibility ceiling: 59 pt status bar, 34 pt home
/// indicator, 200% text.
///
/// The app bar consumes the top inset — measured 115 pt tall, 56 + 59 — and
/// paints its title below the notch, which is the one structural difference
/// from the sibling placeholder that passes no app bar. The 524 pt column then
/// centres in the 737 pt left over and clears both edges.
///
/// The bottom inset is still nobody's job: no bottom bar occupies that slot and
/// `Scaffold` does not `SafeArea` its body, so the column clears the home
/// indicator only because it is centred and short.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Notched · 200% text',
  size: _ratingPromptScreenNotchedCanvas,
)
Widget ratingPromptScreenNotchedLargeText() =>
    _ratingPromptScreenHosted(RatingPromptScreenWindows.notchedLargeText);

/// The same reference phone, handed a DIFFERENT deep-link delivery id.
///
/// Put this card next to `Phone 390 × 844` in the canvas: they are the same
/// picture. The route hands this screen the id of the delivery the customer was
/// asked to rate, and the surface names no delivery, no jeeber and no order
/// reference — the caption above the frame is the only place in either
/// rendering where the id appears at all, and the caption belongs to the
/// preview harness, not to the screen.
///
/// The field is retained deliberately ("so the import-graph stays green", per
/// the class dartdoc) and the route redirects to the real mutual-rating screen
/// in production, so this is not a live user-facing defect today. It is the
/// thing to fix FIRST when `T-MOB-RATING-001` lifts the gate and this screen
/// starts rendering a real jeeber profile.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Deep-link id · never rendered',
  size: _ratingPromptScreenPhoneCanvas,
)
Widget ratingPromptScreenUnusedDeepLinkId() =>
    _ratingPromptScreenHosted(RatingPromptScreenWindows.unusedDeepLinkId);
