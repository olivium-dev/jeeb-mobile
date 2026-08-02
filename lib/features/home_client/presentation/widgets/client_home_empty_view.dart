import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class ClientHomeEmptyView extends StatelessWidget {
  const ClientHomeEmptyView({super.key, this.onNewOrder});

  final VoidCallback? onNewOrder;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: '_request_empty_state_root',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OmdsEmptyState(
              illustration: const _ApplicationIllustration(),
              title: AppLocalizations.of(context).homeEmptyTitle,
              subtitle: AppLocalizations.of(context).homePendingEmpty,
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: Spacing.medium,
              ),
            ),
            _NewOrderButton(onPressed: onNewOrder),
          ],
        ),
      ),
    );
  }
}

class _ApplicationIllustration extends StatelessWidget {
  const _ApplicationIllustration();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(
        'assets/illustrations/empty_orders.png',
        width: Sizes.twoHundredLarge,
        height: Sizes.twoHundredLarge,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _NewOrderButton extends StatelessWidget {
  const _NewOrderButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: '_request_empty_state_new_order_button',
      button: true,
      child: OmdsPrimaryButton(
        text: l10n.homeEmptyCta,
        borderRadius: OmdsBorderRadius.uiSmall,
        onTap: () => onPressed?.call(),
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
// Render tests: test/previews/home_client/client_home_empty_view_preview_test.dart
// ===========================================================================
//
// This widget takes ONE parameter, `onNewOrder`, and every string it shows is
// a fixed ARB lookup (`homeEmptyTitle` / `homePendingEmpty` / `homeEmptyCta`).
// There is no cubit, no repository and no future: these previews are
// network-free because there is nothing to fetch, not merely because
// [jeebPreviewHost] guards the wire.
//
// Its "states" are therefore the two things a host actually varies:
//
//  * **the slot it is given** — width, remaining height, and the ambient text
//    scale, which together decide how much of the empty state is above the
//    fold, and
//  * **whether the CTA is wired** — the only affordance on the surface.
//
// **The host is a scrolling one, so nothing here overflows.** The single live
// caller is `PendingRequestsTab`, and that tab is a child of the
// `ListView` in `ClientHomeScreen._ReadyLayout`. The widget has no scroll view
// of its own (unlike its jeeber-side sibling `JeeberFeedEmptyView`), so it
// relies on the host for that entirely — which is why every preview below
// hosts it in a scroll view of a FIXED height rather than letting the canvas
// hand it the whole viewport. The framed box in each preview *is* the fold:
// anything drawn below its bottom edge is real content the user has to scroll
// for, and the render test measures exactly that.
//
// **About the captions.** The copy never varies — all five states render "What
// do you need?" — so `find.text` on the widget's own output cannot tell one
// state from another, and a render suite pinned to it would pass with all five
// previews wired to the same slot. Each preview therefore carries a one-line
// caption naming its frame, used by the test only to *address* a state; the
// assertions that prove the states differ are the measured geometry in
// `test/previews/home_client/client_home_empty_view_preview_test.dart`.
//
// Two defects these previews surface, both in the widget/host rather than in
// the previews — see [clientHomeEmptyViewLargeText] (the CTA pill is a fixed
// 48 pt and cannot hold its own label at the 200 % accessibility ceiling) and
// [clientHomeEmptyViewUnwiredCta] (a null `onNewOrder` still renders a
// full-strength, tappable, completely dead button).
//
// **About the numbers quoted below.** They are the ones the render test
// measures, i.e. with Flutter's test font (every glyph a full em square), so
// text wraps earlier there than on a device. The relationships they describe —
// a fixed-height pill against a label that grows, a CTA past the fold — hold
// with any font; the exact pixel counts are that font's. The canvas renders
// the real one, which is the other reason to open it.
//
// Directionality is clean and worth recording so nobody re-checks it: the
// widget's own insets are `EdgeInsetsDirectional`, everything inside
// `OmdsEmptyState` is centred, and the AR RTL rendering of every state below
// is the LTR one with the text swapped. Colour roles are clean too — the title
// takes `onSurface` (17.5:1 light / 14.3:1 dark) and the subtitle
// `onSurfaceVariant` (9.4:1 / 10.9:1) against the scaffold surface, and the
// CTA is `onPrimary` on `primary` (17.1:1 / 7.7:1).

/// The phone the Requests screen is designed against.
const double _clientHomeEmptyViewPhoneWidth = 390;

/// The narrowest device the app still supports.
const double _clientHomeEmptyViewCompactPhoneWidth = 320;

/// What the Requests ListView actually leaves the pending tab on a 390 × 844
/// phone: 844 − 47 pt top safe area − 90 pt shell nav bar (`Sizes.fiveXLarge` +
/// a 34 pt home-indicator inset) = 707 pt of viewport, minus the 160 pt of
/// chrome the tab is stacked under (72 pt greeting + `Spacing.large` + 48 pt
/// filter chips + `Spacing.large`).
const double _clientHomeEmptyViewRequestsSlotHeight = 547;

/// The same arithmetic on a 320 × 568 phone: 568 − 20 − 56 = 492 pt of
/// viewport, minus the same 160 pt of chrome.
const double _clientHomeEmptyViewCompactSlotHeight = 332;

/// Canvas boxes: the framed slot plus a line for the caption.
const Size _clientHomeEmptyViewPhoneBox = Size(
  _clientHomeEmptyViewPhoneWidth,
  _clientHomeEmptyViewRequestsSlotHeight + 40,
);
const Size _clientHomeEmptyViewCompactBox = Size(
  _clientHomeEmptyViewCompactPhoneWidth,
  _clientHomeEmptyViewCompactSlotHeight + 40,
);

/// One state: the empty view inside a fixed slot, hosted the way
/// `ClientHomeScreen._ReadyLayout` hosts it.
///
/// [width]/[slotHeight] are pinned into the tree rather than left to the canvas
/// `size` so the canvas and the render tests lay the widget out identically —
/// the render harness pumps an 800 × 600 surface, and a state that took its
/// width from the canvas would measure 800 pt under test and be
/// indistinguishable from every other state.
///
/// The [SingleChildScrollView] stands in for the screen's `ListView`: vertical
/// growth scrolls, exactly as it does in production, so what these previews
/// show is never an overflow stripe but the honest question — *how much of the
/// empty state is above the fold, and is the CTA in it?*
///
/// [textScale] is pinned the same way and for the same reason (a widget test
/// cannot read the canvas's `textScaleFactor`). It is applied INSIDE the slot,
/// so the caption stays 1×.
///
/// [wired] decides whether `onNewOrder` is supplied at all — the difference
/// between a CTA that starts the new-order flow and one that swallows the tap.
Widget _clientHomeEmptyViewHosted({
  required String caption,
  double width = _clientHomeEmptyViewPhoneWidth,
  double slotHeight = _clientHomeEmptyViewRequestsSlotHeight,
  double? textScale,
  bool wired = true,
}) {
  Widget slot = SizedBox(
    width: width,
    height: slotHeight,
    child: SingleChildScrollView(
      child: ClientHomeEmptyView(onNewOrder: wired ? () {} : null),
    ),
  );

  if (textScale != null) {
    final Widget scaled = slot;
    slot = Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: scaled,
      ),
    );
  }

  return Align(
    alignment: AlignmentDirectional.topStart,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ClientHomeEmptyViewCaption(caption),
        _ClientHomeEmptyViewFoldFrame(child: slot),
      ],
    ),
  );
}

