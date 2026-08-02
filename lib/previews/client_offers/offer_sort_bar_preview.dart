/// Widget previews for [OfferSortBar] — run with
/// `flutter widget-preview start`.
///
/// The bar is a pure function of two arguments — an [OfferSortMode] and a
/// `ValueChanged` — with no cubit, no repository and no async work of its own.
/// Every preview below is therefore a plain constructor call: network-free by
/// construction, not merely by the guard in [jeebPreviewHost]. The production
/// screen reads `state.sortMode` off `ClientOffersCubit` and writes back
/// through `setSortMode` (`client_offers_screen.dart:271`); seeding a cubit
/// here would add a dependency the widget does not have.
///
/// Two properties of the widget shape this file:
///
/// * **Its text is identical in every state.** "Sort", "Lowest price" and
///   "Top rated" render the same whichever chip is selected — only the fill
///   changes. A canvas of look-alike rows is exactly the case where a preview
///   file can render one state five times and still pass its render test, so
///   each preview is a *specimen*: the bar, plus a caption naming the state.
///   The caption is preview chrome, not part of the component — `labelSmall` /
///   `onSurfaceVariant`, and deliberately unlocalized, so seeing English there
///   in the AR RTL rendering is expected. The bar's own copy comes from the
///   real ARB (`offersSortLabel` / `offersSortByPrice` / `offersSortByRating`),
///   so the Arabic rendering exercises real strings and real mirroring.
/// * **It is an unflexed [Row].** The label and both chips are non-flexible
///   children with no [Flexible], no [Wrap] and no ellipsis anywhere in the
///   chain — `OmdsChip` wraps a bare [Text] with no `maxLines`. So the row's
///   width is whatever its content wants, and the last two previews are about
///   what happens when the slot is narrower than that.
///
/// The production slot is exact: the offers list pads its [ListView] by
/// `Spacing.medium` on both sides (`client_offers_screen.dart:230`), so on a
/// 390 dp phone the bar is handed [_kProductionWidth] = 358 dp, tight.
/// [_Slot] draws that width as an outlined box and lets the row take its
/// intrinsic width inside a clip, so over-wide content is visibly cut at the
/// slot edge instead of throwing. In the app there is no clip and no
/// [OverflowBox]: the same overflow paints the debug stripe and reports a
/// `RenderFlex overflowed` error. The clip is what makes the state *reviewable*
/// alongside the others; the width assertions in
/// `test/previews/client_offers/offer_sort_bar_preview_test.dart` are the hard
/// evidence.
library;

import 'package:flutter/material.dart';
// `OverflowBoxFit` lives in the rendering library and is not re-exported by
// material.dart; [_Slot] needs `deferToChild` to size to the slot instead of
// the unbounded height a Column hands down.
import 'package:flutter/rendering.dart';
import 'package:omds/omds.dart';

import '../../features/client_offers/application/client_offers_state.dart';
import '../../features/client_offers/presentation/widgets/offer_sort_bar.dart';
import '../harness/jeeb_preview.dart';

/// A short, wide box: the bar is one 48 dp row, and the extra height is for the
/// caption to double in the 200%-text rendering without clipping the evidence.
const Size _rowBox = Size(390, 170);

/// Same width, taller: the live state stacks a readout under the bar.
const Size _liveBox = Size(390, 200);

/// Taller again: the slot states carry a caption, a note and an outlined box.
const Size _slotBox = Size(390, 230);

/// The width the offers list actually hands the bar on a 390 dp phone:
/// 390 − 2 × [Spacing.medium] (`client_offers_screen.dart:230`).
const double _kProductionWidth = 390 - 2 * Spacing.medium;

/// The accessibility ceiling the app itself enforces — `A11y.maxTextScaleFactor`
/// clamps the OS slider here, so this is the largest text the bar can ever be
/// asked to lay out.
const double _kMaxTextScale = 2.0;

/// One specimen: the bar in a named state, with an optional [note] under it.
///
/// [slotWidth] constrains the bar to a real device slot; [textScale] pins the
/// text scaler regardless of the ambient rendering, so the 200%-text state
/// still reads 200% in the EN light and AR RTL dark renderings of the matrix
/// rather than compounding to 400% in the third.
Widget _hosted({
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
        bar = _Slot(width: slotWidth, child: bar);
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
@JeebPreview(group: 'client_offers', name: 'Price selected · default', size: _rowBox)
Widget offerSortBarPriceSelected() => _hosted(
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
@JeebPreview(group: 'client_offers', name: 'Rating selected', size: _rowBox)
Widget offerSortBarRatingSelected() => _hosted(
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
@JeebPreview(group: 'client_offers', name: 'Live toggle', size: _liveBox)
Widget offerSortBarLiveToggle() => _hosted(
      caption: 'Live toggle · tap a chip',
      child: const _LiveToggle(),
    );

/// The bar at the width it actually gets, at default text: 358 dp.
///
/// The outlined box is the slot; everything inside it is the row. This is the
/// headroom reading — 238 dp of content in a 358 dp slot, measured with the
/// bundled Inter face — which is why nothing has ever been reported here and
/// why the state below is a surprise when it lands.
@JeebPreview(group: 'client_offers', name: 'Production slot · 358 dp', size: _slotBox)
Widget offerSortBarProductionSlot() => _hosted(
      caption: 'Production slot · 358 dp',
      note: 'Outline = the width the offers ListView hands the bar.',
      slotWidth: _kProductionWidth,
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
/// The clip in [_Slot] is what you are looking at; the app has none. There the
/// same layout paints the yellow overflow stripe across the offers panel and
/// logs `A RenderFlex overflowed by … pixels on the right`. The numbers above
/// are asserted in `offer_sort_bar_preview_test.dart`.
@JeebPreview(group: 'client_offers', name: 'Production slot · 200% text', size: _slotBox)
Widget offerSortBarLargeTextInSlot() => _hosted(
      caption: 'Production slot · 200% text',
      note: 'Cut at the slot edge. In-app this is a RenderFlex overflow.',
      slotWidth: _kProductionWidth,
      textScale: _kMaxTextScale,
      child: OfferSortBar(mode: OfferSortMode.byPrice, onChanged: (_) {}),
    );

/// A device-width slot with the row laid out at its intrinsic width inside it.
///
/// [OverflowBox] hands the child unbounded width — so the [Row] measures what
/// it *wants* rather than reporting an overflow — while the box itself still
/// reports [width] to its parent, and [ClipRect] cuts whatever does not fit.
/// The cut edge is the point: it is where the app would start painting the
/// debug stripe.
class _Slot extends StatelessWidget {
  const _Slot({required this.width, required this.child});

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
class _LiveToggle extends StatefulWidget {
  const _LiveToggle();

  @override
  State<_LiveToggle> createState() => _LiveToggleState();
}

class _LiveToggleState extends State<_LiveToggle> {
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
