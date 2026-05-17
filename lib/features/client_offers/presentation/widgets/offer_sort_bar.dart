import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/client_offers_state.dart';

/// Sort toggle: price (default) ↔ rating. Two OMDS chips so the active
/// selection reads as "selected" to screen readers via the underlying
/// FilterChip semantics.
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
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            l10n.offersSortLabel,
            style: theme.textTheme.labelLarge,
          ),
        ),
        OmdsChip(
          key: const Key('offer-sort-price'),
          label: l10n.offersSortByPrice,
          isSelected: mode == OfferSortMode.byPrice,
          onTap: () => onChanged(OfferSortMode.byPrice),
        ),
        const SizedBox(width: 8),
        OmdsChip(
          key: const Key('offer-sort-rating'),
          label: l10n.offersSortByRating,
          isSelected: mode == OfferSortMode.byRating,
          onTap: () => onChanged(OfferSortMode.byRating),
        ),
      ],
    );
  }
}
