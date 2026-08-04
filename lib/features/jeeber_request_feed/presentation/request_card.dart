import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_tier_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../cubit/request_feed_state.dart';
import '../data/request_feed_models.dart';

/// The accept/decline request card of the standalone jeeber feed
/// (JEEB-66 / T-mobile-013), rebuilt on the redesign-2026-08 kit.
///
/// Structure is unchanged — tier + countdown header, pickup/dropoff, the
/// distance/earnings meta row, then the two-up decline/accept action row. What
/// changed is the vocabulary: the hand-rolled outlined `Container` is now
/// [JeebOutlinedCard] (outline over shadow, r16, 24px page gutter), the tier
/// pill is [JeebTierChip] (one treatment for every tier, so the eye reads
/// *which* tier rather than a colour-coded severity that does not exist), the
/// location captions are [JeebSectionLabel]s, and both buttons are
/// [JeebCtaButton] pills. Accept is the periwinkle pill, decline the outline —
/// **no orange**: the board rations the accent to one do-it-now moment per
/// screen, and a list of cards has no such single moment.
///
/// The action row rides [JeebOutlinedCard.actions] so the kit owns the gap
/// between the body and the decision.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.actionStatus,
    required this.secondsRemaining,
    required this.onAccept,
    required this.onDecline,
  });

  /// Row gutter — the board's 24px page margin, matching `JeeberFeedCard`.
  static const EdgeInsetsGeometry rowPadding = EdgeInsetsDirectional.symmetric(
    horizontal: Spacing.xLarge,
    vertical: Spacing.xSmall,
  );

  final DeliveryRequest request;
  final RequestActionStatus actionStatus;

  /// Seconds left on a server-supplied per-card deadline. `null` hides the
  /// countdown and leaves actions enabled until the snapshot drops the row.
  final int? secondsRemaining;

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  bool get _actionsLocked =>
      actionStatus != RequestActionStatus.idle ||
      (secondsRemaining != null && secondsRemaining! <= 0);

  @override
  Widget build(BuildContext context) {
    final bool enabled = !_actionsLocked;
    return Padding(
      padding: rowPadding,
      child: JeebOutlinedCard(
        key: Key('requestFeed.card.${request.id}'),
        actions: _CardActions(
          request: request,
          actionStatus: actionStatus,
          enabled: enabled,
          onAccept: enabled ? onAccept : () {},
          onDecline: enabled ? onDecline : () {},
        ),
        child: _CardBody(
          request: request,
          secondsRemaining: secondsRemaining,
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.request, required this.secondsRemaining});

  final DeliveryRequest request;
  final int? secondsRemaining;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (request.tier != null || secondsRemaining != null) ...[
          _CardHeader(tier: request.tier, secondsRemaining: secondsRemaining),
          const SizedBox(height: Spacing.medium),
        ],
        _Locations(request: request),
        const SizedBox(height: Spacing.medium),
        _Metadata(request: request),
      ],
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.tier, required this.secondsRemaining});

  /// Above this text scale a tier chip and a countdown can no longer share one
  /// line, so the row sheds the chip — the tier is the most re-derivable thing
  /// here (the same call, and the same threshold, `JeeberFeedCard` makes).
  static const double largeTextScaleThreshold = 1.5;

  final JeeberRequestTier? tier;
  final int? secondsRemaining;

  @override
  Widget build(BuildContext context) {
    final bool crowded =
        secondsRemaining != null &&
        MediaQuery.textScalerOf(context).scale(1) > largeTextScaleThreshold;
    final JeeberRequestTier? shownTier = crowded ? null : tier;

    if (secondsRemaining case final seconds?) {
      final Widget countdown = _CountdownBadge(secondsRemaining: seconds);
      if (shownTier == null) return countdown;
      return Row(
        children: [
          _TierChip(tier: shownTier),
          const SizedBox(width: Spacing.xSmall),
          // Expanded (not Spacer): the slack collects between the chip and the
          // countdown, so the countdown hugs the end edge in both directions
          // and ELLIPSIZES rather than pushing the row past the card.
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: countdown,
            ),
          ),
        ],
      );
    }
    if (shownTier == null) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: _TierChip(tier: shownTier),
    );
  }
}

/// The board's tier pill — one treatment for every tier, so the eye reads
/// *which* tier, not a colour-coded severity the product never defined. Same
/// app-tier → kit-glyph pairing `JeeberFeedCard` uses.
class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier});

  final JeeberRequestTier tier;

  @override
  Widget build(BuildContext context) {
    return JeebTierChip(
      key: const Key('requestFeed.card.tierChip'),
      tier: _kitTier(tier),
      label: _label(AppLocalizations.of(context)),
    );
  }

  String _label(AppLocalizations l10n) => switch (tier) {
    JeeberRequestTier.light => l10n.requestFeedTierLight,
    JeeberRequestTier.standard => l10n.requestFeedTierStandard,
    JeeberRequestTier.bulk => l10n.requestFeedTierBulk,
    JeeberRequestTier.flash => l10n.requestFeedTierFlash,
  };

  JeebTier _kitTier(JeeberRequestTier tier) => switch (tier) {
    JeeberRequestTier.flash => JeebTier.flash,
    JeeberRequestTier.light => JeebTier.eco,
    JeeberRequestTier.standard => JeebTier.standard,
    JeeberRequestTier.bulk => JeebTier.express,
  };
}

