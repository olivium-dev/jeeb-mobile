import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/jeeber_summary.dart';

/// Shows the matched Jeeber's avatar, display name, vehicle, and rating.
///
/// Renders a `looking for…` placeholder while [jeeber] is null. The card
/// intentionally does not embed the Contact CTA — that's owned by the
/// screen's action bar so the layout stays uniform across lifecycle states.
class DeliveryJeeberCard extends StatelessWidget {
  const DeliveryJeeberCard({super.key, required this.jeeber});

  static const Key rootKey = Key('delivery-status-jeeber-card');

  final JeeberSummary? jeeber;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OMDSSectionCard(
      key: rootKey,
      title: l10n.deliveryJeeberCardTitle,
      content: jeeber == null ? _Waiting() : _JeeberRow(jeeber: jeeber!),
    );
  }
}

class _Waiting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const OmdsLoadingState(
          size: Sizes.xLarge,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: Spacing.medium),
        Expanded(
          child: Text(
            AppLocalizations.of(context).deliveryJeeberWaiting,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _JeeberRow extends StatelessWidget {
  const _JeeberRow({required this.jeeber});

  final JeeberSummary jeeber;

  String _initials() {
    final parts = jeeber.displayName.trim().split(RegExp(r'\s+'));
    final letters = parts
        .where((p) => p.isNotEmpty)
        .map((p) => p.characters.first)
        .take(2)
        .join();
    return letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: Sizes.threeXLarge,
          height: Sizes.threeXLarge,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: jeeber.avatarUrl == null
              ? Text(
                  _initials(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : ClipOval(
                  child: Image.network(
                    jeeber.avatarUrl!,
                    width: Sizes.threeXLarge,
                    height: Sizes.threeXLarge,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Text(_initials()),
                  ),
                ),
        ),
        const SizedBox(width: Spacing.medium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                jeeber.displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Sizes.threeXSmall),
              Text(
                jeeber.vehicleLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (jeeber.rating != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.small,
              vertical: Spacing.twoXSmall,
            ),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer,
              borderRadius: OmdsBorderRadius.small,
            ),
            child: Text(
              l10n.deliveryJeeberRating(jeeber.rating!.toStringAsFixed(1)),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}