/// The production geometry: the pending tab's slot on a 390 pt phone at default
/// text size.
///
/// This is the one state a designer signs off, and it is comfortable — the
/// 200 pt illustration, both lines of copy and the full-width CTA all land
/// inside the 547 pt slot with room to spare. Compare it with every other state
/// here: this is the only one in which the user can see what to do without
/// scrolling.
@JeebPreview(
  group: 'home_client',
  name: 'Requests slot · 390',
  size: _clientHomeEmptyViewPhoneBox,
)
Widget clientHomeEmptyViewRequestsSlot() =>
    _clientHomeEmptyViewHosted(caption: 'Requests slot: 390 x 547');

/// The same content on the narrowest supported phone.
///
/// Two things change, and only one of them is visible in a screenshot. The
/// illustration is `Sizes.twoHundredLarge` — an absolute 200 pt, not a fraction
/// of the frame — so it grows from 51 % to 63 % of the width while the copy
/// around it has 70 pt less room to wrap in. And the slot itself is 332 pt, so
/// **the CTA is already below the fold at default text size** — its top edge
/// sits 72 pt past the bottom of the slot. The first thing a small-phone user
/// sees on an empty Requests screen is an illustration with no visible way to
/// act on it.
@JeebPreview(
  group: 'home_client',
  name: 'Compact phone · 320',
  size: _clientHomeEmptyViewCompactBox,
)
Widget clientHomeEmptyViewCompactPhone() => _clientHomeEmptyViewHosted(
      caption: 'Compact phone: 320 x 332',
      width: _clientHomeEmptyViewCompactPhoneWidth,
      slotHeight: _clientHomeEmptyViewCompactSlotHeight,
    );

