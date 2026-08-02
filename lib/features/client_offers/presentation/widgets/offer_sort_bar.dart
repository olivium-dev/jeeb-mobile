import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/accessibility/accessibility.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/client_offers_state.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
// `OverflowBoxFit` lives in the rendering library and is not re-exported by
// material.dart; the preview slot needs `deferToChild` to size to the slot
// instead of the unbounded height a Column hands down.
import 'package:flutter/rendering.dart';
import '../../../../core/previews/jeeb_preview.dart';

class OfferSortBar extends StatelessWidget {
  const OfferSortBar({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final OfferSortMode mode;
  final ValueChanged<OfferSortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: Spacing.small),
          child: Text(
            l10n.offersSortLabel,
            style: theme.textTheme.labelLarge,
          ),
        ),
        Semantics(
          identifier: 'offer_review_sort_price',
          button: true,
          selected: mode == OfferSortMode.byPrice,
          label: l10n.offersSortByPrice,
          onTap: () => onChanged(OfferSortMode.byPrice),
          child: ExcludeSemantics(
            child: MinTapTarget(
              key: const Key('offer-sort-price'),
              onTap: () => onChanged(OfferSortMode.byPrice),
              child: OmdsChip(
                label: l10n.offersSortByPrice,
                isSelected: mode == OfferSortMode.byPrice,
              ),
            ),
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        Semantics(
          identifier: 'offer_review_sort_rating',
          button: true,
          selected: mode == OfferSortMode.byRating,
          label: l10n.offersSortByRating,
          onTap: () => onChanged(OfferSortMode.byRating),
          child: ExcludeSemantics(
            child: MinTapTarget(
              key: const Key('offer-sort-rating'),
              onTap: () => onChanged(OfferSortMode.byRating),
              child: OmdsChip(
                label: l10n.offersSortByRating,
                isSelected: mode == OfferSortMode.byRating,
              ),
            ),
          ),
        ),
      ],
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
// Render tests: test/previews/client_offers/offer_sort_bar_preview_test.dart
// ===========================================================================

// Widget previews for [OfferSortBar] — run with
// `flutter widget-preview start`.
//
// The bar is a pure function of two arguments — an [OfferSortMode] and a
// `ValueChanged` — with no cubit, no repository and no async work of its own.
// Every preview below is therefore a plain constructor call: network-free by
// construction, not merely by the guard in [jeebPreviewHost]. The production
// screen reads `state.sortMode` off `ClientOffersCubit` and writes back
// through `setSortMode` (`client_offers_screen.dart:271`); seeding a cubit
// here would add a dependency the widget does not have.
//
// Two properties of the widget shape this section:
//
// * **Its text is identical in every state.** "Sort", "Lowest price" and
//   "Top rated" render the same whichever chip is selected — only the fill
//   changes. A canvas of look-alike rows is exactly the case where a preview
//   file can render one state five times and still pass its render test, so
//   each preview is a *specimen*: the bar, plus a caption naming the state.
//   The caption is preview chrome, not part of the component — `labelSmall` /
//   `onSurfaceVariant`, and deliberately unlocalized, so seeing English there
//   in the AR RTL rendering is expected. The bar's own copy comes from the
//   real ARB (`offersSortLabel` / `offersSortByPrice` / `offersSortByRating`),
//   so the Arabic rendering exercises real strings and real mirroring.
// * **It is an unflexed [Row].** The label and both chips are non-flexible
//   children with no [Flexible], no [Wrap] and no ellipsis anywhere in the
//   chain — `OmdsChip` wraps a bare [Text] with no `maxLines`. So the row's
//   width is whatever its content wants, and the last two previews are about
//   what happens when the slot is narrower than that.
//
// The production slot is exact: the offers list pads its [ListView] by
// `Spacing.medium` on both sides (`client_offers_screen.dart:230`), so on a
// 390 dp phone the bar is handed [_offerSortBarProductionWidth] = 358 dp,
// tight. [_OfferSortBarSlot] draws that width as an outlined box and lets the
// row take its intrinsic width inside a clip, so over-wide content is visibly
// cut at the slot edge instead of throwing. In the app there is no clip and no
// [OverflowBox]: the same overflow paints the debug stripe and reports a
// `RenderFlex overflowed` error. The clip is what makes the state *reviewable*
// alongside the others; the width assertions in
// `test/previews/client_offers/offer_sort_bar_preview_test.dart` are the hard
// evidence.

/// A short, wide box: the bar is one 48 dp row, and the extra height is for the
/// caption to double in the 200%-text rendering without clipping the evidence.
const Size _offerSortBarRowBox = Size(390, 170);

/// Same width, taller: the live state stacks a readout under the bar.
const Size _offerSortBarLiveBox = Size(390, 200);

/// Taller again: the slot states carry a caption, a note and an outlined box.
const Size _offerSortBarSlotBox = Size(390, 230);

/// The width the offers list actually hands the bar on a 390 dp phone:
/// 390 − 2 × [Spacing.medium] (`client_offers_screen.dart:230`).
const double _offerSortBarProductionWidth = 390 - 2 * Spacing.medium;

/// The accessibility ceiling the app itself enforces — `A11y.maxTextScaleFactor`
/// clamps the OS slider here, so this is the largest text the bar can ever be
/// asked to lay out.
const double _offerSortBarMaxTextScale = 2.0;

/// One specimen: the bar in a named state, with an optional [note] under it.
///
/// [slotWidth] constrains the bar to a real device slot; [textScale] pins the
/// text scaler regardless of the ambient rendering, so the 200%-text state
/// still reads 200% in the EN light and AR RTL dark renderings of the matrix
/// rather than compounding to 400% in the third.
Widget _offerSortBarHosted({
  required String caption,
  required Widget child,
  String? note,
  double? slotWidth,
  double? textScale,
}) {
  return Builder(
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      Widget bar = child;
      if (textScale != null) {
        bar = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: bar,
        );
      }
      if (slotWidth != null) {
        bar = _OfferSortBarSlot(width: slotWidth, child: bar);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xSmall),
          bar,
          if (note != null) ...<Widget>[
            const SizedBox(height: Spacing.xSmall),
            Text(
              note,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// The default the cubit starts in and the AC names as primary: cheapest first.
///
/// `ClientOffersState.sortMode` defaults to [OfferSortMode.byPrice] and
/// `test/client_offers_cubit_test.dart:53` pins it, so this is the state every
/// client sees when the offers panel first paints. The review question is
/// whether "selected" is legible *as a selection*: `OmdsChip` carries it on
/// fill alone — `colorScheme.primary` versus `surfaceContainerHigh` with a 30%
/// outline — with no checkmark and no weight change beyond `w600`.
@JeebPreview(
  group: 'client_offers',
  name: 'Price selected · default',
  size: _offerSortBarRowBox,
)
Widget offerSortBarPriceSelected() => _offerSortBarHosted(
      caption: 'Price selected · default',
      child: OfferSortBar(mode: OfferSortMode.byPrice, onChanged: (_) {}),
    );

/// The other half of the toggle: best Jeebers first.
///
/// Worth its own preview precisely because the two states differ by fill only.
/// Put this beside [offerSortBarPriceSelected] — if the pair is hard to tell
/// apart at a glance, the control is not communicating which sort is live, and
/// the **AR RTL dark** rendering is where that gets decided: an unselected chip
/// is `surfaceContainerHigh` behind a `outline @ 30%` border, which is the
/// lowest-contrast edge in the widget.
@JeebPreview(
  group: 'client_offers',
  name: 'Rating selected',
  size: _offerSortBarRowBox,
)
Widget offerSortBarRatingSelected() => _offerSortBarHosted(
      caption: 'Rating selected',
      child: OfferSortBar(mode: OfferSortMode.byRating, onChanged: (_) {}),
    );

/// The interactive state: tap either chip and the selection follows.
///
/// This is not decoration. Each chip sits under three layers that can each
/// swallow a tap — `Semantics(onTap:) → ExcludeSemantics → MinTapTarget`, whose
/// `IgnorePointer` deliberately kills the chip's own `onTap` — so "does a tap
/// on the visible capsule reach `onChanged`?" is a real question with a real
/// wrong answer. The readout under the bar reports the mode by enum name
/// (`byPrice` / `byRating`) rather than by label, so it can never be confused
/// with the chip copy above it.
///
/// Stateful only for that readout: no controller, no ticker, nothing to settle
/// beyond `OmdsChip`'s 200 ms fill animation.
@JeebPreview(
  group: 'client_offers',
  name: 'Live toggle',
  size: _offerSortBarLiveBox,
)
Widget offerSortBarLiveToggle() => _offerSortBarHosted(
      caption: 'Live toggle · tap a chip',
      child: const _OfferSortBarLiveToggle(),
    );

/// The bar at the width it actually gets, at default text: 358 dp.
///
/// The outlined box is the slot; everything inside it is the row. This is the
/// headroom reading — 238 dp of content in a 358 dp slot, measured with the
/// bundled Inter face — which is why nothing has ever been reported here and
/// why the state below is a surprise when it lands.
@JeebPreview(
  group: 'client_offers',
  name: 'Production slot · 358 dp',
  size: _offerSortBarSlotBox,
)
Widget offerSortBarProductionSlot() => _offerSortBarHosted(
      caption: 'Production slot · 358 dp',
      note: 'Outline = the width the offers ListView hands the bar.',
      slotWidth: _offerSortBarProductionWidth,
      child: OfferSortBar(mode: OfferSortMode.byPrice, onChanged: (_) {}),
    );

/// **The state that breaks.** The same 358 dp slot at the 200% ceiling.
///
/// AC T-mobile-036 requires every screen to scale to 200% *without overflow*,
/// and `A11y.maxTextScaleFactor` clamps the OS slider to exactly this. The row
/// has no [Flexible], the chips have no `maxLines`, and `MinTapTarget` only
/// ever grows a child — so nothing in the chain can give: the content overruns
/// the slot and the trailing chip ("Top rated", the only way to reach the
/// rating sort) is what falls off the end.
///
/// Measured with the bundled Inter face: **395 dp of content in a 358 dp
/// slot**, ~37 dp over on a 390 dp phone. On the 360 dp S22 the slot is 328 dp
/// and the overrun is ~67 dp — most of the trailing chip.
///
/// The clip in [_OfferSortBarSlot] is what you are looking at; the app has none.
/// There the same layout paints the yellow overflow stripe across the offers
/// panel and logs `A RenderFlex overflowed by … pixels on the right`. The
/// numbers above are asserted in `offer_sort_bar_preview_test.dart`.
@JeebPreview(
  group: 'client_offers',
  name: 'Production slot · 200% text',
  size: _offerSortBarSlotBox,
)
Widget offerSortBarLargeTextInSlot() => _offerSortBarHosted(
      caption: 'Production slot · 200% text',
      note: 'Cut at the slot edge. In-app this is a RenderFlex overflow.',
      slotWidth: _offerSortBarProductionWidth,
      textScale: _offerSortBarMaxTextScale,
      child: OfferSortBar(mode: OfferSortMode.byPrice, onChanged: (_) {}),
    );

/// A device-width slot with the row laid out at its intrinsic width inside it.
///
/// [OverflowBox] hands the child unbounded width — so the [Row] measures what
/// it *wants* rather than reporting an overflow — while the box itself still
/// reports [width] to its parent, and [ClipRect] cuts whatever does not fit.
/// The cut edge is the point: it is where the app would start painting the
/// debug stripe.
class _OfferSortBarSlot extends StatelessWidget {
  const _OfferSortBarSlot({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(Spacing.twoXSmall),
        ),
        child: ClipRect(
          child: OverflowBox(
            alignment: AlignmentDirectional.centerStart,
            minWidth: 0,
            maxWidth: double.infinity,
            fit: OverflowBoxFit.deferToChild,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The bar wired to its own selection, with a live readout of the mode.
class _OfferSortBarLiveToggle extends StatefulWidget {
  const _OfferSortBarLiveToggle();

  @override
  State<_OfferSortBarLiveToggle> createState() =>
      _OfferSortBarLiveToggleState();
}

class _OfferSortBarLiveToggleState extends State<_OfferSortBarLiveToggle> {
  OfferSortMode _mode = OfferSortMode.byPrice;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OfferSortBar(
          mode: _mode,
          onChanged: (OfferSortMode mode) => setState(() => _mode = mode),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text('mode: ${_mode.name}', style: theme.textTheme.labelMedium),
      ],
    );
  }
}
