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

  String _initial() {
    final trimmed = jeeber.displayName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OmdsProfileAvatar(
          initial: _initial(),
          profilePicUrl: jeeber.avatarUrl,
          size: Sizes.threeXLarge,
          backgroundColor: colorScheme.primaryContainer,
          initialColor: colorScheme.onPrimaryContainer,
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