/// The 200 % accessibility ceiling, with the scale pinned so a widget test
/// reproduces it. **This is the preview to open first.**
///
/// `OmdsPrimaryButton` hard-codes `height: Sizes.fourXLarge` (48 pt) and
/// `_NewOrderButton` does not override it, so the CTA pill is 48 pt tall at
/// every text scale while its label is not: measured in the render test, the
/// height the label NEEDS goes from 40 pt at 1× to **120 pt** at 2×, inside
/// that unchanged 48 pt box (80 pt in Arabic, where the string is shorter —
/// the defect is not locale-specific). Nothing clips it and nothing throws —
/// the label simply paints outside the pill, over the padding beneath it. The
/// button is also the tap target, so the touch area stays 48 pt while the thing
/// the user is aiming at gets taller.
///
/// The second half of this state is the fold: the illustration does NOT scale
/// with text (it stays 200 pt), but everything else does, and the CTA's top
/// edge lands ~125 pt past the bottom of the 547 pt slot. A user at the
/// accessibility ceiling gets an illustration and a title, and must scroll to
/// discover there is a button at all.
@JeebPreview(
  group: 'home_client',
  name: '200% text · 390',
  size: _clientHomeEmptyViewPhoneBox,
)
Widget clientHomeEmptyViewLargeText() => _clientHomeEmptyViewHosted(
      caption: '200% text: 390 x 547',
      textScale: 2,
    );

/// Layout ceiling: the smallest supported phone at the accessibility ceiling.
///
/// The compound of the two states above, and the worst the surface ever gets:
/// 760 pt of content in a 332 pt slot. What is on screen is the fixed 200 pt
/// illustration and the top of the title; the sentence that explains why the
/// list is empty starts 124 pt below the fold and the CTA 380 pt below it.
/// Neither is reachable without a scroll gesture the surface gives no
/// affordance for.
///
/// It is a real combination (320 pt phones ship with the same accessibility
/// settings as any other), and it is the state that makes the case for the
/// illustration shrinking, rather than the copy, when space runs out.
@JeebPreview(
  group: 'home_client',
  name: '200% text · 320',
  size: _clientHomeEmptyViewCompactBox,
)
Widget clientHomeEmptyViewCompactLargeText() => _clientHomeEmptyViewHosted(
      caption: '200% text: 320 x 332',
      width: _clientHomeEmptyViewCompactPhoneWidth,
      slotHeight: _clientHomeEmptyViewCompactSlotHeight,
      textScale: 2,
    );

/// What a host that forgets the callback renders — `ClientHomeEmptyView()` with
/// `onNewOrder` left at its default `null`.
///
/// Pixel-identical to [clientHomeEmptyViewRequestsSlot], which is the whole
/// problem. `_NewOrderButton` passes `onTap: () => onPressed?.call()` — a
/// non-null closure whatever the host did — and never touches `isEnabled`, so
/// `OmdsPrimaryButton` paints the full-strength primary fill, keeps its
/// `GestureDetector` live, and the wrapping `Semantics(button: true)` still
/// announces a button. The tap is absorbed and nothing happens: on a surface
/// whose ONLY affordance is this CTA, that is a dead end rather than a disabled
/// control.
///
/// The live caller (`PendingRequestsTab`) always passes a callback, so this is
/// a preview of what the *next* caller gets for free.
@JeebPreview(
  group: 'home_client',
  name: 'CTA not wired',
  size: _clientHomeEmptyViewPhoneBox,
)
Widget clientHomeEmptyViewUnwiredCta() => _clientHomeEmptyViewHosted(
      caption: 'CTA not wired: onNewOrder null',
      wired: false,
    );

// ---------------------------------------------------------------------------
// Fixtures. Nothing below is production code.
// ---------------------------------------------------------------------------

/// Names the frame the state under it is being reviewed in.
///
/// Preview scaffolding — see the banner above. Deliberately small and 1×-only
/// so the `EN 200% text` rendering of the matrix still shows the widget rather
/// than a wall of label.
class _ClientHomeEmptyViewCaption extends StatelessWidget {
  const _ClientHomeEmptyViewCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: Spacing.twoXSmall,
        bottom: Spacing.twoXSmall,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Draws the slot's edge so the fold is visible in the canvas.
///
/// [DecorationPosition.foreground] paints over the child and never affects
/// layout, so the framed box is exactly the slot the arithmetic above describes
/// — the frame cannot become part of what is being measured.
class _ClientHomeEmptyViewFoldFrame extends StatelessWidget {
  const _ClientHomeEmptyViewFoldFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}
