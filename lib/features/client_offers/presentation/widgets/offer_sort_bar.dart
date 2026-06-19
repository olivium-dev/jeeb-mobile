import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/client_offers_state.dart';

/// Sort toggle: price (default) ↔ rating. Two OMDS chips so the active
/// selection reads as "selected" to screen readers via the underlying
/// FilterChip semantics.
///
/// Semantics identifiers (EXACT, 63_W1_TEST_PLAN §2.8 — the AC's
/// `offer_review_sort_<key>` pattern, `price` coined as the primary key):
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
            child: OmdsChip(
              key: const Key('offer-sort-price'),
              label: l10n.offersSortByPrice,
              isSelected: mode == OfferSortMode.byPrice,
              onTap: () => onChanged(OfferSortMode.byPrice),
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
            child: OmdsChip(
              key: const Key('offer-sort-rating'),
              label: l10n.offersSortByRating,
              isSelected: mode == OfferSortMode.byRating,
              onTap: () => onChanged(OfferSortMode.byRating),
            ),
          ),
        ),
      ],
    );
  }
}
