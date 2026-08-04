import 'package:flutter/material.dart';

import '../../../../core/accessibility/accessibility.dart';
import '../../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/client_offers_state.dart';

/// Sort bar: **Best** (default) · **Lowest price** · **Top rated**.
///
/// The board draws three bare pills with no "Sort by" prefix — the chips label
/// themselves — so the prefix is gone. Each capsule is a kit
/// `JeebSelectChip(role: sort)`, which deliberately carries **no** minimum
/// height: the 48dp target is the surrounding [MinTapTarget], and
/// `client_offers_screen_test` asserts the visible capsule stays strictly
/// shorter than it.
///
/// The chips are inert on their own (`onTap: null`) because [MinTapTarget]
/// wraps its child in an `IgnorePointer` and owns the whole target — a second
/// gesture inside would be dead weight.
///
/// Semantics identifiers (EXACT, 63_W1_TEST_PLAN §2.8 — the AC's
/// `offer_review_sort_<key>` pattern):
///   - `offer_review_sort_best`
///   - `offer_review_sort_price`
///   - `offer_review_sort_rating`
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
    return JeebChipRow(
      children: [
        _SortChip(
          identifier: 'offer_review_sort_best',
          chipKey: const Key('offer-sort-best'),
          label: l10n.offersSortByBest,
          selected: mode == OfferSortMode.best,
          onTap: () => onChanged(OfferSortMode.best),
        ),
        _SortChip(
          identifier: 'offer_review_sort_price',
          chipKey: const Key('offer-sort-price'),
          label: l10n.offersSortByPrice,
          selected: mode == OfferSortMode.byPrice,
          onTap: () => onChanged(OfferSortMode.byPrice),
        ),
        _SortChip(
          identifier: 'offer_review_sort_rating',
          chipKey: const Key('offer-sort-rating'),
          label: l10n.offersSortByRating,
          selected: mode == OfferSortMode.byRating,
          onTap: () => onChanged(OfferSortMode.byRating),
        ),
      ],
    );
  }
}

/// One sort pill: the frozen `Semantics → ExcludeSemantics → MinTapTarget`
/// idiom the Maestro flow keys on, around a kit capsule.
class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.identifier,
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String identifier;
  final Key chipKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: MinTapTarget(
          key: chipKey,
          onTap: onTap,
          child: JeebSelectChip(
            role: JeebChipRole.sort,
            label: label,
            selected: selected,
          ),
        ),
      ),
    );
  }
}
