import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../cubit/request_feed_state.dart';
import '../data/request_feed_models.dart';










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

  
  
  final int? secondsRemaining;

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: Key('requestFeed.card.${request.id}'),
      margin: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: _decoration(colorScheme),
      child: _CardBody(
        request: request,
        actionStatus: actionStatus,
        secondsRemaining: secondsRemaining,
        onAccept: onAccept,
        onDecline: onDecline,
      ),
    );
  }

  BoxDecoration _decoration(ColorScheme colorScheme) {
    return BoxDecoration(
      color: colorScheme.surface,
      borderRadius: OmdsBorderRadius.medium,
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(
          alpha: UIConstants.opacityDisabled,
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.request,
    required this.actionStatus,
    required this.secondsRemaining,
    required this.onAccept,
    required this.onDecline,
  });

  final DeliveryRequest request;
  final RequestActionStatus actionStatus;
  final int? secondsRemaining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  bool get _actionsLocked =>
      actionStatus != RequestActionStatus.idle ||
      (secondsRemaining != null && secondsRemaining! <= 0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (request.tier != null || secondsRemaining != null) ...[
          _CardHeader(tier: request.tier, secondsRemaining: secondsRemaining),
          const SizedBox(height: Spacing.medium),
        ],
        _CardSections(
          request: request,
          actionStatus: actionStatus,
          enabled: !_actionsLocked,
          onAccept: _actionsLocked ? () {} : onAccept,
          onDecline: _actionsLocked ? () {} : onDecline,
        ),
      ],
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.tier, required this.secondsRemaining});

  final JeeberRequestTier? tier;
  final int? secondsRemaining;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return _Header(
      tier: tier,
      secondsRemaining: secondsRemaining,
      colorScheme: colorScheme,
      textTheme: textTheme,
      l10n: l10n,
    );
  }
}

class _CardSections extends StatelessWidget {
  const _CardSections({
    required this.request,
    required this.actionStatus,
    required this.enabled,
    required this.onAccept,
    required this.onDecline,
  });

  final DeliveryRequest request;
  final RequestActionStatus actionStatus;
  final bool enabled;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Locations(request: request, l10n: l10n),
        const SizedBox(height: Spacing.medium),
        _Metadata(request: request, l10n: l10n),
        const SizedBox(height: Spacing.medium),
        _CardActions(
          request: request,
          actionStatus: actionStatus,
          onAccept: onAccept,
          onDecline: onDecline,
          enabled: enabled,
          l10n: l10n,
        ),
      ],
    );
  }
}

class _Locations extends StatelessWidget {
  const _Locations({required this.request, required this.l10n});

  final DeliveryRequest request;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.request, required this.l10n});

  final DeliveryRequest request;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return _MetadataRow(
      distanceLabel: l10n.requestFeedDistance(
        request.estimatedDistanceKm.toStringAsFixed(1),
      ),
      earningsLabel: l10n.requestFeedEarnings(
        request.potentialEarnings.toStringAsFixed(2),
        request.currency,
      ),
      colorScheme: colorScheme,
      textTheme: textTheme,
    );
  }
}

