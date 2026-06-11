import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_tier_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/client_home_request.dart';

/// Active delivery card matching the Figma design (node 56611:18887).
///
/// Layout: avatar | (title + tier badge, destination, progress bar,
/// progress labels, optional "Track my order" CTA). Sits flush in the home
/// list and is separated from siblings by a hairline [Divider].
///
/// The card is composed entirely of OMDS primitives — [OmdsProfileAvatar],
/// [OmdsPrimaryButton], plus tokenized [LinearProgressIndicator]. No raw
/// `FilledButton`, no `CircleAvatar`, no hardcoded colors.
class ActiveOrderCard extends StatelessWidget {
  const ActiveOrderCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  final ClientHomeRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'orders_active_card_${request.id}',
      child: Padding(
        key: Key('active-request-card-${request.id}'),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.xSmall,
        ),
        child: _ActiveOrderColumn(
          request: request,
          onTap: onTap,
          divider: Divider(height: 1, color: colorScheme.outlineVariant),
        ),
      ),
    );
  }
}

class _ActiveOrderColumn extends StatelessWidget {
  const _ActiveOrderColumn({
    required this.request,
    required this.onTap,
    required this.divider,
  });

  final ClientHomeRequest request;
  final VoidCallback onTap;
  final Widget divider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActiveOrderRow(request: request, onTap: onTap),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: Spacing.xSmall),
          child: divider,
        ),
      ],
    );
  }
}

class _ActiveOrderRow extends StatelessWidget {
  const _ActiveOrderRow({required this.request, required this.onTap});

  final ClientHomeRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActiveOrderAvatar(initial: _initial(request.title)),
        const SizedBox(width: Spacing.twoXSmall),
        Expanded(
          child: _ActiveOrderBody(request: request, onTap: onTap),
        ),
      ],
    );
  }

  static String _initial(String title) {
    final trimmed = title.trim();
    return trimmed.isEmpty ? '?' : trimmed[0];
  }
}

class _ActiveOrderAvatar extends StatelessWidget {
  const _ActiveOrderAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsProfileAvatar(
      initial: initial,
      size: Sizes.threeXLarge,
      backgroundColor: colorScheme.surfaceContainerHigh,
      initialColor: colorScheme.primary,
    );
  }
}

class _ActiveOrderBody extends StatelessWidget {
  const _ActiveOrderBody({required this.request, required this.onTap});

  final ClientHomeRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActiveOrderHeader(title: request.title, tier: request.tier),
        const SizedBox(height: Spacing.twoXSmall),
        _ActiveOrderDestination(label: request.summaryLine),
        const SizedBox(height: Spacing.medium),
        _ActiveOrderProgressBar(progressStep: request.progressStep),
        const SizedBox(height: Spacing.small),
        const _ActiveOrderProgressLabels(),
        if (_canTrack(request.status))
          _TrackOrderButton(requestId: request.id, onTap: onTap),
      ],
    );
  }

  /// The "Track my order" CTA shows once a Jeeber is engaged and the order is
  /// physically trackable — accepted, at pickup, or en route. A request that is
  /// still merely searching for a Jeeber has nothing to track yet.
  static bool _canTrack(ClientRequestStatus s) =>
      s == ClientRequestStatus.accepted ||
      s == ClientRequestStatus.atPickup ||
      s == ClientRequestStatus.enRoute;
}

class _ActiveOrderHeader extends StatelessWidget {
  const _ActiveOrderHeader({required this.title, required this.tier});

  final String title;
  final ClientRequestTier tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        ClientHomeTierBadge(tier: tier),
      ],
    );
  }
}

/// Tier chip used by every home-tab card (In Progress / Pending / Replies).
/// Picks its color from [JeebTierColors] so the same theme extension drives
/// the visual treatment everywhere.
class ClientHomeTierBadge extends StatelessWidget {
  const ClientHomeTierBadge({super.key, required this.tier});

  final ClientRequestTier tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tokens = theme.extension<JeebTierColors>();
    final color = _colorFor(tokens) ?? theme.colorScheme.tertiary;
    final label = _labelFor(l10n);
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }

  Color? _colorFor(JeebTierColors? tokens) {
    if (tokens == null) return null;
    switch (tier) {
      case ClientRequestTier.flash:
        return tokens.flash;
      case ClientRequestTier.express:
        return tokens.express;
      case ClientRequestTier.standard:
        return tokens.standard;
      case ClientRequestTier.unknown:
        return null;
    }
  }

  String _labelFor(AppLocalizations l10n) {
    switch (tier) {
      case ClientRequestTier.flash:
        return l10n.tierSelectionTierFlash;
      case ClientRequestTier.express:
        return l10n.tierSelectionTierExpress;
      case ClientRequestTier.standard:
        return l10n.tierSelectionTierStandard;
      case ClientRequestTier.unknown:
        return '';
    }
  }
}

class _ActiveOrderDestination extends StatelessWidget {
  const _ActiveOrderDestination({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
        letterSpacing: 0.4,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ActiveOrderProgressBar extends StatelessWidget {
  const _ActiveOrderProgressBar({required this.progressStep});

  /// 0=Ordered, 1=Picked, 2=InTransit, 3=AtDoor/Done.
  final int progressStep;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: OmdsBorderRadius.twoXSmall,
      child: LinearProgressIndicator(
        value: _progressFor(progressStep),
        minHeight: Sizes.twoXSmall,
        backgroundColor: colorScheme.outlineVariant,
        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primaryContainer),
      ),
    );
  }

  static double _progressFor(int step) {
    final clamped = step.clamp(0, 3).toDouble();
    return clamped / 3.0;
  }
}

class _ActiveOrderProgressLabels extends StatelessWidget {
  const _ActiveOrderProgressLabels();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ProgressStepLabel(text: l10n.homeStageOrdered),
        _ProgressStepLabel(text: l10n.homeStagePicked),
        _ProgressStepLabel(text: l10n.homeStageInTransit),
      ],
    );
  }
}

class _ProgressStepLabel extends StatelessWidget {
  const _ProgressStepLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: theme.colorScheme.onSecondaryContainer,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _TrackOrderButton extends StatelessWidget {
  const _TrackOrderButton({required this.requestId, required this.onTap});

  final String requestId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: Spacing.small),
        child: SizedBox(
          height: Sizes.twoXLarge,
          child: Semantics(
            identifier: 'orders_track_order_button_$requestId',
            button: true,
            child: OmdsPrimaryButton(
              key: Key('active-track-order-$requestId'),
              text: AppLocalizations.of(context).homeTrackOrderCta,
              onTap: onTap,
              borderRadius: OmdsBorderRadius.pill,
            ),
          ),
        ),
      ),
    );
  }
}
