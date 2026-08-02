import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/accessibility/accessibility.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/client_offers_state.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
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

// Widget previews for [OfferSortBar] — run with

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
const double _offerSortBarMaxTextScale = 2.0;

/// One specimen: the bar in a named state, with an optional [note] under it.
/// [slotWidth] constrains the bar to a real device slot; [textScale] pins the
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
/// `ClientOffersState.sortMode` defaults to [OfferSortMode.byPrice] and
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
/// Worth its own preview precisely because the two states differ by fill only.
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
/// This is not decoration. Each chip sits under three layers that can each
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
/// The outlined box is the slot; everything inside it is the row. This is the
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
/// AC T-mobile-036 requires every screen to scale to 200% *without overflow*,
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
/// [OverflowBox] hands the child unbounded width — so the [Row] measures what
/// it *wants* rather than reporting an overflow — while the box itself still
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
