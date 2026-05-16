import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../cubit/request_feed_state.dart';
import '../data/request_feed_models.dart';

/// OMDS-styled card rendering one [DeliveryRequest] in the Jeeber feed.
///
/// The card is intentionally composed from OMDS primitives (Spacing, Sizes,
/// OmdsBorderRadius, OmdsPrimaryButton) rather than the salehly-lineage
/// `OmdsRequestCard`, because that card's fixed avatar/title/body shape
/// doesn't match the pickup/dropoff/tier/distance/earnings layout Jeeb
/// needs. Per JEEB-BOUNDARIES.md F8, raw Material widgets are still
/// forbidden — Material.Card and ColorScheme/TextTheme accesses are
/// theme-mediated and explicitly allowed by omds_theme.dart.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.actionStatus,
    required this.secondsRemaining,
    required this.onAccept,
    required this.onDecline,
  });

  final DeliveryRequest request;
  final RequestActionStatus actionStatus;

  /// Seconds left on the per-card countdown — owned by the screen layer's
  /// ticker, not the cubit (the cubit handles the actual expiry, this is
  /// just the visual counter).
  final int secondsRemaining;

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final isAccepting = actionStatus == RequestActionStatus.accepting;
    final isDeclining = actionStatus == RequestActionStatus.declining;
    final actionsLocked =
        actionStatus != RequestActionStatus.idle || secondsRemaining <= 0;

    return Container(
      key: Key('requestFeed.card.${request.id}'),
      margin: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: OmdsBorderRadius.medium,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            tier: request.tier,
            secondsRemaining: secondsRemaining,
            colorScheme: colorScheme,
            textTheme: textTheme,
            l10n: l10n,
          ),
          const SizedBox(height: Spacing.medium),
          _LocationRow(
            icon: Icons.adjust,
            label: l10n.requestFeedPickupLabel,
            value: request.pickup.label,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: Spacing.xSmall),
          _LocationRow(
            icon: Icons.location_on_outlined,
            label: l10n.requestFeedDropoffLabel,
            value: request.dropoff.label,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: Spacing.medium),
          _MetadataRow(
            distanceLabel: l10n.requestFeedDistance(
              request.estimatedDistanceKm.toStringAsFixed(1),
            ),
            earningsLabel: l10n.requestFeedEarnings(
              request.potentialEarnings.toStringAsFixed(2),
              request.currency,
            ),
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: Spacing.medium),
          _Actions(
            acceptLabel: isAccepting
                ? l10n.requestFeedAccepting
                : l10n.requestFeedAccept,
            declineLabel: isDeclining
                ? l10n.requestFeedDeclining
                : l10n.requestFeedDecline,
            onAccept: actionsLocked ? () {} : onAccept,
            onDecline: actionsLocked ? () {} : onDecline,
            acceptEnabled: !actionsLocked,
            declineEnabled: !actionsLocked,
            requestId: request.id,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.tier,
    required this.secondsRemaining,
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
  });

  final JeeberRequestTier tier;
  final int secondsRemaining;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final tierLabel = switch (tier) {
      JeeberRequestTier.light => l10n.requestFeedTierLight,
      JeeberRequestTier.standard => l10n.requestFeedTierStandard,
      JeeberRequestTier.bulk => l10n.requestFeedTierBulk,
    };
    final tierBackground = switch (tier) {
      JeeberRequestTier.light => colorScheme.tertiaryContainer,
      JeeberRequestTier.standard => colorScheme.secondaryContainer,
      JeeberRequestTier.bulk => colorScheme.primaryContainer,
    };
    final tierForeground = switch (tier) {
      JeeberRequestTier.light => colorScheme.onTertiaryContainer,
      JeeberRequestTier.standard => colorScheme.onSecondaryContainer,
      JeeberRequestTier.bulk => colorScheme.onPrimaryContainer,
    };

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.twoXSmall,
          ),
          decoration: BoxDecoration(
            color: tierBackground,
            borderRadius: OmdsBorderRadius.small,
          ),
          child: Text(
            tierLabel,
            key: const Key('requestFeed.card.tierChip'),
            style: textTheme.labelMedium?.copyWith(
              color: tierForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        Icon(
          Icons.timer_outlined,
          size: Sizes.medium,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Text(
          l10n.requestFeedExpiresIn(secondsRemaining),
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: Sizes.large, color: colorScheme.primary),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.distanceLabel,
    required this.earningsLabel,
    required this.colorScheme,
    required this.textTheme,
  });

  final String distanceLabel;
  final String earningsLabel;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.route_outlined,
          size: Sizes.medium,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Text(
          distanceLabel,
          key: const Key('requestFeed.card.distance'),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: Spacing.medium),
        Icon(
          Icons.payments_outlined,
          size: Sizes.medium,
          color: colorScheme.primary,
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Text(
          earningsLabel,
          key: const Key('requestFeed.card.earnings'),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.acceptLabel,
    required this.declineLabel,
    required this.onAccept,
    required this.onDecline,
    required this.acceptEnabled,
    required this.declineEnabled,
    required this.requestId,
  });

  final String acceptLabel;
  final String declineLabel;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool acceptEnabled;
  final bool declineEnabled;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OmdsPrimaryButton(
            key: Key('requestFeed.card.decline.$requestId'),
            text: declineLabel,
            variant: OmdsButtonVariant.outlined,
            isEnabled: declineEnabled,
            onTap: onDecline,
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: OmdsPrimaryButton(
            key: Key('requestFeed.card.accept.$requestId'),
            text: acceptLabel,
            isEnabled: acceptEnabled,
            onTap: onAccept,
          ),
        ),
      ],
    );
  }
}