/// Muted secondary ink (countdown, captions, distance). Falls back the way the
/// `context.jeebText`/`jeebRoles` accessors do rather than `!`-asserting the
/// extension, so a bare `ThemeData.light()` widget host still renders.
Color _mutedInk(BuildContext context) =>
    (Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.light())
        .mutedText;

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({required this.secondsRemaining});

  final int secondsRemaining;

  @override
  Widget build(BuildContext context) {
    final Color ink = _mutedInk(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: Sizes.medium, color: ink),
        const SizedBox(width: Spacing.twoXSmall),
        Flexible(
          child: Text(
            AppLocalizations.of(context).requestFeedExpiresIn(secondsRemaining),
            style: context.jeebText.caption.copyWith(color: ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Locations extends StatelessWidget {
  const _Locations({required this.request});

  final DeliveryRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LocationRow(
          icon: Icons.adjust,
          label: l10n.requestFeedPickupLabel,
          value: request.pickup.label,
        ),
        const SizedBox(height: Spacing.small),
        _LocationRow(
          icon: Icons.location_on_outlined,
          label: l10n.requestFeedDropoffLabel,
          value: request.dropoff.label,
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
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    // Two pins per row, two rows per card: `primary` here spent the accent four
    // times over. Muted, like every other glyph on this card.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: Sizes.large, color: _mutedInk(context)),
        const SizedBox(width: Spacing.small),
        Expanded(child: _LocationText(label: label, value: value)),
      ],
    );
  }
}

class _LocationText extends StatelessWidget {
  const _LocationText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The kit owns the casing (locale-gated) and the tracking — never
        // `.toUpperCase()` at the call site.
        JeebSectionLabel(label, small: true),
        const SizedBox(height: Spacing.twoXSmall),
        Text(
          value,
          style: context.jeebText.body.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.request});

  final DeliveryRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        // Both halves flex so a long distance/currency string ellipsizes
        // instead of painting an overflow stripe on a 360dp handset.
        Flexible(
          child: _DistanceBadge(
            label: l10n.requestFeedDistance(
              request.estimatedDistanceKm.toStringAsFixed(1),
            ),
          ),
        ),
        const SizedBox(width: Spacing.medium),
        Flexible(
          child: _EarningsBadge(
            label: l10n.requestFeedEarnings(
              request.potentialEarnings.toStringAsFixed(2),
              request.currency,
            ),
          ),
        ),
      ],
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final Color ink = _mutedInk(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.route_outlined, size: Sizes.medium, color: ink),
        const SizedBox(width: Spacing.twoXSmall),
        Flexible(
          child: Text(
            label,
            key: const Key('requestFeed.card.distance'),
            style: context.jeebText.bodySmall.copyWith(color: ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// The money figure — the card's most-read number, so it takes `onSurface`,
/// the bright ink R10 gives every offer price. The accent stays a CTA.
class _EarningsBadge extends StatelessWidget {
  const _EarningsBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.payments_outlined, size: Sizes.medium, color: ink),
        const SizedBox(width: Spacing.twoXSmall),
        Flexible(
          child: Text(
            label,
            key: const Key('requestFeed.card.earnings'),
            style: context.jeebText.cardTitle.copyWith(color: ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.request,
    required this.actionStatus,
    required this.enabled,
    required this.onAccept,
    required this.onDecline,
  });

  /// Both pills share the outline height and one label style so the two-up row
  /// reads as one control, not as a large button next to a small one.
  static const double pillHeight = JeebCtaButton.outlineHeight;

  final DeliveryRequest request;
  final RequestActionStatus actionStatus;
  final bool enabled;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bool isAccepting = actionStatus == RequestActionStatus.accepting;
    final bool isDeclining = actionStatus == RequestActionStatus.declining;
    final TextStyle labelStyle = context.jeebText.cardTitle;
    return Row(
      children: [
        Expanded(
          child: JeebCtaButton.outline(
            key: Key('requestFeed.card.decline.${request.id}'),
            identifier: 'request_feed_decline_${request.id}',
            label: isDeclining
                ? l10n.requestFeedDeclining
                : l10n.requestFeedDecline,
            height: pillHeight,
            labelStyle: labelStyle,
            isEnabled: enabled,
            onTap: onDecline,
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: JeebCtaButton.primary(
            key: Key('requestFeed.card.accept.${request.id}'),
            identifier: 'request_feed_accept_${request.id}',
            label: isAccepting
                ? l10n.requestFeedAccepting
                : l10n.requestFeedAccept,
            height: pillHeight,
            labelStyle: labelStyle,
            isEnabled: enabled,
            onTap: onAccept,
          ),
        ),
      ],
    );
  }
}