class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.request,
    required this.actionStatus,
    required this.onAccept,
    required this.onDecline,
    required this.enabled,
    required this.l10n,
  });

  final DeliveryRequest request;
  final RequestActionStatus actionStatus;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool enabled;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isAccepting = actionStatus == RequestActionStatus.accepting;
    final isDeclining = actionStatus == RequestActionStatus.declining;
    return _Actions(
      acceptLabel: isAccepting ? l10n.requestFeedAccepting : l10n.requestFeedAccept,
      declineLabel:
          isDeclining ? l10n.requestFeedDeclining : l10n.requestFeedDecline,
      onAccept: onAccept,
      onDecline: onDecline,
      acceptEnabled: enabled,
      declineEnabled: enabled,
      requestId: request.id,
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

  final JeeberRequestTier? tier;
  final int? secondsRemaining;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (tier case final knownTier?)
          _TierChip(
            tier: knownTier,
            colorScheme: colorScheme,
            textTheme: textTheme,
            l10n: l10n,
          ),
        if (tier != null && secondsRemaining != null) const Spacer(),
        if (secondsRemaining case final seconds?)
          _CountdownBadge(
            secondsRemaining: seconds,
            colorScheme: colorScheme,
            textTheme: textTheme,
            l10n: l10n,
          ),
      ],
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({
    required this.tier,
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
  });

  final JeeberRequestTier tier;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  String _label() => switch (tier) {
        JeeberRequestTier.light => l10n.requestFeedTierLight,
        JeeberRequestTier.standard => l10n.requestFeedTierStandard,
        JeeberRequestTier.bulk => l10n.requestFeedTierBulk,
        JeeberRequestTier.flash => l10n.requestFeedTierFlash,
      };

  Color _background() => switch (tier) {
        JeeberRequestTier.light => colorScheme.tertiaryContainer,
        JeeberRequestTier.standard => colorScheme.secondaryContainer,
        JeeberRequestTier.bulk => colorScheme.primaryContainer,
        JeeberRequestTier.flash => colorScheme.primaryContainer,
      };

  Color _foreground() => switch (tier) {
        JeeberRequestTier.light => colorScheme.onTertiaryContainer,
        JeeberRequestTier.standard => colorScheme.onSecondaryContainer,
        JeeberRequestTier.bulk => colorScheme.onPrimaryContainer,
        JeeberRequestTier.flash => colorScheme.onPrimaryContainer,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.twoXSmall,
      ),
      decoration: BoxDecoration(
        color: _background(),
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Text(
        _label(),
        key: const Key('requestFeed.card.tierChip'),
        style: textTheme.labelMedium?.copyWith(
          color: _foreground(),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({
    required this.secondsRemaining,
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
  });

  final int secondsRemaining;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
          child: _LocationText(
            label: label,
            value: value,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ),
      ],
    );
  }
}

class _LocationText extends StatelessWidget {
  const _LocationText({
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
        _DistanceBadge(
          label: distanceLabel,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(width: Spacing.medium),
        _EarningsBadge(
          label: earningsLabel,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
      ],
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({
    required this.label,
    required this.colorScheme,
    required this.textTheme,
  });

  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.route_outlined,
          size: Sizes.medium,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Text(
          label,
          key: const Key('requestFeed.card.distance'),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EarningsBadge extends StatelessWidget {
  const _EarningsBadge({
    required this.label,
    required this.colorScheme,
    required this.textTheme,
  });

  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.payments_outlined,
          size: Sizes.medium,
          color: colorScheme.primary,
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Text(
          label,
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
          child: _DeclineButton(
            label: declineLabel,
            enabled: declineEnabled,
            onTap: onDecline,
            requestId: requestId,
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: _AcceptButton(
            label: acceptLabel,
            enabled: acceptEnabled,
            onTap: onAccept,
            requestId: requestId,
          ),
        ),
      ],
    );
  }
}

class _DeclineButton extends StatelessWidget {
  const _DeclineButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.requestId,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'request_feed_decline_$requestId',
      container: true,
      button: true,
      child: OmdsPrimaryButton(
        key: Key('requestFeed.card.decline.$requestId'),
        text: label,
        variant: OmdsButtonVariant.outlined,
        isEnabled: enabled,
        onTap: onTap,
      ),
    );
  }
}

class _AcceptButton extends StatelessWidget {
  const _AcceptButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.requestId,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'request_feed_accept_$requestId',
      container: true,
      button: true,
      child: OmdsPrimaryButton(
        key: Key('requestFeed.card.accept.$requestId'),
        text: label,
        isEnabled: enabled,
        onTap: onTap,
      ),
    );
  }
}

